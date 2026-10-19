import XCTest

@testable import Tangerine

final class CatalogTests: XCTestCase {
  private func url(_ ext: String) -> URL { URL(fileURLWithPath: "/tmp/sample.\(ext)") }
  func testAllToolsHaveUniqueIdentifiers() {
    XCTAssertEqual(Tool.all.count, 28)
    XCTAssertEqual(Set(Tool.all.map(\.id)).count, 28)
  }
  func testMixedSelectionsOnlyOfferSharedConversions() {
    XCTAssertEqual(Catalog.formats(for: [url("png"), url("pdf")]), ["jpg"])
    XCTAssertTrue(Catalog.formats(for: [url("wav"), url("pdf")]).isEmpty)
  }
  func testMixedSelectionToolsAreCompatible() {
    XCTAssertEqual(
      Catalog.tools(for: [url("png"), url("pdf")]).map(\.id), ["compress", "removeMetadata"])
  }
  func testInputOnlyFormatsAreNotOffered() {
    for category in FileCategory.all {
      for ext in category.extensions {
        XCTAssertFalse(
          Catalog.formats(for: url(ext)).contains(where: {
            ["svg", "ppt", "xls", "rtf", "rar"].contains($0)
          }))
      }
    }
  }
  func testImageWheelContainsRequestedTools() {
    let ids = Set(Catalog.tools(for: [url("png")]).map(\.id))
    XCTAssertTrue(
      Set(["cropImage", "resizeImage", "removeBackground", "frameImage", "compress"]).isSubset(
        of: ids))
    XCTAssertTrue(Catalog.tools(for: [url("pdf")]).contains(where: { $0.id == "splitPDF" }))
    XCTAssertTrue(Catalog.tools(for: [url("mp4")]).contains(where: { $0.id == "cropVideo" }))
  }
  func testReferenceCatalogContains275Routes() {
    let referenceInputs = [
      "jpg", "png", "webp", "heic", "tiff", "svg", "avif", "bmp", "mp3", "m4a", "wav", "flac",
      "ogg", "opus", "aiff", "wma", "mp4", "mov", "mkv", "webm", "avi", "wmv", "gif", "pdf", "docx",
      "pages", "md", "rtf", "rtfd", "textclipping", "txt", "ppt", "pptx", "xlsx", "xls", "ods",
      "csv", "tsv", "epub", "srt", "vtt", "zip", "tar", "gz", "rar",
    ]
    XCTAssertEqual(referenceInputs.reduce(0) { $0 + Catalog.formats(for: url($1)).count }, 275)
  }
  func testAliasesAndUnknownTypes() {
    XCTAssertFalse(Catalog.formats(for: url("JPEG")).contains("jpg"))
    XCTAssertTrue(Catalog.formats(for: url("unknown")).isEmpty)
    XCTAssertEqual(Catalog.actions.count, 6)
  }
  func testEveryAdvertisedFormatHasRoutes() {
    for category in FileCategory.all {
      for ext in category.extensions {
        XCTAssertFalse(Catalog.formats(for: url(ext)).isEmpty, "No routes for \(ext)")
      }
    }
  }
}
