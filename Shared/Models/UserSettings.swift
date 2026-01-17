import Foundation
import Security

@Observable
final class UserSettings {
    static let shared = UserSettings()

    private let apiKeyKey = "com.beewatch.apikey"
    private let usernameKey = "com.beewatch.username"

    // Stored properties for @Observable to track
    private var _apiKey: String = ""
    private var _username: String = "me"

    var apiKey: String {
        get { _apiKey }
        set {
            _apiKey = newValue
            saveToKeychain(value: newValue, for: apiKeyKey)
        }
    }

    var username: String {
        get { _username }
        set {
            _username = newValue
            UserDefaults.standard.set(newValue, forKey: usernameKey)
        }
    }

    var isConfigured: Bool {
        !_apiKey.isEmpty
    }

    private init() {
        // Load saved values on init
        _apiKey = loadFromKeychain(for: apiKeyKey) ?? ""
        _username = UserDefaults.standard.string(forKey: usernameKey) ?? "me"
    }

    private func saveToKeychain(value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)

        if !value.isEmpty {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            SecItemAdd(newQuery as CFDictionary, nil)
        }
    }

    private func loadFromKeychain(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    func clearAll() {
        apiKey = ""
        username = "me"
    }
}
