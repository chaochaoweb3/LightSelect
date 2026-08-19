import Foundation
import Security

public protocol APICredentialStoring: AnyObject {
    var apiKey: String? { get }

    @discardableResult
    func updateAPIKey(_ value: String?) -> Bool
}

public final class KeychainAPICredentialStore: APICredentialStoring {
    public static let service = "local.ccw3.LightSelect"
    public static let account = "openai-compatible-api-key"

    public init() {}

    public var apiKey: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }

    @discardableResult
    public func updateAPIKey(_ value: String?) -> Bool {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            let status = SecItemDelete(baseQuery as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }

        let data = Data(normalized.utf8)
        if apiKey != nil {
            let attributes = [kSecValueData as String: data]
            return SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary) == errSecSuccess
        }

        var query = baseQuery
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
    }
}
