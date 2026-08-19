import Foundation

public protocol SettingsPersisting: AnyObject {
    var apiKey: String? { get }
    var hasAPIKey: Bool { get }
    func load() -> LightSelectSettings
    @discardableResult func save(_ settings: LightSelectSettings) -> Bool
    func updateAPIKey(_ value: String?)
}

extension SettingsStore: SettingsPersisting {}

public protocol SelectionMonitoring: AnyObject {
    func start(settings: LightSelectSettings, handler: @escaping (SelectionSnapshot) -> Void)
    func update(settings: LightSelectSettings)
    func stop()
    func controlKeyReleased()
    func invokeShortcut()
}

extension SelectionMonitor: SelectionMonitoring {}

public protocol SelectionActionRouting: AnyObject {
    func perform(action: SelectionActionItem, selectedText: String, anchor: CGPoint)
    func cancel(requestID: UUID)
    func regenerate()
    func cancelActive()
}

extension SelectionActionRouter: SelectionActionRouting {}

public protocol ToolbarPanelControlling: AnyObject {
    func show(anchor: CGPoint, visibleFrame: CGRect)
    func resize(width: Double, height: Double)
    func send(_ event: WebEvent)
    func hide(animated: Bool)
    func invalidate()
}

extension ToolbarPanelController: ToolbarPanelControlling {}

public protocol ActionPanelControlling: AnyObject {
    func update(settings: LightSelectSettings)
    func setPinned(_ pinned: Bool)
    func setOpacity(_ opacity: Double)
    func send(_ event: WebEvent)
    func close()
    func invalidate()
}

extension ActionPanelController: ActionPanelControlling {}

public protocol SettingsWindowControlling: AnyObject {
    func show(section: SettingsSection?)
    func send(_ event: WebEvent)
    func close()
    func invalidate()
}

extension SettingsWindowController: SettingsWindowControlling {}

public final class AppCoordinator: SelectionWebBridgeDelegate {
    public private(set) var settings: LightSelectSettings
    public var onSettingsChanged: ((LightSelectSettings) -> Void)?
    private let settingsStore: SettingsPersisting
    private let monitor: SelectionMonitoring
    private let router: SelectionActionRouting
    private let toolbar: ToolbarPanelControlling
    private let actionPanel: ActionPanelControlling
    private let settingsWindow: SettingsWindowControlling
    private let configurationService: OpenAIConfigurationServing
    private let anchorProvider: (SelectionSnapshot) -> CGPoint
    private let visibleFrameProvider: (CGPoint) -> CGRect
    private let copyText: (String) -> Bool
    private let openURL: (URL) -> Bool
    private let openAccessibilitySettings: () -> Void
    private let openSource: () -> Void
    private var monitoring = false
    private var currentAnchor = CGPoint.zero
    private var activeConfigurationRequests: [UUID: APIConfigurationOperation] = [:]

    public init(
        settingsStore: SettingsPersisting,
        monitor: SelectionMonitoring,
        router: SelectionActionRouting,
        toolbar: ToolbarPanelControlling,
        actionPanel: ActionPanelControlling,
        settingsWindow: SettingsWindowControlling,
        configurationService: OpenAIConfigurationServing,
        anchor: @escaping (SelectionSnapshot) -> CGPoint,
        visibleFrame: @escaping (CGPoint) -> CGRect,
        copyText: @escaping (String) -> Bool,
        openURL: @escaping (URL) -> Bool,
        openAccessibilitySettings: @escaping () -> Void,
        openSource: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.monitor = monitor
        self.router = router
        self.toolbar = toolbar
        self.actionPanel = actionPanel
        self.settingsWindow = settingsWindow
        self.configurationService = configurationService
        anchorProvider = anchor
        visibleFrameProvider = visibleFrame
        self.copyText = copyText
        self.openURL = openURL
        self.openAccessibilitySettings = openAccessibilitySettings
        self.openSource = openSource
        settings = settingsStore.load()
    }

    public func launch() {
        settings = settingsStore.load()
        actionPanel.update(settings: settings)
        onSettingsChanged?(settings)
        broadcastBootstrap()
        if settings.enabled { startMonitoring() }
    }

