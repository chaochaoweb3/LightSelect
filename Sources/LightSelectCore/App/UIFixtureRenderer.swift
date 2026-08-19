import AppKit
import Foundation
import WebKit

public enum UIFixtureRenderer {
    public static func render(_ request: UIFixtureRequest) throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.finishLaunching()
        let runner = try UIFixtureRunner(request: request, webRoot: resolveWebRoot())
        runner.start()
        application.run()
        if let error = runner.error { throw error }
    }

    private static func resolveWebRoot() throws -> URL {
        if let bundled = WebViewFactory.bundledWebRoot(),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        let development = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Web", isDirectory: true)
        guard FileManager.default.fileExists(atPath: development.path) else {
            throw UIFixtureError.missingWebResources
        }
        return development
    }
}

private final class UIFixtureRunner {
    private static let selectedText = "LightSelect 2.0 selection fixture"
    private static let requestID = "00000000-0000-4000-8000-000000000200"

    let request: UIFixtureRequest
    let host: WebViewHost
    let window: NSWindow
    private let webRoot: URL
    private var timeout: Timer?
    private(set) var error: Error?
    private var finished = false

    init(request: UIFixtureRequest, webRoot: URL) throws {
        self.request = request
        self.webRoot = webRoot
        let entry: WebEntry
        switch request.kind {
        case .toolbar:
            entry = .toolbar
        case .action:
            entry = .action
        case .settings:
            entry = .settings
        }
        host = try WebViewFactory.make(entry: entry, webRoot: webRoot)
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: request.width, height: request.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = host.webView
        host.bridge.delegate = self
    }

