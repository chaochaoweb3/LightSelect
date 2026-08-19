import Foundation

public struct OpenAIStreamRequest: Equatable, Sendable {
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var prompt: String
    public var timeoutSeconds: Int

    public init(baseURL: String, apiKey: String, model: String, prompt: String, timeoutSeconds: Int) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.prompt = prompt
        self.timeoutSeconds = timeoutSeconds
    }
}

public enum OpenAIClientError: Error, Equatable, Sendable {
    case configuration
    case authentication
    case rateLimit
    case server
    case timeout
    case invalidResponse
    case cancelled

    public var code: String {
        switch self {
        case .configuration: "configuration"
        case .authentication: "authentication"
        case .rateLimit: "rate_limit"
        case .server: "server"
        case .timeout: "timeout"
        case .invalidResponse: "invalid_response"
        case .cancelled: "cancelled"
        }
    }
}

extension OpenAIClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .configuration: "API configuration is incomplete."
        case .authentication: "API authentication failed."
        case .rateLimit: "API rate limit reached."
        case .server: "API server error."
        case .timeout: "API request timed out."
        case .invalidResponse: "API returned an invalid response."
        case .cancelled: "Request cancelled."
        }
    }
}

public enum OpenAIStreamEvent: Equatable, Sendable {
    case started(requestID: UUID)
    case delta(requestID: UUID, text: String)
    case completed(requestID: UUID, content: String)
    case failed(requestID: UUID, error: OpenAIClientError)
    case cancelled(requestID: UUID)
}

public protocol OpenAIStreaming: AnyObject {
    @discardableResult
    func stream(request: OpenAIStreamRequest, onEvent: @escaping (OpenAIStreamEvent) -> Void) -> UUID
    func cancel(requestID: UUID)
}

public final class OpenAIClient: OpenAIStreaming {
    private struct Context {
        let session: URLSession
        let task: URLSessionDataTask
        let delegate: StreamDelegate
    }

    private let configuration: URLSessionConfiguration
    private let lock = NSLock()
    private var contexts: [UUID: Context] = [:]

    public init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration
    }

    @discardableResult
    public func stream(request: OpenAIStreamRequest, onEvent: @escaping (OpenAIStreamEvent) -> Void) -> UUID {
        let requestID = UUID()
        onEvent(.started(requestID: requestID))

        let urlRequest: URLRequest
        do {
            urlRequest = try makeURLRequest(from: request)
        } catch {
            onEvent(.failed(requestID: requestID, error: .configuration))
            return requestID
        }

        let delegate = StreamDelegate(requestID: requestID, owner: self, onEvent: onEvent)
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        let task = session.dataTask(with: urlRequest)
        delegate.task = task
        lock.lock()
        contexts[requestID] = Context(session: session, task: task, delegate: delegate)
        lock.unlock()
        task.resume()
        return requestID
    }

    public func cancel(requestID: UUID) {
        lock.lock()
        let context = contexts[requestID]
        lock.unlock()
        guard let context else { return }
        context.delegate.cancelNow()
        context.task.cancel()
    }

    fileprivate func remove(requestID: UUID) {
        lock.lock()
        let context = contexts.removeValue(forKey: requestID)
        lock.unlock()
        context?.session.finishTasksAndInvalidate()
    }

    private func makeURLRequest(from streamRequest: OpenAIStreamRequest) throws -> URLRequest {
        let base = streamRequest.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !streamRequest.apiKey.isEmpty,
              !streamRequest.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var url = URL(string: base),
              url.scheme == "https" || url.scheme == "http" else {
            throw OpenAIClientError.configuration
        }
        if !url.path.hasSuffix("/chat/completions") {
            url.appendPathComponent("chat/completions")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(min(max(streamRequest.timeoutSeconds, 5), 300))
        request.setValue("Bearer \(streamRequest.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: streamRequest.model,
            stream: true,
            messages: [
                .init(
                    role: "system",
                    content: "You are a concise reading assistant. Follow the user's requested output language exactly. " +
                        "Do not add bilingual sections unless explicitly requested."
                ),
                .init(role: "user", content: streamRequest.prompt)
            ],
            temperature: 0.2
        ))
        return request
    }
}

private struct RequestBody: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let stream: Bool
    let messages: [Message]
    let temperature: Double
}

private final class StreamDelegate: NSObject, URLSessionDataDelegate {
    let requestID: UUID
    weak var owner: OpenAIClient?
    weak var task: URLSessionDataTask?
    private let onEvent: (OpenAIStreamEvent) -> Void
    private let lock = NSLock()
    private var parser = ServerSentEventParser()
    private var responseStatus = 0
    private var content = ""
    private var terminal = false

    init(requestID: UUID, owner: OpenAIClient, onEvent: @escaping (OpenAIStreamEvent) -> Void) {
        self.requestID = requestID
        self.owner = owner
        self.onEvent = onEvent
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        responseStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isTerminal else { return }
        guard (200...299).contains(responseStatus) else { return }
        process(parser.append(data))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isTerminal else { return }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                finish(.cancelled(requestID: requestID))
            } else if urlError.code == .timedOut {
                finish(.failed(requestID: requestID, error: .timeout))
            } else {
                finish(.failed(requestID: requestID, error: .invalidResponse))
            }
            return
        }
        if error != nil {
            finish(.failed(requestID: requestID, error: .invalidResponse))
            return
        }
        guard (200...299).contains(responseStatus) else {
            finish(.failed(requestID: requestID, error: Self.error(for: responseStatus)))
            return
        }
        process(parser.finish())
        if !isTerminal {
            content.isEmpty
                ? finish(.failed(requestID: requestID, error: .invalidResponse))
                : finish(.completed(requestID: requestID, content: content))
        }
    }

    func cancelNow() {
        finish(.cancelled(requestID: requestID))
    }

    private var isTerminal: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminal
    }

    private func process(_ events: [ServerSentEvent]) {
        for event in events where !isTerminal {
            switch event {
            case .done:
                finish(.completed(requestID: requestID, content: content))
                task?.cancel()
            case .data(let payload):
                do {
                    switch try OpenAIStreamPayload.decode(payload) {
                    case .delta(let text):
                        content += text
                        onEvent(.delta(requestID: requestID, text: text))
                    case .done:
                        finish(.completed(requestID: requestID, content: content))
                        task?.cancel()
                    case .error:
                        finish(.failed(requestID: requestID, error: .invalidResponse))
                        task?.cancel()
                    case .ignored:
                        break
                    }
                } catch {
                    finish(.failed(requestID: requestID, error: .invalidResponse))
                    task?.cancel()
                }
            }
        }
    }

    private func finish(_ event: OpenAIStreamEvent) {
        lock.lock()
        guard !terminal else {
            lock.unlock()
            return
        }
        terminal = true
        lock.unlock()
        onEvent(event)
        owner?.remove(requestID: requestID)
    }

    private static func error(for status: Int) -> OpenAIClientError {
        switch status {
        case 401, 403: .authentication
        case 429: .rateLimit
        case 500...599: .server
        default: .invalidResponse
        }
    }
}
