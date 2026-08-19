import XCTest
@testable import LightSelectCore

final class SelectionPositionerTests: XCTestCase {
    func testToolbarUsesEightPointInsetAtBottomRightScreenEdge() {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        XCTAssertEqual(
            SelectionPositioner.toolbarOrigin(
                anchor: CGPoint(x: 1_435, y: 5),
                toolbarSize: CGSize(width: 350, height: 43),
                visibleFrame: visible
            ),
            CGPoint(x: 1_082, y: 13)
        )
    }

    func testToolbarFallsBelowAnchorNearTopEdge() {
        let visible = CGRect(x: 100, y: 50, width: 800, height: 600)
        XCTAssertEqual(
            SelectionPositioner.toolbarOrigin(
                anchor: CGPoint(x: 500, y: 645),
                toolbarSize: CGSize(width: 300, height: 43),
                visibleFrame: visible
            ),
            CGPoint(x: 350, y: 594)
        )
    }

    func testActionFollowsToolbarAndRemainsInsideVisibleFrame() {
        let origin = SelectionPositioner.actionOrigin(
            toolbarFrame: CGRect(x: 1_082, y: 13, width: 350, height: 43),
            actionSize: CGSize(width: 500, height: 400),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        XCTAssertEqual(origin, CGPoint(x: 932, y: 64))
    }
}
