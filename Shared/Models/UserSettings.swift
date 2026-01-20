import Foundation

@Observable
final class UserSettings {
    static let shared = UserSettings()

    private let apiKeyKey = "com.beewatch.apikey"
    private let usernameKey = "com.beewatch.username"
    private let defaultCommentKey = "com.beewatch.defaultComment"

    // Use App Group shared container for data sharing with complications
    private let sharedDefaults = UserDefaults(suiteName: "group.com.beewatch") ?? UserDefaults.standard

    // Stored properties for @Observable to track
    private var _apiKey: String = ""
    private var _username: String = "me"
    private var _defaultComment: String = "from my Apple Watch"

    var apiKey: String {
        get { _apiKey }
        set {
            _apiKey = newValue
            // Save to shared UserDefaults (accessible by complications)
            sharedDefaults.set(newValue, forKey: apiKeyKey)
        }
    }

    var username: String {
        get { _username }
        set {
            _username = newValue
            sharedDefaults.set(newValue, forKey: usernameKey)
        }
    }

    var defaultComment: String {
        get { _defaultComment }
        set {
            _defaultComment = newValue
            sharedDefaults.set(newValue, forKey: defaultCommentKey)
        }
    }

    var isConfigured: Bool {
        !_apiKey.isEmpty
    }

    private init() {
        // Load saved values from shared UserDefaults
        _apiKey = sharedDefaults.string(forKey: apiKeyKey) ?? ""
        _username = sharedDefaults.string(forKey: usernameKey) ?? "me"
        _defaultComment = sharedDefaults.string(forKey: defaultCommentKey) ?? "from my Apple Watch"
    }

    func reloadSettings() {
        _apiKey = sharedDefaults.string(forKey: apiKeyKey) ?? ""
        _username = sharedDefaults.string(forKey: usernameKey) ?? "me"
        _defaultComment = sharedDefaults.string(forKey: defaultCommentKey) ?? "from my Apple Watch"
    }

    func clearAll() {
        apiKey = ""
        username = "me"
        defaultComment = "from my Apple Watch"
    }
}
