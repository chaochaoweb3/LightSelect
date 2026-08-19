import AppKit
import Foundation
import LightSelectCore
import WebKit

private enum ContractFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): message
        }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw ContractFailure.failed(message) }
}

private final class MemoryCredentialStore: APICredentialStoring {
    var apiKey: String?
    var acceptsWrites = true

    @discardableResult
    func updateAPIKey(_ value: String?) -> Bool {
        guard acceptsWrites else { return false }
        apiKey = value
        return true
    }
}

private func settingsLanguageContract() throws {
    let current = LightSelectSettings.default
    try require(current.schemaVersion == 3, "schema version must be 3")
    try require(current.interfaceLanguage == .zhCN, "default language must preserve Chinese behavior")

    let legacy = """
    {"schemaVersion":2,"enabled":false,"actionItems":[],"actionWindowOpacity":100,
    "autoClose":false,"autoPin":false,"compact":false,"filterList":[],"filterMode":"default",
    "followToolbar":true,"rememberWindowSize":false,"triggerMode":"selected",
    "api":{"baseURL":"https://api.example.com/v1","model":"m","sourceLanguage":"auto",
    "targetLanguage":"zh-cn","timeoutSeconds":60}}
    """
    let migrated = try JSONDecoder().decode(LightSelectSettings.self, from: Data(legacy.utf8))
    try require(migrated.interfaceLanguage == .zhCN, "schema 2 must migrate to zh-CN")

    let suiteName = "LightSelectContract.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw ContractFailure.failed("could not create isolated defaults")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("legacy-secret", forKey: SettingsStore.legacyAPIKeyKey)
    let credentials = MemoryCredentialStore()
    let store = SettingsStore(defaults: defaults, credentials: credentials)

    _ = store.load()

    try require(credentials.apiKey == "legacy-secret", "legacy API key must migrate")
    try require(defaults.string(forKey: SettingsStore.legacyAPIKeyKey) == nil, "migrated API key must leave defaults")
}

private func preferenceSaveContract() throws {
    let commandData = Data(#"{"type":"preferences.update","requestId":"save-1","key":"interfaceLanguage","value":"en-US"}"#.utf8)
    let command = try JSONDecoder().decode(WebCommand.self, from: commandData)
    try require(
        command == .updatePreference(requestID: "save-1", update: .interfaceLanguage(.enUS)),
        "preference update must retain request ID and typed language"
    )

    let event = WebEvent.preferenceSaved(
        requestID: "save-1",
        update: .interfaceLanguage(.enUS)
    )
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any]
    try require(object?["type"] as? String == "preferences.saved", "saved event type")
    try require(object?["requestId"] as? String == "save-1", "saved event request ID")
    try require(object?["key"] as? String == "interfaceLanguage", "saved event key")
    try require(object?["value"] as? String == "en-US", "saved event value")

    let store = ContractSettingsStore()
    let settingsWindow = ContractSettingsWindow()
    let coordinator = AppCoordinator(
        settingsStore: store,
        monitor: ContractMonitor(),
        router: ContractRouter(),
        toolbar: ContractToolbar(),
        actionPanel: ContractActionPanel(),
        settingsWindow: settingsWindow,
        configurationService: ContractConfigurationService(),
        anchor: { _ in .zero },
        visibleFrame: { _ in .zero },
        copyText: { _ in true },
        openURL: { _ in true },
        openAccessibilitySettings: {},
        openSource: {}
    )
    coordinator.launch()
    store.acceptsSaves = false
    coordinator.receive(.updatePreference(requestID: "save-fail", update: .compact(true)))
    try require(!coordinator.settings.compact, "failed save must keep confirmed settings")
    try require(
        settingsWindow.events.contains(.preferenceSaveFailed(requestID: "save-fail", key: "compact")),
        "failed save must emit failure event"
    )
}

