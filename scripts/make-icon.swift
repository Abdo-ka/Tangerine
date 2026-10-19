import AppKit

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let transform = NSAffineTransform()
  transform.scale(by: CGFloat(size) / 1024)
  transform.concat()
  let source = URL(
    fileURLWithPath: CommandLine.arguments.count > 2
      ? CommandLine.arguments[2] : "Sources/Tangerine/Assets/Brandmark.png")
  guard let image = NSImage(contentsOf: source) else { fatalError("Missing brand artwork") }
  image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
  NSGraphicsContext.restoreGraphicsState()
  let data = bitmap.representation(using: .png, properties: [:])!
  let names: [String]
  switch size {
  case 16: names = ["icon_16x16.png"]
  case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
  case 64: names = ["icon_32x32@2x.png"]
  case 128: names = ["icon_128x128.png"]
  case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
  case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
  default: names = ["icon_512x512@2x.png"]
  }
  for name in names { try data.write(to: folder.appendingPathComponent(name)) }
}
