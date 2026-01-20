import SwiftUI

@main
struct beeWatchApp: App {
    init() {
        NotificationManager.shared.setupNotificationCategories()
        // Initialize WatchConnectivity
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