    func start() {
        timeout = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            self?.finish(UIFixtureError.snapshotFailed)
        }
        host.onReady = { [weak self] in
            self?.waitForBridgeReady(attempt: 0)
        }
        window.orderFrontRegardless()
    }

    private func waitForBridgeReady(attempt: Int) {
        guard attempt < 100 else {
            finish(UIFixtureError.snapshotFailed)
            return
        }
        host.webView.evaluateJavaScript("document.documentElement.dataset.lightselectReady === 'true'") { [weak self] value, error in
            guard let self else { return }
            if error != nil {
                self.finish(UIFixtureError.snapshotFailed)
            } else if (value as? Bool) == true {
                self.loadFixture()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.waitForBridgeReady(attempt: attempt + 1)
                }
            }
        }
    }

    private func loadFixture() {
        let settings = UIFixtureRequest.settings(for: request.kind, language: request.language)
        host.bridge.send(.bootstrap(preferences: settings, hasAPIKey: true))
        host.bridge.send(.appearanceChanged(request.appearance))
        switch request.kind {
        case .toolbar:
            host.bridge.send(.textSelected(text: Self.selectedText, isFullscreen: false))
            host.bridge.send(.toolbarVisibilityChanged(true))
        case .action:
            guard let response = try? fixtureResponse() else {
                finish(UIFixtureError.missingFixtureResponse)
                return
            }
            let action = settings.actionItems.first(where: { $0.id == "translate" })!
            host.bridge.send(.actionStarted(
                requestID: Self.requestID,
                action: action,
                selectedText: Self.selectedText
            ))
            host.bridge.send(.actionCompleted(requestID: Self.requestID, content: response))
        case .settings:
            break
        }

        let deterministicCSS = """
        (() => {
          const style = document.createElement('style');
          style.textContent = '*,*::before,*::after{animation:none!important;transition:none!important;scroll-behavior:auto!important}';
          document.head.appendChild(style);
          document.documentElement.dataset.uiTest = 'true';
          document.querySelector('[data-settings-page="api"]')?.click();
        })();
        """
        host.webView.evaluateJavaScript(deterministicCSS) { [weak self] _, scriptError in
            guard let self else { return }
            if let scriptError {
                self.finish(scriptError)
                return
            }
            self.waitForFixtureElement(attempt: 0)
        }
    }

    private func waitForFixtureElement(attempt: Int) {
        guard attempt < 100 else {
            finish(UIFixtureError.snapshotFailed)
            return
        }
        let selector: String
        switch request.kind {
        case .toolbar: selector = "[data-ui='selection.toolbar']"
        case .action: selector = "[data-ui='selection.action']"
        case .settings: selector = "[data-ui='settings.page.api']"
        }
        let script = "Boolean(document.querySelector(\(String(reflecting: selector))))"
        host.webView.evaluateJavaScript(script) { [weak self] value, error in
            guard let self else { return }
            if error != nil {
                self.finish(UIFixtureError.snapshotFailed)
            } else if (value as? Bool) == true {
                self.prepareSnapshot()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.waitForFixtureElement(attempt: attempt + 1)
                }
            }
        }
    }

    private func prepareSnapshot() {
        if request.kind == .settings {
            prepareSettingsSnapshot()
            return
        }
        guard request.kind == .toolbar else {
            snapshot()
            return
        }
        let geometry = """
        (() => {
          const element = document.querySelector('[data-ui="selection.toolbar"]');
          if (!(element instanceof HTMLElement)) return null;
          const rect = element.getBoundingClientRect();
          const style = getComputedStyle(element);
          return {
            width: Math.ceil(rect.width + parseFloat(style.marginLeft) + parseFloat(style.marginRight)),
            height: Math.ceil(rect.height + parseFloat(style.marginTop) + parseFloat(style.marginBottom))
          };
        })();
        """
        host.webView.evaluateJavaScript(geometry) { [weak self] value, evaluationError in
            guard let self else { return }
            if let evaluationError {
                self.finish(evaluationError)
                return
            }
            guard let dimensions = value as? [String: Any],
                  let width = dimensions["width"] as? NSNumber,
                  let height = dimensions["height"] as? NSNumber else {
                self.finish(UIFixtureError.snapshotFailed)
                return
            }
            self.window.setContentSize(CGSize(width: width.doubleValue, height: height.doubleValue))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.snapshot() }
        }
    }

    private func prepareSettingsSnapshot() {
        let trigger = """
        (() => {
          const baseURL = document.querySelector('input[aria-label="Base URL"]');
          if (baseURL instanceof HTMLInputElement) { baseURL.focus(); baseURL.blur(); }
          document.querySelector('.lightselect-model-combobox button')?.click();
          document.querySelector('.lightselect-api-connection > button')?.click();
        })();
        """
        host.webView.evaluateJavaScript(trigger) { [weak self] _, error in
            guard let self else { return }
            if let error {
                self.finish(error)
                return
            }
            self.waitForSettingsStatus(attempt: 0)
        }
    }

    private func waitForSettingsStatus(attempt: Int) {
        guard attempt < 100 else {
            finish(UIFixtureError.snapshotFailed)
            return
        }
        let ready = """
        (() => {
          const apiStatuses = document.querySelectorAll('.lightselect-api-status.is-success');
          const saved = document.querySelector('[data-ui="settings.save-status"].is-saved');
          return apiStatuses.length === 2 && saved instanceof HTMLElement && saved.innerText.trim().length > 0;
        })();
        """
        host.webView.evaluateJavaScript(ready) { [weak self] value, error in
            guard let self else { return }
            if error != nil {
                self.finish(UIFixtureError.snapshotFailed)
            } else if (value as? Bool) == true {
                let closeModels = "document.querySelector('[role=\"combobox\"]')?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))"
                self.host.webView.evaluateJavaScript(closeModels) { [weak self] _, closeError in
                    guard let self else { return }
                    if let closeError {
                        self.finish(closeError)
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.snapshot() }
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.waitForSettingsStatus(attempt: attempt + 1)
                }
            }
        }
    }

    private func snapshot() {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = host.webView.bounds
        configuration.afterScreenUpdates = true
        host.webView.takeSnapshot(with: configuration) { [weak self] image, snapshotError in
            guard let self else { return }
            if let snapshotError {
                self.finish(snapshotError)
                return
            }
            guard let image,
                  let tiff = image.tiffRepresentation,
                  let representation = NSBitmapImageRep(data: tiff),
                  let png = representation.representation(using: .png, properties: [:]) else {
                self.finish(UIFixtureError.snapshotFailed)
                return
            }
            do {
                try FileManager.default.createDirectory(
                    at: self.request.outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try png.write(to: self.request.outputURL, options: .atomic)
                self.finish(nil)
            } catch {
                self.finish(error)
            }
        }
    }

    private func fixtureResponse() throws -> String {
        let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("Fixtures/action-response.md")
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tests/Fixtures/action-response.md")
        guard let url = [bundled, repository]
            .compactMap({ $0 })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw UIFixtureError.missingFixtureResponse
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func finish(_ error: Error?) {
        guard !finished else { return }
        finished = true
        self.error = error
        timeout?.invalidate()
        timeout = nil
        host.bridge.invalidate()
        window.orderOut(nil)
        let application = NSApplication.shared
        application.stop(nil)
        if let wakeEvent = NSEvent.otherEvent(
            with: .applicationDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 0,
            data1: 0,
            data2: 0
        ) {
            application.postEvent(wakeEvent, atStart: true)
        }
    }

}

extension UIFixtureRunner: SelectionWebBridgeDelegate {
    func selectionWebBridge(_ bridge: SelectionWebBridge, didReceive command: WebCommand) {
        switch command {
        case .updatePreference(let requestID, let update):
            bridge.send(.preferenceSaved(requestID: requestID, update: update))
        case .fetchModels(let requestID, _, _):
            bridge.send(.modelsLoaded(
                requestID: requestID,
                models: UIFixtureRequest.fixtureModels,
                latencyMilliseconds: UIFixtureRequest.fixtureLatencyMilliseconds
            ))
        case .testConnection(let requestID, _, _):
            bridge.send(.connectionSucceeded(
                requestID: requestID,
                latencyMilliseconds: UIFixtureRequest.fixtureLatencyMilliseconds
            ))
        default:
            break
        }
    }
}
