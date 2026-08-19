import XCTest
@testable import LightSelectCore

final class UIFixtureTests: XCTestCase {
    func testParsesCompleteFixtureArguments() throws {
        let request = try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "toolbar", "--appearance", "dark", "--output", "/tmp/toolbar.png"
        ])

        XCTAssertEqual(request.kind, .toolbar)
        XCTAssertEqual(request.appearance, .dark)
        XCTAssertEqual(request.outputURL.path, "/tmp/toolbar.png")
        XCTAssertEqual(request.language, .zhCN)
        XCTAssertEqual(request.width, 560)
        XCTAssertEqual(request.height, 44)
    }

    func testParsesLocalizedDesktopAndNarrowSettingsFixtures() throws {
        let desktop = try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "settings", "--appearance", "dark",
            "--language", "en-US", "--width", "900", "--height", "700",
            "--output", "/tmp/settings-en.png"
        ])
        XCTAssertEqual(desktop.language, .enUS)
        XCTAssertEqual(desktop.width, 900)
        XCTAssertEqual(desktop.height, 700)

        let narrow = try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "settings", "--appearance", "light",
            "--language", "zh-CN", "--width", "520", "--height", "760",
            "--output", "/tmp/settings-zh.png"
        ])
        XCTAssertEqual(narrow.language, .zhCN)
        XCTAssertEqual(narrow.width, 520)
        XCTAssertEqual(narrow.height, 760)
    }

    func testRejectsMissingOrUnsupportedFixtureArguments() {
        XCTAssertThrowsError(try UIFixtureRequest.parse(arguments: ["LightSelect", "--ui-test", "toolbar"]))
        XCTAssertThrowsError(try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "chat", "--appearance", "light", "--output", "/tmp/a.png"
        ]))
        XCTAssertThrowsError(try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "toolbar", "--appearance", "system", "--output", "/tmp/a.png"
        ]))
        XCTAssertThrowsError(try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "settings", "--appearance", "light",
            "--language", "fr-FR", "--output", "/tmp/a.png"
        ]))
        XCTAssertThrowsError(try UIFixtureRequest.parse(arguments: [
            "LightSelect", "--ui-test", "settings", "--appearance", "light",
            "--width", "479", "--height", "760", "--output", "/tmp/a.png"
        ]))
    }

    func testFixtureSettingsContainDefaultActionsAndOneCustomPrompt() {
        let settings = UIFixtureRequest.fixtureSettings
        XCTAssertEqual(settings.actionItems.filter { !$0.isBuiltIn }.count, 1)
        XCTAssertEqual(settings.actionItems.last?.prompt, "Define {{text}} in one sentence.")
        XCTAssertTrue(settings.enabled)
    }

    func testOnlySettingsFixtureIncludesTheCustomPrompt() {
        XCTAssertEqual(UIFixtureRequest.settings(for: .toolbar).actionItems.filter { !$0.isBuiltIn }.count, 0)
        XCTAssertEqual(UIFixtureRequest.settings(for: .action).actionItems.filter { !$0.isBuiltIn }.count, 0)
        XCTAssertEqual(UIFixtureRequest.settings(for: .settings).actionItems.filter { !$0.isBuiltIn }.count, 1)
    }

    func testSettingsFixtureUsesDeterministicLocalizedAPIState() {
        let settings = UIFixtureRequest.settings(for: .settings, language: .enUS)
        XCTAssertEqual(settings.interfaceLanguage, .enUS)
        XCTAssertEqual(settings.api.baseURL, "http://127.0.0.1:18431/success/v1")
        XCTAssertEqual(settings.api.model, "gpt-fixture-small")
        XCTAssertEqual(UIFixtureRequest.fixtureModels, ["gpt-fixture-large", "gpt-fixture-small"])
        XCTAssertEqual(UIFixtureRequest.fixtureLatencyMilliseconds, 24)
    }
}
