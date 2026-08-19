import XCTest
@testable import LightSelectCore

final class SelectionMonitorTests: XCTestCase {
    func testSelectedModeDeliversAcceptedSelectionOnMainQueue() {
        let hook = FakeSelectionHook()
        let monitor = SelectionMonitor(hook: hook)
        var settings = LightSelectSettings.default
        settings.enabled = true
        let delivered = expectation(description: "selection delivered")

        monitor.start(settings: settings) { selection in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(selection.text, "hello")
            delivered.fulfill()
        }
        hook.emit(.fixture(text: "hello"))

        wait(for: [delivered], timeout: 1)
        XCTAssertTrue(hook.started)
        XCTAssertEqual(hook.passiveValues, [false])
    }

    func testControlModeReadsCurrentSelectionOnControlRelease() {
        let hook = FakeSelectionHook()
        hook.current = .fixture(text: "control")
        let monitor = SelectionMonitor(hook: hook)
        var settings = LightSelectSettings.default
        settings.enabled = true
        settings.triggerMode = .ctrlkey
        let delivered = expectation(description: "control selection")

        monitor.start(settings: settings) { selection in
            XCTAssertEqual(selection.text, "control")
            delivered.fulfill()
        }
        hook.emit(.fixture(text: "ignored passive callback"))
        monitor.controlKeyReleased()

        wait(for: [delivered], timeout: 1)
        XCTAssertEqual(hook.passiveValues, [true])
        XCTAssertEqual(hook.currentSelectionCount, 1)
    }

    func testShortcutModeOnlyReadsAfterShortcutInvocation() {
        let hook = FakeSelectionHook()
        hook.current = .fixture(text: "shortcut")
        let monitor = SelectionMonitor(hook: hook)
        var settings = LightSelectSettings.default
        settings.enabled = true
        settings.triggerMode = .shortcut
        let delivered = expectation(description: "shortcut selection")

        monitor.start(settings: settings) { _ in delivered.fulfill() }
        monitor.controlKeyReleased()
        XCTAssertEqual(hook.currentSelectionCount, 0)
        monitor.invokeShortcut()

        wait(for: [delivered], timeout: 1)
        XCTAssertEqual(hook.currentSelectionCount, 1)
    }

    func testRejectsPunctuationFilteredAndDuplicateSelections() {
        let hook = FakeSelectionHook()
        var now = Date(timeIntervalSince1970: 10)
        let monitor = SelectionMonitor(hook: hook, now: { now })
        var settings = LightSelectSettings.default
        settings.enabled = true
        settings.filterMode = .blacklist
        settings.filterList = ["com.blocked"]
        var values: [String] = []

        monitor.start(settings: settings) { values.append($0.text) }
        hook.emit(.fixture(text: "——"))
        hook.emit(.fixture(text: "blocked", bundleIdentifier: "COM.BLOCKED"))
        hook.emit(.fixture(text: "accepted"))
        hook.emit(.fixture(text: "accepted"))
        now = now.addingTimeInterval(1.1)
        hook.emit(.fixture(text: "accepted"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(values, ["accepted", "accepted"])
    }

    func testDisabledStateDoesNotStartAndUpdatePropagatesFilter() {
        let hook = FakeSelectionHook()
        let monitor = SelectionMonitor(hook: hook)
        var settings = LightSelectSettings.default
        monitor.start(settings: settings) { _ in XCTFail("disabled monitor delivered") }
        XCTAssertFalse(hook.started)

        settings.enabled = true
        settings.filterMode = .whitelist
        settings.filterList = ["COM.ONE"]
        monitor.update(settings: settings)

        XCTAssertTrue(hook.started)
        XCTAssertEqual(hook.filters.last?.mode, .whitelist)
        XCTAssertEqual(hook.filters.last?.identifiers, ["com.one"])
    }

    func testStopCleansUpHookAndPendingHandler() {
        let hook = FakeSelectionHook()
        let monitor = SelectionMonitor(hook: hook)
        var settings = LightSelectSettings.default
        settings.enabled = true
        monitor.start(settings: settings) { _ in XCTFail("stopped monitor delivered") }

        monitor.stop()
        hook.emit(.fixture(text: "late"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(hook.stopCount, 1)
        XCTAssertFalse(hook.started)
    }
}

private final class FakeSelectionHook: SelectionHooking {
    var started = false
    var stopCount = 0
    var passiveValues: [Bool] = []
    var filters: [(mode: SelectionFilterMode, identifiers: [String])] = []
    var current: SelectionSnapshot?
    var currentSelectionCount = 0
    private var handler: ((SelectionSnapshot) -> Void)?

    func start(handler: @escaping (SelectionSnapshot) -> Void) {
        started = true
        self.handler = handler
    }

    func stop() {
        started = false
        stopCount += 1
        handler = nil
    }

    func setPassive(_ passive: Bool) { passiveValues.append(passive) }

    func setFilter(mode: SelectionFilterMode, bundleIdentifiers: [String]) {
        filters.append((mode, bundleIdentifiers))
    }

    func currentSelection() -> SelectionSnapshot? {
        currentSelectionCount += 1
        return current
    }

    func emit(_ selection: SelectionSnapshot) { handler?(selection) }
}

private extension SelectionSnapshot {
    static func fixture(text: String, bundleIdentifier: String = "com.allowed") -> SelectionSnapshot {
        SelectionSnapshot(
            text: text,
            bundleIdentifier: bundleIdentifier,
            startTop: .zero,
            startBottom: .zero,
            endTop: .zero,
            endBottom: .zero,
            mouseStart: .zero,
            mouseEnd: CGPoint(x: 100, y: 100),
            method: .accessibility,
            positionLevel: .mouseDual,
            isFullscreen: false
        )
    }
}
