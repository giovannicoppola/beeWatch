import Foundation

@Observable
final class UserSettings {
    static let shared = UserSettings()

    private let apiKeyKey = "com.beewatch.apikey"
    private let usernameKey = "com.beewatch.username"
    private let defaultCommentKey = "com.beewatch.defaultComment"
    private let verifiedKeyKey = "com.beewatch.verifiedKey"

    // Use App Group shared container for data sharing with complications
    // Try App Group first, fall back to standard if not available
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: "group.com.beewatch") ?? UserDefaults.standard
    }

    // Stored properties for @Observable to track
    private var _apiKey: String = ""
    private var _username: String = "me"
    private var _defaultComment: String = "from my Apple Watch"
    private var _verifiedKey: String = ""

    var apiKey: String {
        get { _apiKey }
        set {
            _apiKey = newValue
            // Save to shared UserDefaults (accessible by complications)
            sharedDefaults.set(newValue, forKey: apiKeyKey)
            // Also save to standard as backup
            UserDefaults.standard.set(newValue, forKey: apiKeyKey)
        }
    }

    var username: String {
        get { _username }
        set {
            _username = newValue
            sharedDefaults.set(newValue, forKey: usernameKey)
            UserDefaults.standard.set(newValue, forKey: usernameKey)
        }
    }

    var defaultComment: String {
        get { _defaultComment }
        set {
            _defaultComment = newValue
            sharedDefaults.set(newValue, forKey: defaultCommentKey)
            UserDefaults.standard.set(newValue, forKey: defaultCommentKey)
        }
    }

    /// The API key Beeminder last accepted. Changing `apiKey` doesn't clear it,
    /// but `isVerified` compares the two, so a new key starts out unverified.
    var verifiedKey: String {
        get { _verifiedKey }
        set {
            _verifiedKey = newValue
            UserDefaults.standard.set(newValue, forKey: verifiedKeyKey)
        }
    }

    var isConfigured: Bool {
        !_apiKey.isEmpty
    }

    /// True only once Beeminder has accepted the current key, not merely when one is typed.
    var isVerified: Bool {
        isConfigured && _verifiedKey == _apiKey
    }

    private init() {
        // Load saved values - try App Group first, then standard UserDefaults
        _apiKey = sharedDefaults.string(forKey: apiKeyKey)
            ?? UserDefaults.standard.string(forKey: apiKeyKey)
            ?? ""
        _username = sharedDefaults.string(forKey: usernameKey)
            ?? UserDefaults.standard.string(forKey: usernameKey)
            ?? "me"
        _defaultComment = sharedDefaults.string(forKey: defaultCommentKey)
            ?? UserDefaults.standard.string(forKey: defaultCommentKey)
            ?? "from my Apple Watch"
        _verifiedKey = UserDefaults.standard.string(forKey: verifiedKeyKey) ?? ""
    }

    func reloadSettings() {
        _apiKey = sharedDefaults.string(forKey: apiKeyKey)
            ?? UserDefaults.standard.string(forKey: apiKeyKey)
            ?? ""
        _username = sharedDefaults.string(forKey: usernameKey)
            ?? UserDefaults.standard.string(forKey: usernameKey)
            ?? "me"
        _defaultComment = sharedDefaults.string(forKey: defaultCommentKey)
            ?? UserDefaults.standard.string(forKey: defaultCommentKey)
            ?? "from my Apple Watch"
    }

    func clearAll() {
        apiKey = ""
        username = "me"
        defaultComment = "from my Apple Watch"
        verifiedKey = ""
    }
}
