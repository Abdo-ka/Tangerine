import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @EnvironmentObject var model: AppModel
  @State private var targeted = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var tabSelection
  var body: some View {
    HStack(spacing: 0) {
      sidebar.frame(width: 204)
      Divider()
      VStack(spacing: 0) {
        header
        ScrollView {
          VStack(alignment: .leading, spacing: 26) {
            intro
            dropzone
            if !model.files.isEmpty { fileList }
            workspace
            if !model.jobs.isEmpty { history }
          }.padding(32)
        }
        footer
      }.background(paper)
    }
    .background(paper)
    .frame(minWidth: 900, minHeight: 640)
    .foregroundStyle(ink)

    .tint(accent)
    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted, perform: acceptDrop)
    .popover(isPresented: $model.showKeyboardMenu) { KeyboardFileMenu().environmentObject(model) }
    .sheet(item: $model.selectedTool) { tool in
      ToolSheet(tool: tool, inputs: model.toolFiles).environmentObject(model)
    }
    .sheet(item: $model.selectedFormat) { choice in
      ConversionSheet(format: choice.format).environmentObject(model)
    }
    .sheet(isPresented: $model.showSettings) { SettingsView().environmentObject(model) }
    .alert(
      "Tangerine",
      isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })
    ) {
      Button("OK") { model.alert = nil }
    } message: {
      Text(model.alert ?? "")
    }
  }
  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 9) {
        Image(nsImage: tangerineBrandmark).resizable().scaledToFit().frame(width: 38, height: 38)
        Text("Tangerine").font(.system(size: 20, weight: .semibold, design: .rounded))
      }.padding(.top, 37).padding(.bottom, 29)
      Text("YOUR WORKSPACE").font(.system(size: 11, weight: .semibold)).tracking(1.3)
        .foregroundStyle(.secondary).padding(.bottom, 9)
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          categoryButton("all", "All tools", "square.grid.2x2")
          ForEach(FileCategory.all) { category in
            categoryButton(category.id, category.name, category.symbol)
          }
        }
      }.scrollIndicators(.hidden)
      VStack(alignment: .leading, spacing: 9) {
        Image(systemName: "lock.shield").font(.title2).foregroundStyle(
          Color(red: 0.31, green: 0.43, blue: 0.27))
        Text("Private by design").font(.system(size: 13, weight: .semibold))
        Text("Every file is processed on your Mac.").font(.system(size: 12)).foregroundStyle(
          .secondary
        ).fixedSize(horizontal: false, vertical: true)
      }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(
        surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
      Button {
        model.showSettings = true
      } label: {
        Label("Settings", systemImage: "gearshape").font(.system(size: 13)).foregroundStyle(
          .secondary)
      }.buttonStyle(PressFeedbackStyle()).padding(.vertical, 17)
    }.padding(.horizontal, 18).modifier(ChromeMaterial()).foregroundStyle(ink)
  }
  private func categoryButton(_ id: String, _ name: String, _ symbol: String) -> some View {
    Button {
      model.selectedCategory = id
      model.activeTab = "tools"
    } label: {
      HStack(spacing: 11) {
        Image(systemName: symbol).frame(width: 19)
        Text(name)
        Spacer()
        if id == "all" {
          Text("\(Tool.all.count)").font(.system(size: 11, weight: .medium)).padding(.horizontal, 6)
            .padding(.vertical, 2).background(surface.opacity(0.65), in: Capsule())
        }
      }
      .font(.system(size: 13, weight: model.selectedCategory == id ? .semibold : .regular)).padding(
        .horizontal, 11
      ).padding(.vertical, 9)
      .foregroundStyle(model.selectedCategory == id ? accent : ink.opacity(0.8)).background(
        model.selectedCategory == id ? surface.opacity(0.8) : .clear,
        in: RoundedRectangle(cornerRadius: 8))
    }.buttonStyle(PressFeedbackStyle())
  }
  private var header: some View {
    HStack {
      Text("TANGERINE STUDIO").font(.system(size: 11, weight: .medium)).tracking(1.7)
        .foregroundStyle(.secondary)
      Spacer()
      HStack(spacing: 5) {
        Circle().fill(Color.green.opacity(0.7)).frame(width: 5, height: 5)
        Text("On your Mac").font(.system(size: 12))
      }.foregroundStyle(.secondary)
      Button(action: model.browse) { Image(systemName: "plus").padding(6) }.buttonStyle(.borderless)
        .help("Add files (⌘O)")
    }.padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 17).modifier(ChromeMaterial())
  }
  private var intro: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Your files. In good hands.").font(.system(size: 32, weight: .semibold)).tracking(-0.8)
          .foregroundStyle(ink)
        Text("Convert and edit files privately on your Mac.").font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "sparkle").font(.system(size: 31, weight: .ultraLight)).foregroundStyle(
        accent
      ).padding(.trailing, 12)
    }
  }
  private var dropzone: some View {
    Button(action: model.browse) {
      VStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 12).fill(Color.white).frame(width: 44, height: 54)
            .rotationEffect(.degrees(-13)).offset(x: -17, y: 3)
          RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.12)).frame(width: 44, height: 54)
            .rotationEffect(.degrees(12)).offset(x: 16, y: 2)
          Image(systemName: "arrow.down.doc").font(.system(size: 25, weight: .light))
            .foregroundStyle(accent)
        }.frame(height: 65)
        Text(targeted ? "Drop to add your files" : "Drop files to get started").font(
          .system(size: 17, weight: .medium, design: .rounded)
        ).foregroundStyle(ink)
        Text("Drop files here, or click to browse").font(.system(size: 13)).foregroundStyle(
          .secondary)
        HStack(spacing: 15) {
          keyHint(model.keySymbol(model.convertWheelKey), "Convert")
          keyHint(model.keySymbol(model.toolsWheelKey), "Tools")
          keyHint(model.keySymbol(model.actionsWheelKey), "Actions")
        }.padding(.top, 6)
      }.frame(maxWidth: .infinity).padding(.vertical, 27)
        .background(
          targeted ? accent.opacity(0.08) : surface.opacity(0.45),
          in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 18).strokeBorder(
            targeted ? accent : ink.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
    }.buttonStyle(PressFeedbackStyle())
  }
  private func keyHint(_ key: String, _ text: String) -> some View {
    HStack(spacing: 5) {
      Text(key).font(.system(size: 13)).frame(width: 22, height: 20).background(
        surface, in: RoundedRectangle(cornerRadius: 4)
      ).overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.08)))
      Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
    }
  }
  private var fileList: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("\(model.files.count) FILE\(model.files.count == 1 ? "" : "S") READY").font(
          .system(size: 11, weight: .semibold)
        ).tracking(1)
        Spacer()
        Button("Clear") { model.files = [] }.buttonStyle(PressFeedbackStyle()).font(
          .system(size: 12)
        ).foregroundStyle(.secondary)
      }
      ForEach(Array(model.files.enumerated()), id: \.element) { index, url in
        HStack(spacing: 10) {
          Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(
            width: 28, height: 28)
          VStack(alignment: .leading, spacing: 3) {
            Text(url.lastPathComponent).font(.system(size: 13, weight: .medium))
            Text(url.deletingLastPathComponent().path).font(.system(size: 11)).foregroundStyle(
              .secondary
            ).lineLimit(1).truncationMode(.middle)
          }
          Spacer()
          if index > 0 {
            Button {
              model.files.swapAt(index, index - 1)
            } label: {
              Image(systemName: "arrow.up")
            }.help("Move earlier in batch")
          }
          Button {
            model.files.removeAll { $0 == url }
          } label: {
            Image(systemName: "xmark").foregroundStyle(.secondary)
          }
        }.buttonStyle(.borderless).padding(10).background(
          surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
      }
    }
  }
  private var workspace: some View {
    VStack(alignment: .leading, spacing: 17) {
      HStack {
        ForEach(
          [("convert", "Convert"), ("tools", "File tools"), ("actions", "File actions")], id: \.0
        ) { id, name in
          Button {
            model.activeTab = id
          } label: {
            VStack(spacing: 9) {
              Text(name).font(.system(size: 13, weight: .medium)).foregroundStyle(
                model.activeTab == id ? ink : .secondary)
              Capsule().fill(model.activeTab == id ? accent : .clear).frame(height: 2)
            }
          }.buttonStyle(PressFeedbackStyle()).fixedSize(horizontal: true, vertical: false)
            .animation(
              reduceMotion ? nil : .interactiveSpring(response: 0.3, dampingFraction: 1),
              value: model.activeTab)
        }
        Spacer()
        if model.activeTab == "tools" {
          TextField("Find a tool", text: $model.query).textFieldStyle(.roundedBorder).frame(
            width: 150)
        }
      }
      if model.activeTab == "convert" {
        if model.files.isEmpty {
          Text(
            "Images, video, audio, PDFs, documents, spreadsheets, and more.\nAdd files to see compatible output formats."
          ).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(5).padding(
            .vertical, 12)
          HStack(spacing: 8) {
            ForEach(["PNG", "MP4", "MP3", "PDF", "DOCX", "ZIP"], id: \.self) { format in
              Text(format).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink.opacity(0.55)).padding(10).background(
                  surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
            }
          }
        } else if model.formats.isEmpty {
          Text(
            "No shared conversion formats for this selection. Try selecting files of the same category, or use File actions."
          ).font(.callout).foregroundStyle(.secondary)
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
            ForEach(model.formats, id: \.self) { format in
              Button {
                model.submit(format: format)
              } label: {
                VStack(spacing: 8) {
                  Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(accent)
                  Text(format == "gz" ? "TAR.GZ" : format.uppercased()).font(
                    .system(size: 13, weight: .semibold, design: .monospaced))
                }.frame(maxWidth: .infinity).padding(.vertical, 20).background(
                  surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
              }.buttonStyle(PressFeedbackStyle()).contextMenu {
                Button("Convert now") { model.submit(format: format) }
                Button("Options…") { model.selectedFormat = ConversionChoice(format: format) }
              }.help("Convert to \(format.uppercased()). Right-click for options.")
            }
          }
        }
      } else if model.activeTab == "tools" {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 12) {
          ForEach(model.tools) { tool in
            Button {
              model.configure(tool)
            } label: {
              VStack(alignment: .leading, spacing: 10) {
                Image(systemName: tool.symbol).font(.system(size: 21, weight: .light))
                  .foregroundStyle(accent).frame(height: 28)
                Text(tool.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
                Text(tool.detail).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                  .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
              }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(
                surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 13))
            }.buttonStyle(PressFeedbackStyle())
          }
        }
        if model.tools.isEmpty {
          Text("No matching tools for this selection.").foregroundStyle(.secondary)
        }
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 175))], spacing: 12) {
          ForEach(Catalog.actions, id: \.0) { id, name, symbol in
            Button {
              model.fileAction(id)
            } label: {
              HStack {
                Image(systemName: symbol).foregroundStyle(accent)
                Text(name).font(.system(size: 13, weight: .medium))
                Spacer()
              }.padding(18).background(
                surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(PressFeedbackStyle())
          }
        }
      }
    }
  }
  private var history: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("RECENT ACTIVITY").font(.system(size: 11, weight: .semibold)).tracking(1)
        Spacer()
        if model.isBusy {
          Button("Cancel jobs", action: model.cancel).font(.system(size: 12))
        } else {
          Button("Clear history") { model.jobs.removeAll() }.font(.system(size: 12))
        }
      }
      ForEach(model.jobs) { job in
        VStack(alignment: .leading, spacing: 7) {
          HStack {
            Image(
              systemName: job.error != nil
                ? "exclamationmark.circle"
                : job.state == "Complete" ? "checkmark.circle.fill" : "clock"
            ).foregroundStyle(job.error != nil ? .red : orange)
            Text(job.title).font(.system(size: 13, weight: .medium))
            Spacer()
            Text(job.state).font(.system(size: 11)).foregroundStyle(.secondary)
          }
          if let error = job.error {
            Text(error).font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled)
          }
          ForEach(job.outputs, id: \.self) { output in
            HStack {
              Text(output.lastPathComponent).font(.system(size: 12)).lineLimit(1)
              Spacer()
              Button("Open") { NSWorkspace.shared.open(output) }
              Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([output]) }
            }.font(.system(size: 11))
          }
        }.padding(13).background(surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
      }
    }
  }
  private var footer: some View {
    HStack {
      Button(action: model.chooseDestination) {
        Label(model.destination?.lastPathComponent ?? "Save beside original", systemImage: "folder")
          .lineLimit(1)
      }.buttonStyle(PressFeedbackStyle()).help(
        model.destination?.path ?? "Outputs are saved beside their originals")
      if model.destination != nil {
        Button {
          model.destination = nil
        } label: {
          Image(systemName: "xmark.circle.fill")
        }.buttonStyle(PressFeedbackStyle())
      }
      Spacer()
      Text("Originals kept. Always local.").foregroundStyle(.secondary)
    }.font(.system(size: 11)).padding(.horizontal, 32).padding(.vertical, 14).modifier(
      ChromeMaterial())
  }
  private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
    Task {
      let ordered = await withTaskGroup(of: (Int, URL?).self, returning: [URL].self) { group in
        for (index, provider) in providers.enumerated() {
          group.addTask {
            let url: URL? = await withCheckedContinuation { continuation in
              provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                item, _ in
                let url =
                  (item as? URL)
                  ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                continuation.resume(returning: url)
              }
            }
            return (index, url)
          }
        }
        var results: [(Int, URL?)] = []
        for await result in group { results.append(result) }
        return results.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
      }
      model.add(ordered)
    }
    return !providers.isEmpty
  }

}

