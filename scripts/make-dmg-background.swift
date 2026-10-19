import AppKit

// A two-resolution TIFF keeps Finder's 700 x 470 point canvas crisp on Retina.
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 700, height: 470))
for scale in [1, 2] {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 700 * scale, pixelsHigh: 470 * scale,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = image.size
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let context = NSGraphicsContext.current!.cgContext
  context.translateBy(x: 0, y: 470)
  context.scaleBy(x: 1, y: -1)
  NSColor(calibratedWhite: 0.975, alpha: 1).setFill()
  NSRect(x: 0, y: 0, width: 700, height: 470).fill()
  let orange = NSColor(calibratedRed: 1, green: 0.34, blue: 0.12, alpha: 1)
  func text(_ value: String, _ rect: NSRect, _ size: CGFloat,
            _ weight: NSFont.Weight, _ color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    // NSString expects an unflipped graphics context; flip its local drawing.
    NSGraphicsContext.saveGraphicsState()
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1, y: -1)
    (value as NSString).draw(in: NSRect(origin: .zero, size: rect.size), withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: color, .paragraphStyle: paragraph,
    ])
    NSGraphicsContext.restoreGraphicsState()
  }
  text("Tangerine Studio", NSRect(x: 42, y: 35, width: 610, height: 44), 31, .bold,
       NSColor(calibratedWhite: 0.13, alpha: 1))
  text("Drag Tangerine into the wheel to install.",
       NSRect(x: 43, y: 83, width: 610, height: 28), 16, .regular,
       NSColor(calibratedWhite: 0.35, alpha: 1))
  // The real Applications shortcut sits inside this stationary wheel.
  for segment in 0..<8 {
    let path = NSBezierPath()
    path.appendArc(withCenter: NSPoint(x: 420, y: 228), radius: 104,
                   startAngle: CGFloat(segment * 45 + 4),
                   endAngle: CGFloat(segment * 45 + 41))
    path.lineWidth = 12
    path.lineCapStyle = .round
    orange.withAlphaComponent(segment == 4 ? 0.55 : 0.15).setStroke()
    path.stroke()
  }
  NSColor.white.setFill()
  NSBezierPath(ovalIn: NSRect(x: 339, y: 147, width: 162, height: 162)).fill()
  let arrow = NSBezierPath()
  arrow.move(to: NSPoint(x: 235, y: 228))
  arrow.line(to: NSPoint(x: 292, y: 228))
  arrow.move(to: NSPoint(x: 281, y: 217))
  arrow.line(to: NSPoint(x: 292, y: 228))
  arrow.line(to: NSPoint(x: 281, y: 239))
  arrow.lineWidth = 3
  arrow.lineCapStyle = .round
  arrow.lineJoinStyle = .round
  orange.setStroke()
  arrow.stroke()
  NSGraphicsContext.restoreGraphicsState()
  image.addRepresentation(bitmap)
}
try image.tiffRepresentation!.write(to: URL(fileURLWithPath: output))
