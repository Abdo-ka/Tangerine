import AppKit

// Whole closed tangerine in the original orange-and-white visual language.
let output =
  CommandLine.arguments.count > 1
  ? CommandLine.arguments[1] : "Sources/Tangerine/Assets/Brandmark.png"
let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
  bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let tile = NSBezierPath(
  roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 190, yRadius: 190)
NSGradient(
  starting: NSColor(calibratedRed: 1, green: 0.48, blue: 0.18, alpha: 1),
  ending: NSColor(calibratedRed: 0.93, green: 0.29, blue: 0.08, alpha: 1)
)!.draw(in: tile, angle: -70)
NSColor.white.setStroke()
let fruit = NSBezierPath(ovalIn: NSRect(x: 274, y: 250, width: 476, height: 432))
fruit.lineWidth = 36
fruit.stroke()
let stem = NSBezierPath()
stem.move(to: NSPoint(x: 506, y: 678))
stem.curve(
  to: NSPoint(x: 487, y: 740), controlPoint1: NSPoint(x: 510, y: 703),
  controlPoint2: NSPoint(x: 499, y: 726))
stem.lineWidth = 26
stem.lineCapStyle = .round
stem.stroke()
let leaf = NSBezierPath()
leaf.move(to: NSPoint(x: 528, y: 705))
leaf.curve(
  to: NSPoint(x: 723, y: 777), controlPoint1: NSPoint(x: 549, y: 800),
  controlPoint2: NSPoint(x: 652, y: 815))
leaf.curve(
  to: NSPoint(x: 528, y: 705), controlPoint1: NSPoint(x: 698, y: 690),
  controlPoint2: NSPoint(x: 608, y: 675))
leaf.close()
NSColor.white.setFill()
leaf.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