struct SettingsView: View {
  @EnvironmentObject var model: AppModel
  @Environment(\.dismiss) var dismiss
  private func keyPicker(_ title: String, selection: Binding<String>) -> some View {
    Picker(title, selection: selection) {
      Text("⇧ Shift").tag("shift")
      Text("⌘ Command").tag("command")
      Text("⌃ Control").tag("control")
      Text("⌥ Option").tag("option")
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      Text("Settings").font(.system(size: 25, weight: .semibold)).tracking(-0.5)
      Toggle("Show the drag wheel across apps", isOn: $model.globalWheelEnabled)
      Text(
        "Start dragging files in Finder, then tap Shift to convert, Command for tools, or Control for actions. Drop on an option. The wheel stays open after you release the key."
      ).font(.callout).foregroundStyle(.secondary)
      keyPicker(
        "Convert",
        selection: Binding(
          get: { model.convertWheelKey }, set: { model.setWheelKey("convert", $0) }))
      keyPicker(
        "Tools",
        selection: Binding(get: { model.toolsWheelKey }, set: { model.setWheelKey("tools", $0) }))
      keyPicker(
        "Actions",
        selection: Binding(
          get: { model.actionsWheelKey }, set: { model.setWheelKey("actions", $0) }))
      if Set([model.convertWheelKey, model.toolsWheelKey, model.actionsWheelKey]).count < 3 {
        Text("Choose a different key for each wheel.").font(.caption).foregroundStyle(.red)
      }
      Toggle("Reveal completed files in Finder", isOn: $model.revealAfterConversion)
      Divider()
      Text(
        "All processing happens locally. Pages conversion requires Apple Pages and macOS Automation permission. The app includes the conversion engine when built with scripts/build-app.sh."
      ).font(.callout).foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
      }
    }.padding(30).frame(width: 480).tint(accent)
  }
}
