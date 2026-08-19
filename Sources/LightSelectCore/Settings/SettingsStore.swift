import Foundation

public final class SettingsStore {
    public static let settingsKey = "lightselect.settings.v3"
    public static let legacySettingsKey = "lightselect.settings.v2"
    public static let legacyAPIKeyKey = "lightselect.credentials.apiKey"
    public static let maskedAPIKey = "••••••••"

    private let defaults: UserDefaults
    private let credentials: APICredentialStoring
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        credentials: APICredentialStoring = KeychainAPICredentialStore()
    ) {
        self.defaults = defaults
        self.credentials = credentials
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public var apiKey: String? { credentials.apiKey }

    public var hasAPIKey: Bool { apiKey != nil }

    public func load() -> LightSelectSettings {
        if let data = defaults.data(forKey: Self.settingsKey),
           let settings = try? decoder.decode(LightSelectSettings.self, from: data) {
            migrateCredentialIfNeeded()
            return settings
        }

        if let data = defaults.data(forKey: Self.legacySettingsKey),
           let settings = try? decoder.decode(LightSelectSettings.self, from: data) {
            if save(settings) {
                defaults.removeObject(forKey: Self.legacySettingsKey)
            }
            migrateCredentialIfNeeded()
            return settings
        }

        var settings = LightSelectSettings.default
        settings.api.baseURL = firstLegacyString(keys: ["api.baseURL", "apiBaseURL"]) ?? settings.api.baseURL
        settings.api.model = firstLegacyString(keys: ["api.model", "apiModel"]) ?? settings.api.model

        if save(settings) {
            migrateCredentialIfNeeded()
        }
        return settings
    }

    @discardableResult
    public func save(_ settings: LightSelectSettings) -> Bool {
        guard let data = try? encoder.encode(settings) else { return false }
        defaults.set(data, forKey: Self.settingsKey)
        return defaults.data(forKey: Self.settingsKey) == data
    }

    public func updateAPIKey(_ value: String?) {
        guard value != Self.maskedAPIKey else { return }
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            _ = credentials.updateAPIKey(nil)
            return
        }
        _ = credentials.updateAPIKey(value)
    }

    private func migrateCredentialIfNeeded() {
        let legacyKeys = [Self.legacyAPIKeyKey, "api.key", "apiKey"]
        if apiKey != nil {
            legacyKeys.forEach(defaults.removeObject(forKey:))
            return
        }
        guard let key = legacyKeys.first(where: {
            guard let value = defaults.string(forKey: $0) else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }), let legacy = defaults.string(forKey: key), credentials.updateAPIKey(legacy) else { return }
        defaults.removeObject(forKey: key)
    }

    private func firstLegacyString(keys: [String]) -> String? {
        keys.lazy.compactMap { self.defaults.string(forKey: $0) }.first
    }
}
