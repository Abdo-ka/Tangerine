import AppKit
import SwiftUI

@MainActor final class DragWheelController {
  private weak var model: AppModel?
  private var monitor: Any?
  private var localMonitor: Any?
  private var timer: Timer?
  private var activationObserver: NSObjectProtocol?
  private var shortcutGate = WheelShortcutGate()
  private var panel: NSPanel?
  private var wheel: WheelView?
  private var lastChange = -1
  private var shownAt = Date.distantPast
  private var activeMode = ""
  private var activeURLs: [URL] = []
  init(model: AppModel) {
    self.model = model
    lastChange = NSPasteboard(name: .drag).changeCount
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) {
      [weak self] event in
      Task { @MainActor in self?.handle(event) }
    }
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) {
      [weak self] event in
      self?.handle(event)
      return event
    }
    activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, NSEvent.pressedMouseButtons & 1 != 0,
          NSEvent.modifierFlags.contains(.command)
        else { return }
        // The system app switcher can consume Tab before global event monitors see it.
        self.shortcutGate.suppress()
        self.dismissWheel()
      }
    }
    timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in self.tick() }
    }
  }
  private func handle(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 48, event.modifierFlags.contains(.command) {
      shortcutGate.suppress()
      dismissWheel()
    }
    flags(event.modifierFlags)
  }
  private func dismissWheel() {
    panel?.orderOut(nil)
    activeMode = ""
    activeURLs = []
  }
  private func flags(_ flags: NSEvent.ModifierFlags) {
    let suppress = shortcutGate.update(
      mouseDown: NSEvent.pressedMouseButtons & 1 != 0,
      commandDown: flags.contains(.command),
      tabDown: CGEventSource.keyState(.combinedSessionState, key: 48))
    if suppress {
      dismissWheel()
      return
    }
    guard model?.globalWheelEnabled == true, NSEvent.pressedMouseButtons & 1 != 0 else { return }
    guard let model else { return }
    let keys: [String: NSEvent.ModifierFlags] = [
      "shift": .shift, "command": .command, "control": .control, "option": .option,
    ]
    let held = flags.intersection([.shift, .command, .control, .option])
    let mode =
      held == keys[model.actionsWheelKey]
      ? "actions"
      : held == keys[model.toolsWheelKey]
        ? "tools" : held == keys[model.convertWheelKey] ? "convert" : ""
    guard !mode.isEmpty else { return }
    let pasteboard = NSPasteboard(name: .drag)
    guard pasteboard.changeCount != lastChange || panel?.isVisible == true else { return }
    let urls =
      pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
      as? [URL] ?? []
    guard !urls.isEmpty else { return }
    show(urls: urls, mode: mode)
  }
  private func tick() {
    if NSEvent.pressedMouseButtons & 1 != 0 {
      // Polling flags is a fallback when global keyboard monitoring is restricted.
      // AppKit still tracks the actual drag at native event frequency in WheelView.
      flags(NSEvent.modifierFlags)
    } else {
      shortcutGate.reset()
      lastChange = NSPasteboard(name: .drag).changeCount
      if panel?.isVisible == true, Date().timeIntervalSince(shownAt) > 0.15 {
        dismissWheel()
      }
    }
  }
  private func show(urls: [URL], mode: String) {
    if panel?.isVisible == true, activeMode == mode, activeURLs == urls { return }
    activeMode = mode
    activeURLs = urls
    let options: [WheelOption]
    if mode == "convert" {
      options = Catalog.formats(for: urls).map {
        .init(
          id: $0, title: $0 == "gz" ? "TAR.GZ" : $0.uppercased(),
          symbol: "arrow.triangle.2.circlepath")
      }
    } else if mode == "tools" {
      options = Catalog.tools(for: urls).map { .init(id: $0.id, title: $0.name, symbol: $0.symbol) }
    } else {
      options = Catalog.actions.map { .init(id: $0.0, title: $0.1, symbol: $0.2) }
    }
    guard !options.isEmpty else {
      panel?.orderOut(nil)
      return
    }
    let diameter: CGFloat = options.count > 8 ? 440 : 360
    if panel == nil {
      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: diameter, height: diameter),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = true
      panel.level = .popUpMenu
      panel.hidesOnDeactivate = false
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      panel.isReleasedWhenClosed = false
      self.panel = panel
    }
    let view = WheelView(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
    view.options = options
    view.caption = mode == "convert" ? "CONVERT" : mode.uppercased()
    view.hint =
      "\(model?.keySymbol(model?.convertWheelKey ?? "shift") ?? "⇧") Formats\n\(model?.keySymbol(model?.toolsWheelKey ?? "command") ?? "⌘") Tools · \(model?.keySymbol(model?.actionsWheelKey ?? "control") ?? "⌃") Actions"
    view.chosen = { [weak self] id, dropped in
      guard let self, let model = self.model, !self.shortcutGate.isSuppressed else { return }
      self.panel?.orderOut(nil)
      let actual = dropped.isEmpty ? urls : dropped
      if mode == "convert" {
        model.submit(format: id, inputs: actual)
      } else if mode == "tools", let tool = Tool.all.first(where: { $0.id == id }) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        model.configure(tool, inputs: actual)
      } else {
        model.fileAction(id, urls: actual)
      }
    }
    let shouldReposition = panel?.isVisible != true || panel?.frame.size.width != diameter
    wheel = view
    panel?.setContentSize(NSSize(width: diameter, height: diameter))
    panel?.contentView = view
    if shouldReposition {
      let mouse = NSEvent.mouseLocation
      let screen =
        NSScreen.screens.first { $0.frame.contains(mouse) }?.visibleFrame
        ?? NSScreen.main!.visibleFrame
      let x = min(screen.maxX - diameter, max(screen.minX, mouse.x - diameter / 2))
      let y = min(screen.maxY - diameter, max(screen.minY, mouse.y - diameter / 2))
      panel?.setFrameOrigin(NSPoint(x: x, y: y))
      panel?.orderFrontRegardless()
      shownAt = Date()
    }
  }
}

