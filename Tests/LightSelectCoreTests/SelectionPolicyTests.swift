import XCTest
@testable import LightSelectCore

final class SelectionPolicyTests: XCTestCase {
    func testMeaningfulTextRejectsBlankPunctuationAndOverlongValues() {
        XCTAssertFalse(SelectionPolicy.isMeaningfulSelection("   ", maxLength: 4_000))
        XCTAssertFalse(SelectionPolicy.isMeaningfulSelection("——", maxLength: 4_000))
        XCTAssertFalse(SelectionPolicy.isMeaningfulSelection(String(repeating: "a", count: 4_001), maxLength: 4_000))
        XCTAssertTrue(SelectionPolicy.isMeaningfulSelection("AI", maxLength: 4_000))
        XCTAssertTrue(SelectionPolicy.isMeaningfulSelection("这是一段文字", maxLength: 4_000))
    }

    func testApplicationFiltersNormalizeBundleIdentifiers() {
        let list = ["COM.APP.ONE", "com.app.two"]
        XCTAssertTrue(SelectionPolicy.allowsApplication("com.other", mode: .default, filterList: list))
        XCTAssertTrue(SelectionPolicy.allowsApplication("com.app.one", mode: .whitelist, filterList: list))
        XCTAssertFalse(SelectionPolicy.allowsApplication("COM.OTHER", mode: .whitelist, filterList: list))
        XCTAssertFalse(SelectionPolicy.allowsApplication("Com.App.Two", mode: .blacklist, filterList: list))
        XCTAssertTrue(SelectionPolicy.allowsApplication(nil, mode: .blacklist, filterList: list))
        XCTAssertFalse(SelectionPolicy.allowsApplication(nil, mode: .whitelist, filterList: list))
    }

    func testDuplicateSuppressionUsesTextAndElapsedTimeInputs() {
        let now = Date(timeIntervalSince1970: 20)
        XCTAssertFalse(SelectionPolicy.shouldAccept(text: "same", previousText: "same", previousAcceptedAt: now.addingTimeInterval(-0.5), now: now))
        XCTAssertTrue(SelectionPolicy.shouldAccept(text: "same", previousText: "same", previousAcceptedAt: now.addingTimeInterval(-1.1), now: now))
        XCTAssertTrue(SelectionPolicy.shouldAccept(text: "new", previousText: "same", previousAcceptedAt: now, now: now))
    }
}
