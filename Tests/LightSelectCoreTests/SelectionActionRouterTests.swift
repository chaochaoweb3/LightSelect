import XCTest
@testable import LightSelectCore

final class SelectionActionRouterTests: XCTestCase {
    func testRoutesCopyQuoteAndSearchWithoutNetwork() {
        let client = FakeOpenAIClient()
        var copied: [String] = []
        var opened: [URL] = []
        let router = makeRouter(client: client, copy: { copied.append($0); return true }, open: { opened.append($0); return true })

        router.perform(action: action("copy"), selectedText: "copy me", anchor: .zero)
        router.perform(action: action("quote"), selectedText: "a\nb", anchor: .zero)
        router.perform(action: action("search", searchEngine: "Google|https://google.com/search?q={{queryString}}"), selectedText: "hello world", anchor: .zero)
        router.perform(action: action("search"), selectedText: "https://example.com/path", anchor: .zero)

        XCTAssertEqual(copied, ["copy me", "> a\n> b"])
        XCTAssertEqual(opened.map(\.absoluteString), ["https://google.com/search?q=hello%20world", "https://example.com/path"])
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testBuildsPromptsFromLanguagesBuiltInsAndCustomTemplate() {
        let client = FakeOpenAIClient()
        let router = makeRouter(client: client)
        for item in [
            action("translate"),
            action("explain"),
            action("summary"),
            action("refine"),
            SelectionActionItem(id: "custom", name: "Custom", enabled: true, isBuiltIn: false, prompt: "Analyze {{text}} now")
        ] {
            router.perform(action: item, selectedText: "sample", anchor: CGPoint(x: 1, y: 2))
        }

        XCTAssertTrue(client.requests[0].prompt.contains("auto"))
        XCTAssertTrue(client.requests[0].prompt.contains("zh-cn"))
        XCTAssertTrue(client.requests[1].prompt.contains("仅用简体中文"))
        XCTAssertTrue(client.requests[1].prompt.contains("不要输出英文对照、双语标题或双语术语表"))
        XCTAssertFalse(client.requests[1].prompt.contains("Explain the following"))
        XCTAssertTrue(client.requests[2].prompt.contains("Summarize"))
        XCTAssertTrue(client.requests[3].prompt.contains("Improve"))
        XCTAssertEqual(client.requests[4].prompt, "Analyze sample now")
    }

    func testRejectsStaleStreamEventsAndMapsCurrentFailure() {
        let client = FakeOpenAIClient()
        var emitted: [WebEvent] = []
        let router = makeRouter(client: client, emit: { emitted.append($0) })
        let item = action("explain")

        router.perform(action: item, selectedText: "first", anchor: .zero)
        let first = client.requestIDs[0]
        router.perform(action: item, selectedText: "second", anchor: .zero)
        let second = client.requestIDs[1]
        client.emit(.delta(requestID: first, text: "stale"))
        client.emit(.delta(requestID: second, text: "current"))
        client.emit(.failed(requestID: second, error: .rateLimit))

        XCTAssertFalse(emitted.contains(.actionDelta(requestID: first.uuidString, text: "stale")))
        XCTAssertTrue(emitted.contains(.actionDelta(requestID: second.uuidString, text: "current")))
        XCTAssertTrue(emitted.contains(.actionFailed(
            requestID: second.uuidString,
            code: "rate_limit",
            message: OpenAIClientError.rateLimit.localizedDescription
        )))
    }

    private func makeRouter(
        client: FakeOpenAIClient,
        emit: @escaping (WebEvent) -> Void = { _ in },
        copy: @escaping (String) -> Bool = { _ in true },
        open: @escaping (URL) -> Bool = { _ in true }
    ) -> SelectionActionRouter {
        var settings = LightSelectSettings.default
        settings.api.sourceLanguage = "auto"
        settings.api.targetLanguage = "zh-cn"
        return SelectionActionRouter(
            client: client,
            settings: { settings },
            apiKey: { "key" },
            presentAction: { _ in },
            emit: emit,
            copyText: copy,
            openURL: open
        )
    }

    private func action(_ id: String, searchEngine: String? = nil) -> SelectionActionItem {
        SelectionActionItem(id: id, name: id, enabled: true, isBuiltIn: true, searchEngine: searchEngine)
    }
}

private final class FakeOpenAIClient: OpenAIStreaming {
    var requests: [OpenAIStreamRequest] = []
    var requestIDs: [UUID] = []
    var cancelled: [UUID] = []
    private var handlers: [UUID: (OpenAIStreamEvent) -> Void] = [:]

    func stream(request: OpenAIStreamRequest, onEvent: @escaping (OpenAIStreamEvent) -> Void) -> UUID {
        let id = UUID()
        requests.append(request)
        requestIDs.append(id)
        handlers[id] = onEvent
        onEvent(.started(requestID: id))
        return id
    }

    func cancel(requestID: UUID) { cancelled.append(requestID) }
    func emit(_ event: OpenAIStreamEvent) {
        let id: UUID
        switch event {
        case .started(let value), .delta(let value, _), .completed(let value, _), .failed(let value, _), .cancelled(let value): id = value
        }
        handlers[id]?(event)
    }
}
