import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var reminderSettings: [String: ReminderSetting] = [:]

    private let settingsKey = "com.beewatch.reminderSettings"

    private init() {
        loadSettings()
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Reminder Settings

    func getReminderSetting(for goalSlug: String) -> ReminderSetting {
        reminderSettings[goalSlug] ?? ReminderSetting(goalSlug: goalSlug)
    }

    func updateReminderSetting(_ setting: ReminderSetting) {
        reminderSettings[setting.goalSlug] = setting
        saveSettings()

        Task {
            await scheduleReminder(for: setting)
        }
    }

    func disableReminder(for goalSlug: String) {
        var setting = getReminderSetting(for: goalSlug)
        setting.isEnabled = false
        reminderSettings[goalSlug] = setting
        saveSettings()

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationId(for: goalSlug)]
        )
    }

    // MARK: - Scheduling

    func scheduleReminder(for setting: ReminderSetting) async {
        guard setting.isEnabled, isAuthorized else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = notificationId(for: setting.goalSlug)

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Time to update: \(setting.goalSlug)"
        content.body = "Don't forget to log your progress!"
        content.sound = .default
        content.categoryIdentifier = "GOAL_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = setting.reminderHour
        dateComponents.minute = setting.reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func scheduleUrgentReminder(for goal: Goal) async {
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "urgent-\(goal.slug)"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Urgent: \(goal.title)"
        content.body = "You have \(goal.timeRemaining) left! \(goal.baremin ?? "")"
        content.sound = .defaultCritical
        content.categoryIdentifier = "GOAL_URGENT"
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule urgent notification: \(error)")
        }
    }

    func setupNotificationCategories() {
        let quickEntry1 = UNNotificationAction(
            identifier: "QUICK_ENTRY_1",
            title: "Log 1",
            options: []
        )

        let quickEntry5 = UNNotificationAction(
            identifier: "QUICK_ENTRY_5",
            title: "Log 5",
            options: []
        )

        let quickEntry10 = UNNotificationAction(
            identifier: "QUICK_ENTRY_10",
            title: "Log 10",
            options: []
        )

        let openAction = UNNotificationAction(
            identifier: "OPEN_GOAL",
            title: "Open Goal",
            options: [.foreground]
        )

        let reminderCategory = UNNotificationCategory(
            identifier: "GOAL_REMINDER",
            actions: [quickEntry1, quickEntry5, quickEntry10, openAction],
            intentIdentifiers: [],
            options: []
        )

        let urgentCategory = UNNotificationCategory(
            identifier: "GOAL_URGENT",
            actions: [quickEntry1, quickEntry5, quickEntry10, openAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([reminderCategory, urgentCategory])
    }

    // MARK: - Private

    private func notificationId(for goalSlug: String) -> String {
        "reminder-\(goalSlug)"
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode([String: ReminderSetting].self, from: data) else {
            return
        }
        reminderSettings = decoded
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(reminderSettings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
}

struct ReminderSetting: Codable, Identifiable {
    var id: String { goalSlug }
    let goalSlug: String
    var isEnabled: Bool = false
    var reminderHour: Int = 20
    var reminderMinute: Int = 0
    var intervalDays: Int = 1

    var reminderTimeString: String {
        let hour = reminderHour > 12 ? reminderHour - 12 : reminderHour
        let ampm = reminderHour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour, reminderMinute, ampm)
    }
}
