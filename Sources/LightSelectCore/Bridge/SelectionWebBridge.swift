import Foundation
import WebKit

public protocol SelectionWebBridgeDelegate: AnyObject {
    func selectionWebBridge(_ bridge: SelectionWebBridge, didReceive command: WebCommand)
}

public enum SelectionWebBridgeError: Error, Equatable {
    case invalidBody
    case invalidEventEncoding
}

public final class SelectionWebBridge: NSObject, WKScriptMessageHandler {
    public static let handlerName = "lightselect"

    public weak var delegate: SelectionWebBridgeDelegate?
    private weak var webView: WKWebView?
    private weak var userContentController: WKUserContentController?
    private var isInvalidated = false

    public init(webView: WKWebView) {
        self.webView = webView
        userContentController = webView.configuration.userContentController
        super.init()
        webView.configuration.userContentController.add(self, name: Self.handlerName)
    }

    deinit {
        invalidate()
    }

    public static func decodeCommand(body: Any) throws -> WebCommand {
        guard JSONSerialization.isValidJSONObject(body) else { throw SelectionWebBridgeError.invalidBody }
        let data = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(WebCommand.self, from: data)
    }

    public static func javaScript(for event: WebEvent) throws -> String {
        let data = try JSONEncoder().encode(event)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SelectionWebBridgeError.invalidEventEncoding
        }
        return "window.dispatchEvent(new CustomEvent('lightselect:event', { detail: \(json) }))"
    }

    public func send(_ event: WebEvent, completion: ((Error?) -> Void)? = nil) {
        do {
            let script = try Self.javaScript(for: event)
            guard let webView else {
                completion?(SelectionWebBridgeError.invalidBody)
                return
            }
            webView.evaluateJavaScript(script) { _, error in completion?(error) }
        } catch {
            completion?(error)
        }
    }

    public func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        userContentController?.removeScriptMessageHandler(forName: Self.handlerName)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !isInvalidated, message.name == Self.handlerName,
              let command = try? Self.decodeCommand(body: message.body) else { return }
        delegate?.selectionWebBridge(self, didReceive: command)
    }
}
