import AppKit

public final class ToolbarPanelController {
    public let panel: NSPanel
    public let host: WebViewHost
    private var state = ToolbarPanelState()

    public init(webRoot: URL, bridgeDelegate: SelectionWebBridgeDelegate? = nil) throws {
        host = try WebViewFactory.make(entry: .toolbar, webRoot: webRoot, bridgeDelegate: bridgeDelegate)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = host.webView
    }

    public func show(anchor: CGPoint, visibleFrame: CGRect) {
        _ = state.show()
        panel.animator().alphaValue = 1
        let origin = SelectionPositioner.toolbarOrigin(
            anchor: anchor,
            toolbarSize: panel.frame.size,
            visibleFrame: visibleFrame
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    public func resize(width: Double, height: Double) {
        let size = CGSize(width: max(1, ceil(width)), height: max(1, ceil(height)))
        panel.setContentSize(size)
    }

    public func send(_ event: WebEvent) {
        host.bridge.send(event)
    }

    public func hide(animated: Bool = true) {
        guard let token = state.beginHide() else { return }
        let finish = { [weak self] in
            guard let self, self.state.completeHide(token: token) else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        }
        guard animated else {
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }

    public func invalidate() {
        state = ToolbarPanelState()
        panel.orderOut(nil)
        host.bridge.invalidate()
    }
}
