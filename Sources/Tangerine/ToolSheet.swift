import AVKit
import ImageIO
import PDFKit
import SwiftUI

struct ToolSheet: View {
  let tool: Tool
  let inputs: [URL]
  @EnvironmentObject var model: AppModel
  @Environment(\.dismiss) var dismiss
  @State private var values: [String: String] = [:]
  @State private var region = CGRect(x: 0, y: 0, width: 1, height: 1)
  @State private var detected: [[String: Double]] = []
  @State private var advanced = "{}"
  @State private var error: String?
  @State private var player: AVPlayer?
  @State private var duration: Double = 0
  @State private var playhead: Double = 0
  @State private var isDetecting = false
  @State private var metadataMode = "remove"
  @State private var annotations: [[String: Any]] = []
  @State private var orderedInputs: [URL] = []
  @State private var videoFrame: NSImage?
  @State private var editVideoRegion = true
  @State private var timeObserver: Any?
  @State private var waveform: [Double] = []
  @State private var pageChoices: [PDFPageChoice] = []
  @State private var appliedPageOrder = ""
  var category: String { FileCategory.of(inputs[0])?.id ?? "" }
  var imageTools: Bool { category == "image" }
  var regionTool: Bool {
    ["cropImage", "cropVideo", "redactImage", "redactVideo", "annotateImage"].contains(tool.id)
  }
  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        Image(systemName: tool.symbol).font(.system(size: 25, weight: .light)).foregroundStyle(
          accent
        ).padding(.trailing, 7)
        VStack(alignment: .leading, spacing: 5) {
          Text(tool.name).font(.system(size: 25, weight: .semibold)).tracking(-0.5)
          Text(tool.detail).font(.system(size: 13)).foregroundStyle(.secondary)
        }
        Spacer()
      }.padding(25)
      Divider()
      HStack(alignment: .top, spacing: 0) {
        VStack(spacing: 12) {
          if category == "video" && regionTool {
            Picker("Preview", selection: $editVideoRegion) {
              Text("Select region").tag(true)
              Text("Play source").tag(false)
            }.pickerStyle(.segmented)
          }
          preview.frame(maxWidth: .infinity, maxHeight: .infinity)
          if category == "audio", !waveform.isEmpty {
            WaveformEditor(
              peaks: waveform, duration: duration,
              start: Binding(get: { number("start", 0) }, set: { values["start"] = String($0) }),
              end: Binding(get: { number("end", 0) }, set: { values["end"] = String($0) }),
              playhead: $playhead, seek: { seek() },
              editable: ["trimAudio", "redactAudio"].contains(tool.id))
          }
          Text(inputs[0].lastPathComponent + (inputs.count > 1 ? " + \(inputs.count-1) more" : ""))
            .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
          if player != nil {
            HStack {
              Button {
                player?.pause()
                playhead = max(0, playhead - 1 / 30)
                seek()
              } label: {
                Image(systemName: "backward.frame")
              }.help("Previous frame")
              Slider(value: $playhead, in: 0...max(duration, 1), onEditingChanged: { _ in seek() })
              Button {
                player?.pause()
                playhead = min(duration, playhead + 1 / 30)
                seek()
              } label: {
                Image(systemName: "forward.frame")
              }.help("Next frame")
              Text(String(format: "%.2fs", playhead)).monospacedDigit().frame(width: 63)
            }.font(.system(size: 12)).buttonStyle(.borderless)
            if ["trimVideo", "trimAudio", "redactVideo", "redactAudio"].contains(tool.id) {
              HStack {
                Button("Set start") { values["start"] = String(format: "%.3f", playhead) }
                Button("Set end") { values["end"] = String(format: "%.3f", playhead) }
                Spacer()
                Button("Preview range") {
                  seek(to: number("start", 0))
                  player?.play()
                }
              }.font(.system(size: 12))
            }
            if ["videoSnapshots", "splitVideo"].contains(tool.id) {
              Button("Add current time") {
                let current = values["times"] ?? ""
                values["times"] =
                  current + (current.isEmpty ? "" : ",") + String(format: "%.3f", playhead)
              }.font(.system(size: 12))
            }
          }
          if tool.combines { orderedFiles }
        }.padding(22).frame(width: 430).frame(maxHeight: .infinity).background(
          Color.black.opacity(0.025))
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            controls
            DisclosureGroup("Advanced options (JSON)") {
              TextEditor(text: $advanced).font(.system(size: 11, design: .monospaced)).frame(
                height: 100
              ).border(.gray.opacity(0.25))
              Text(
                "See docs/ENGINE.md for supported keys. These values override the controls above."
              ).font(.system(size: 11)).foregroundStyle(.secondary)
            }.font(.system(size: 12))
            if let error {
              Text(error).font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled)
            }
          }.padding(22)
        }.frame(width: 330)
      }.frame(height: 460)
      Divider()
      HStack {
        Label("A new copy. Your original stays safe.", systemImage: "lock").font(.system(size: 11))
          .foregroundStyle(.secondary)
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("\(tool.name) →", action: apply).buttonStyle(.borderedProminent).keyboardShortcut(
          .defaultAction)
      }.padding(20)
    }.frame(width: 760).background(paper).foregroundStyle(ink).tint(accent)
      .task { await prepare() }
      .task(id: playhead) {
        if category == "video" && regionTool && editVideoRegion { await refreshVideoFrame() }
      }
      .task(id: editVideoRegion) {
        if editVideoRegion && category == "video" && regionTool { await refreshVideoFrame() }
      }
      .onDisappear {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        player?.pause()
      }
  }
  @ViewBuilder private var preview: some View {
    if imageTools, let image = NSImage(contentsOf: inputs[0]) {
      RegionPreview(
        image: image, region: $region, enabled: regionTool, regions: detected,
        annotations: tool.id == "annotateImage" ? annotations + [annotation()] : [],
        annotationColor: values["color"] ?? "#ff702e", fontSize: number("fontSize", 36),
        stroke: number("stroke", 6)
      )
      .brightness((number("brightness", 1) - 1) * 0.3).contrast(number("contrast", 1)).saturation(
        number("saturation", 1))
    } else if category == "video", regionTool, editVideoRegion, let frame = videoFrame {
      RegionPreview(image: frame, region: $region, enabled: true, regions: [])
    } else if let player {
      NativeMediaPlayer(player: player).clipShape(RoundedRectangle(cornerRadius: 10))
    } else if tool.id == "organizePDF" {
      PDFOrganizer(url: inputs[0], pages: $pageChoices)
    } else if category == "pdf" {
      PDFPreview(url: inputs[0])
    } else {
      VStack(spacing: 15) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: inputs[0].path)).resizable().frame(
          width: 85, height: 85)
        Text("Ready to process locally").foregroundStyle(.secondary)
      }
    }
  }
  private var orderedFiles: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("OUTPUT ORDER").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
      ForEach(Array(orderedInputs.enumerated()), id: \.offset) { i, file in
        HStack {
          Text("\(i+1). \(file.lastPathComponent)").font(.system(size: 11)).lineLimit(1)
          Spacer()
          if i > 0 {
            Button {
              orderedInputs.swapAt(i, i - 1)
            } label: {
              Image(systemName: "arrow.up")
            }
          }
          if orderedInputs.count > 1 {
            Button {
              orderedInputs.remove(at: i)
            } label: {
              Image(systemName: "minus.circle")
            }
          }
        }.buttonStyle(.borderless)
      }
    }.frame(maxHeight: 120)
  }
  @ViewBuilder private var controls: some View {
    switch tool.id {
    case "compress":
      Picker("Preset", selection: string("preset", "balanced")) {
        Text("Smallest").tag("small")
        Text("Balanced").tag("balanced")
        Text("Best quality").tag("high")
      }.onChange(of: values["preset"]) {
        let preset = values["preset"] ?? "balanced"
        values["quality"] = preset == "small" ? "45" : preset == "high" ? "92" : "75"
        values["audioKbps"] = preset == "small" ? "64" : preset == "high" ? "256" : "128"
        values["videoKbps"] = preset == "small" ? "900" : preset == "high" ? "5000" : "1800"
      }
      slider("quality", "Quality", 10...100, 75)
      if imageTools {
        slider("scale", "Image scale", 0.1...1, 1)
        field("targetKB", "Target size (KB, 0 = automatic)", "0")
      }
      if category == "audio" || category == "video" {
        field("audioKbps", "Audio bitrate (kbps)", "128")
        field("targetKB", "Target size (KB, approximate)", "0")
      }
      if category != "pdf" { field("reduction", "Reduce size by (%, 0 = use quality)", "0") }
      if category == "video" { field("videoKbps", "Video bitrate (kbps)", "1800") }
      Text("Compression depends on the source. Already optimized files can grow.").font(
        .system(size: 12)
      ).foregroundStyle(.secondary)
    case "cropImage", "cropVideo":
      regionControls
      Picker("Aspect ratio", selection: string("aspect", "free")) {
        Text("Free").tag("free")
        Text("1:1").tag("1:1")
        Text("4:3").tag("4:3")
        Text("16:9").tag("16:9")
        Text("9:16").tag("9:16")
      }.onChange(of: values["aspect"]) { setAspect() }
      if imageTools {
        field("outputWidth", "Output width (pixels, 0 = crop size)", "0")
        field("outputHeight", "Output height (pixels, 0 = proportional)", "0")
      }
    case "resizeImage":
      field("outputWidth", "Width (pixels, 0 = proportional)", "0")
      field("outputHeight", "Height (pixels, 0 = proportional)", "0")
      slider("scale", "Scale (when dimensions are zero)", 0.1...3, 1)
      Text("Set one dimension to preserve proportions, or both for an exact output size.").font(
        .callout
      ).foregroundStyle(.secondary)
    case "removeBackground":
      Text(
        "Apple Vision identifies the subject on your Mac. The result is saved as a PNG with transparency, at the original size."
      ).font(.callout).foregroundStyle(.secondary)
      Text("For best results, use a photo with a clear subject separated from the background.")
        .font(.callout).foregroundStyle(.secondary)
    case "editImage":
      slider("brightness", "Exposure", 0...2, 1)
      slider("contrast", "Contrast", 0...2, 1)
      slider("saturation", "Saturation", 0...2, 1)
      slider("sharpness", "Sharpness", 0...3, 1)
      field("rotation", "Clockwise rotation (degrees)", "0")
      Picker("Effect", selection: string("effect", "original")) {
        ForEach(["original", "grayscale", "sepia", "invert", "blur"], id: \.self) {
          Text($0.capitalized).tag($0)
        }
      }
    case "annotateImage":
      Picker("Annotation", selection: string("annotationType", "text")) {
        ForEach(["text", "arrow", "rectangle", "ellipse", "callout"], id: \.self) {
          Text($0.capitalized).tag($0)
        }
      }
      field("text", "Text / callout number", "Annotation")
      field("fontSize", "Font size (pixels)", "36")
      field("color", "Color (hex)", "#ff702e")
      field("stroke", "Stroke width", "6")
      regionControls
      Button("Add annotation") {
        annotations.append(annotation())
        values["text"] = ""
      }
      Text(
        "\(annotations.count) saved annotations. The current annotation is also included when you apply."
      ).font(.system(size: 11)).foregroundStyle(.secondary)
    case "frameImage":
      field("background", "Background color", "#fff0df")
      field("color", "Gradient end color", "#ff702e")
      check("gradient", "Use gradient")
      field("spacing", "Padding (pixels)", "60")
      field("radius", "Corner radius", "24")
      backgroundPicker
    case "redactImage", "redactVideo":
      Picker("Cover", selection: string("redaction", "solid")) {
        Text("Solid").tag("solid")
        Text("Blur").tag("blur")
      }
      regionControls
      if imageTools {
        HStack {
          Button("Detect faces") { detect(faces: true) }
          Button("Detect text") { detect(faces: false) }
        }.disabled(isDetecting)
        if isDetecting { ProgressView().controlSize(.small) }
        Text(
          "\(detected.count) detected regions. Inspect the highlighted regions before exporting."
        ).font(.system(size: 12)).foregroundStyle(.secondary)
        Button("Use manual region") { detected = [] }
      } else {
        timeControls
      }
    case "trimVideo", "trimAudio":
      timeControls
      if tool.id == "trimAudio" { check("removeSilence", "Remove silence at the ends") }
    case "redactAudio":
      field("ranges", "Bleep ranges in seconds (start:end)", "0:1")
      Button("Add selected waveform range") {
        let range = String(
          format: "%.3f:%.3f", number("start", 0),
          number("end", 0) > 0 ? number("end", 0) : duration)
        values["ranges"] =
          (values["ranges"] ?? "") + ((values["ranges"] ?? "").isEmpty ? "" : ",") + range
      }
      Text(
        "Separate multiple ranges with commas: 1:2.5, 4:6. Preview the source to choose exact times."
      ).font(.system(size: 12)).foregroundStyle(.secondary)
    case "changeVideoSpeed": slider("speed", "Playback speed", 0.25...4, 2)
    case "normalizeAudio": slider("lufs", "Target loudness (LUFS)", -30 ... -8, -16)
    case "audioChannels":
      Picker("Channels", selection: string("channels", "1")) {
        Text("Mono").tag("1")
        Text("Stereo").tag("2")
      }
    case "audioToVideo":
      Picker("Canvas", selection: string("canvas", "landscape")) {
        Text("Landscape").tag("landscape")
        Text("Portrait").tag("portrait")
        Text("Square").tag("square")
      }
      backgroundPicker
      Text("Without a background image, an orange waveform is rendered on black.").font(
        .system(size: 12)
      ).foregroundStyle(.secondary)
    case "videoSnapshots", "splitVideo":
      field(
        "times", tool.id == "splitVideo" ? "Split points (seconds)" : "Snapshot times (seconds)",
        "1")
      Text("Separate timestamps with commas. Each result is saved in a new folder.").font(
        .system(size: 12)
      ).foregroundStyle(.secondary)
    case "organizePDF":
      field("pages", "Page order", "1")
      Button("Update thumbnails") {
        do { try updatePageOrder() } catch { self.error = error.localizedDescription }
      }

      Text("Reorder or duplicate: 3,1,2,2. Use ranges: 1-4,8. Omitted pages are removed.").font(
        .system(size: 12)
      ).foregroundStyle(.secondary)
      Picker("Rotate all output pages", selection: string("rotation", "0")) {
        Text("0°").tag("0")
        Text("90°").tag("90")
        Text("180°").tag("180")
        Text("270°").tag("270")
      }
    case "removeMetadata":
      Picker("Mode", selection: $metadataMode) {
        Text("Remove all").tag("remove")
        Text("Edit tags").tag("edit")
      }
      Button("Inspect existing metadata", action: inspectMetadata)
      if metadataMode == "edit" {
        field("title", "Title", "")
        field("author", "Author / artist", "")
        field("album", "Album", "")
        field("copyright", "Copyright", "")
      }
      Text(
        "A new copy is written. Files may still contain structural identifiers required by their format."
      ).font(.system(size: 12)).foregroundStyle(.secondary)
    case "createCollage":
      Picker("Layout", selection: string("layout", "grid")) {
        ForEach(["grid", "row", "column", "featured"], id: \.self) { Text($0.capitalized).tag($0) }
      }
      field("spacing", "Spacing", "20")
      field("radius", "Corner radius", "0")
      field("cellSize", "Tile size (pixels)", "600")
      field("background", "Background color", "#fff8ef")
    default:
      Text(
        tool.combines
          ? "Arrange the inputs on the left. All selected files will be combined into one output."
          : "The result will be saved beside the original, or in your chosen output folder."
      ).font(.system(size: 13)).foregroundStyle(.secondary)
    }
  }
  private var regionControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Drag over the preview to select a region.").font(.system(size: 12)).foregroundStyle(
        .secondary)
      HStack {
        coordinate("X", \.origin.x)
        coordinate("Y", \.origin.y)
      }
      HStack {
        coordinate("Width", \.size.width)
        coordinate("Height", \.size.height)
      }
      Text("Coordinates are fractions from 0 to 1.").font(.system(size: 11)).foregroundStyle(
        .secondary)
    }
  }
  private func coordinate(_ title: String, _ key: WritableKeyPath<CGRect, CGFloat>) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
      TextField(
        title,
        value: Binding(
          get: { Double(region[keyPath: key]) }, set: { region[keyPath: key] = CGFloat($0) }),
        format: .number.precision(.fractionLength(3))
      ).textFieldStyle(.roundedBorder)
    }
  }
  private var timeControls: some View {
    VStack(alignment: .leading, spacing: 15) {
      field("start", "Start (seconds)", "0")
      field("end", "End (seconds, 0 = end of file)", "0")
    }
  }
  private var backgroundPicker: some View {
    VStack(alignment: .leading, spacing: 7) {
      Button("Choose background image…") {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.image]
        if p.runModal() == .OK { values["backgroundImage"] = p.url?.path }
      }
      if let name = values["backgroundImage"], !name.isEmpty {
        Text(URL(fileURLWithPath: name).lastPathComponent).font(.system(size: 11))
        Button("Remove background image") { values.removeValue(forKey: "backgroundImage") }
      }
    }
  }
  private func string(_ key: String, _ fallback: String) -> Binding<String> {
    Binding(get: { values[key] ?? fallback }, set: { values[key] = $0 })
  }
  private func number(_ key: String, _ fallback: Double) -> Double {
    Double(values[key] ?? "") ?? fallback
  }
  private func field(_ key: String, _ title: String, _ fallback: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
      TextField(title, text: string(key, fallback)).textFieldStyle(.roundedBorder)
    }
  }
  private func slider(
    _ key: String, _ title: String, _ range: ClosedRange<Double>, _ fallback: Double
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(title)
        Spacer()
        Text(String(format: "%.2f", number(key, fallback))).monospacedDigit().foregroundStyle(
          .secondary)
      }.font(.system(size: 12))
      Slider(
        value: Binding(get: { number(key, fallback) }, set: { values[key] = String($0) }), in: range
      )
    }
  }
  private func check(_ key: String, _ title: String) -> some View {
    Toggle(
      title,
      isOn: Binding(get: { values[key] == "true" }, set: { values[key] = $0 ? "true" : "false" })
    ).font(.system(size: 12))
  }
  private func annotation() -> [String: Any] {
    [
      "type": values["annotationType"] ?? "text", "text": values["text"] ?? "Annotation",
      "x": Double(region.minX), "y": Double(region.minY), "width": Double(region.width),
      "height": Double(region.height),
    ]
  }
  private func apply() {
    do {
      guard let data = advanced.data(using: .utf8),
        let extra = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { throw AppError("Advanced options must be a JSON object.") }
      var options: [String: Any] = [:]
      let numeric: Set<String> = [
        "quality", "scale", "targetKB", "audioKbps", "videoKbps", "outputWidth", "outputHeight",
        "brightness", "contrast", "saturation", "sharpness", "rotation", "fontSize", "stroke",
        "spacing", "radius", "start", "end", "speed", "lufs", "channels", "cellSize", "reduction",
      ]
      for (key, value) in values {
        if numeric.contains(key) {
          guard let n = Double(value), n.isFinite else {
            throw AppError("\(key) must be a number.")
          }
          options[key] = n
        } else if ["gradient", "removeSilence"].contains(key) {
          options[key] = value == "true"
        } else {
          options[key] = value
        }
      }
      if regionTool {
        options["x"] = region.minX
        options["y"] = region.minY
        options["width"] = region.width
        options["height"] = region.height
      }
      if !detected.isEmpty { options["regions"] = detected }
      if tool.id == "annotateImage" { options["annotations"] = annotations + [annotation()] }
      if tool.id == "organizePDF" {
        if values["pages"] != appliedPageOrder { try updatePageOrder() }
        options["pageSelections"] = pageChoices.map { ["page": $0.page, "rotation": $0.rotation] }
      }
      if tool.id == "audioToVideo" {
        let canvas = values["canvas"] ?? "landscape"
        options["outputWidth"] = canvas == "portrait" ? 720 : canvas == "square" ? 1080 : 1280
        options["outputHeight"] = canvas == "portrait" ? 1280 : canvas == "square" ? 1080 : 720
      }
      if tool.id == "removeMetadata" {
        var tags: [String: String] = [:]
        if metadataMode == "edit" {
          for key in ["title", "author", "album", "copyright"] {
            if let value = values[key], !value.isEmpty {
              tags[key == "author" && category != "pdf" && category != "image" ? "artist" : key] =
                value
            }
          }
        }
        options["metadata"] = tags
      }
      for (key, value) in extra { options[key] = value }
      model.submit(
        operation: tool.id, options: options, inputs: orderedInputs.isEmpty ? inputs : orderedInputs
      )
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
  private func seek(to time: Double? = nil) {
    player?.seek(
      to: CMTime(seconds: time ?? playhead, preferredTimescale: 600), toleranceBefore: .zero,
      toleranceAfter: .zero)
  }
  private func prepare() async {
    orderedInputs = inputs
    if ["redactImage", "redactVideo", "annotateImage"].contains(tool.id) {
      region = CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.25)
    }
    if category == "audio" || category == "video" {
      let asset = AVURLAsset(url: inputs[0])
      player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
      duration = (try? await asset.load(.duration).seconds) ?? 0
      if !duration.isFinite { duration = 0 }
      if ["splitVideo", "videoSnapshots"].contains(tool.id) {
        values["times"] = String(format: "%.3f", min(1, duration / 2))
      }
      timeObserver = player?.addPeriodicTimeObserver(
        forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main
      ) { time in
        if player?.rate != 0 {
          playhead = time.seconds
          let end = number("end", 0)
          if end > 0 && time.seconds >= end { player?.pause() }
        }
      }
      if category == "video" { await refreshVideoFrame() }
      if category == "audio" {
        waveform =
          (try? await Task.detached { try await AudioAnalysis.peaks(inputs[0]) }.value) ?? []
      }
    }
    if category == "pdf", let pdf = PDFDocument(url: inputs[0]) {
      values["pages"] = (1...max(1, pdf.pageCount)).map(String.init).joined(separator: ",")
      pageChoices = (0..<pdf.pageCount).map { PDFPageChoice(page: $0 + 1) }
      appliedPageOrder = values["pages"] ?? ""
    }
  }
  private func updatePageOrder() throws {
    var indexes: [Int] = []
    for token in (values["pages"] ?? "1").split(separator: ",") {
      let parts = token.split(separator: "-").compactMap {
        Int($0.trimmingCharacters(in: .whitespaces))
      }
      if parts.count == 2, parts[0] <= parts[1], parts[1] - parts[0] < 10000 {
        indexes.append(contentsOf: parts[0]...parts[1])
      } else if parts.count == 1 {
        indexes.append(parts[0])
      } else {
        throw AppError("Page order contains an invalid range.")
      }
    }
    let count = PDFDocument(url: inputs[0])?.pageCount ?? 0
    guard !indexes.isEmpty, !indexes.contains(where: { $0 < 1 || $0 > count }) else {
      throw AppError("Page order contains an invalid page number.")
    }
    pageChoices = indexes.map { PDFPageChoice(page: $0) }
    appliedPageOrder = values["pages"] ?? ""
    error = nil
  }
  private func refreshVideoFrame() async {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: inputs[0]))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = NSSize(width: 1200, height: 1200)
    if let result = try? await generator.image(
      at: CMTime(seconds: playhead, preferredTimescale: 600)), !Task.isCancelled
    {
      videoFrame = NSImage(cgImage: result.image, size: .zero)
    }
  }
  private func setAspect() {
    guard let aspect = values["aspect"], aspect != "free" else { return }
    let parts = aspect.split(separator: ":").compactMap { Double($0) }
    guard parts.count == 2 else { return }
    let size =
      videoFrame?.size ?? NSImage(contentsOf: inputs[0])?.size ?? NSSize(width: 16, height: 9)
    let target = parts[0] / parts[1]
    let original = size.width / size.height
    if original > target {
      let w = target / original
      region = CGRect(x: (1 - w) / 2, y: 0, width: w, height: 1)
    } else {
      let h = original / target
      region = CGRect(x: 0, y: (1 - h) / 2, width: 1, height: h)
    }
  }
  private func detect(faces: Bool) {
    isDetecting = true
    let url = inputs[0]
    Task {
      do {
        detected = try await Task.detached { try NativeAnalysis.regions(url, faces: faces) }.value
        if detected.isEmpty {
          error = "No \(faces ? "faces":"text") detected. Select a region manually."
        }
      } catch { self.error = error.localizedDescription }
      isDetecting = false
    }
  }
  private func inspectMetadata() {
    var text = ""
    if category == "pdf", let pdf = PDFDocument(url: inputs[0]) {
      text = String(describing: pdf.documentAttributes ?? [:])
    } else if imageTools, let source = CGImageSourceCreateWithURL(inputs[0] as CFURL, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
    {
      text = String(describing: props)
    } else {
      let asset = AVURLAsset(url: inputs[0])
      Task {
        let metadata = (try? await asset.load(.metadata)) ?? []
        var lines: [String] = []
        for item in metadata {
          let value = try? await item.load(.stringValue)
          lines.append("\(item.identifier?.rawValue ?? "Tag"): \(value ?? "")")
        }
        error = lines.isEmpty ? "No embedded metadata found." : lines.joined(separator: "\n")
      }
      return
    }
    error = text.isEmpty ? "No embedded metadata found." : text
  }
}

