import XCTest
@testable import LightSelectCore

final class LocalWebResourceTests: XCTestCase {
    func testResolvesOnlyExistingFilesInsideRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let asset = root.appendingPathComponent("assets/app.js")
        try FileManager.default.createDirectory(at: asset.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("ok".utf8).write(to: asset)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertEqual(
            LocalWebResource.resolve(URL(string: "lightselect://app/assets/app.js")!, within: root),
            asset.standardizedFileURL
        )
        XCTAssertNil(LocalWebResource.resolve(URL(string: "https://app/assets/app.js")!, within: root))
        XCTAssertNil(LocalWebResource.resolve(URL(string: "lightselect://other/assets/app.js")!, within: root))
        XCTAssertNil(LocalWebResource.resolve(URL(string: "lightselect://app/%2e%2e/secret")!, within: root))
        XCTAssertNil(LocalWebResource.resolve(URL(string: "lightselect://app/missing.js")!, within: root))
    }

    func testRejectsSymlinksEscapingRoot() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = temporary.appendingPathComponent("root", isDirectory: true)
        let outside = temporary.appendingPathComponent("secret.js")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape.js"), withDestinationURL: outside)
        defer { try? FileManager.default.removeItem(at: temporary) }

        XCTAssertNil(LocalWebResource.resolve(URL(string: "lightselect://app/escape.js")!, within: root))
    }

    func testProvidesBrowserMIMETypesAndEntryURLs() {
        XCTAssertEqual(LocalWebResource.mimeType(forExtension: "html"), "text/html")
        XCTAssertEqual(LocalWebResource.mimeType(forExtension: "js"), "application/javascript")
        XCTAssertEqual(LocalWebResource.mimeType(forExtension: "css"), "text/css")
        XCTAssertEqual(LocalWebResource.mimeType(forExtension: "png"), "image/png")
        XCTAssertEqual(LocalWebResource.entryURL(relativePath: "src/toolbar/index.html")?.absoluteString,
                       "lightselect://app/src/toolbar/index.html")
    }
}