    public func broadcastBootstrap() {
        broadcast(.bootstrap(preferences: settings, hasAPIKey: settingsStore.hasAPIKey))
    }

    public func selectionCleared() {
        toolbar.send(.toolbarVisibilityChanged(false))
        toolbar.hide(animated: true)
    }

    public func controlKeyReleased() {
        monitor.controlKeyReleased()
    }

    public func invokeShortcut() {
        monitor.invokeShortcut()
    }

    public func terminate() {
        monitoring = false
        monitor.stop()
        router.cancelActive()
        cancelAllConfigurationRequests(emitEvents: false)
        toolbar.invalidate()
        actionPanel.invalidate()
        settingsWindow.invalidate()
    }

    public func receive(_ command: WebCommand) {
        switch command {
        case .performAction(let actionID, let selectedText):
            guard let action = settings.actionItems.first(where: { $0.id == actionID }) else { return }
            router.perform(action: action, selectedText: selectedText, anchor: currentAnchor)
            selectionCleared()
        case .determineToolbarSize(let width, let height):
            toolbar.resize(width: width, height: height)
        case .copySelectedText(let text), .copyResult(let text):
            _ = copyText(text)
        case .openURL(let value):
            if let url = Self.url(from: value) {
                _ = openURL(url)
                selectionCleared()
            }
        case .closeAction:
            actionPanel.close()
        case .pinAction(let pinned):
            actionPanel.setPinned(pinned)
        case .setActionOpacity(let opacity):
            actionPanel.setOpacity(opacity)
        case .cancelAction(let requestID):
            if let id = UUID(uuidString: requestID) { router.cancel(requestID: id) }
        case .regenerateAction:
            router.regenerate()
        case .updatePreference(let requestID, let update):
            apply(requestID: requestID, update: update)
        case .updateAPIKey(let value):
            settingsStore.updateAPIKey(value)
            broadcastBootstrap()
        case .fetchModels(let requestID, let configuration, let apiKeyInput):
            beginModelsRequest(requestID: requestID, settings: configuration, apiKeyInput: apiKeyInput)
        case .testConnection(let requestID, let configuration, let apiKeyInput):
            beginConnectionRequest(requestID: requestID, settings: configuration, apiKeyInput: apiKeyInput)
        case .cancelAPIRequest(let requestID):
            cancelConfigurationRequest(requestID: requestID)
        case .openSettings(let section):
            settingsWindow.show(section: section)
        case .closeSettings:
            settingsWindow.close()
        case .openAccessibilitySettings:
            openAccessibilitySettings()
        case .openSource:
            openSource()
        }
    }

    public func selectionWebBridge(_ bridge: SelectionWebBridge, didReceive command: WebCommand) {
        receive(command)
    }

    public func settingsWindowDidClose() {
        cancelAllConfigurationRequests(emitEvents: false)
    }

    private func beginModelsRequest(requestID: String, settings: APISettings, apiKeyInput: String?) {
        guard let id = UUID(uuidString: requestID),
              let configuration = resolveConfiguration(settings: settings, apiKeyInput: apiKeyInput) else {
            settingsWindow.send(.apiRequestFailed(requestID: requestID, operation: .models, code: APIConfigurationError.configuration.rawValue))
            return
        }
        activeConfigurationRequests[id] = .models
        configurationService.fetchModels(requestID: id, configuration: configuration) { [weak self] result in
            guard let self, self.activeConfigurationRequests.removeValue(forKey: id) == .models else { return }
            switch result {
            case .success(let value):
                self.settingsWindow.send(.modelsLoaded(
                    requestID: requestID,
                    models: value.models,
                    latencyMilliseconds: value.latencyMilliseconds
                ))
            case .failure(.cancelled):
                self.settingsWindow.send(.apiRequestCancelled(requestID: requestID))
            case .failure(let error):
                self.settingsWindow.send(.apiRequestFailed(requestID: requestID, operation: .models, code: error.rawValue))
            }
        }
    }

