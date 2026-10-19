import AppKit
import SwiftUI

@main struct TangerineApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var model = AppModel()
  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(model)
        .onAppear {
          delegate.connect(model)
          delegate.installWheel()
          NSApp.setActivationPolicy(.regular)
          NSApp.applicationIconImage = tangerineBrandmark
        }
    }
    .defaultSize(width: 1120, height: 780)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Add files…", action: model.browse).keyboardShortcut("o")
        Button("Clear files") { model.files = [] }.keyboardShortcut("k")
      }
      CommandGroup(after: .newItem) {
        Button("Open file menu") { model.showKeyboardMenu = true }.keyboardShortcut(
          .return, modifiers: []
        ).disabled(
          model.files.isEmpty || model.selectedTool != nil || model.selectedFormat != nil
            || model.showSettings)
      }
      CommandGroup(after: .appInfo) {
        Button("Settings…") { model.showSettings = true }.keyboardShortcut(",")
      }
    }
    MenuBarExtra {
      Button("Open Tangerine") {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
      }
      Button("Add files…", action: model.browse)
      Button("Open file shelf") { ShelfWindow.shared.show(model: model) }
      Toggle("Drag wheel", isOn: $model.globalWheelEnabled)
      Divider()
      Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    } label: {
      Image(nsImage: tangerineBrandmark).resizable().scaledToFit().frame(width: 18, height: 18)
        .accessibilityLabel("Tangerine")
    }
  }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  weak var model: AppModel?
  private var wheel: DragWheelController?
  private var pendingURLs: [URL] = []
  func connect(_ model: AppModel) {
    self.model = model
    if !pendingURLs.isEmpty {
      model.add(pendingURLs)
      pendingURLs = []
    }
  }
  func installWheel() {
    guard wheel == nil, let model else { return }
    wheel = DragWheelController(model: model)
  }
  func application(_ application: NSApplication, open urls: [URL]) {
    if let model { model.add(urls) } else { pendingURLs.append(contentsOf: urls) }
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
