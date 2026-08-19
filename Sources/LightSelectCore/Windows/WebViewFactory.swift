import AppKit
import Foundation
import WebKit

public enum WebEntry: String, Sendable {
    case toolbar
    case action
    case settings

    fileprivate var relativePaths: [String] {
        ["src/\(rawValue)/index.html", "\(rawValue).html"]
    }
}

public enum WebViewFactoryError: Error, Equatable {
    case missingEntry(WebEntry)
}

public final class LightSelectWebView: WKWebView {
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

public final class WebViewHost {
    public let webView: WKWebView
    public let bridge: SelectionWebBridge
    private let navigationDelegate: LocalNavigationDelegate
    private let schemeHandler: LocalWebSchemeHandler

    public var onReady: (() -> Void)? {
        get { navigationDelegate.onReady }
        set { navigationDelegate.onReady = newValue }
    }

    fileprivate init(
        webView: WKWebView,
        bridge: SelectionWebBridge,
        navigationDelegate: LocalNavigationDelegate,
        schemeHandler: LocalWebSchemeHandler
    ) {
        self.webView = webView
        self.bridge = bridge
        self.navigationDelegate = navigationDelegate
        self.schemeHandler = schemeHandler
    }

    deinit {
        bridge.invalidate()
    }
}

public enum WebViewFactory {
    public static func make(
        entry: WebEntry,
        webRoot: URL,
        bridgeDelegate: SelectionWebBridgeDelegate? = nil
    ) throws -> WebViewHost {
        let fileManager = FileManager.default
        guard let entryURL = entry.relativePaths
            .map({ webRoot.appendingPathComponent($0) })
            .first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            throw WebViewFactoryError.missingEntry(entry)
        }

        let controller = WKUserContentController()
        let style = """
        (() => {
          const style = document.createElement('style');
          style.textContent = '::-webkit-scrollbar{display:none!important}';
          document.documentElement.appendChild(style);
        })();
        """
        controller.addUserScript(WKUserScript(source: style, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let schemeHandler = LocalWebSchemeHandler(root: webRoot)
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: LocalWebResource.scheme)

        let webView = LightSelectWebView(frame: .zero, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        let navigationDelegate = LocalNavigationDelegate()
        webView.navigationDelegate = navigationDelegate
        let bridge = SelectionWebBridge(webView: webView)
        bridge.delegate = bridgeDelegate
        let relativePath = String(entryURL.standardizedFileURL.path.dropFirst(webRoot.standardizedFileURL.path.count + 1))
        guard let entryRequestURL = LocalWebResource.entryURL(relativePath: relativePath) else {
            throw WebViewFactoryError.missingEntry(entry)
        }
        webView.load(URLRequest(url: entryRequestURL))
        return WebViewHost(
            webView: webView,
            bridge: bridge,
            navigationDelegate: navigationDelegate,
            schemeHandler: schemeHandler
        )
    }

    public static func bundledWebRoot(bundle: Bundle = .main) -> URL? {
        bundle.resourceURL?.appendingPathComponent("Web", isDirectory: true)
    }
}

private final class LocalNavigationDelegate: NSObject, WKNavigationDelegate {
    var onReady: (() -> Void)?

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              url.scheme == LocalWebResource.scheme,
              url.host == LocalWebResource.host else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onReady?()
    }
}
