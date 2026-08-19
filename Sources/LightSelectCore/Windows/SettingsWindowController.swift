import AppKit

public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public let window: NSWindow
    public let host: WebViewHost
    public var onClose: (() -> Void)?
    private var state = SettingsPresentationState()
    private var keyDownMonitor: Any?

    public init(webRoot: URL, bridgeDelegate: SelectionWebBridgeDelegate? = nil) throws {
        host = try WebViewFactory.make(entry: .settings, webRoot: webRoot, bridgeDelegate: bridgeDelegate)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.delegate = self
        window.title = "LightSelect 设置"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 560)
        window.center()
        window.contentView = host.webView
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
    }

    deinit {
        removeKeyDownMonitor()
    }

    public func show(section: SettingsSection? = nil) {
        switch state.requestShow() {
        case .create:
            window.makeKeyAndOrderFront(nil)
        case .focusExisting:
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        if let section {
            let page = section == .api ? "api" : "general"
            let script = "document.querySelector('[data-settings-page=\"\(page)\"]')?.click()"
            host.webView.evaluateJavaScript(script)
        }
    }

    public func send(_ event: WebEvent) {
        host.bridge.send(event)
    }

    public func close() {
        window.performClose(nil)
    }

    public func setLanguage(_ language: InterfaceLanguage) {
        window.title = AppLocalization.strings(for: language).settingsTitle
    }

    public func invalidate() {
        removeKeyDownMonitor()
        window.orderOut(nil)
        window.delegate = nil
        state.didClose()
        host.bridge.invalidate()
    }

    public func windowWillClose(_ notification: Notification) {
        state.didClose()
        onClose?()
    }

    public static func shouldForwardControlPaste(
        characters: String?,
        modifierFlags: NSEvent.ModifierFlags,
        isKeyWindow: Bool,
        responderIsInsideWebView: Bool
    ) -> Bool {
        let shortcutFlags = modifierFlags.intersection([.command, .control, .option, .shift])
        return isKeyWindow
            && responderIsInsideWebView
            && shortcutFlags == .control
            && characters?.lowercased() == "v"
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let responderView = window.firstResponder as? NSView
        let responderIsInsideWebView = responderView.map {
            $0 === host.webView || $0.isDescendant(of: host.webView)
        } ?? false
        let isSettingsWindowKey = event.window === window && window.isKeyWindow
        guard Self.shouldForwardControlPaste(
            characters: event.charactersIgnoringModifiers,
            modifierFlags: event.modifierFlags,
            isKeyWindow: isSettingsWindowKey,
            responderIsInsideWebView: responderIsInsideWebView
        ), NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: window) else {
            return event
        }
        return nil
    }

    private func removeKeyDownMonitor() {
        guard let keyDownMonitor else { return }
        NSEvent.removeMonitor(keyDownMonitor)
        self.keyDownMonitor = nil
    }
}
