import SwiftUI

struct ReminderSettingsView: View {
    let goalSlug: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared

    @State private var isEnabled = false
    @State private var reminderHour = 20
    @State private var reminderMinute = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    enableSection
                    if isEnabled {
                        timeSection
                    }
                    permissionSection
                }
                .padding()
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    private var enableSection: some View {
        Toggle("Enable Reminders", isOn: $isEnabled)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminder Time")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Picker("Hour", selection: $reminderHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 80)

                Text(":")

                Picker("Minute", selection: $reminderMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 80)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }

    private var permissionSection: some View {
        Group {
            if !notificationManager.isAuthorized {
                VStack(spacing: 8) {
                    Text("Notifications not authorized")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Button("Enable Notifications") {
                        Task {
                            _ = await notificationManager.requestAuthorization()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"
        return "\(displayHour) \(ampm)"
    }

    private func loadSettings() {
        let setting = notificationManager.getReminderSetting(for: goalSlug)
        isEnabled = setting.isEnabled
        reminderHour = setting.reminderHour
        reminderMinute = setting.reminderMinute
    }

    private func saveSettings() {
        let setting = ReminderSetting(
            goalSlug: goalSlug,
            isEnabled: isEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
        notificationManager.updateReminderSetting(setting)
    }
}

#Preview {
    ReminderSettingsView(goalSlug: "exercise")
}