struct RegionPreview: View {
  let image: NSImage
  @Binding var region: CGRect
  let enabled: Bool
  let regions: [[String: Double]]
  var annotations: [[String: Any]] = []
  var annotationColor = "#ff702e"
  var fontSize: Double = 36
  var stroke: Double = 6
  var body: some View {
    GeometryReader { geometry in
      let ratio = image.size.width / image.size.height
      let width = min(geometry.size.width, geometry.size.height * ratio)
      let height = width / ratio
      ZStack(alignment: .topLeading) {
        Image(nsImage: image).resizable().frame(width: width, height: height)
        AnnotationOverlay(
          annotations: annotations, color: annotationColor, fontSize: fontSize, stroke: stroke,
          sourceWidth: image.size.width
        ).frame(width: width, height: height).allowsHitTesting(false)
        if enabled {
          Rectangle().fill(.black.opacity(0.18))
          Rectangle().stroke(accent, lineWidth: 2).background(surface.opacity(0.04)).frame(
            width: width * region.width, height: height * region.height
          ).offset(x: width * region.minX, y: height * region.minY)
          ForEach(Array(regions.enumerated()), id: \.offset) { _, r in
            Rectangle().stroke(.red, lineWidth: 2).frame(
              width: width * (r["width"] ?? 0), height: height * (r["height"] ?? 0)
            ).offset(x: width * (r["x"] ?? 0), y: height * (r["y"] ?? 0))
          }
        }
      }.frame(width: width, height: height).clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle()).gesture(
          DragGesture(minimumDistance: 1).onChanged { drag in
            guard enabled else { return }
            let x1 = min(1, max(0, drag.startLocation.x / width))
            let y1 = min(1, max(0, drag.startLocation.y / height))
            let x2 = min(1, max(0, drag.location.x / width))
            let y2 = min(1, max(0, drag.location.y / height))
            region = CGRect(
              x: min(x1, x2), y: min(y1, y2), width: max(0.001, abs(x2 - x1)),
              height: max(0.001, abs(y2 - y1)))
          }
        ).position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
  }
}

