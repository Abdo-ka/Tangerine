import AppKit
import SwiftUI

// Semantic colors keep content legible in both system appearances.
func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
  Color(
    nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    })
}
let orange = Color(red: 0.95, green: 0.36, blue: 0.12)
let ink = Color.primary
let paper = adaptive(
  NSColor(calibratedRed: 0.98, green: 0.975, blue: 0.96, alpha: 1),
  NSColor(calibratedWhite: 0.105, alpha: 1))
let surface = adaptive(.white, NSColor(calibratedWhite: 0.18, alpha: 1))
let sidebarPaper = adaptive(
  NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.92, alpha: 1),
  NSColor(calibratedWhite: 0.14, alpha: 1))
let accent = orange
let tangerineBrandmark = NSImage(
  contentsOf: Bundle.module.url(forResource: "Brandmark", withExtension: "png")!
)!

/// Feedback starts on press; spring retargeting remains interruptible.
struct PressFeedbackStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Rectangle())
      .opacity(!enabled ? 0.45 : configuration.isPressed ? 0.72 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .animation(
        reduceMotion ? nil : .interactiveSpring(response: 0.3, dampingFraction: 1),
        value: configuration.isPressed)
  }
}

/// Opaque structural surfaces keep labels readable over every desktop background.
struct ChromeMaterial: ViewModifier {
  func body(content: Content) -> some View {
    content.background(sidebarPaper)
  }
}
