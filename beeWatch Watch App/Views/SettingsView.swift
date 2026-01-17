import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var username: String = ""
    @State private var showingClearConfirmation = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    private let settings = UserSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    apiKeySection
                    usernameSection
                    testSection
                    helpSection
                    if settings.isConfigured {
                        clearSection
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = settings.apiKey
                username = settings.username
            }
            .confirmationDialog(
                "Clear Settings",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    settings.clearAll()
                    apiKey = ""
                    username = ""
                    testResult = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your API key and sign you out.")
            }
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.caption)
                .foregroundColor(.secondary)

            SecureField("Enter API key", text: $apiKey)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Username (optional)")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("me", text: $username)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text("Leave blank to use 'me'")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var testSection: some View {
        VStack(spacing: 8) {
            Button {
                testConnection()
            } label: {
                if isTesting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Test Connection", systemImage: "network")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(apiKey.isEmpty || isTesting)

            if let result = testResult {
                HStack {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.success ? .green : .red)
                    Text(result.message)
                        .font(.caption)
                }
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to get your API key:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("1. Go to beeminder.com/settings/account")
                .font(.caption2)

            Text("2. Find 'Auth Token' section")
                .font(.caption2)

            Text("3. Copy and paste the token here")
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var clearSection: some View {
        Button(role: .destructive) {
            showingClearConfirmation = true
        } label: {
            Label("Clear Settings", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func saveSettings() {
        settings.apiKey = apiKey
        settings.username = username.isEmpty ? "me" : username
    }

    private func testConnection() {
        saveSettings()
        isTesting = true
        testResult = nil

        Task {
            do {
                let goals = try await BeeminderAPI.shared.fetchGoals()
                await MainActor.run {
                    testResult = TestResult(
                        success: true,
                        message: "Connected! Found \(goals.count) goals."
                    )
                }
            } catch {
                await MainActor.run {
                    testResult = TestResult(
                        success: false,
                        message: error.localizedDescription
                    )
                }
            }
            await MainActor.run {
                isTesting = false
            }
        }
    }
}

struct TestResult {
    let success: Bool
    let message: String
}

#Preview {
    SettingsView()
}
