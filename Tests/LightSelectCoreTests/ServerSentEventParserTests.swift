import XCTest
@testable import LightSelectCore

final class ServerSentEventParserTests: XCTestCase {
    func testParsesUTF8ChunkBoundariesMultipleDataLinesAndDone() {
        var parser = ServerSentEventParser()
        let bytes = Data("data: 你\ndata: 好\n\ndata: [DONE]\n\n".utf8)
        let split = bytes.firstIndex(of: 0xE4)! + 1

        XCTAssertEqual(parser.append(bytes.prefix(split)), [])
        XCTAssertEqual(
            parser.append(bytes.suffix(from: split)),
            [.data("你\n好"), .done]
        )
    }

    func testIgnoresHeartbeatsAndFlushesFinalEventWithoutNewline() {
        var parser = ServerSentEventParser()
        XCTAssertEqual(parser.append(Data(": heartbeat\n\n\n\n".utf8)), [])
        XCTAssertEqual(parser.append(Data("data: final".utf8)), [])
        XCTAssertEqual(parser.finish(), [.data("final")])
    }

    func testDecodesOpenAIDeltaAndErrorPayloads() throws {
        XCTAssertEqual(
            try OpenAIStreamPayload.decode(#"{"choices":[{"delta":{"content":"你"}}]}"#),
            .delta("你")
        )
        XCTAssertEqual(try OpenAIStreamPayload.decode("[DONE]"), .done)
        XCTAssertEqual(
            try OpenAIStreamPayload.decode(#"{"error":{"message":"bad request"}}"#),
            .error("bad request")
        )
    }
}
