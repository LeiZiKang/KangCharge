import Foundation
import Security

/// Small Keychain wrapper. On iOS and watchOS the personal MCP address (which embeds
/// the device serial and an access token) lives here instead of in UserDefaults.
/// Items are shared with the widget through the App Group access group and stay
/// readable after first unlock so the widget can refresh in the background.
enum SecureStore {
    private static let service = "KangCharge"

    private static func baseQuery(_ key: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    static func string(forKey key: String) -> String? {
        for group in candidateGroups {
            var query = baseQuery(key, accessGroup: group)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
               let data = result as? Data, let value = String(data: data, encoding: .utf8) {
                return value
            }
        }
        return nil
    }

    static func set(_ value: String?, forKey key: String) {
        for group in candidateGroups {
            SecItemDelete(baseQuery(key, accessGroup: group) as CFDictionary)
        }
        guard let value, !value.isEmpty else { return }
        for group in candidateGroups {
            var query = baseQuery(key, accessGroup: group)
            query[kSecValueData as String] = Data(value.utf8)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if SecItemAdd(query as CFDictionary, nil) == errSecSuccess { return }
        }
    }

    /// Shared App Group first; fall back to the app's own keychain when the build has
    /// no App Group (unsigned simulator builds), so the app still works on its own.
    private static var candidateGroups: [String?] {
        AppConfig.appGroup.map { [$0, nil] } ?? [nil]
    }
}