struct AnnotationOverlay: View {
  let annotations: [[String: Any]]
  let color: String
  let fontSize: Double
  let stroke: Double
  let sourceWidth: Double
  var body: some View {
    Canvas { context, size in
      let scale = size.width / max(sourceWidth, 1)
      let ink = Color(hex: color)
      for annotation in annotations {
        let x = (annotation["x"] as? Double ?? 0.1) * size.width
        let y = (annotation["y"] as? Double ?? 0.1) * size.height
        let w = (annotation["width"] as? Double ?? 0.4) * size.width
        let h = (annotation["height"] as? Double ?? 0.25) * size.height
        let rect = CGRect(x: x, y: y, width: w, height: h)
        let type = annotation["type"] as? String ?? "text"
        let text = annotation["text"] as? String ?? "Annotation"
        if type == "text" {
          context.draw(
            Text(text).font(.system(size: max(8, fontSize * scale))).foregroundColor(ink),
            at: CGPoint(x: x, y: y), anchor: .topLeading)
        } else if type == "rectangle" {
          context.stroke(Path(rect), with: .color(ink), lineWidth: max(1, stroke * scale))
        } else if type == "ellipse" {
          context.stroke(
            Path(ellipseIn: rect), with: .color(ink), lineWidth: max(1, stroke * scale))
        } else if type == "callout" {
          let r = max(20, sourceWidth / 30) * scale
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: 2 * r, height: 2 * r)), with: .color(ink))
          context.draw(
            Text(text).font(.system(size: max(8, fontSize * scale))).foregroundColor(.white),
            at: CGPoint(x: x + r, y: y + r))
        } else if type == "arrow" {
          var path = Path()
          path.move(to: CGPoint(x: x, y: y))
          path.addLine(to: CGPoint(x: x + w, y: y + h))
          context.stroke(path, with: .color(ink), lineWidth: max(1, stroke * scale))
          let angle = atan2(h, w)
          let head = max(18, stroke * 4) * scale
          var arrow = Path()
          arrow.move(to: CGPoint(x: x + w, y: y + h))
          arrow.addLine(
            to: CGPoint(x: x + w - head * cos(angle - 0.5), y: y + h - head * sin(angle - 0.5)))
          arrow.addLine(
            to: CGPoint(x: x + w - head * cos(angle + 0.5), y: y + h - head * sin(angle + 0.5)))
          arrow.closeSubpath()
          context.fill(arrow, with: .color(ink))
        }
      }
    }
  }
}

extension Color {
  init(hex: String) {
    let value =
      UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xff702e
    self.init(
      red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255)
  }
}

struct PDFPreview: NSViewRepresentable {
  let url: URL
  func makeNSView(context: Context) -> PDFView {
    let view = PDFView()
    view.document = PDFDocument(url: url)
    view.autoScales = true
    view.displayMode = .singlePageContinuous
    view.backgroundColor = .clear
    return view
  }
  func updateNSView(_ nsView: PDFView, context: Context) {}
}
