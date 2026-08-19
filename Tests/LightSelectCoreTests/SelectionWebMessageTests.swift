import XCTest
@testable import LightSelectCore

final class SelectionWebMessageTests: XCTestCase {
    func testDecodesPerformActionCommandByType() throws {
        let data = Data(#"{"type":"selection.performAction","actionId":"translate","selectedText":"hello"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(WebCommand.self, from: data), .performAction(actionID: "translate", selectedText: "hello"))
    }

    func testDecodesTypedPreferenceUpdate() throws {
        let data = Data(#"{"type":"preferences.update","requestId":"save-1","key":"actionWindowOpacity","value":60}"#.utf8)
        XCTAssertEqual(
            try JSONDecoder().decode(WebCommand.self, from: data),
            .updatePreference(requestID: "save-1", update: .actionWindowOpacity(60))
        )
    }

    func testEncodesPreferenceSaveAcknowledgements() throws {
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            WebEvent.preferenceSaved(requestID: "save-1", update: .interfaceLanguage(.enUS))
        )) as? [String: Any]
        XCTAssertEqual(saved?["type"] as? String, "preferences.saved")
        XCTAssertEqual(saved?["requestId"] as? String, "save-1")
        XCTAssertEqual(saved?["key"] as? String, "interfaceLanguage")
        XCTAssertEqual(saved?["value"] as? String, "en-US")

        let failed = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            WebEvent.preferenceSaveFailed(requestID: "save-2", key: "compact")
        )) as? [String: Any]
        XCTAssertEqual(failed?["type"] as? String, "preferences.saveFailed")
        XCTAssertEqual(failed?["requestId"] as? String, "save-2")
        XCTAssertEqual(failed?["key"] as? String, "compact")
    }

    func testDecodesAPICommandsWithoutRequiringANewCredential() throws {
        let requestID = "B04E446B-834E-4A26-98F7-6642A8451E63"
        let data = Data("""
        {"type":"api.fetchModels","requestId":"\(requestID)","configuration":{
        "baseURL":"https://api.example.com/v1","model":"gpt-a","sourceLanguage":"auto",
        "targetLanguage":"zh-cn","timeoutSeconds":30}}
        """.utf8)
        XCTAssertEqual(
            try JSONDecoder().decode(WebCommand.self, from: data),
            .fetchModels(
                requestID: requestID,
                configuration: APISettings(
                    baseURL: "https://api.example.com/v1",
                    model: "gpt-a",
                    sourceLanguage: "auto",
                    targetLanguage: "zh-cn",
                    timeoutSeconds: 30
                ),
                apiKeyInput: nil
            )
        )
    }

    func testAPIEventsContainStableResultsButNoCredentials() throws {
        let data = try JSONEncoder().encode(WebEvent.modelsLoaded(
            requestID: "B04E446B-834E-4A26-98F7-6642A8451E63",
            models: ["gpt-a"],
            latencyMilliseconds: 18
        ))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains(#""type":"api.modelsLoaded""#))
        XCTAssertTrue(json.contains(#""latencyMilliseconds":18"#))
        XCTAssertFalse(json.contains("secret"))
        XCTAssertFalse(json.contains("apiKey"))
    }

    func testRejectsUnknownCommandType() {
        let data = Data(#"{"type":"electron.invoke","channel":"settings"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(WebCommand.self, from: data))
    }

    func testBootstrapEventEncodesSettingsAndOnlyCredentialPresence() throws {
        let event = WebEvent.bootstrap(preferences: .default, hasAPIKey: true)
        let data = try JSONEncoder().encode(event)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let preferences = try XCTUnwrap(object["preferences"] as? [String: Any])
        let api = try XCTUnwrap(preferences["api"] as? [String: Any])

        XCTAssertTrue(json.contains(#""type":"bootstrap""#))
        XCTAssertTrue(json.contains(#""hasAPIKey":true"#))
        XCTAssertNil(api["apiKey"])
        XCTAssertFalse(json.contains("secret"))
    }
}
