import XCTest
@testable import LightSelectCore

final class AppCoordinatorTests: XCTestCase {
    func testLaunchStartsMonitoringOnlyWhenEnabled() {
        let disabled = Fixture(enabled: false)
        disabled.coordinator.launch()
        XCTAssertEqual(disabled.monitor.startCount, 0)

        let enabled = Fixture(enabled: true)
        enabled.coordinator.launch()
        XCTAssertEqual(enabled.monitor.startCount, 1)
    }

    func testSelectionShowsToolbarAndClearingHidesIt() {
        let fixture = Fixture(enabled: true)
        fixture.coordinator.launch()
        fixture.monitor.emit(.fixture(text: "selected"))

        XCTAssertEqual(fixture.toolbar.shownText, "selected")
        XCTAssertTrue(fixture.toolbar.events.contains(.toolbarVisibilityChanged(true)))
        fixture.coordinator.selectionCleared()
        XCTAssertEqual(fixture.toolbar.hideCount, 1)
        XCTAssertTrue(fixture.toolbar.events.contains(.toolbarVisibilityChanged(false)))
    }

    func testPreferenceChangesReconfigureMonitorPersistAndBroadcast() {
        let fixture = Fixture(enabled: true)
        fixture.coordinator.launch()
        fixture.coordinator.receive(.updatePreference(requestID: "save-filter", update: .filterMode(.whitelist)))
        fixture.coordinator.receive(.updatePreference(requestID: "save-list", update: .filterList(["COM.ONE"])))
        fixture.coordinator.receive(.updatePreference(requestID: "save-trigger", update: .triggerMode(.ctrlkey)))

        XCTAssertEqual(fixture.monitor.updated.last?.filterMode, .whitelist)
        XCTAssertEqual(fixture.monitor.updated.last?.filterList, ["com.one"])
        XCTAssertEqual(fixture.monitor.updated.last?.triggerMode, .ctrlkey)
        XCTAssertEqual(fixture.store.saved.last?.filterMode, .whitelist)
        XCTAssertTrue(fixture.action.events.contains(.preferenceChanged(.triggerMode(.ctrlkey))))
        XCTAssertTrue(fixture.settings.events.contains(.preferenceChanged(.filterList(["com.one"]))))
        XCTAssertTrue(fixture.settings.events.contains(.preferenceSaved(
            requestID: "save-trigger",
            update: .triggerMode(.ctrlkey)
        )))
    }

    func testFailedPreferenceSaveKeepsConfirmedSettingsAndReportsFailure() {
        let fixture = Fixture(enabled: true)
        fixture.coordinator.launch()
        fixture.store.shouldSave = false

        fixture.coordinator.receive(.updatePreference(requestID: "save-fail", update: .compact(true)))

        XCTAssertFalse(fixture.coordinator.settings.compact)
        XCTAssertFalse(fixture.monitor.updated.contains(where: \.compact))
        XCTAssertTrue(fixture.settings.events.contains(.preferenceSaveFailed(requestID: "save-fail", key: "compact")))
    }

    func testCommandsReachRouterSettingsAndTerminationCleansUp() {
        let fixture = Fixture(enabled: true)
        fixture.coordinator.launch()
        fixture.monitor.emit(.fixture(text: "hello"))
        fixture.coordinator.receive(.performAction(actionID: "explain", selectedText: "hello"))
        fixture.coordinator.receive(.openSettings(.api))
        fixture.coordinator.receive(.updateAPIKey("new-key"))

        XCTAssertEqual(fixture.router.actions.last?.action.id, "explain")
        XCTAssertEqual(fixture.settings.sections, [.api])
        XCTAssertEqual(fixture.store.apiKey, "new-key")

        fixture.coordinator.terminate()
        XCTAssertEqual(fixture.monitor.stopCount, 1)
        XCTAssertEqual(fixture.router.cancelActiveCount, 1)
        XCTAssertEqual(fixture.toolbar.invalidateCount, 1)
        XCTAssertEqual(fixture.action.invalidateCount, 1)
        XCTAssertEqual(fixture.settings.invalidateCount, 1)
    }

