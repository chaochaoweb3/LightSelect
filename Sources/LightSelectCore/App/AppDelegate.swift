import AppKit
import ApplicationServices
import Foundation

public enum StatusItemAppearance {
    public static func apply(to button: NSStatusBarButton) {
        button.title = ""
        button.toolTip = "LightSelect"
        button.imagePosition = .imageOnly

        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(
            systemSymbolName: "cursorarrow.rays",
            accessibilityDescription: "LightSelect"
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image
    }
}

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/LightSelect.log")

    private var statusItem: NSStatusItem?
    private var enabledItem: NSMenuItem?
    private var settingsStore: SettingsStore?
    private var monitor: SelectionMonitor?
    private var toolbar: ToolbarPanelController?
    private var actionPanel: ActionPanelController?
    private var settingsWindow: SettingsWindowController?
    private var coordinator: AppCoordinator?
    private var globalMonitors: [Any] = []
    private var testClient: OpenAIClient?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            try configureApplication()
            rebuildMainMenu(language: coordinator?.settings.interfaceLanguage ?? .zhCN)
            setupStatusItem()
            installGlobalMonitors()
            requestAccessibilityIfNeeded()
            coordinator?.launch()
            log("launched trusted=\(AXIsProcessTrusted())")
        } catch {
            let alert = NSAlert(error: error)
            let language = settingsStore?.load().interfaceLanguage ?? .zhCN
            alert.messageText = AppLocalization.strings(for: language).startupFailure
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        globalMonitors.forEach(NSEvent.removeMonitor)
        globalMonitors.removeAll()
        coordinator?.terminate()
        testClient?.cancelActiveRequests()
        log("terminated")
    }

    private func configureApplication() throws {
        let webRoot = try resolveWebRoot()
        let store = SettingsStore()
        let currentSettings = store.load()
        guard let nativeHook = NativeSelectionHook() else { throw AppStartupError.nativeHook }
        let monitor = SelectionMonitor(hook: nativeHook)
        let toolbar = try ToolbarPanelController(webRoot: webRoot)
        let actionPanel = try ActionPanelController(
            webRoot: webRoot,
            settings: currentSettings,
            visibleFrame: NSScreen.main?.visibleFrame
        )
        let settingsWindow = try SettingsWindowController(webRoot: webRoot)
        let configurationService = OpenAIConfigurationService()
        let client = OpenAIClient()
        let router = SelectionActionRouter(
            client: client,
            settings: { store.load() },
            apiKey: { store.apiKey },
            presentAction: { [weak actionPanel, weak toolbar] anchor in
                guard let actionPanel else { return }
                let visible = Self.visibleFrame(containing: anchor)
                let settings = store.load()
                let toolbarFrame = settings.followToolbar
                    ? (toolbar?.panel.frame ?? CGRect(origin: anchor, size: .zero))
                    : CGRect(origin: anchor, size: .zero)
                actionPanel.show(toolbarFrame: toolbarFrame, visibleFrame: visible)
            },
            emit: { [weak actionPanel] event in actionPanel?.send(event) },
            copyText: Self.writePasteboard,
            openURL: { NSWorkspace.shared.open($0) }
        )
        let coordinator = AppCoordinator(
            settingsStore: store,
            monitor: monitor,
            router: router,
            toolbar: toolbar,
            actionPanel: actionPanel,
            settingsWindow: settingsWindow,
            configurationService: configurationService,
            anchor: { _ in NSEvent.mouseLocation },
            visibleFrame: Self.visibleFrame(containing:),
            copyText: Self.writePasteboard,
            openURL: { NSWorkspace.shared.open($0) },
            openAccessibilitySettings: Self.openAccessibilitySettings,
            openSource: Self.openSource
        )
        toolbar.host.bridge.delegate = coordinator
        actionPanel.host.bridge.delegate = coordinator
        settingsWindow.host.bridge.delegate = coordinator
        toolbar.host.onReady = { [weak coordinator] in coordinator?.broadcastBootstrap() }
        actionPanel.host.onReady = { [weak coordinator] in coordinator?.broadcastBootstrap() }
        settingsWindow.host.onReady = { [weak coordinator] in coordinator?.broadcastBootstrap() }
        settingsWindow.onClose = { [weak coordinator] in coordinator?.settingsWindowDidClose() }
        coordinator.onSettingsChanged = { [weak self] settings in
            self?.rebuildMainMenu(language: settings.interfaceLanguage)
            self?.rebuildStatusMenu(language: settings.interfaceLanguage)
            self?.settingsWindow?.setLanguage(settings.interfaceLanguage)
        }

        settingsStore = store
        self.monitor = monitor
        self.toolbar = toolbar
        self.actionPanel = actionPanel
        self.settingsWindow = settingsWindow
        self.coordinator = coordinator
    }

    private func resolveWebRoot() throws -> URL {
        if let bundled = WebViewFactory.bundledWebRoot(),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        let development = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Web", isDirectory: true)
        guard FileManager.default.fileExists(atPath: development.path) else {
            throw AppStartupError.webResources
        }
        return development
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            StatusItemAppearance.apply(to: button)
        }
        self.statusItem = statusItem
        rebuildStatusMenu(language: coordinator?.settings.interfaceLanguage ?? .zhCN)
    }

    private func rebuildMainMenu(language: InterfaceLanguage) {
        NSApp.mainMenu = ApplicationMenuFactory.make(language: language)
    }

    private func rebuildStatusMenu(language: InterfaceLanguage) {
        guard let statusItem else { return }
        let strings = AppLocalization.strings(for: language)
        let menu = NSMenu()
        let enabled = item(strings.enabled, #selector(toggleEnabled(_:)))
        enabled.state = coordinator?.settings.enabled == true ? .on : .off
        menu.addItem(enabled)
        menu.addItem(item(strings.selectionSettings, #selector(openSelectionSettings), key: ","))
        menu.addItem(item(strings.apiSettings, #selector(openAPISettings)))
        menu.addItem(item(strings.testAPI, #selector(testAPI), key: "t"))
        menu.addItem(.separator())
        menu.addItem(item(strings.showTestToolbar, #selector(showTestToolbar)))
        menu.addItem(item(strings.showTestAction, #selector(showTestAction)))
        menu.addItem(.separator())
        menu.addItem(item(strings.openAccessibility, #selector(openAccessibility)))
        menu.addItem(item(strings.openLog, #selector(openLog)))
        menu.addItem(item(strings.viewSource, #selector(openSourceCode)))
        menu.addItem(.separator())
        menu.addItem(item(strings.quit, #selector(quit), key: "q"))
        statusItem.menu = menu
        enabledItem = enabled
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func installGlobalMonitors() {
        if let eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .scrollWheel],
            handler: { [weak self] _ in self?.coordinator?.selectionCleared() }
        ) {
            globalMonitors.append(eventMonitor)
        }
        if let eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            if (event.keyCode == 59 || event.keyCode == 62), !event.modifierFlags.contains(.control) {
                self?.coordinator?.controlKeyReleased()
            }
        }) {
            globalMonitors.append(eventMonitor)
        }
        if let eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains([.command, .shift]), event.charactersIgnoringModifiers?.lowercased() == "l" {
                self?.coordinator?.invokeShortcut()
            } else if !flags.contains(.shift) && !flags.contains(.option) {
                self?.coordinator?.selectionCleared()
            }
        }) {
            globalMonitors.append(eventMonitor)
        }
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        coordinator?.receive(.updatePreference(
            requestID: "native-\(UUID().uuidString)",
            update: .enabled(sender.state != .on)
        ))
    }

    @objc private func openSelectionSettings() { coordinator?.receive(.openSettings(.selection)) }
    @objc private func openAPISettings() { coordinator?.receive(.openSettings(.api)) }
    @objc private func openAccessibility() { Self.openAccessibilitySettings() }
    @objc private func openSourceCode() { Self.openSource() }
    @objc private func openLog() { NSWorkspace.shared.open(Self.logURL) }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showTestToolbar() {
        guard let toolbar else { return }
        let anchor = NSEvent.mouseLocation
        toolbar.send(.textSelected(text: "LightSelect 2.0 selection fixture", isFullscreen: false))
        toolbar.send(.toolbarVisibilityChanged(true))
        toolbar.show(anchor: anchor, visibleFrame: Self.visibleFrame(containing: anchor))
    }

    @objc private func showTestAction() {
        guard let actionPanel else { return }
        let anchor = NSEvent.mouseLocation
        let requestID = UUID().uuidString
        let action = settingsStore?.load().actionItems.first(where: { $0.id == "translate" })
            ?? SelectionActionItem(id: "translate", name: "Translate", enabled: true, isBuiltIn: true)
        actionPanel.send(.actionStarted(requestID: requestID, action: action, selectedText: "LightSelect fixture"))
        actionPanel.send(.actionCompleted(requestID: requestID, content: "LightSelect fixture response"))
        actionPanel.show(
            toolbarFrame: toolbar?.panel.frame ?? CGRect(origin: anchor, size: .zero),
            visibleFrame: Self.visibleFrame(containing: anchor)
        )
    }

    @objc private func testAPI() {
        guard let store = settingsStore else { return }
        let settings = store.load()
        let strings = AppLocalization.strings(for: settings.interfaceLanguage)
        let client = OpenAIClient()
        testClient = client
        _ = client.stream(request: .init(
            baseURL: settings.api.baseURL,
            apiKey: store.apiKey ?? "",
            model: settings.api.model,
            prompt: "Reply only with OK.",
            timeoutSeconds: settings.api.timeoutSeconds
        )) { [weak self] event in
            switch event {
            case .completed(_, let content): self?.showAPIResult(title: strings.apiSuccess, message: content)
            case .failed(_, let error): self?.showAPIResult(title: strings.apiFailure, message: error.localizedDescription)
            default: break
            }
        }
    }

    private func showAPIResult(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.testClient = nil
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
        }
    }

    private static func visibleFrame(containing point: CGPoint) -> CGRect {
        NSScreen.screens.first(where: { $0.frame.contains(point) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1_440, height: 900)
    }

    private static func writePasteboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func openSource() {
        if let url = URL(string: "https://github.com/chaochaoweb3/LightSelect") {
            NSWorkspace.shared.open(url)
        }
    }

    private func log(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: Self.logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            FileManager.default.createFile(atPath: Self.logURL.path, contents: data)
        }
    }
}

private enum AppStartupError: LocalizedError {
    case nativeHook
    case webResources

    var errorDescription: String? {
        switch self {
        case .nativeHook: "Native selection hook could not be created."
        case .webResources: "Bundled Web resources are missing."
        }
    }
}

private extension OpenAIClient {
    func cancelActiveRequests() {
        // Individual test requests finish or are cancelled by URLSession invalidation on release.
    }
}
