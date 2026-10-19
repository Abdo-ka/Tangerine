import AppKit
import PDFKit
import XCTest

@testable import Tangerine

final class NativeAnalysisTests: XCTestCase {
  private func fixture() -> NSImage {
    NSImage(size: NSSize(width: 900, height: 220), flipped: false) { rect in
      NSColor.white.setFill()
      rect.fill()
      ("OFFLINE CONVERSION" as NSString).draw(
        at: NSPoint(x: 35, y: 85),
        withAttributes: [
          .font: NSFont.systemFont(ofSize: 54, weight: .bold), .foregroundColor: NSColor.black,
        ])
      return true
    }
  }
  func testScannedPDFUsesLocalOCR() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("scan.pdf")
    let doc = PDFDocument()
    doc.insert(try XCTUnwrap(PDFPage(image: fixture())), at: 0)
    XCTAssertTrue(doc.write(to: source))
    let original = try Data(contentsOf: source)
    let text = try NativeAnalysis.pdfText(source, password: "").joined(separator: " ")
    XCTAssertTrue(text.contains("OFFLINE"), "OCR result: \(text)")
    XCTAssertEqual(original, try Data(contentsOf: source))
  }
  func testTextDetectionReturnsNormalizedRegions() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: file) }
    let image = fixture()
    let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    let data = try XCTUnwrap(
      NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]))
    try data.write(to: file)
    let regions = try NativeAnalysis.regions(file, faces: false)
    XCTAssertFalse(regions.isEmpty)
    for box in regions {
      XCTAssertGreaterThan(box["width"] ?? 0, 0)
      XCTAssertLessThanOrEqual((box["x"] ?? 0) + (box["width"] ?? 0), 1.001)
    }
  }
  func testBackgroundRemovalCreatesTransparentPNG() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("subject.png")
    let image = NSImage(size: NSSize(width: 640, height: 480), flipped: false) { rect in
      NSColor.white.setFill()
      rect.fill()
      let fruit = NSBezierPath(ovalIn: NSRect(x: 180, y: 70, width: 290, height: 290))
      NSGradient(
        starting: NSColor.systemOrange,
        ending: NSColor(calibratedRed: 0.8, green: 0.25, blue: 0.02, alpha: 1))?.draw(
          in: fruit, angle: 45)
      NSColor.systemGreen.setFill()
      NSBezierPath(ovalIn: NSRect(x: 320, y: 325, width: 130, height: 60)).fill()
      return true
    }
    let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    try XCTUnwrap(NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])).write(
      to: source)
    let job = try Worker().run(
      WorkRequest(
        inputs: [source], operation: "removeBackground", format: "", options: [:],
        destination: directory))
    XCTAssertTrue(job.errors.isEmpty)
    let output = try XCTUnwrap(job.outputs.first)
    let result = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: output)))
    XCTAssertEqual(result.pixelsWide, cg.width)
    XCTAssertEqual(result.pixelsHigh, cg.height)
    XCTAssertLessThan(try XCTUnwrap(result.colorAt(x: 0, y: 0)).alphaComponent, 0.1)
    XCTAssertGreaterThan(
      try XCTUnwrap(result.colorAt(x: result.pixelsWide / 2, y: result.pixelsHigh / 2))
        .alphaComponent, 0.5)
  }
  func testScannedPDFTextCrossesWorkerBridge() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("scan.pdf")
    let document = PDFDocument()
    document.insert(try XCTUnwrap(PDFPage(image: fixture())), at: 0)
    XCTAssertTrue(document.write(to: source))
    let job = try Worker().run(
      WorkRequest(
        inputs: [source], operation: "convert", format: "txt", options: [:], destination: directory)
    )
    let output = try XCTUnwrap(job.outputs.first)
    XCTAssertTrue(try String(contentsOf: output).contains("OFFLINE"))
  }
  func testCancellationStopsBeforeOCRPages() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".pdf")
    defer { try? FileManager.default.removeItem(at: file) }
    let doc = PDFDocument()
    doc.insert(try XCTUnwrap(PDFPage(image: fixture())), at: 0)
    XCTAssertTrue(doc.write(to: file))
    XCTAssertThrowsError(try NativeAnalysis.pdfText(file, password: "", cancelled: { true })) {
      XCTAssertTrue($0 is CancellationError)
    }
  }
}