private func settingsCloseContract() throws {
    let command = try JSONDecoder().decode(
        WebCommand.self,
        from: Data(#"{"type":"application.closeSettings"}"#.utf8)
    )
    try require(command == .closeSettings, "settings close command must decode separately from action close")

    let settingsWindow = ContractSettingsWindow()
    let actionPanel = ContractActionPanel()
    let coordinator = AppCoordinator(
        settingsStore: ContractSettingsStore(),
        monitor: ContractMonitor(),
        router: ContractRouter(),
        toolbar: ContractToolbar(),
        actionPanel: actionPanel,
        settingsWindow: settingsWindow,
        configurationService: ContractConfigurationService(),
        anchor: { _ in .zero },
        visibleFrame: { _ in .zero },
        copyText: { _ in true },
        openURL: { _ in true },
        openAccessibilitySettings: {},
        openSource: {}
    )

    coordinator.receive(command)

    try require(settingsWindow.closeCount == 1, "settings close command must close the settings window")
    try require(actionPanel.closeCount == 0, "settings close command must not close the action window")
}

private func statusItemBrandingContract() throws {
    let button = NSStatusBarButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    let approvedConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    let approvedImage = NSImage(
        systemSymbolName: "cursorarrow.rays",
        accessibilityDescription: "LightSelect"
    )?.withSymbolConfiguration(approvedConfiguration)

    StatusItemAppearance.apply(to: button)

    try require(button.title.isEmpty, "status item must not show the LS text monogram")
    try require(button.image != nil, "status item must use a graphical selection icon")
    try require(
        button.image?.tiffRepresentation == approvedImage?.tiffRepresentation,
        "status item must use the letter-free cursor-and-rays symbol"
    )
    try require(button.image?.isTemplate == true, "status item icon must adapt to the macOS menu bar")
    try require(button.toolTip == "LightSelect", "status item must retain its accessible tooltip")
}

private final class ContractURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw ContractFailure.failed("missing URL handler") }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func apiConfigurationContract() throws {
    try require(
        OpenAIConfigurationService.endpoint(baseURL: "https://api.example.com/v1", resource: .models)?.absoluteString
            == "https://api.example.com/v1/models",
        "v1 base URL must append models"
    )
    try require(
        OpenAIConfigurationService.endpoint(
            baseURL: "https://api.example.com/v1/chat/completions",
            resource: .models
        )?.absoluteString == "https://api.example.com/v1/models",
        "chat completions URL must normalize before models"
    )

    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [ContractURLProtocol.self]
    ContractURLProtocol.handler = { request in
        try require(request.httpMethod == "GET", "model discovery must use GET")
        try require(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-secret", "bearer header")
        try require(request.url?.absoluteString == "https://api.example.com/v1/models", "models endpoint")
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(#"{"data":[{"id":"gpt-z"},{"id":"gpt-a"},{"id":"gpt-z"},{"id":""}]}"#.utf8))
    }
    let service = OpenAIConfigurationService(
        configuration: sessionConfiguration,
        callbackQueue: DispatchQueue(label: "LightSelectContract.callback")
    )
    let completed = DispatchSemaphore(value: 0)
    var result: Result<ModelDiscoveryResult, APIConfigurationError>?
    service.fetchModels(
        requestID: UUID(),
        configuration: APIConfiguration(
            baseURL: "https://api.example.com/v1/chat/completions",
            apiKey: "test-secret",
            model: "gpt-a",
            timeoutSeconds: 10
        )
    ) {
        result = $0
        completed.signal()
    }
    try require(completed.wait(timeout: .now() + 2) == .success, "model discovery completion")
    guard case .success(let discovery) = result else {
        throw ContractFailure.failed("model discovery must succeed")
    }
    try require(discovery.models == ["gpt-a", "gpt-z"], "models must be trimmed, unique, and sorted")
}

private func apiBridgeContract() throws {
    let requestID = "B04E446B-834E-4A26-98F7-6642A8451E63"
    let fetchData = Data("""
    {"type":"api.fetchModels","requestId":"\(requestID)","configuration":{
    "baseURL":"https://api.example.com/v1","model":"gpt-a","sourceLanguage":"auto",
    "targetLanguage":"zh-cn","timeoutSeconds":30}}
    """.utf8)
    let fetchCommand = try JSONDecoder().decode(WebCommand.self, from: fetchData)
    try require(
        fetchCommand == .fetchModels(
            requestID: requestID,
            configuration: APISettings(
                baseURL: "https://api.example.com/v1",
                model: "gpt-a",
                sourceLanguage: "auto",
                targetLanguage: "zh-cn",
                timeoutSeconds: 30
            ),
            apiKeyInput: nil
        ),
        "model command must decode without a new API key"
    )

    let event = WebEvent.modelsLoaded(requestID: requestID, models: ["gpt-a"], latencyMilliseconds: 18)
    let encoded = try JSONEncoder().encode(event)
    let eventObject = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    try require(eventObject?["type"] as? String == "api.modelsLoaded", "models event type")
    try require(eventObject?["requestId"] as? String == requestID, "models event request ID")
    try require(eventObject?["models"] as? [String] == ["gpt-a"], "models event values")
    try require(!String(decoding: encoded, as: UTF8.self).contains("secret"), "API events must not disclose credentials")

    let store = ContractSettingsStore()
    store.apiKey = "stored-secret"
    let settingsWindow = ContractSettingsWindow()
    let service = ContractConfigurationService()
    let coordinator = AppCoordinator(
        settingsStore: store,
        monitor: ContractMonitor(),
        router: ContractRouter(),
        toolbar: ContractToolbar(),
        actionPanel: ContractActionPanel(),
        settingsWindow: settingsWindow,
        configurationService: service,
        anchor: { _ in .zero },
        visibleFrame: { _ in .zero },
        copyText: { _ in true },
        openURL: { _ in true },
        openAccessibilitySettings: {},
        openSource: {}
    )
    let api = APISettings(baseURL: "https://api.example.com/v1", model: "gpt-a", timeoutSeconds: 30)
    coordinator.receive(.fetchModels(requestID: requestID, configuration: api, apiKeyInput: nil))
    try require(service.fetchConfiguration?.apiKey == "stored-secret", "missing input must use stored credential")
    service.completeModels(.success(.init(models: ["gpt-a"], latencyMilliseconds: 12)))
    try require(
        settingsWindow.events.contains(.modelsLoaded(requestID: requestID, models: ["gpt-a"], latencyMilliseconds: 12)),
        "active model result must reach settings"
    )

    let connectionID = "8E3BF978-2508-4D18-A94F-775A268707EC"
    coordinator.receive(.testConnection(requestID: connectionID, configuration: api, apiKeyInput: "new-secret"))
    try require(store.apiKey == "new-secret", "new credential must persist before request")
    try require(service.connectionConfiguration?.apiKey == "new-secret", "new credential must be used immediately")
    coordinator.receive(.cancelAPIRequest(requestID: connectionID))
    service.completeConnection(.success(.init(latencyMilliseconds: 7)))
    try require(
        settingsWindow.events.contains(.apiRequestCancelled(requestID: connectionID)),
        "cancel must emit one cancellation event"
    )
    try require(
        !settingsWindow.events.contains(.connectionSucceeded(requestID: connectionID, latencyMilliseconds: 7)),
        "cancelled request must ignore stale success"
    )
}

private func localizationContract() throws {
    let chinese = AppLocalization.strings(for: .zhCN)
    let english = AppLocalization.strings(for: .enUS)
    try require(chinese.settingsTitle == "LightSelect 设置", "Chinese settings title")
    try require(english.settingsTitle == "LightSelect Settings", "English settings title")
    try require(english.quit == "Quit LightSelect", "English quit menu")
    try require(chinese.openAccessibility == "打开辅助功能设置", "Chinese accessibility menu")
}

private func editingMenuContract() throws {
    let menu = ApplicationMenuFactory.make(language: .zhCN)
    guard let edit = menu.items.first(where: { $0.title == "编辑" })?.submenu else {
        throw ContractFailure.failed("localized Edit menu must exist")
    }
    let commands: [(String, Selector, String, NSEvent.ModifierFlags)] = [
        ("撤销", #selector(UndoManager.undo), "z", .command),
        ("重做", #selector(UndoManager.redo), "Z", [.command, .shift]),
        ("剪切", #selector(NSText.cut(_:)), "x", .command),
        ("复制", #selector(NSText.copy(_:)), "c", .command),
        ("粘贴", #selector(NSText.paste(_:)), "v", .command),
        ("全选", #selector(NSText.selectAll(_:)), "a", .command)
    ]
    for (title, action, key, modifiers) in commands {
        let item = edit.item(withTitle: title)
        try require(item?.action == action, "\(title) action")
        try require(item?.keyEquivalent == key, "\(title) key equivalent")
        try require(item?.keyEquivalentModifierMask == modifiers, "\(title) modifiers")
        try require(item?.target == nil, "\(title) must use the first responder")
    }

    try require(SettingsWindowController.shouldForwardControlPaste(
        characters: "v", modifierFlags: [.control], isKeyWindow: true, responderIsInsideWebView: true
    ), "Control-V in the settings web view")
    try require(!SettingsWindowController.shouldForwardControlPaste(
        characters: "v", modifierFlags: [.command], isKeyWindow: true, responderIsInsideWebView: true
    ), "Command-V must remain on the standard AppKit path")
    try require(!SettingsWindowController.shouldForwardControlPaste(
        characters: "v", modifierFlags: [.control, .shift], isKeyWindow: true, responderIsInsideWebView: true
    ), "mixed modifiers must not forward")
    try require(!SettingsWindowController.shouldForwardControlPaste(
        characters: "v", modifierFlags: [.control], isKeyWindow: false, responderIsInsideWebView: true
    ), "other windows must not forward")
    try require(!SettingsWindowController.shouldForwardControlPaste(
        characters: "v", modifierFlags: [.control], isKeyWindow: true, responderIsInsideWebView: false
    ), "responders outside the web view must not forward")
}

private func firstMouseWebViewContract() throws {
    let webView = LightSelectWebView(frame: .zero, configuration: WKWebViewConfiguration())
    try require(webView.acceptsFirstMouse(for: nil), "LightSelect web views must handle the first click")
}

private func uiFixtureSettingsContract() throws {
    let desktop = try UIFixtureRequest.parse(arguments: [
        "LightSelect", "--ui-test", "settings", "--appearance", "dark",
        "--language", "en-US", "--width", "900", "--height", "700",
        "--output", "/tmp/settings-en.png"
    ])
    try require(desktop.language == .enUS, "settings fixture language")
    try require(desktop.width == 900 && desktop.height == 700, "settings fixture desktop size")

    let narrow = try UIFixtureRequest.parse(arguments: [
        "LightSelect", "--ui-test", "settings", "--appearance", "light",
        "--language", "zh-CN", "--width", "520", "--height", "760",
        "--output", "/tmp/settings-zh.png"
    ])
    try require(narrow.language == .zhCN, "narrow fixture language")
    try require(narrow.width == 520 && narrow.height == 760, "narrow fixture size")

    do {
        _ = try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "settings", "--appearance", "light",
            "--language", "fr-FR", "--output", "/tmp/invalid.png"
        ])
        throw ContractFailure.failed("unsupported fixture language must fail")
    } catch UIFixtureError.invalidArguments {}

    do {
        _ = try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "settings", "--appearance", "light",
            "--width", "479", "--height", "760", "--output", "/tmp/invalid.png"
        ])
        throw ContractFailure.failed("undersized fixture must fail")
    } catch UIFixtureError.invalidArguments {}

    let settings = UIFixtureRequest.settings(for: .settings, language: .enUS)
    try require(settings.interfaceLanguage == .enUS, "fixture bootstrap language")
    try require(settings.api.baseURL == "http://127.0.0.1:18431/success/v1", "fixture API base URL")
    try require(UIFixtureRequest.fixtureModels == ["gpt-fixture-large", "gpt-fixture-small"], "fixture models")
    try require(UIFixtureRequest.fixtureLatencyMilliseconds == 24, "fixture latency")
}

private final class ContractSettingsStore: SettingsPersisting {
    var value = LightSelectSettings.default
    var apiKey: String?
    var hasAPIKey: Bool { apiKey != nil }
    var acceptsSaves = true

    func load() -> LightSelectSettings { value }
    func save(_ settings: LightSelectSettings) -> Bool {
        guard acceptsSaves else { return false }
        value = settings
        return true
    }
    func updateAPIKey(_ value: String?) { apiKey = value }
}

private final class ContractConfigurationService: OpenAIConfigurationServing {
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

private final class ContractMonitor: SelectionMonitoring {
    func start(settings: LightSelectSettings, handler: @escaping (SelectionSnapshot) -> Void) {}
    func update(settings: LightSelectSettings) {}
    func stop() {}
    func controlKeyReleased() {}
    func invokeShortcut() {}
}

private final class ContractRouter: SelectionActionRouting {
    func perform(action: SelectionActionItem, selectedText: String, anchor: CGPoint) {}
    func cancel(requestID: UUID) {}
    func regenerate() {}
    func cancelActive() {}
}

private final class ContractToolbar: ToolbarPanelControlling {
    func show(anchor: CGPoint, visibleFrame: CGRect) {}
    func resize(width: Double, height: Double) {}
    func send(_ event: WebEvent) {}
    func hide(animated: Bool) {}
    func invalidate() {}
}

private final class ContractActionPanel: ActionPanelControlling {
    var closeCount = 0
    func update(settings: LightSelectSettings) {}
    func setPinned(_ pinned: Bool) {}
    func setOpacity(_ opacity: Double) {}
    func send(_ event: WebEvent) {}
    func close() { closeCount += 1 }
    func invalidate() {}
}

private final class ContractSettingsWindow: SettingsWindowControlling {
    var events: [WebEvent] = []
    var closeCount = 0
    func show(section: SettingsSection?) {}
    func send(_ event: WebEvent) { events.append(event) }
    func close() { closeCount += 1 }
    func invalidate() {}
}

private let selected = CommandLine.arguments.dropFirst().first ?? "all"

do {
    if selected == "all" || selected == "settings-language" {
        try settingsLanguageContract()
    }
    if selected == "all" || selected == "preference-save" {
        try preferenceSaveContract()
    }
    if selected == "all" || selected == "settings-close" {
        try settingsCloseContract()
    }
    if selected == "all" || selected == "status-item-branding" {
        try statusItemBrandingContract()
    }
    if selected == "all" || selected == "api-configuration" {
        try apiConfigurationContract()
    }
    if selected == "all" || selected == "api-bridge" {
        try apiBridgeContract()
    }
    if selected == "all" || selected == "localization" {
        try localizationContract()
    }
    if selected == "all" || selected == "editing-menu" {
        try editingMenuContract()
    }
    if selected == "all" || selected == "first-mouse" {
        try firstMouseWebViewContract()
    }
    if selected == "all" || selected == "ui-fixture-settings" {
        try uiFixtureSettingsContract()
    }
    print("CONTRACT_OK \(selected)")
} catch {
    fputs("CONTRACT_FAILED \(selected): \(error)\n", stderr)
    exit(1)
}
