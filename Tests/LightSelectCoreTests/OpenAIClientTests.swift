import Foundation
import XCTest
@testable import LightSelectCore

final class OpenAIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.handler = nil
    }

    func testPostsOpenAICompatibleStreamingRequestAndEmitsDeltas() throws {
        let completed = expectation(description: "stream completed")
        MockURLProtocol.handler = { request, client in
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
            XCTAssertEqual(request.timeoutInterval, 12)
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "test-model")
            XCTAssertEqual(json["stream"] as? Bool, true)
            let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
            XCTAssertEqual(
                messages.first?["content"],
                "You are a concise reading assistant. Follow the user's requested output language exactly. " +
                    "Do not add bilingual sections unless explicitly requested."
            )
            client.urlProtocol(self.protocolInstance, didReceive: HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"]
            )!, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self.protocolInstance, didLoad: Data("data: {\"choices\":[{\"delta\":{\"content\":\"你\"}}]}\n\n".utf8))
            client.urlProtocol(self.protocolInstance, didLoad: Data("data: [DONE]\n\n".utf8))
            client.urlProtocolDidFinishLoading(self.protocolInstance)
        }
        let client = OpenAIClient(configuration: mockConfiguration())
        var events: [OpenAIStreamEvent] = []

        let requestID = client.stream(request: .init(
            baseURL: "https://api.example.com/v1",
            apiKey: "test-secret",
            model: "test-model",
            prompt: "hello",
            timeoutSeconds: 12
        )) { event in
            events.append(event)
            if case .completed = event { completed.fulfill() }
        }

        wait(for: [completed], timeout: 1)
        XCTAssertEqual(events.first, .started(requestID: requestID))
        XCTAssertTrue(events.contains(.delta(requestID: requestID, text: "你")))
        XCTAssertTrue(events.contains(.completed(requestID: requestID, content: "你")))
    }

    func testMapsHTTPStatusWithoutLeakingAPIKey() {
        for (status, expected) in [(401, OpenAIClientError.authentication), (429, .rateLimit), (500, .server)] {
            let failed = expectation(description: "status \(status)")
            MockURLProtocol.handler = { request, client in
                client.urlProtocol(self.protocolInstance, didReceive: HTTPURLResponse(
                    url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
                )!, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self.protocolInstance, didLoad: Data(#"{"error":{"message":"secret-key server body"}}"#.utf8))
                client.urlProtocolDidFinishLoading(self.protocolInstance)
            }
            let client = OpenAIClient(configuration: mockConfiguration())
            _ = client.stream(request: .init(
                baseURL: "https://api.example.com/v1",
                apiKey: "secret-key",
                model: "model",
                prompt: "prompt",
                timeoutSeconds: 10
            )) { event in
                if case .failed(_, let error) = event {
                    XCTAssertEqual(error, expected)
                    XCTAssertFalse(error.localizedDescription.contains("secret-key"))
                    failed.fulfill()
                }
            }
            wait(for: [failed], timeout: 1)
        }
    }

    func testCancellationEmitsCancelledForSameRequestID() {
        let cancelled = expectation(description: "cancelled")
        MockURLProtocol.handler = { _, _ in }
        let client = OpenAIClient(configuration: mockConfiguration())
        var requestID: UUID?
        requestID = client.stream(request: .init(
            baseURL: "https://api.example.com/v1",
            apiKey: "key",
            model: "model",
            prompt: "prompt",
            timeoutSeconds: 10
        )) { event in
            if case .cancelled(let value) = event, value == requestID { cancelled.fulfill() }
        }
        client.cancel(requestID: requestID!)
        wait(for: [cancelled], timeout: 1)
    }

    private var protocolInstance: MockURLProtocol { MockURLProtocol.current! }

    private func mockConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest, URLProtocolClient) throws -> Void)?
    static weak var current: MockURLProtocol?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.current = self
        do { try Self.handler?(request, client!) } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
