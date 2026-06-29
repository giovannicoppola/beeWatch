import SwiftUI
import SwiftData
import UserNotifications
import WatchKit
import WidgetKit

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
                // Refresh goal stats on resume. A view's `.task` only runs once
                // per appearance, so on a warm resume (the common case when
                // tapping a complication) nothing else re-fetches, and the UI
                // would otherwise show a stale `losedate` → false "Derailed!".
                if UserSettings.shared.isConfigured {
                    Task {
                        await DataStore.shared.refreshGoals()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
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
