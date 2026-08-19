import Foundation

public enum APIConfigurationResource: Sendable {
    case models
    case chatCompletions

    fileprivate var path: String {
        switch self {
        case .models: "models"
        case .chatCompletions: "chat/completions"
        }
    }
}

public struct APIConfiguration: Equatable, Sendable {
    public let baseURL: String
    public let apiKey: String
    public let model: String
    public let timeoutSeconds: Int

    public init(baseURL: String, apiKey: String, model: String, timeoutSeconds: Int) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.timeoutSeconds = min(max(timeoutSeconds, 5), 300)
    }
}

public struct ModelDiscoveryResult: Equatable, Sendable {
    public let models: [String]
    public let latencyMilliseconds: Int

    public init(models: [String], latencyMilliseconds: Int) {
        self.models = models
        self.latencyMilliseconds = latencyMilliseconds
    }
}

public struct ConnectionTestResult: Equatable, Sendable {
    public let latencyMilliseconds: Int

    public init(latencyMilliseconds: Int) {
        self.latencyMilliseconds = latencyMilliseconds
    }
}

public enum APIConfigurationError: String, Error, Equatable, Sendable {
    case configuration
    case authentication
    case forbidden
    case rateLimit = "rate_limit"
    case server
    case timeout
    case connection
    case invalidResponse = "invalid_response"
    case cancelled
}

public protocol OpenAIConfigurationServing: AnyObject {
    func fetchModels(
        requestID: UUID,
        configuration: APIConfiguration,
        completion: @escaping (Result<ModelDiscoveryResult, APIConfigurationError>) -> Void
    )
    func testConnection(
        requestID: UUID,
        configuration: APIConfiguration,
        completion: @escaping (Result<ConnectionTestResult, APIConfigurationError>) -> Void
    )
    func cancel(requestID: UUID)
    func cancelAll()
}

public final class OpenAIConfigurationService: OpenAIConfigurationServing {
    private struct Context {
        let session: URLSession
        let task: URLSessionDataTask
    }

    private let configuration: URLSessionConfiguration
    private let callbackQueue: DispatchQueue
    private let lock = NSLock()
    private var contexts: [UUID: Context] = [:]

    public init(
        configuration: URLSessionConfiguration = .ephemeral,
        callbackQueue: DispatchQueue = .main
    ) {
        self.configuration = configuration
        self.callbackQueue = callbackQueue
    }

    public static func endpoint(baseURL: String, resource: APIConfigurationResource) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else { return nil }

        components.query = nil
        components.fragment = nil
        var path = components.percentEncodedPath
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        for suffix in ["/chat/completions", "/models"] where path.hasSuffix(suffix) {
            path.removeLast(suffix.count)
            break
        }
        if path.isEmpty { path = "/" }
        if !path.hasSuffix("/") { path += "/" }
        components.percentEncodedPath = path + resource.path
        return components.url
    }

    public func fetchModels(
        requestID: UUID,
        configuration: APIConfiguration,
        completion: @escaping (Result<ModelDiscoveryResult, APIConfigurationError>) -> Void
    ) {
        guard let request = makeRequest(configuration: configuration, resource: .models, method: "GET") else {
            complete(.failure(.configuration), completion: completion)
            return
        }
        let started = DispatchTime.now()
        start(requestID: requestID, request: request) { [weak self] data, response, error in
            guard let self else { return }
            let result: Result<ModelDiscoveryResult, APIConfigurationError>
            if let failure = self.failure(response: response, error: error) {
                result = .failure(failure)
            } else if let payload = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
                let models = Array(Set(payload.data.map {
                    $0.id.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty })).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                result = .success(.init(models: models, latencyMilliseconds: Self.latency(since: started)))
            } else {
                result = .failure(.invalidResponse)
            }
            self.complete(result, completion: completion)
        }
    }

    public func testConnection(
        requestID: UUID,
        configuration: APIConfiguration,
        completion: @escaping (Result<ConnectionTestResult, APIConfigurationError>) -> Void
    ) {
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var request = makeRequest(configuration: configuration, resource: .chatCompletions, method: "POST"),
              let body = try? JSONEncoder().encode(ConnectionRequest(model: configuration.model)) else {
            complete(.failure(.configuration), completion: completion)
            return
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let started = DispatchTime.now()
        start(requestID: requestID, request: request) { [weak self] data, response, error in
            guard let self else { return }
            let result: Result<ConnectionTestResult, APIConfigurationError>
            if let failure = self.failure(response: response, error: error) {
                result = .failure(failure)
            } else if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = object["choices"] as? [Any], !choices.isEmpty {
                result = .success(.init(latencyMilliseconds: Self.latency(since: started)))
            } else {
                result = .failure(.invalidResponse)
            }
            self.complete(result, completion: completion)
        }
    }

    public func cancel(requestID: UUID) {
        lock.lock()
        let task = contexts[requestID]?.task
        lock.unlock()
        task?.cancel()
    }

    public func cancelAll() {
        lock.lock()
        let tasks = contexts.values.map(\.task)
        lock.unlock()
        tasks.forEach { $0.cancel() }
    }

    private func makeRequest(
        configuration: APIConfiguration,
        resource: APIConfigurationResource,
        method: String
    ) -> URLRequest? {
        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, let url = Self.endpoint(baseURL: configuration.baseURL, resource: resource) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = TimeInterval(configuration.timeoutSeconds)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func start(
        requestID: UUID,
        request: URLRequest,
        completion: @escaping (Data, HTTPURLResponse?, Error?) -> Void
    ) {
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            self.remove(requestID: requestID)
            completion(data ?? Data(), response as? HTTPURLResponse, error)
        }

        lock.lock()
        let previous = contexts.updateValue(Context(session: session, task: task), forKey: requestID)
        lock.unlock()
        previous?.task.cancel()
        previous?.session.invalidateAndCancel()
        task.resume()
    }

    private func remove(requestID: UUID) {
        lock.lock()
        let context = contexts.removeValue(forKey: requestID)
        lock.unlock()
        context?.session.finishTasksAndInvalidate()
    }

    private func failure(response: HTTPURLResponse?, error: Error?) -> APIConfigurationError? {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled: return .cancelled
            case .timedOut: return .timeout
            default: return .connection
            }
        }
        if error != nil { return .connection }
        guard let status = response?.statusCode else { return .invalidResponse }
        switch status {
        case 200...299: return nil
        case 401: return .authentication
        case 403: return .forbidden
        case 429: return .rateLimit
        case 500...599: return .server
        default: return .invalidResponse
        }
    }

    private func complete<Value>(
        _ result: Result<Value, APIConfigurationError>,
        completion: @escaping (Result<Value, APIConfigurationError>) -> Void
    ) {
        callbackQueue.async { completion(result) }
    }

    private static func latency(since start: DispatchTime) -> Int {
        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        return max(0, Int(elapsed / 1_000_000))
    }
}

private struct ModelsResponse: Decodable {
    struct Model: Decodable { let id: String }
    let data: [Model]
}

private struct ConnectionRequest: Encodable {
    struct Message: Encodable {
        let role = "user"
        let content = "Reply with OK."
    }

    let model: String
    let stream = false
    let maxTokens = 1
    let messages = [Message()]

    enum CodingKeys: String, CodingKey {
        case model, stream, messages
        case maxTokens = "max_tokens"
    }
}
