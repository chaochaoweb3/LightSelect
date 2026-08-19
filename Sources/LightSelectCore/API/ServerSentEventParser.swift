import Foundation

public enum ServerSentEvent: Equatable, Sendable {
    case data(String)
    case done
}

public struct ServerSentEventParser: Sendable {
    private var lineBuffer = Data()
    private var dataLines: [String] = []

    public init() {}

    public mutating func append<DataBytes: DataProtocol>(_ bytes: DataBytes) -> [ServerSentEvent] {
        var events: [ServerSentEvent] = []
        for byte in bytes {
            if byte == 0x0A {
                processCompletedLine(into: &events)
            } else {
                lineBuffer.append(byte)
            }
        }
        return events
    }

    public mutating func finish() -> [ServerSentEvent] {
        var events: [ServerSentEvent] = []
        if !lineBuffer.isEmpty { processCompletedLine(into: &events) }
        emitPendingEvent(into: &events)
        return events
    }

    private mutating func processCompletedLine(into events: inout [ServerSentEvent]) {
        if lineBuffer.last == 0x0D { lineBuffer.removeLast() }
        guard let line = String(data: lineBuffer, encoding: .utf8) else {
            lineBuffer.removeAll(keepingCapacity: true)
            return
        }
        lineBuffer.removeAll(keepingCapacity: true)

        if line.isEmpty {
            emitPendingEvent(into: &events)
            return
        }
        guard !line.hasPrefix(":"), line.hasPrefix("data:") else { return }
        var value = String(line.dropFirst(5))
        if value.first == " " { value.removeFirst() }
        dataLines.append(value)
    }

    private mutating func emitPendingEvent(into events: inout [ServerSentEvent]) {
        guard !dataLines.isEmpty else { return }
        let payload = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        events.append(payload == "[DONE]" ? .done : .data(payload))
    }
}

public enum OpenAIStreamPayload: Equatable, Sendable {
    case delta(String)
    case done
    case error(String)
    case ignored

    public static func decode(_ payload: String) throws -> OpenAIStreamPayload {
        if payload == "[DONE]" { return .done }
        guard let data = payload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIClientError.invalidResponse
        }
        if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
            return .error(message)
        }
        if let choices = object["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any],
           let content = delta["content"] as? String,
           !content.isEmpty {
            return .delta(content)
        }
        return .ignored
    }
}
