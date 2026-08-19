import XCTest
@testable import LightSelectCore

final class SettingsStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var credentials: MemoryCredentialStore!

    override func setUp() {
        super.setUp()
        suiteName = "LightSelectCoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        credentials = MemoryCredentialStore()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        credentials = nil
        super.tearDown()
    }

    func testDefaultsMatchCherryActionOrderAndEnabledState() {
        let settings = LightSelectSettings.default

        XCTAssertEqual(settings.schemaVersion, 3)
        XCTAssertEqual(settings.interfaceLanguage, .zhCN)
        XCTAssertEqual(settings.actionItems.map(\.id), ["translate", "explain", "summary", "search", "copy", "refine", "quote"])
        XCTAssertEqual(settings.actionItems.map(\.enabled), [true, true, true, true, true, false, false])
        XCTAssertEqual(settings.actionWindowOpacity, 100)
        XCTAssertEqual(settings.triggerMode, .selected)
    }

    func testDecodesSchemaTwoSettingsWithoutLanguageAsChinese() throws {
        let data = Data("""
        {"schemaVersion":2,"enabled":false,"actionItems":[],"actionWindowOpacity":100,
        "autoClose":false,"autoPin":false,"compact":false,"filterList":[],"filterMode":"default",
        "followToolbar":true,"rememberWindowSize":false,"triggerMode":"selected",
        "api":{"baseURL":"https://api.example.com/v1","model":"m","sourceLanguage":"auto",
        "targetLanguage":"zh-cn","timeoutSeconds":60}}
        """.utf8)

        let settings = try JSONDecoder().decode(LightSelectSettings.self, from: data)

        XCTAssertEqual(settings.schemaVersion, 3)
        XCTAssertEqual(settings.interfaceLanguage, .zhCN)
    }

    func testOpacityIsClampedToCherrySliderRange() {
        XCTAssertEqual(LightSelectSettings(actionWindowOpacity: 1).actionWindowOpacity, 20)
        XCTAssertEqual(LightSelectSettings(actionWindowOpacity: 150).actionWindowOpacity, 100)
    }

    func testMigratesLegacyAPIValuesAndKeepsCredentialsOutsideSettingsJSON() throws {
        defaults.set("https://legacy.example/v1", forKey: "api.baseURL")
        defaults.set("legacy-secret", forKey: "api.key")
        defaults.set("legacy-model", forKey: "api.model")
        let store = SettingsStore(defaults: defaults, credentials: credentials)

        let settings = store.load()

        XCTAssertEqual(settings.api.baseURL, "https://legacy.example/v1")
        XCTAssertEqual(settings.api.model, "legacy-model")
        XCTAssertTrue(store.hasAPIKey)
        XCTAssertEqual(credentials.apiKey, "legacy-secret")
        let persisted = try XCTUnwrap(defaults.data(forKey: SettingsStore.settingsKey))
        let text = try XCTUnwrap(String(data: persisted, encoding: .utf8))
        XCTAssertFalse(text.contains("legacy-secret"))
        XCTAssertFalse(text.contains(SettingsStore.maskedAPIKey))
        XCTAssertNil(defaults.string(forKey: "api.key"))
    }

    func testMaskedKeyIsNeverPersistedAsCredential() {
        let store = SettingsStore(defaults: defaults, credentials: credentials)
        store.updateAPIKey("real-secret")
        store.updateAPIKey(SettingsStore.maskedAPIKey)
        XCTAssertEqual(store.apiKey, "real-secret")

        store.updateAPIKey("")
        XCTAssertNil(store.apiKey)
        XCTAssertFalse(store.hasAPIKey)
    }

    func testMigratesVersionTwoSettingsToVersionThreeKey() throws {
        var legacy = LightSelectSettings.default
        legacy.api.model = "legacy-model"
        defaults.set(try JSONEncoder().encode(legacy), forKey: SettingsStore.legacySettingsKey)
        let store = SettingsStore(defaults: defaults, credentials: credentials)

        let loaded = store.load()

        XCTAssertEqual(loaded.api.model, "legacy-model")
        XCTAssertNotNil(defaults.data(forKey: SettingsStore.settingsKey))
        XCTAssertNil(defaults.data(forKey: SettingsStore.legacySettingsKey))
    }

    func testKeepsLegacyCredentialWhenSecureWriteFails() {
        defaults.set("legacy-secret", forKey: SettingsStore.legacyAPIKeyKey)
        credentials.acceptsWrites = false
        let store = SettingsStore(defaults: defaults, credentials: credentials)

        _ = store.load()

        XCTAssertNil(credentials.apiKey)
        XCTAssertEqual(defaults.string(forKey: SettingsStore.legacyAPIKeyKey), "legacy-secret")
    }
}

private final class MemoryCredentialStore: APICredentialStoring {
    var apiKey: String?
    var acceptsWrites = true

    @discardableResult
    func updateAPIKey(_ value: String?) -> Bool {
        guard acceptsWrites else { return false }
        apiKey = value
        return true
    }
}
