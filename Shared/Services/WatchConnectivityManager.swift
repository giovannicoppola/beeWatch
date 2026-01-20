import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var lastSyncDate: Date?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send Settings (iPhone -> Watch)

    func sendSettingsToWatch() {
        guard WCSession.default.activationState == .activated else {
            print("WCSession not activated")
            return
        }

        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else {
            print("Watch app not installed")
            return
        }
        #endif

        let settings = UserSettings.shared
        let message: [String: Any] = [
            "type": "settings",
            "apiKey": settings.apiKey,
            "username": settings.username,
            "defaultComment": settings.defaultComment
        ]

        // Use updateApplicationContext for reliable background delivery
        do {
            try WCSession.default.updateApplicationContext(message)
            print("Settings sent via applicationContext")
        } catch {
            print("Failed to send applicationContext: \(error)")
        }

        // Also try sendMessage for immediate delivery if reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { _ in
                print("Settings sent via message")
            }, errorHandler: { error in
                print("Failed to send message: \(error)")
            })
        }
    }

    // MARK: - Request Settings (Watch -> iPhone)

    func requestSettingsFromPhone() {
        guard WCSession.default.activationState == .activated else { return }

        #if os(watchOS)
        // Check applicationContext first (this persists across app launches)
        let context = WCSession.default.receivedApplicationContext
        if let apiKey = context["apiKey"] as? String, !apiKey.isEmpty {
            applySettings(from: context)
            return
        }

        // Request fresh settings if reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["type": "requestSettings"], replyHandler: { response in
                DispatchQueue.main.async {
                    self.applySettings(from: response)
                }
            }, errorHandler: { error in
                print("Failed to request settings: \(error)")
            })
        }
        #endif
    }

    private func applySettings(from message: [String: Any]) {
        guard let apiKey = message["apiKey"] as? String else { return }

        let settings = UserSettings.shared
        settings.apiKey = apiKey

        if let username = message["username"] as? String {
            settings.username = username
        }
        if let comment = message["defaultComment"] as? String {
            settings.defaultComment = comment
        }

        DispatchQueue.main.async {
            self.lastSyncDate = Date()
        }

        print("Settings applied from phone: apiKey length = \(apiKey.count)")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        if activationState == .activated {
            #if os(watchOS)
            // On Watch activation, check for settings from phone
            requestSettingsFromPhone()
            #endif
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    // Receive messages
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if let type = message["type"] as? String {
            switch type {
            case "settings":
                // Watch received settings from phone
                DispatchQueue.main.async {
                    self.applySettings(from: message)
                }
                replyHandler(["status": "received"])

            case "requestSettings":
                // Phone received request from watch, send current settings
                #if os(iOS)
                let settings = UserSettings.shared
                replyHandler([
                    "apiKey": settings.apiKey,
                    "username": settings.username,
                    "defaultComment": settings.defaultComment
                ])
                #else
                replyHandler([:])
                #endif

            default:
                replyHandler([:])
            }
        } else {
            replyHandler([:])
        }
    }

    // Receive applicationContext updates
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if applicationContext["type"] as? String == "settings" {
            DispatchQueue.main.async {
                self.applySettings(from: applicationContext)
            }
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for switching watches
        WCSession.default.activate()
    }
    #endif
}