// Keep a Command-Tab gesture suppressed after Tab is released while Command stays held.
struct WheelShortcutGate {
  private(set) var isSuppressed = false
  mutating func suppress() { isSuppressed = true }
  mutating func reset() { isSuppressed = false }
  mutating func update(mouseDown: Bool, commandDown: Bool, tabDown: Bool) -> Bool {
    guard mouseDown, commandDown else {
      reset()
      return false
    }
    if tabDown { suppress() }
    return isSuppressed
  }
}

struct WheelOption {
  let id: String
  let title: String
  let symbol: String
}
final class WheelView: NSView {
  var options: [WheelOption] = []
  var caption = "CONVERT"
  var hint = "⇧ Formats\n⌘ Tools · ⌃ Actions"
  var chosen: ((String, [URL]) -> Void)?
  private var selected: Int?
  override init(frame: NSRect) {
    super.init(frame: frame)
    registerForDraggedTypes([.fileURL])
    updateTrackingAreas()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
  override var acceptsFirstResponder: Bool { true }
  override func updateTrackingAreas() {
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(
      NSTrackingArea(
        rect: bounds, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited], owner: self))
    super.updateTrackingAreas()
  }
  private func index(at point: NSPoint) -> Int? {
    let dx = point.x - bounds.midX
    let dy = point.y - bounds.midY
    let distance = hypot(dx, dy)
    guard distance > bounds.width * 0.135, distance < bounds.width / 2 - 6, !options.isEmpty else {
      return nil
    }
    let angle = (atan2(dx, dy) + Double.pi * 2).truncatingRemainder(dividingBy: Double.pi * 2)
    return Int(
      (angle + Double.pi / Double(options.count)).truncatingRemainder(dividingBy: Double.pi * 2)
        / (Double.pi * 2) * Double(options.count))
  }
  override func draw(_ dirtyRect: NSRect) {
    let center = NSPoint(x: bounds.midX, y: bounds.midY)
    NSColor.windowBackgroundColor.setFill()
    NSBezierPath(ovalIn: bounds.insetBy(dx: 6, dy: 6)).fill()
    let count = Double(max(1, options.count))
    let outer = bounds.width / 2 - 12
    let inner = outer * 0.29
    let labelRadius = outer * 0.66
    let labelWidth = min(104, 2 * Double.pi * labelRadius / count * 0.95)
    for (i, option) in options.enumerated() {
      let angle = 90 - Double(i) * 360 / count
      let half = 180 / count - 1.8
      let path = NSBezierPath()
      path.appendArc(
        withCenter: center, radius: outer, startAngle: angle - half, endAngle: angle + half)
      path.appendArc(
        withCenter: center, radius: inner, startAngle: angle + half, endAngle: angle - half,
        clockwise: true)
      path.close()
      (selected == i
        ? NSColor.systemOrange.withAlphaComponent(0.18)
        : NSColor.controlBackgroundColor.withAlphaComponent(0.95))
        .setFill()
      path.fill()
      NSColor(calibratedWhite: 0.82, alpha: 0.55).setStroke()
      path.lineWidth = 0.5
      path.stroke()
      let rad = angle * Double.pi / 180
      let x = center.x + cos(rad) * labelRadius
      let y = center.y + sin(rad) * labelRadius
      let symbol = NSImage(systemSymbolName: option.symbol, accessibilityDescription: option.title)?
        .withSymbolConfiguration(.init(pointSize: 18, weight: .regular))
      symbol?.draw(in: NSRect(x: x - 10, y: y + 3, width: 20, height: 20))
      let p = NSMutableParagraphStyle()
      p.alignment = .center
      let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: options.count > 10 ? 10 : 11, weight: .medium),
        .foregroundColor: NSColor.labelColor, .paragraphStyle: p,
      ]
      (option.title as NSString).draw(
        in: NSRect(x: x - labelWidth / 2, y: y - 26, width: labelWidth, height: 30),
        withAttributes: attrs)
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (caption as NSString).draw(
      in: NSRect(x: center.x - 46, y: center.y + 7, width: 92, height: 18),
      withAttributes: [
        .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
        .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph,
      ])
    (hint as NSString).draw(
      in: NSRect(x: center.x - 58, y: center.y - 28, width: 116, height: 31),
      withAttributes: [
        .font: NSFont.systemFont(ofSize: 9, weight: .medium),
        .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph,
      ])
  }
  override func mouseMoved(with event: NSEvent) {
    selected = index(at: convert(event.locationInWindow, from: nil))
    needsDisplay = true
  }
  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      window?.orderOut(nil)
    } else if event.keyCode == 36, let selected {
      chosen?(options[selected].id, [])
    } else if [123, 124, 125, 126].contains(event.keyCode) {
      selected =
        ((selected ?? 0) + ([123, 126].contains(event.keyCode) ? options.count - 1 : 1))
        % max(1, options.count)
      needsDisplay = true
    } else {
      super.keyDown(with: event)
    }
  }
  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    draggingUpdated(sender)
  }
  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    selected = index(at: convert(sender.draggingLocation, from: nil))
    needsDisplay = true
    return selected == nil ? [] : .copy
  }
  override func draggingExited(_ sender: NSDraggingInfo?) {
    selected = nil
    needsDisplay = true
  }
  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { selected != nil }
  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard let selected else { return false }
    let urls =
      sender.draggingPasteboard.readObjects(
        forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    chosen?(options[selected].id, urls)
    return true
  }
}

