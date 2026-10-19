import AppKit
import SwiftUI

struct KeyboardFileMenu: View {
  @EnvironmentObject var model: AppModel
  @State private var mode = "convert"
  @State private var selected = 0
  private var options: [WheelOption] {
    if mode == "convert" {
      return model.formats.map {
        WheelOption(id: $0, title: $0.uppercased(), symbol: "arrow.triangle.2.circlepath")
      }
    }
    if mode == "tools" {
      return Catalog.tools(for: model.files).map {
        WheelOption(id: $0.id, title: $0.name, symbol: $0.symbol)
      }
    }
    return Catalog.actions.map { WheelOption(id: $0.0, title: $0.1, symbol: $0.2) }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Picker("Menu", selection: $mode) {
        Text("Convert").tag("convert")
        Text("Tools").tag("tools")
        Text("Actions").tag("actions")
      }.pickerStyle(.segmented)
      if options.isEmpty {
        Text("No compatible choices for this selection.").foregroundStyle(.secondary)
      }
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
              Button {
                perform(option)
              } label: {
                HStack {
                  Image(systemName: option.symbol).frame(width: 22)
                  Text(option.title)
                  Spacer()
                  if selected == index { Image(systemName: "return").foregroundStyle(.secondary) }
                }.padding(10).background(
                  selected == index ? accent.opacity(0.14) : .clear,
                  in: RoundedRectangle(cornerRadius: 7))
              }.buttonStyle(PressFeedbackStyle()).id(mode + "-" + option.id)
            }
          }.id(mode)
        }.onChange(of: selected) {
          if options.indices.contains(selected) {
            proxy.scrollTo(mode + "-" + options[selected].id)
          }
        }
      }
      Text("Arrow keys to choose · Return to apply · Escape to close").font(.caption)
        .foregroundStyle(.secondary)
    }.padding(18).frame(width: 340, height: 370).background(paper).foregroundStyle(ink)
      .background(
        KeyboardCapture(
          key: { code in
            if code == 53 {
              model.showKeyboardMenu = false
            } else if code == 36, !options.isEmpty {
              perform(options[min(selected, options.count - 1)])
            } else if [123, 124, 125, 126].contains(code), !options.isEmpty {
              selected =
                (selected + ([123, 126].contains(code) ? options.count - 1 : 1)) % options.count
            }
          },
          modifiers: { flags in
            let keys: [String: NSEvent.ModifierFlags] = [
              "shift": .shift, "command": .command, "control": .control, "option": .option,
            ]
            let held = flags.intersection([.shift, .command, .control, .option])
            if held == keys[model.actionsWheelKey] {
              mode = "actions"
            } else if held == keys[model.toolsWheelKey] {
              mode = "tools"
            } else if held == keys[model.convertWheelKey] {
              mode = "convert"
            }
          }
        ).frame(width: 0, height: 0)
      )
      .onChange(of: mode) { selected = 0 }
  }
  private func perform(_ option: WheelOption) {
    model.showKeyboardMenu = false
    if mode == "convert" {
      model.submit(format: option.id)
    } else if mode == "tools", let tool = Tool.all.first(where: { $0.id == option.id }) {
      model.configure(tool)
    } else {
      model.fileAction(option.id)
    }
  }
}
struct KeyboardCapture: NSViewRepresentable {
  let key: (UInt16) -> Void
  let modifiers: (NSEvent.ModifierFlags) -> Void
  func makeNSView(context: Context) -> CaptureView {
    let view = CaptureView()
    view.key = key
    view.modifiers = modifiers
    DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
    return view
  }
  func updateNSView(_ view: CaptureView, context: Context) {
    view.key = key
    view.modifiers = modifiers
  }
  final class CaptureView: NSView {
    var key: ((UInt16) -> Void)?
    var modifiers: ((NSEvent.ModifierFlags) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { key?(event.keyCode) }
    override func flagsChanged(with event: NSEvent) { modifiers?(event.modifierFlags) }
  }
}