    func testCloseSettingsCommandClosesOnlySettingsWindow() {
        let fixture = Fixture(enabled: true)

        fixture.coordinator.receive(.closeSettings)

        XCTAssertEqual(fixture.settings.closeCount, 1)
        XCTAssertEqual(fixture.action.closeCount, 0)
    }

    func testOpeningSearchURLHidesSelectionToolbar() {
        let fixture = Fixture(enabled: true)
        fixture.coordinator.launch()
        fixture.monitor.emit(.fixture(text: "LightSelect"))

        fixture.coordinator.receive(.openURL("https://www.google.com/search?q=LightSelect"))

        XCTAssertEqual(fixture.toolbar.hideCount, 1)
        XCTAssertTrue(fixture.toolbar.events.contains(.toolbarVisibilityChanged(false)))
    }

    func testAPIOperationsUseStoredOrNewCredentialsAndIgnoreCancelledCompletion() {
        let fixture = Fixture(enabled: true)
        fixture.store.apiKey = "stored-secret"
        let settings = APISettings(baseURL: "https://api.example.com/v1", model: "gpt-a", timeoutSeconds: 30)
        let modelsID = "B04E446B-834E-4A26-98F7-6642A8451E63"

        fixture.coordinator.receive(.fetchModels(requestID: modelsID, configuration: settings, apiKeyInput: nil))
        XCTAssertEqual(fixture.configurationService.fetchConfiguration?.apiKey, "stored-secret")
        fixture.configurationService.completeModels(.success(.init(models: ["gpt-a"], latencyMilliseconds: 12)))
        XCTAssertTrue(fixture.settings.events.contains(
            .modelsLoaded(requestID: modelsID, models: ["gpt-a"], latencyMilliseconds: 12)
        ))

        let connectionID = "8E3BF978-2508-4D18-A94F-775A268707EC"
        fixture.coordinator.receive(.testConnection(
            requestID: connectionID,
            configuration: settings,
            apiKeyInput: "new-secret"
        ))
        XCTAssertEqual(fixture.store.apiKey, "new-secret")
        XCTAssertEqual(fixture.configurationService.connectionConfiguration?.apiKey, "new-secret")
        fixture.coordinator.receive(.cancelAPIRequest(requestID: connectionID))
        fixture.configurationService.completeConnection(.success(.init(latencyMilliseconds: 7)))
        XCTAssertFalse(fixture.settings.events.contains(
            .connectionSucceeded(requestID: connectionID, latencyMilliseconds: 7)
        ))
    }
}

private final class Fixture {
    let store: FakeSettingsStore
    let monitor = FakeMonitor()
    let router = FakeRouter()
    let toolbar = FakeToolbar()
    let action = FakeActionPanel()
    let settings = FakeSettingsWindow()
    let configurationService = FakeConfigurationService()
    let coordinator: AppCoordinator

    init(enabled: Bool) {
        var value = LightSelectSettings.default
        value.enabled = enabled
        store = FakeSettingsStore(settings: value)
        coordinator = AppCoordinator(
            settingsStore: store,
            monitor: monitor,
            router: router,
            toolbar: toolbar,
            actionPanel: action,
            settingsWindow: settings,
            configurationService: configurationService,
            anchor: { $0.mouseEnd },
            visibleFrame: { _ in CGRect(x: 0, y: 0, width: 1_440, height: 900) },
            copyText: { _ in true },
            openURL: { _ in true },
            openAccessibilitySettings: {},
            openSource: {}
        )
    }
}

private final class FakeSettingsStore: SettingsPersisting {
    var settings: LightSelectSettings
    var apiKey: String?
    var saved: [LightSelectSettings] = []
    var shouldSave = true
    var hasAPIKey: Bool { apiKey != nil }
    init(settings: LightSelectSettings) { self.settings = settings }
    func load() -> LightSelectSettings { settings }
    func save(_ settings: LightSelectSettings) -> Bool {
        guard shouldSave else { return false }
        self.settings = settings
        saved.append(settings)
        return true
    }
    func updateAPIKey(_ value: String?) { apiKey = value }
}

