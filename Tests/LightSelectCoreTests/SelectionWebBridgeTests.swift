import WebKit
import XCTest
@testable import LightSelectCore

final class SelectionWebBridgeTests: XCTestCase {
    func testDecodesEveryWebCommandFromDictionaryBodies() throws {
        let cases: [(String, WebCommand)] = [
            (#"{"type":"selection.performAction","actionId":"translate","selectedText":"hello"}"#, .performAction(actionID: "translate", selectedText: "hello")),
            (#"{"type":"selection.determineToolbarSize","width":320,"height":43}"#, .determineToolbarSize(width: 320, height: 43)),
            (#"{"type":"selection.copySelectedText","selectedText":"hello"}"#, .copySelectedText("hello")),
            (#"{"type":"result.copy","content":"result"}"#, .copyResult("result")),
            (#"{"type":"system.openURL","url":"https://example.com"}"#, .openURL("https://example.com")),
            (#"{"type":"action.close"}"#, .closeAction),
            (#"{"type":"action.pin","pinned":true}"#, .pinAction(true)),
            (#"{"type":"action.setOpacity","opacity":0.8}"#, .setActionOpacity(0.8)),
            (#"{"type":"action.cancel","requestId":"r1"}"#, .cancelAction(requestID: "r1")),
            (#"{"type":"action.regenerate","requestId":"r1"}"#, .regenerateAction(requestID: "r1")),
            (
                #"{"type":"preferences.update","requestId":"save-1","key":"compact","value":true}"#,
                .updatePreference(requestID: "save-1", update: .compact(true))
            ),
            (#"{"type":"credentials.updateAPIKey","value":null}"#, .updateAPIKey(nil)),
            (#"{"type":"application.openSettings","section":"api"}"#, .openSettings(.api)),
            (#"{"type":"application.closeSettings"}"#, .closeSettings),
            (#"{"type":"application.openAccessibilitySettings"}"#, .openAccessibilitySettings),
            (#"{"type":"application.openSource"}"#, .openSource)
        ]

        for (json, expected) in cases {
            let body = try JSONSerialization.jsonObject(with: Data(json.utf8))
            XCTAssertEqual(try SelectionWebBridge.decodeCommand(body: body), expected)
        }
    }

    func testRejectsMissingFieldsAndUnknownTypes() {
        XCTAssertThrowsError(try SelectionWebBridge.decodeCommand(body: ["type": "action.cancel"]))
        XCTAssertThrowsError(try SelectionWebBridge.decodeCommand(body: ["type": "electron.invoke"]))
        XCTAssertThrowsError(try SelectionWebBridge.decodeCommand(body: "action.close"))
    }

    func testEventJavaScriptSafelySerializesUnicodeAndNewlines() throws {
        let script = try SelectionWebBridge.javaScript(for: .actionDelta(requestID: "r1", text: "你\n'quoted'"))

        XCTAssertTrue(script.hasPrefix("window.dispatchEvent(new CustomEvent('lightselect:event'"))
        XCTAssertTrue(script.contains(#""text":"你\n'quoted'""#))
        XCTAssertFalse(script.contains("你\n'quoted'"))
    }

    func testBootstrapIncludesOnlyCredentialPresence() throws {
        let script = try SelectionWebBridge.javaScript(for: .bootstrap(preferences: .default, hasAPIKey: true))
        XCTAssertTrue(script.contains(#""hasAPIKey":true"#))
        XCTAssertFalse(script.contains(#""apiKey":"#))
    }
}
