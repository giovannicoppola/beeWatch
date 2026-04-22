import SwiftUI
import SwiftData
import UserNotifications
import WatchKit

@main
struct beeWatch_Watch_App: App {
    @Environment(\.scenePhase) private var scenePhase
    @WKApplicationDelegateAdaptor(NotificationDelegate.self) var notificationDelegate

    init() {
        NotificationManager.shared.setupNotificationCategories()
        // Initialize WatchConnectivity to receive settings from iPhone
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            GoalListView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Reload settings in case they were changed from iPhone app
                UserSettings.shared.reloadSettings()
                // Also request latest settings from phone
                WatchConnectivityManager.shared.requestSettingsFromPhone()
            }
        }
    }
}

class NotificationDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        let goalSlug = response.notification.request.content.userInfo["goalSlug"] as? String ?? ""

        var value: Double? = nil

        switch actionId {
        case "QUICK_ENTRY_1":
            value = 1
        case "QUICK_ENTRY_5":
            value = 5
        case "QUICK_ENTRY_10":
            value = 10
        default:
            break
        }

        if let value = value, !goalSlug.isEmpty {
            // Must wait for async work to complete before calling completionHandler
            // Otherwise the app may be suspended before the network request finishes
            Task {
                do {
                    _ = try await DataStore.shared.submitDatapoint(goalSlug: goalSlug, value: value)
                    await NotificationManager.shared.showConfirmationNotification(goalSlug: goalSlug, value: value)
                } catch {
                    print("Failed to submit from notification: \(error)")
                }
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
}