private final class FakeMonitor: SelectionMonitoring {
    var startCount = 0
    var stopCount = 0
    var updated: [LightSelectSettings] = []
    var handler: ((SelectionSnapshot) -> Void)?
    func start(settings: LightSelectSettings, handler: @escaping (SelectionSnapshot) -> Void) { startCount += 1; self.handler = handler }
    func update(settings: LightSelectSettings) { updated.append(settings) }
    func stop() { stopCount += 1; handler = nil }
    func controlKeyReleased() {}
    func invokeShortcut() {}
    func emit(_ value: SelectionSnapshot) { handler?(value) }
}

private final class FakeRouter: SelectionActionRouting {
    var actions: [(action: SelectionActionItem, text: String, anchor: CGPoint)] = []
    var cancelActiveCount = 0
    func perform(action: SelectionActionItem, selectedText: String, anchor: CGPoint) { actions.append((action, selectedText, anchor)) }
    func cancel(requestID: UUID) {}
    func regenerate() {}
    func cancelActive() { cancelActiveCount += 1 }
}

private final class FakeToolbar: ToolbarPanelControlling {
    var events: [WebEvent] = []
    var shownText: String?
    var hideCount = 0
    var invalidateCount = 0
    func show(anchor: CGPoint, visibleFrame: CGRect) {}
    func resize(width: Double, height: Double) {}
    func send(_ event: WebEvent) {
        events.append(event)
        if case .textSelected(let text, _) = event { shownText = text }
    }
    func hide(animated: Bool) { hideCount += 1 }
    func invalidate() { invalidateCount += 1 }
}

private final class FakeActionPanel: ActionPanelControlling {
    var events: [WebEvent] = []
    var closeCount = 0
    var invalidateCount = 0
    func update(settings: LightSelectSettings) {}
    func setPinned(_ pinned: Bool) {}
    func setOpacity(_ opacity: Double) {}
    func send(_ event: WebEvent) { events.append(event) }
    func close() { closeCount += 1 }
    func invalidate() { invalidateCount += 1 }
}

private final class FakeSettingsWindow: SettingsWindowControlling {
    var events: [WebEvent] = []
    var sections: [SettingsSection?] = []
    var closeCount = 0
    var invalidateCount = 0
    func show(section: SettingsSection?) { sections.append(section) }
    func send(_ event: WebEvent) { events.append(event) }
    func close() { closeCount += 1 }
    func invalidate() { invalidateCount += 1 }
}

private final class FakeConfigurationService: OpenAIConfigurationServing {
    var fetchConfiguration: APIConfiguration?
    var connectionConfiguration: APIConfiguration?
    private var modelsCompletion: ((Result<ModelDiscoveryResult, APIConfigurationError>) -> Void)?
    private var connectionCompletion: ((Result<ConnectionTestResult, APIConfigurationError>) -> Void)?

    func fetchModels(
        requestID: UUID,
        configuration: APIConfiguration,
        completion: @escaping (Result<ModelDiscoveryResult, APIConfigurationError>) -> Void
    ) {
        fetchConfiguration = configuration
        modelsCompletion = completion
    }
    func testConnection(
        requestID: UUID,
        configuration: APIConfiguration,
        completion: @escaping (Result<ConnectionTestResult, APIConfigurationError>) -> Void
    ) {
        connectionConfiguration = configuration
        connectionCompletion = completion
    }
    func cancel(requestID: UUID) {}
    func cancelAll() {}
    func completeModels(_ result: Result<ModelDiscoveryResult, APIConfigurationError>) { modelsCompletion?(result) }
    func completeConnection(_ result: Result<ConnectionTestResult, APIConfigurationError>) { connectionCompletion?(result) }
}

private extension SelectionSnapshot {
    static func fixture(text: String) -> SelectionSnapshot {
        .init(
            text: text, bundleIdentifier: "com.test", startTop: .zero, startBottom: .zero,
            endTop: .zero, endBottom: .zero, mouseStart: .zero, mouseEnd: CGPoint(x: 20, y: 30),
            method: .accessibility, positionLevel: .mouseDual, isFullscreen: false
        )
    }
}
