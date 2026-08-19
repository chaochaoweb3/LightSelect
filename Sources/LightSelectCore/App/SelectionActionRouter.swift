import Foundation

public final class SelectionActionRouter {
    private let client: OpenAIStreaming
    private let settingsProvider: () -> LightSelectSettings
    private let apiKeyProvider: () -> String?
    private let presentAction: (CGPoint) -> Void
    private let eventEmitter: (WebEvent) -> Void
    private let copyText: (String) -> Bool
    private let openURL: (URL) -> Bool
    private let lock = NSLock()
    private var activeRequestID: UUID?
    private var lastAIAction: (action: SelectionActionItem, text: String, anchor: CGPoint)?

    public init(
        client: OpenAIStreaming,
        settings: @escaping () -> LightSelectSettings,
        apiKey: @escaping () -> String?,
        presentAction: @escaping (CGPoint) -> Void,
        emit: @escaping (WebEvent) -> Void,
        copyText: @escaping (String) -> Bool,
        openURL: @escaping (URL) -> Bool
    ) {
        self.client = client
        settingsProvider = settings
        apiKeyProvider = apiKey
        self.presentAction = presentAction
        eventEmitter = emit
        self.copyText = copyText
        self.openURL = openURL
    }

    public func perform(action: SelectionActionItem, selectedText: String, anchor: CGPoint) {
        switch action.id {
        case "copy":
            _ = copyText(selectedText)
            return
        case "quote":
            _ = copyText(selectedText.split(separator: "\n", omittingEmptySubsequences: false)
                .map { "> \($0)" }.joined(separator: "\n"))
            return
        case "search":
            if let url = Self.searchURL(for: selectedText, action: action) { _ = openURL(url) }
            return
        default:
            performAI(action: action, selectedText: selectedText, anchor: anchor)
        }
    }

    public func cancel(requestID: UUID) {
        lock.lock()
        let shouldCancel = activeRequestID == requestID
        lock.unlock()
        if shouldCancel { client.cancel(requestID: requestID) }
    }

    public func regenerate() {
        lock.lock()
        let last = lastAIAction
        lock.unlock()
        if let last { performAI(action: last.action, selectedText: last.text, anchor: last.anchor) }
    }

    public func cancelActive() {
        lock.lock()
        let requestID = activeRequestID
        lock.unlock()
        if let requestID { client.cancel(requestID: requestID) }
    }

    public static func searchURL(for text: String, action: SelectionActionItem) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let containsWhitespace = trimmed.contains(where: { $0.isWhitespace })
        if !containsWhitespace,
           let schemeRange = trimmed.range(of: "://"), schemeRange.lowerBound != trimmed.startIndex,
           let direct = URL(string: trimmed) {
            return direct
        }
        if !containsWhitespace, trimmed.hasPrefix("/") { return URL(fileURLWithPath: trimmed) }
        if !containsWhitespace, trimmed.count >= 3 {
            let characters = Array(trimmed)
            if characters[1] == ":", characters[2] == "/" || characters[2] == "\\" {
                return URL(fileURLWithPath: trimmed)
            }
        }
        guard let template = action.searchEngine?.split(separator: "|", maxSplits: 1).last,
              String(template).contains("{{queryString}}") else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.!~*'()"))
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: String(template).replacingOccurrences(of: "{{queryString}}", with: encoded))
    }

    private func performAI(action: SelectionActionItem, selectedText: String, anchor: CGPoint) {
        lock.lock()
        let previous = activeRequestID
        lastAIAction = (action, selectedText, anchor)
        lock.unlock()
        if let previous { client.cancel(requestID: previous) }

        deliverOnMain { self.presentAction(anchor) }
        let settings = settingsProvider()
        let streamRequest = OpenAIStreamRequest(
            baseURL: settings.api.baseURL,
            apiKey: apiKeyProvider() ?? "",
            model: settings.api.model,
            prompt: Self.prompt(for: action, text: selectedText, api: settings.api),
            timeoutSeconds: settings.api.timeoutSeconds
        )

        let buffer = InitialEventBuffer()
        let requestID = client.stream(request: streamRequest) { [weak self, buffer] event in
            if buffer.appendWhileBuffering(event) { return }
            self?.handle(event)
        }
        lock.lock()
        activeRequestID = requestID
        lock.unlock()
        deliverOnMain {
            self.eventEmitter(.actionStarted(
                requestID: requestID.uuidString,
                action: action,
                selectedText: selectedText
            ))
        }
        for event in buffer.finishBuffering() { handle(event) }
    }

    private func handle(_ event: OpenAIStreamEvent) {
        let requestID = event.requestID
        lock.lock()
        let isCurrent = activeRequestID == requestID
        lock.unlock()
        guard isCurrent else { return }

        switch event {
        case .started:
            return
        case .delta(_, let text):
            deliverOnMain { self.eventEmitter(.actionDelta(requestID: requestID.uuidString, text: text)) }
        case .completed(_, let content):
            deliverOnMain { self.eventEmitter(.actionCompleted(requestID: requestID.uuidString, content: content)) }
            clearActive(requestID)
        case .failed(_, let error):
            deliverOnMain {
                self.eventEmitter(.actionFailed(
                    requestID: requestID.uuidString,
                    code: error.code,
                    message: error.localizedDescription
                ))
            }
            clearActive(requestID)
        case .cancelled:
            deliverOnMain { self.eventEmitter(.actionCancelled(requestID: requestID.uuidString)) }
            clearActive(requestID)
        }
    }

    private func clearActive(_ requestID: UUID) {
        lock.lock()
        if activeRequestID == requestID { activeRequestID = nil }
        lock.unlock()
    }

    private func deliverOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private static func prompt(for action: SelectionActionItem, text: String, api: APISettings) -> String {
        if let custom = action.prompt, !custom.isEmpty {
            return custom.contains("{{text}}")
                ? custom.replacingOccurrences(of: "{{text}}", with: text)
                : "\(custom)\n\n\(text)"
        }
        switch action.id {
        case "translate":
            return "Translate the following text from \(api.sourceLanguage) to \(api.targetLanguage). Output only the translation.\n\n\(text)"
        case "explain":
            return """
            请仅用简体中文清晰解释以下内容，说明其含义、语境、关键词，并给出一个简短例子。
            所有标题、正文和项目符号均须使用简体中文；不要输出英文对照、双语标题或双语术语表。
            只有原文中的专有名词、代码、网址或无法翻译的准确引用可以保留原文。

            \(text)
            """
        case "summary":
            return "Summarize the following text concisely while preserving key facts and conclusions.\n\n\(text)"
        case "refine":
            return "Improve the following text for clarity, correctness, and natural phrasing while preserving its meaning.\n\n\(text)"
        default:
            return "Process the following text concisely.\n\n\(text)"
        }
    }
}

private final class InitialEventBuffer {
    private let lock = NSLock()
    private var buffering = true
    private var events: [OpenAIStreamEvent] = []

    func appendWhileBuffering(_ event: OpenAIStreamEvent) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard buffering else { return false }
        events.append(event)
        return true
    }

    func finishBuffering() -> [OpenAIStreamEvent] {
        lock.lock()
        defer { lock.unlock() }
        buffering = false
        let result = events
        events.removeAll()
        return result
    }
}

private extension OpenAIStreamEvent {
    var requestID: UUID {
        switch self {
        case .started(let requestID), .delta(let requestID, _), .completed(let requestID, _),
             .failed(let requestID, _), .cancelled(let requestID):
            requestID
        }
    }
}
