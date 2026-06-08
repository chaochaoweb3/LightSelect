import AppKit
import ApplicationServices
import Foundation

private let appName = "LightSelect"
private let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/LightSelect.log")

private func log(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.synchronizeFile()
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logURL.path, contents: data)
        }
    }
}

private extension NSColor {
    static let cherryPrimary = NSColor(red: 0.0, green: 0.725, blue: 0.42, alpha: 1.0)
    static let cherryPrimaryMuted = NSColor(red: 0.0, green: 0.725, blue: 0.42, alpha: 0.16)
    static let cherryToolbarBackground = NSColor(calibratedWhite: 20.0 / 255.0, alpha: 0.95)
    static let cherryToolbarLightBackground = NSColor(calibratedWhite: 245.0 / 255.0, alpha: 0.95)
    static let cherryToolbarHover = NSColor(calibratedWhite: 51.0 / 255.0, alpha: 1.0)
    static let cherryToolbarLightHover = NSColor.black.withAlphaComponent(0.04)
    static let cherryPanelBackground = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
}

final class ToolbarButton: NSButton {
    private var tracking: NSTrackingArea?
    private let normalTint = NSColor.black

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.backgroundColor = NSColor.clear.cgColor
        contentTintColor = normalTint
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        if let tracking {
            addTrackingArea(tracking)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.cherryToolbarLightHover.cgColor
        contentTintColor = .cherryPrimary
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
        contentTintColor = normalTint
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: SelectionMonitor!
    private var toolbar: SelectionToolbar!
    private var actionWindow: ActionWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        log("app launched; trusted=\(AXIsProcessTrusted())")

        actionWindow = ActionWindow()
        toolbar = SelectionToolbar(actionWindow: actionWindow)
        monitor = SelectionMonitor(onSelection: { [weak self] text, anchor in
            log("show toolbar for text length=\(text.count), preview=\(String(text.prefix(80)))")
            self?.toolbar.show(text: text, anchor: anchor)
        }, onClear: { [weak self] in
            self?.toolbar.hide()
        })

        setupStatusItem()
        requestAccessibilityIfNeeded()
        monitor.start()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "LS"
        statusItem.button?.toolTip = appName

        let menu = NSMenu()
        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        enabledItem.state = .on
        menu.addItem(enabledItem)
        menu.addItem(NSMenuItem(title: "API Settings...", action: #selector(openAPISettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Test API", action: #selector(testAPI), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Show Reading Panel", action: #selector(showReadingPanel), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Test Toolbar", action: #selector(showTestToolbar), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func requestAccessibilityIfNeeded() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            showAccessibilityNotice()
        }
    }

    private func showAccessibilityNotice() {
        let alert = NSAlert()
        alert.messageText = "Enable Accessibility for LightSelect"
        alert.informativeText = "LightSelect needs Accessibility permission to read the text you select in other apps. After enabling it, restart LightSelect."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        if sender.state == .on {
            sender.state = .off
            monitor.stop()
            toolbar.hide()
        } else {
            sender.state = .on
            monitor.start()
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func showTestToolbar() {
        log("manual test toolbar requested")
        toolbar.show(text: "LightSelect test: if you can see this, the popup window works.", anchor: NSEvent.mouseLocation)
    }

    @objc private func showReadingPanel() {
        actionWindow.run(action: .explain, text: "LightSelect test: selected text will appear here.", near: NSEvent.mouseLocation)
    }

    @objc private func openAPISettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func testAPI() {
        let client = OpenAIClient()
        client.test { result in
            DispatchQueue.main.async {
                let alert = NSAlert()
                switch result {
                case .success(let content):
                    alert.messageText = "LightSelect API OK"
                    alert.informativeText = content
                case .failure(let error):
                    alert.messageText = "LightSelect API Failed"
                    alert.informativeText = error.localizedDescription
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

struct APISettings {
    var baseURL: String
    var apiKey: String
    var model: String

    static func load() -> APISettings {
        let defaults = UserDefaults.standard
        return APISettings(
            baseURL: defaults.string(forKey: "api.baseURL") ?? "https://api.openai.com/v1",
            apiKey: defaults.string(forKey: "api.key") ?? "",
            model: defaults.string(forKey: "api.model") ?? "gpt-4.1-mini"
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL, forKey: "api.baseURL")
        defaults.set(apiKey, forKey: "api.key")
        defaults.set(model, forKey: "api.model")
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let baseURLField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LightSelect API Settings"
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        let settings = APISettings.load()
        baseURLField.stringValue = settings.baseURL
        apiKeyField.stringValue = settings.apiKey
        modelField.stringValue = settings.model
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "OpenAI-compatible endpoint")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        root.addArrangedSubview(title)

        root.addArrangedSubview(row("Base URL", baseURLField, placeholder: "https://api.openai.com/v1"))
        root.addArrangedSubview(row("API Key", apiKeyField, placeholder: "sk-..."))
        root.addArrangedSubview(row("Model", modelField, placeholder: "gpt-4.1-mini"))

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(spacer)
        buttonRow.addArrangedSubview(save)
        root.addArrangedSubview(buttonRow)

        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func row(_ label: String, _ field: NSTextField, placeholder: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.widthAnchor.constraint(equalToConstant: 76).isActive = true
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(labelView)
        stack.addArrangedSubview(field)
        return stack
    }

    @objc private func save() {
        APISettings(
            baseURL: baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            model: modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        ).save()
        window?.close()
    }
}

enum SelectionAction: String {
    case translate = "Translate"
    case explain = "Explain"
    case summary = "Summary"

    var title: String {
        switch self {
        case .translate: return "翻译"
        case .explain: return "解释"
        case .summary: return "总结"
        }
    }

    var prompt: String {
        switch self {
        case .translate:
            return "请判断下面文本的主要语言：如果主要是中文，翻译成自然、准确的英文；如果主要是英文或其他非中文，翻译成自然、准确的中文。只输出译文，不要解释。"
        case .explain:
            return "请用中文解释下面文本。包括核心含义、语境/背景、关键术语、一个简短例子。保持清晰简洁。"
        case .summary:
            return "请用中文总结下面文本，保留关键事实和结论。"
        }
    }
}

final class OpenAIClient {
    func test(completion: @escaping (Result<String, Error>) -> Void) {
        complete(prompt: "只回复 OK", completion: completion)
    }

    func complete(action: SelectionAction, text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = "\(action.prompt)\n\n\(text)"
        complete(prompt: prompt, completion: completion)
    }

    private func complete(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let settings = APISettings.load()
        guard !settings.apiKey.isEmpty else {
            completion(.failure(NSError(domain: appName, code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API key. Open LS -> API Settings."])))
            return
        }

        let trimmedBase = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = trimmedBase.hasSuffix("/chat/completions")
            ? trimmedBase
            : "\(trimmedBase)/chat/completions"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: appName, code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL."])))
            return
        }
        log("API request endpoint=\(endpoint), model=\(settings.model.isEmpty ? "gpt-4.1-mini" : settings.model)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": settings.model.isEmpty ? "gpt-4.1-mini" : settings.model,
            "messages": [
                ["role": "system", "content": "You are a concise bilingual reading assistant."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                log("API error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let data else {
                log("API error: empty response")
                completion(.failure(NSError(domain: appName, code: 3, userInfo: [NSLocalizedDescriptionKey: "Empty API response."])))
                return
            }
            do {
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    log("API HTTP status=\(http.statusCode), bytes=\(data.count)")
                    let raw = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                    throw NSError(domain: appName, code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: raw])
                }
                if let http = response as? HTTPURLResponse {
                    log("API HTTP status=\(http.statusCode), bytes=\(data.count)")
                }
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let message = choices.first?["message"] as? [String: Any],
                    let content = message["content"] as? String
                else {
                    let raw = String(data: data, encoding: .utf8) ?? "Unknown response"
                    throw NSError(domain: appName, code: 4, userInfo: [NSLocalizedDescriptionKey: raw])
                }
                completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

final class ActionWindow {
    private let window: NSPanel
    private let titleLabel = NSTextField(labelWithString: "")
    private let originalText = NSTextField(wrappingLabelWithString: "")
    private let resultView = NSTextView()
    private let progress = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")
    private var actionButtons: [SelectionAction: NSButton] = [:]
    private let client = OpenAIClient()
    private var currentAction: SelectionAction = .explain
    private var currentText = ""
    private var currentAnchor = NSEvent.mouseLocation

    init() {
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.hidesOnDeactivate = false
        buildUI()
    }

    func run(action: SelectionAction, text: String, near point: NSPoint) {
        currentAction = action
        currentText = text
        currentAnchor = point
        titleLabel.stringValue = action.title
        originalText.stringValue = text
        resultView.string = ""
        statusLabel.stringValue = "正在请求..."
        updateActionButtons()
        progress.startAnimation(nil)
        position(near: point)
        window.orderFrontRegardless()

        client.complete(action: action, text: text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.progress.stopAnimation(nil)
                switch result {
                case .success(let content):
                    self.statusLabel.stringValue = "完成"
                    self.resultView.string = content
                case .failure(let error):
                    self.statusLabel.stringValue = "请求失败"
                    self.resultView.string = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func buildUI() {
        guard let content = window.contentView else { return }

        let chrome = NSView()
        chrome.wantsLayer = true
        chrome.layer?.cornerRadius = 16
        chrome.layer?.masksToBounds = true
        chrome.layer?.backgroundColor = NSColor.cherryPanelBackground.cgColor
        chrome.layer?.borderWidth = 0.5
        chrome.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.65).cgColor
        chrome.translatesAutoresizingMaskIntoConstraints = false

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .labelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        let settingsButton = iconButton("gearshape", action: #selector(openSettings), toolTip: "API Settings")
        let retryButton = iconButton("arrow.clockwise", action: #selector(regenerate), toolTip: "Regenerate")
        let copyButton = iconButton("doc.on.doc", action: #selector(copyResult), toolTip: "Copy")
        let closeButton = iconButton("xmark", action: #selector(close), toolTip: "Close")
        progress.style = .spinning
        progress.controlSize = .small
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(statusLabel)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(progress)
        header.addArrangedSubview(settingsButton)
        header.addArrangedSubview(retryButton)
        header.addArrangedSubview(copyButton)
        header.addArrangedSubview(closeButton)

        let segmented = NSStackView()
        segmented.orientation = .horizontal
        segmented.spacing = 8
        for action in [SelectionAction.translate, .explain, .summary] {
            let button = chipButton(action.title, action: #selector(switchAction(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
            actionButtons[action] = button
            segmented.addArrangedSubview(button)
        }

        originalText.font = .systemFont(ofSize: 12)
        originalText.textColor = .secondaryLabelColor
        originalText.maximumNumberOfLines = 4
        originalText.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder
        scroll.documentView = resultView
        resultView.isEditable = false
        resultView.font = .systemFont(ofSize: 14)
        resultView.textContainerInset = NSSize(width: 12, height: 12)
        resultView.backgroundColor = .controlBackgroundColor

        root.addArrangedSubview(header)
        root.addArrangedSubview(segmented)
        root.addArrangedSubview(originalText)
        root.addArrangedSubview(scroll)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        content.addSubview(chrome)
        content.addSubview(root)
        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            chrome.topAnchor.constraint(equalTo: content.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func iconButton(_ symbol: String, action: Selector, toolTip: String) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.bezelStyle = .inline
        button.isBordered = false
        button.toolTip = toolTip
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)
        return button
    }

    private func chipButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = .cherryPrimary
        button.widthAnchor.constraint(equalToConstant: 86).isActive = true
        return button
    }

    private func updateActionButtons() {
        for (action, button) in actionButtons {
            button.state = action == currentAction ? .on : .off
            button.contentTintColor = action == currentAction ? .white : .cherryPrimary
        }
    }

    private func position(near point: NSPoint) {
        let screenFrame = NSScreen.screens.first(where: { $0.frame.contains(point) })?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let size = window.frame.size
        var x = point.x - size.width / 2
        var y = point.y - size.height - 18
        if y < screenFrame.minY + 8 {
            y = point.y + 18
        }
        x = min(max(x, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)
        y = min(max(y, screenFrame.minY + 8), screenFrame.maxY - size.height - 8)
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func copyResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultView.string, forType: .string)
    }

    @objc private func regenerate() {
        run(action: currentAction, text: currentText, near: currentAnchor)
    }

    @objc private func switchAction(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let action = SelectionAction(rawValue: raw) else { return }
        run(action: action, text: currentText, near: currentAnchor)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func close() {
        window.orderOut(nil)
    }
}

@main
struct Main {
    private static let delegate = AppDelegate()

    static func main() {
        if CommandLine.arguments.contains("--api-test") {
            runAPITestAndExit()
        }
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }

    private static func runAPITestAndExit() -> Never {
        let semaphore = DispatchSemaphore(value: 0)
        var exitCode: Int32 = 1
        OpenAIClient().test { result in
            switch result {
            case .success(let content):
                print("API_TEST_OK \(content)")
                exitCode = 0
            case .failure(let error):
                print("API_TEST_FAILED \(error.localizedDescription)")
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 40)
        exit(exitCode)
    }
}

final class SelectionMonitor {
    private let onSelection: (String, NSPoint) -> Void
    private let onClear: () -> Void
    private var timer: Timer?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var scrollMonitor: Any?
    private var keyMonitor: Any?
    private var lastText = ""
    private var lastSeenAt = Date.distantPast
    private var lastAnchor = NSEvent.mouseLocation
    private var isReadingPasteboardSelection = false

    init(onSelection: @escaping (String, NSPoint) -> Void, onClear: @escaping () -> Void) {
        self.onSelection = onSelection
        self.onClear = onClear
    }

    func start() {
        guard timer == nil else { return }
        log("monitor start; trusted=\(AXIsProcessTrusted())")
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.tick()
        }
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.lastAnchor = NSEvent.mouseLocation
            self?.clearSelectionState(reason: "global mouseDown")
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            log("global leftMouseUp")
            self?.lastAnchor = NSEvent.mouseLocation
            self?.readSelectionAfterMouseUp()
        }
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            self?.clearSelectionState(reason: "global scroll")
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.shift) || flags.contains(.option) {
                return
            }
            self?.clearSelectionState(reason: "global keyDown")
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let mouseDownMonitor {
            NSEvent.removeMonitor(mouseDownMonitor)
            self.mouseDownMonitor = nil
        }
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        lastText = ""
    }

    private func tick() {
        guard AXIsProcessTrusted() else {
            return
        }
        guard let text = readSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            if !lastText.isEmpty, Date().timeIntervalSince(lastSeenAt) > 0.7 {
                clearSelectionState(reason: "selection empty")
            }
            return
        }

        guard text.count <= 4_000 else { return }
        if text == lastText, Date().timeIntervalSince(lastSeenAt) < 1.0 { return }
        lastText = text
        lastSeenAt = Date()
        onSelection(text, lastAnchor)
    }

    private func readSelectionAfterMouseUp() {
        guard AXIsProcessTrusted() else {
            log("mouseUp skipped: accessibility not trusted")
            return
        }
        guard !isReadingPasteboardSelection else {
            log("mouseUp skipped: already reading pasteboard")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, !self.isReadingPasteboardSelection else { return }

            if let text = self.readSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                log("selected text read via AX; length=\(text.count)")
                self.accept(text)
                return
            }

            self.isReadingPasteboardSelection = true
            self.readSelectedTextViaCopy { [weak self] text in
                guard let self else { return }
                self.isReadingPasteboardSelection = false
                guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    self.clearSelectionState(reason: "mouseUp no selected text")
                    return
                }
                log("selected text read via Cmd+C; length=\(text.count)")
                self.accept(text)
            }
        }
    }

    private func accept(_ text: String) {
        guard text.count <= 4_000 else { return }
        if text == lastText, Date().timeIntervalSince(lastSeenAt) < 1.0 { return }
        lastText = text
        lastSeenAt = Date()
        onSelection(text, lastAnchor)
    }

    private func clearSelectionState(reason: String) {
        guard !lastText.isEmpty || reason == "global mouseDown" || reason == "global scroll" || reason == "global keyDown" else { return }
        log("hide toolbar: \(reason)")
        lastText = ""
        lastSeenAt = Date.distantPast
        onClear()
    }

    private func readSelectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )
        guard focusedResult == .success, let focusedObject else {
            return nil
        }

        let focused = focusedObject as! AXUIElement
        var selectedObject: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedObject
        )
        guard selectedResult == .success else {
            return nil
        }
        return selectedObject as? String
    }

    private func readSelectedTextViaCopy(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    copy.setString(string, forType: type)
                }
            }
            return copy
        } ?? []

        pasteboard.clearContents()
        postCommandC()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let copiedText = pasteboard.string(forType: .string)
            pasteboard.clearContents()
            if !previousItems.isEmpty {
                pasteboard.writeObjects(previousItems)
            }
            log("Cmd+C fallback result length=\(copiedText?.count ?? 0)")
            completion(copiedText)
        }
    }

    private func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeForC = CGKeyCode(8)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForC, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForC, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

final class SelectionToolbar {
    private let panel: NSPanel
    private let actionWindow: ActionWindow
    private var selectedText = ""
    private var anchorPoint = NSEvent.mouseLocation
    private var hideWorkItem: DispatchWorkItem?

    init(actionWindow: ActionWindow) {
        self.actionWindow = actionWindow
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        let background = NSView()
        background.wantsLayer = true
        background.layer?.cornerRadius = 32
        background.layer?.masksToBounds = true
        background.layer?.backgroundColor = NSColor.cherryToolbarLightBackground.cgColor
        background.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        background.layer?.borderWidth = 0.5
        background.layer?.shadowColor = NSColor.black.cgColor
        background.layer?.shadowOpacity = 0.1
        background.layer?.shadowRadius = 12
        background.layer?.shadowOffset = NSSize(width: 0, height: -3)
        background.translatesAutoresizingMaskIntoConstraints = false

        let root = NSStackView()
        root.orientation = .horizontal
        root.alignment = .centerY
        root.spacing = 0
        root.edgeInsets = NSEdgeInsets(top: 6, left: 18, bottom: 8, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false

        let logo = NSImageView()
        logo.imageScaling = .scaleProportionallyUpOrDown
        if let logoPath = Bundle.main.path(forResource: "cherry-logo", ofType: "png") {
            logo.image = NSImage(contentsOfFile: logoPath)
        }
        logo.widthAnchor.constraint(equalToConstant: 44).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 18
        buttons.distribution = .fillEqually

        buttons.addArrangedSubview(makeButton(title: "翻译", symbol: "character.book.closed", action: #selector(translate), toolTip: "Translate"))
        buttons.addArrangedSubview(makeButton(title: "解释", symbol: "questionmark.app", action: #selector(explain), toolTip: "Explain"))
        buttons.addArrangedSubview(makeButton(title: "总结", symbol: "text.alignleft", action: #selector(summary), toolTip: "Summary"))
        buttons.addArrangedSubview(makeButton(title: "搜索", symbol: "magnifyingglass", action: #selector(search), toolTip: "Search"))
        buttons.addArrangedSubview(makeButton(title: "复制", symbol: "doc.on.clipboard", action: #selector(copyText), toolTip: "Copy selected text"))
        buttons.addArrangedSubview(makeButton(title: "引用", symbol: "quote.opening", action: #selector(quoteText), toolTip: "Quote selected text"))

        root.addArrangedSubview(logo)
        root.addArrangedSubview(buttons)

        let content = NSView()
        content.addSubview(background)
        content.addSubview(root)
        panel.contentView = content

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 0),
            background.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: 0),
            background.topAnchor.constraint(equalTo: content.topAnchor, constant: 0),
            background.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -2),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    func show(text: String, anchor: NSPoint) {
        selectedText = text
        anchorPoint = anchor
        position(near: anchor)
        panel.orderFrontRegardless()
        scheduleAutoHide(after: 25)
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel.orderOut(nil)
    }

    private func makeButton(title: String, symbol: String, action: Selector, toolTip: String) -> NSButton {
        let button = ToolbarButton(frame: .zero)
        button.title = title
        button.target = self
        button.action = action
        button.bezelStyle = .inline
        button.isBordered = false
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 22, weight: .regular)
        button.toolTip = toolTip
        button.widthAnchor.constraint(equalToConstant: 92).isActive = true
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            button.image = image
            button.imagePosition = .imageLeading
            button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 27, weight: .regular)
        }
        return button
    }

    private func separator() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.14).cgColor
        view.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        view.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return view
    }

    private func position(near point: NSPoint) {
        let visibleFrame = NSScreen.screens
            .first(where: { $0.frame.contains(point) })?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        let size = panel.frame.size
        var x = point.x - size.width / 2
        var y = point.y - size.height - 8

        if y < visibleFrame.minY + 8 {
            y = point.y + 8
        }
        x = min(max(x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        y = min(max(y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func scheduleAutoHide(after seconds: TimeInterval) {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    @objc private func translate() {
        actionWindow.run(action: .translate, text: selectedText, near: actionAnchor())
        hide()
    }

    @objc private func explain() {
        actionWindow.run(action: .explain, text: selectedText, near: actionAnchor())
        hide()
    }

    @objc private func summary() {
        actionWindow.run(action: .summary, text: selectedText, near: actionAnchor())
        hide()
    }

    @objc private func search() {
        openWeb("https://www.google.com/search?q=\(encoded(selectedText))")
        hide()
    }

    @objc private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
        hide()
    }

    @objc private func quoteText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("> \(selectedText.replacingOccurrences(of: "\n", with: "\n> "))", forType: .string)
        hide()
    }

    private func openWeb(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }

    private func actionAnchor() -> NSPoint {
        NSPoint(x: panel.frame.midX, y: panel.frame.minY)
    }

    private func encoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
