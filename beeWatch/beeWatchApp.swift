import SwiftUI

@main
struct beeWatchApp: App {
    init() {
        NotificationManager.shared.setupNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
