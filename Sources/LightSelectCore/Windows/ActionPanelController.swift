import AppKit

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

public final class ActionPanelController: NSObject, NSWindowDelegate {
    public let panel: NSPanel
    public let host: WebViewHost
    public var onRememberedSizeChanged: ((CGSize) -> Void)?
    private var state: ActionPanelState
    private var rememberWindowSize: Bool

    public init(
        webRoot: URL,
        settings: LightSelectSettings,
        rememberedSize: CGSize? = nil,
        visibleFrame: CGRect? = nil,
        bridgeDelegate: SelectionWebBridgeDelegate? = nil
    ) throws {
        host = try WebViewFactory.make(entry: .action, webRoot: webRoot, bridgeDelegate: bridgeDelegate)
        state = ActionPanelState(
            pinned: settings.autoPin,
            autoClose: settings.autoClose,
            opacity: Double(settings.actionWindowOpacity) / 100
        )
        rememberWindowSize = settings.rememberWindowSize
        let proposedSize = rememberedSize ?? CGSize(width: 500, height: 400)
        let size = visibleFrame.map { ActionPanelState.clampedSize(proposedSize, visibleFrame: $0) } ?? proposedSize
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.delegate = self
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = host.webView
        applyState()
    }

    public func update(settings: LightSelectSettings) {
        state.pinned = settings.autoPin
        state.autoClose = settings.autoClose
        state.setOpacity(Double(settings.actionWindowOpacity) / 100)
        rememberWindowSize = settings.rememberWindowSize
        applyState()
    }

    public func show(toolbarFrame: CGRect, visibleFrame: CGRect) {
        let size = ActionPanelState.clampedSize(panel.frame.size, visibleFrame: visibleFrame)
        panel.setContentSize(size)
        panel.setFrameOrigin(SelectionPositioner.actionOrigin(
            toolbarFrame: toolbarFrame,
            actionSize: size,
            visibleFrame: visibleFrame
        ))
        panel.makeKeyAndOrderFront(nil)
    }

    public func setPinned(_ pinned: Bool) {
        state.pinned = pinned
        applyState()
    }

    public func setOpacity(_ opacity: Double) {
        state.setOpacity(opacity)
        applyState()
    }

    public func send(_ event: WebEvent) {
        host.bridge.send(event)
    }

    public func close() {
        panel.orderOut(nil)
    }

    public func invalidate() {
        panel.orderOut(nil)
        panel.delegate = nil
        host.bridge.invalidate()
    }

    public func windowDidResignKey(_ notification: Notification) {
        if state.shouldCloseOnResignKey { close() }
    }

    public func windowDidResize(_ notification: Notification) {
        if rememberWindowSize { onRememberedSizeChanged?(panel.frame.size) }
    }

    private func applyState() {
        panel.alphaValue = state.opacity
        panel.level = state.pinned ? .statusBar : .floating
    }
}
