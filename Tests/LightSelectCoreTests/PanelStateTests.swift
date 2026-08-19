import XCTest
import WebKit
@testable import LightSelectCore

final class PanelStateTests: XCTestCase {
    func testLightSelectWebViewHandlesTheFirstClickInAnInactivePanel() {
        let webView = LightSelectWebView(frame: .zero, configuration: WKWebViewConfiguration())

        XCTAssertTrue(webView.acceptsFirstMouse(for: nil))
    }

    func testToolbarRepeatedHideIsIdempotentAndStaleCompletionCannotHideNewShow() {
        var state = ToolbarPanelState()
        _ = state.show()
        let staleHide = state.beginHide()
        XCTAssertNotNil(staleHide)
        XCTAssertNil(state.beginHide())

        _ = state.show()
        XCTAssertFalse(state.completeHide(token: staleHide!))
        XCTAssertEqual(state.visibility, .visible)

        let currentHide = state.beginHide()!
        XCTAssertTrue(state.completeHide(token: currentHide))
        XCTAssertEqual(state.visibility, .hidden)
    }

    func testActionStateAppliesPinAutoCloseOpacityAndRememberedSizeClamping() {
        var state = ActionPanelState(pinned: false, autoClose: true, opacity: 1)
        XCTAssertTrue(state.shouldCloseOnResignKey)
        state.pinned = true
        XCTAssertFalse(state.shouldCloseOnResignKey)
        state.setOpacity(0.05)
        XCTAssertEqual(state.opacity, 0.2)
        state.setOpacity(2)
        XCTAssertEqual(state.opacity, 1)

        XCTAssertEqual(
            ActionPanelState.clampedSize(
                CGSize(width: 100, height: 2_000),
                visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
            ),
            CGSize(width: 360, height: 884)
        )
    }

    func testSettingsPresentationReusesExistingWindowUntilClosed() {
        var state = SettingsPresentationState()
        XCTAssertEqual(state.requestShow(), .create)
        XCTAssertEqual(state.requestShow(), .focusExisting)
        state.didClose()
        XCTAssertEqual(state.requestShow(), .create)
    }
}
