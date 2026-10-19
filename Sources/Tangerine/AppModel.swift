import AppKit
import CoreImage
import PDFKit
import SwiftUI
import Vision

struct Job: Identifiable {
  let id = UUID()
  let title: String
  var state: String = "Waiting"
  var outputs: [URL] = []
  var error: String?
}

struct WorkRequest {
  let inputs: [URL]
  let operation: String
  let format: String
  let options: [String: Any]
  let destination: URL?
}

struct WorkerResult {
  let outputs: [URL]
  let errors: [String]
}

final class Worker: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var cancelled = false
  func cancel() {
    lock.lock()
    cancelled = true
    let p = process
    lock.unlock()
    if let p, p.isRunning { p.terminate() }
  }
  private func isCancelled() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }
  func run(_ work: WorkRequest) throws -> WorkerResult {
    let fm = FileManager.default
    let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: temp) }
    var options = work.options
    if work.operation == "convert", !["jpg", "png", "pptx"].contains(work.format) {
      var overrides: [String: [String]] = [:]
      for input in work.inputs where input.pathExtension.lowercased() == "pdf" {
        overrides[input.resolvingSymlinksInPath().path] = try NativeAnalysis.pdfText(
          input, password: options["password"] as? String ?? "", cancelled: { self.isCancelled() })
      }
      if !overrides.isEmpty { options["textOverrides"] = overrides }
    }
    if work.operation == "removeBackground" {
      var prepared: [String: String] = [:]
      for (index, input) in work.inputs.enumerated() {
        if isCancelled() { throw CancellationError() }
        let output = temp.appendingPathComponent("foreground-\(index).png")
        try NativeAnalysis.removeBackground(input, to: output)
        if isCancelled() { throw CancellationError() }
        prepared[input.resolvingSymlinksInPath().path] = output.path
      }
      options["preparedImages"] = prepared
    }
    var payload: [String: Any] = [
      "inputs": work.inputs.map(\.path), "operation": work.operation, "format": work.format,
      "options": options,
    ]
    if let destination = work.destination { payload["destination"] = destination.path }
    let input = temp.appendingPathComponent("request.json")
    try JSONSerialization.data(withJSONObject: payload).write(to: input)
    let p = Process()
    let bundled = Bundle.main.resourceURL?.appendingPathComponent("engine/tangerine-engine")
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    if let bundled, fm.isExecutableFile(atPath: bundled.path) {
      p.executableURL = bundled
      p.arguments = [input.path]
    } else {
      p.executableURL = root.appendingPathComponent(".venv/bin/python3")
      p.arguments = [root.appendingPathComponent("Resources/engine.py").path, input.path]
    }
    let output = temp.appendingPathComponent("result.json")
    let errors = temp.appendingPathComponent("error.log")
    fm.createFile(atPath: output.path, contents: nil)
    fm.createFile(atPath: errors.path, contents: nil)
    let stdout = try FileHandle(forWritingTo: output)
    let stderr = try FileHandle(forWritingTo: errors)
    defer {
      try? stdout.close()
      try? stderr.close()
    }
    p.standardOutput = stdout
    p.standardError = stderr
    lock.lock()
    if cancelled {
      lock.unlock()
      throw CancellationError()
    }
    process = p
    do {
      try p.run()
      lock.unlock()
    } catch {
      lock.unlock()
      throw error
    }
    p.waitUntilExit()
    lock.lock()
    process = nil
    let wasCancelled = cancelled
    lock.unlock()
    if wasCancelled { throw CancellationError() }
    let data = try Data(contentsOf: output)
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      let log = (try? String(contentsOf: errors)) ?? ""
      throw AppError(
        log.isEmpty
          ? "The conversion engine returned no result. Run scripts/bootstrap.sh and rebuild."
          : String(log.suffix(2000)))
    }
    if let error = object["error"] as? String { throw AppError(error) }
    guard p.terminationStatus == 0, let paths = object["outputs"] as? [String] else {
      throw AppError("The conversion engine failed to produce output.")
    }
    let batchErrors = (object["errors"] as? [[String: String]] ?? []).map {
      "\(URL(fileURLWithPath: $0["input"] ?? "").lastPathComponent): \($0["error"] ?? "Unknown error")"
    }
    return WorkerResult(outputs: paths.map { URL(fileURLWithPath: $0) }, errors: batchErrors)
  }
}

struct AppError: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