    private func beginConnectionRequest(requestID: String, settings: APISettings, apiKeyInput: String?) {
        guard let id = UUID(uuidString: requestID),
              let configuration = resolveConfiguration(settings: settings, apiKeyInput: apiKeyInput) else {
            settingsWindow.send(.apiRequestFailed(requestID: requestID, operation: .connection, code: APIConfigurationError.configuration.rawValue))
            return
        }
        activeConfigurationRequests[id] = .connection
        configurationService.testConnection(requestID: id, configuration: configuration) { [weak self] result in
            guard let self, self.activeConfigurationRequests.removeValue(forKey: id) == .connection else { return }
            switch result {
            case .success(let value):
                self.settingsWindow.send(.connectionSucceeded(
                    requestID: requestID,
                    latencyMilliseconds: value.latencyMilliseconds
                ))
            case .failure(.cancelled):
                self.settingsWindow.send(.apiRequestCancelled(requestID: requestID))
            case .failure(let error):
                self.settingsWindow.send(.apiRequestFailed(requestID: requestID, operation: .connection, code: error.rawValue))
            }
        }
    }

    private func resolveConfiguration(settings: APISettings, apiKeyInput: String?) -> APIConfiguration? {
        let input = apiKeyInput?.trimmingCharacters(in: .whitespacesAndNewlines)
        let genuineInput = input.flatMap { value in
            !value.isEmpty && value != SettingsStore.maskedAPIKey ? value : nil
        }
        if let genuineInput { settingsStore.updateAPIKey(genuineInput) }
        let resolvedKey = genuineInput ?? settingsStore.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !resolvedKey.isEmpty else { return nil }
        return APIConfiguration(
            baseURL: settings.baseURL,
            apiKey: resolvedKey,
            model: settings.model,
            timeoutSeconds: settings.timeoutSeconds
        )
    }

    private func cancelConfigurationRequest(requestID: String) {
        guard let id = UUID(uuidString: requestID), activeConfigurationRequests.removeValue(forKey: id) != nil else { return }
        configurationService.cancel(requestID: id)
        settingsWindow.send(.apiRequestCancelled(requestID: requestID))
    }

    private func cancelAllConfigurationRequests(emitEvents: Bool) {
        let requestIDs = activeConfigurationRequests.keys
        activeConfigurationRequests.removeAll()
        configurationService.cancelAll()
        if emitEvents {
            requestIDs.forEach { settingsWindow.send(.apiRequestCancelled(requestID: $0.uuidString)) }
        }
    }

    private func startMonitoring() {
        guard !monitoring else {
            monitor.update(settings: settings)
            return
        }
        monitoring = true
        monitor.start(settings: settings) { [weak self] selection in self?.selected(selection) }
    }

    private func selected(_ selection: SelectionSnapshot) {
        currentAnchor = anchorProvider(selection)
        toolbar.send(.textSelected(text: selection.text, isFullscreen: selection.isFullscreen))
        toolbar.send(.toolbarVisibilityChanged(true))
        toolbar.show(anchor: currentAnchor, visibleFrame: visibleFrameProvider(currentAnchor))
    }

    private func apply(requestID: String, update: SelectionPreferenceUpdate) {
        let wasEnabled = settings.enabled
        var candidate = settings
        update.apply(to: &candidate)
        guard settingsStore.save(candidate) else {
            settingsWindow.send(.preferenceSaveFailed(requestID: requestID, key: update.key))
            return
        }
        settings = candidate
        actionPanel.update(settings: settings)
        onSettingsChanged?(settings)

        if settings.enabled {
            startMonitoring()
        } else if wasEnabled && monitoring {
            monitoring = false
            monitor.stop()
            selectionCleared()
        }
        broadcast(.preferenceChanged(update))
        settingsWindow.send(.preferenceSaved(requestID: requestID, update: update))
    }

    private func broadcast(_ event: WebEvent) {
        toolbar.send(event)
        actionPanel.send(event)
        settingsWindow.send(event)
    }

    private static func url(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") { return URL(fileURLWithPath: trimmed) }
        return URL(string: trimmed)
    }
}