@MainActor final class ShelfWindow {
  static let shared = ShelfWindow()
  private var window: NSPanel?
  func pin(_ edge: String) {
    guard let window, let screen = window.screen ?? NSScreen.main else { return }
    let bounds = screen.visibleFrame
    let frame = window.frame
    let x = edge == "left" ? bounds.minX + 8 : bounds.maxX - frame.width - 8
    let y = min(bounds.maxY - frame.height, max(bounds.minY, frame.minY))
    window.setFrameOrigin(NSPoint(x: x, y: y))
    UserDefaults.standard.set(edge, forKey: "shelfEdge")
  }
  func show(model: AppModel) {
    if window == nil {
      let panel = NSPanel(
        contentRect: NSRect(x: 100, y: 200, width: 290, height: 280),
        styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered,
        defer: false)
      panel.title = "Tangerine shelf"
      panel.level = .floating
      panel.hidesOnDeactivate = false
      panel.isReleasedWhenClosed = false
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      window = panel
    }
    window?.contentView = NSHostingView(rootView: ShelfView().environmentObject(model))
    window?.orderFrontRegardless()
    if let edge = UserDefaults.standard.string(forKey: "shelfEdge") { pin(edge) }
  }
}
struct ShelfView: View {
  @EnvironmentObject var model: AppModel
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("File shelf").font(.system(size: 21, weight: .semibold))
        Spacer()
        Menu {
          Button("Pin left") { ShelfWindow.shared.pin("left") }
          Button("Pin right") { ShelfWindow.shared.pin("right") }
        } label: {
          Image(systemName: "pin")
        }
        Button("Clear") { model.floatFiles = [] }
      }
      Text(
        "Drag a file from here into any app. Move this window to a screen edge to keep it handy."
      ).font(.system(size: 11)).foregroundStyle(.secondary)
      ScrollView {
        ForEach(model.floatFiles, id: \.self) { url in
          HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(
              width: 25, height: 25)
            Text(url.lastPathComponent).font(.system(size: 12)).lineLimit(1)
            Spacer()
          }.padding(8).background(surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            .onDrag { NSItemProvider(object: url as NSURL) }
        }
      }
    }.padding(18).modifier(ChromeMaterial())
  }
}