enum NativeAnalysis {
  static func recognize(_ image: CGImage) throws -> [VNRecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.automaticallyDetectsLanguage = true
    try VNImageRequestHandler(cgImage: image).perform([request])
    return request.results ?? []
  }
  static func pdfText(_ url: URL, password: String, cancelled: () -> Bool = { false }) throws
    -> [String]
  {
    guard let doc = PDFDocument(url: url) else { throw AppError("Unable to read PDF.") }
    if doc.isLocked && !doc.unlock(withPassword: password) {
      throw AppError("Enter the PDF password in Advanced options.")
    }
    return try (0..<doc.pageCount).map { i in
      if cancelled() { throw CancellationError() }
      guard let page = doc.page(at: i) else { return "" }
      let text = page.string ?? ""
      if text.trimmingCharacters(in: .whitespacesAndNewlines).count > 15 { return text }
      let bounds = page.bounds(for: .mediaBox)
      let thumbnail = page.thumbnail(
        of: NSSize(width: bounds.width * 2, height: bounds.height * 2), for: .mediaBox)
      guard let cg = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return text
      }
      return try recognize(cg).compactMap { $0.topCandidates(1).first?.string }.joined(
        separator: "\n")
    }
  }
  static func removeBackground(_ url: URL, to output: URL) throws {
    guard let image = NSImage(contentsOf: url),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { throw AppError("Cannot read this image for background removal.") }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cg)
    do {
      try handler.perform([request])
    } catch {
      // Virtualized Macs may lack the accelerator needed by Vision's default
      // inference context. Retry once on CPU, including on older macOS SDKs.
      request.usesCPUOnly = true
      try handler.perform([request])
    }
    guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
      throw AppError("No foreground subject was detected. Try a photo with a distinct subject.")
    }
    let buffer = try observation.generateMaskedImage(
      ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
    let result = CIImage(cvPixelBuffer: buffer)
    let context = CIContext()
    try context.writePNGRepresentation(
      of: result, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
  }
  static func regions(_ url: URL, faces: Bool) throws -> [[String: Double]] {
    guard let image = NSImage(contentsOf: url),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { throw AppError("The image cannot be read by Vision.") }
    let boxes: [CGRect]
    if faces {
      let request = VNDetectFaceRectanglesRequest()
      try VNImageRequestHandler(cgImage: cg).perform([request])
      boxes = (request.results ?? []).map(\.boundingBox)
    } else {
      boxes = try recognize(cg).map(\.boundingBox)
    }
    return boxes.map {
      [
        "x": max(0, $0.minX - 0.005), "y": max(0, 1 - $0.maxY - 0.005),
        "width": min(1 - $0.minX, $0.width + 0.005), "height": min($0.maxY, $0.height + 0.005),
      ]
    }
  }
}

