import Foundation
import XCTest
@testable import LightSelectCore

final class OpenAIConfigurationServiceTests: XCTestCase {
    override func tearDown() {
        ConfigurationURLProtocol.handler = nil
        super.tearDown()
    }

    func testNormalizesSupportedBaseURLs() {
        XCTAssertEqual(
            OpenAIConfigurationService.endpoint(baseURL: "https://api.example.com/v1", resource: .models)?.absoluteString,
            "https://api.example.com/v1/models"
        )
        XCTAssertEqual(
            OpenAIConfigurationService.endpoint(
                baseURL: "https://api.example.com/v1/chat/completions",
                resource: .models
            )?.absoluteString,
            "https://api.example.com/v1/models"
        )
        XCTAssertEqual(
            OpenAIConfigurationService.endpoint(baseURL: "file:///tmp", resource: .models),
            nil
        )
    }

    func testFetchesDeduplicatedSortedModels() throws {
        let done = expectation(description: "models")
        ConfigurationURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/models")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
            return Self.response(
                request,
                status: 200,
                body: #"{"data":[{"id":"z"},{"id":"a"},{"id":"z"},{"id":" "}]}"#
            )
        }
        let service = makeService()

        service.fetchModels(requestID: UUID(), configuration: configuration()) { result in
            XCTAssertEqual(try? result.get().models, ["a", "z"])
            done.fulfill()
        }

        wait(for: [done], timeout: 1)
    }

    func testMapsHTTPAndMalformedResponsesWithoutReturningBodies() {
        for (status, expected) in [(401, APIConfigurationError.authentication), (403, .forbidden), (429, .rateLimit), (500, .server)] {
            let done = expectation(description: "status \(status)")
            ConfigurationURLProtocol.handler = { request in
                Self.response(request, status: status, body: #"{"error":"secret provider body"}"#)
            }
            makeService().fetchModels(requestID: UUID(), configuration: configuration()) { result in
                XCTAssertEqual(result, .failure(expected))
                XCTAssertFalse(String(describing: result).contains("secret provider body"))
                done.fulfill()
            }
            wait(for: [done], timeout: 1)
        }

        let malformed = expectation(description: "malformed")
        ConfigurationURLProtocol.handler = { request in Self.response(request, status: 200, body: "not-json") }
        makeService().fetchModels(requestID: UUID(), configuration: configuration()) { result in
            XCTAssertEqual(result, .failure(.invalidResponse))
            malformed.fulfill()
        }
        wait(for: [malformed], timeout: 1)
    }

    func testConnectionUsesSmallNonStreamingRequest() throws {
        let done = expectation(description: "connection")
        ConfigurationURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/chat/completions")
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["stream"] as? Bool, false)
            XCTAssertEqual(json["max_tokens"] as? Int, 1)
            XCTAssertEqual(json["model"] as? String, "model-a")
            return Self.response(request, status: 200, body: #"{"choices":[{"message":{"content":"OK"}}]}"#)
        }

        makeService().testConnection(requestID: UUID(), configuration: configuration()) { result in
            XCTAssertNotNil(try? result.get())
            done.fulfill()
        }

        wait(for: [done], timeout: 1)
    }

    private func makeService() -> OpenAIConfigurationService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ConfigurationURLProtocol.self]
        return OpenAIConfigurationService(configuration: configuration, callbackQueue: .main)
    }

    private func configuration() -> APIConfiguration {
        .init(
            baseURL: "https://api.example.com/v1",
            apiKey: "secret",
            model: "model-a",
            timeoutSeconds: 10
        )
    }

    private static func response(_ request: URLRequest, status: Int, body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            Data(body.utf8)
        )
    }
}

private final class ConfigurationURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
