import SwiftUI
import SwiftData

@main
struct beeWatch_Watch_App: App {
    init() {
        NotificationManager.shared.setupNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            GoalListView()
        }
    }
}