@MainActor final class AppModel: ObservableObject {
  @Published var files: [URL] = []
  @Published var selectedCategory = "all"
  @Published var query = ""
  @Published var jobs: [Job] = []
  @Published var selectedTool: Tool?
  @Published var selectedFormat: ConversionChoice?
  @Published var alert: String?
  @Published var destination: URL?
  @Published var isBusy = false
  @Published var activeTab = "convert"
  @Published var floatFiles: [URL] = [] {
    didSet { UserDefaults.standard.set(floatFiles.map(\.path), forKey: "shelfFiles") }
  }
  @Published var toolFiles: [URL] = []
  @Published var showSettings = false
  @Published var showKeyboardMenu = false
  @AppStorage("convertWheelKey") var convertWheelKey = "shift"
  @AppStorage("toolsWheelKey") var toolsWheelKey = "command"
  @AppStorage("actionsWheelKey") var actionsWheelKey = "control"
  init() {
    floatFiles = (UserDefaults.standard.stringArray(forKey: "shelfFiles") ?? []).map {
      URL(fileURLWithPath: $0)
    }.filter { FileManager.default.fileExists(atPath: $0.path) }
  }
  @AppStorage("globalWheelEnabled") var globalWheelEnabled = true
  @AppStorage("revealAfterConversion") var revealAfterConversion = false
  private var queue: [(UUID, WorkRequest)] = []
  private var worker: Worker?
  var formats: [String] { Catalog.formats(for: files) }
  var tools: [Tool] {
    (files.isEmpty ? Tool.all : Catalog.tools(for: files)).filter {
      (selectedCategory == "all" || $0.categories.contains(selectedCategory))
        && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
          || $0.detail.localizedCaseInsensitiveContains(query))
    }
  }
  func setWheelKey(_ mode: String, _ key: String) {
    guard ["shift", "command", "control", "option"].contains(key) else { return }
    let old =
      mode == "convert" ? convertWheelKey : mode == "tools" ? toolsWheelKey : actionsWheelKey
    if mode != "convert", convertWheelKey == key { convertWheelKey = old }
    if mode != "tools", toolsWheelKey == key { toolsWheelKey = old }
    if mode != "actions", actionsWheelKey == key { actionsWheelKey = old }
    if mode == "convert" {
      convertWheelKey = key
    } else if mode == "tools" {
      toolsWheelKey = key
    } else {
      actionsWheelKey = key
    }
  }
  func keySymbol(_ key: String) -> String {
    ["shift": "⇧", "command": "⌘", "control": "⌃", "option": "⌥"][key] ?? key
  }
  func add(_ urls: [URL]) {
    for url in urls where !files.contains(url) { files.append(url) }
  }
  func browse() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    if panel.runModal() == .OK { add(panel.urls) }
  }
  func chooseDestination() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.prompt = "Choose output folder"
    if panel.runModal() == .OK { destination = panel.url }
  }
  func configure(_ tool: Tool, inputs: [URL]? = nil) {
    let urls = inputs ?? files
    guard !urls.isEmpty else {
      alert = "Add files before choosing a tool."
      return
    }
    guard Catalog.tools(for: urls).contains(tool) else {
      alert = "This tool cannot process the selected combination of files."
      return
    }
    toolFiles = urls
    selectedTool = tool
  }
  func submit(
    operation: String = "convert", format: String = "", options: [String: Any] = [:],
    inputs: [URL]? = nil
  ) {
    let urls = inputs ?? files
    guard !urls.isEmpty else {
      alert = "Add files to get started."
      return
    }
    let title =
      operation == "convert"
      ? "Convert to \(format.uppercased())"
      : Tool.all.first { $0.id == operation }?.name ?? operation
    let job = Job(title: "\(title) · \(urls.count) file\(urls.count == 1 ? "" : "s")")
    jobs.insert(job, at: 0)
    queue.append(
      (
        job.id,
        .init(
          inputs: urls, operation: operation, format: format, options: options,
          destination: destination)
      ))
    processNext()
  }
  private func processNext() {
    guard !isBusy, !queue.isEmpty else { return }
    isBusy = true
    let (id, request) = queue.removeFirst()
    let worker = Worker()
    self.worker = worker
    update(id) { $0.state = "Processing locally…" }
    Task {
      do {
        let result = try await Task.detached(priority: .userInitiated) { try worker.run(request) }
          .value
        update(id) {
          $0.state =
            result.errors.isEmpty
            ? "Complete" : result.outputs.isEmpty ? "Failed" : "Completed with errors"
          $0.outputs = result.outputs
          $0.error = result.errors.isEmpty ? nil : result.errors.joined(separator: "\n")
        }
        if revealAfterConversion, !result.outputs.isEmpty {
          NSWorkspace.shared.activateFileViewerSelecting(result.outputs)
        }
      } catch is CancellationError { update(id) { $0.state = "Cancelled" } } catch {
        update(id) {
          $0.state = "Failed"
          $0.error = error.localizedDescription
        }
      }
      isBusy = false
      self.worker = nil
      processNext()
    }
  }
  func cancel() {
    worker?.cancel()
    for (id, _) in queue { update(id) { $0.state = "Cancelled" } }
    queue.removeAll()
  }
  private func update(_ id: UUID, _ action: (inout Job) -> Void) {
    if let index = jobs.firstIndex(where: { $0.id == id }) { action(&jobs[index]) }
  }
  func fileAction(_ id: String, urls: [URL]? = nil) {
    let inputs = urls ?? files
    guard !inputs.isEmpty else {
      alert = "Add files first."
      return
    }
    switch id {
    case "copy":
      NSPasteboard.general.clearContents()
      NSPasteboard.general.writeObjects(inputs as [NSURL])
    case "copyPath":
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(inputs.map(\.path).joined(separator: "\n"), forType: .string)
    case "airDrop":
      guard let service = NSSharingService(named: .sendViaAirDrop) else {
        alert = "AirDrop is unavailable on this Mac."
        return
      }
      service.perform(withItems: inputs)
    case "float":
      floatFiles = inputs
      ShelfWindow.shared.show(model: self)
    case "openTerminal":
      var isDir: ObjCBool = false
      FileManager.default.fileExists(atPath: inputs[0].path, isDirectory: &isDir)
      let folder = isDir.boolValue ? inputs[0] : inputs[0].deletingLastPathComponent()
      guard
        let terminal = NSWorkspace.shared.urlForApplication(
          withBundleIdentifier: "com.apple.Terminal")
      else {
        alert = "Terminal is unavailable."
        return
      }
      NSWorkspace.shared.open(
        [folder], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    case "move":
      let panel = NSOpenPanel()
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      panel.prompt = "Move here"
      if panel.runModal() == .OK, let folder = panel.url {
        for source in inputs {
          let target = folder.appendingPathComponent(source.lastPathComponent)
          do {
            try FileManager.default.moveItem(at: source, to: target)
            if let i = files.firstIndex(of: source) { files[i] = target }
          } catch {
            alert = "Could not move \(source.lastPathComponent): \(error.localizedDescription)"
            break
          }
        }
      }
    default: break
    }
  }
}
