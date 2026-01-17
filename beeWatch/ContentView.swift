import SwiftUI

struct ContentView: View {
    @State private var apiKey: String = ""
    @State private var username: String = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showingClearConfirmation = false
    @State private var showingSavedAlert = false

    private let settings = UserSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                if settings.isConfigured {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You're all set!")
                                    .font(.headline)
                                Text("Open the Watch app to track your goals")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    statusView
                } header: {
                    Text("Connection Status")
                }

                Section {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Username (optional)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Beeminder Account")
                } footer: {
                    Text("Leave username blank to use 'me' (recommended)")
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || isTesting)

                    Button {
                        saveSettings()
                        showingSavedAlert = true
                    } label: {
                        HStack {
                            Text("Save Settings")
                            Spacer()
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    .disabled(apiKey.isEmpty)
                }

                Section {
                    Link(destination: URL(string: "https://www.beeminder.com/settings/account")!) {
                        HStack {
                            Text("Get API Key from Beeminder")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }

                    Link(destination: URL(string: "https://www.beeminder.com")!) {
                        HStack {
                            Text("Open Beeminder")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                } header: {
                    Text("Help")
                } footer: {
                    Text("Your API key can be found in your Beeminder account settings under 'Auth Token'.")
                }

                if settings.isConfigured {
                    Section {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            HStack {
                                Text("Clear All Settings")
                                Spacer()
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("beeWatch 🐝")
            .alert("Settings Saved", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your settings have been saved. Open the Watch app to see your goals.")
            }
            .onAppear {
                apiKey = settings.apiKey
                username = settings.username == "me" ? "" : settings.username
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
                Text("This will remove your API key and sign you out of the Watch app as well.")
            }
        }
    }

    private var statusView: some View {
        HStack {
            if settings.isConfigured {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected")
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Not configured")
            }
            Spacer()
            if let result = testResult {
                Text(result.success ? "OK" : "Failed")
                    .font(.caption)
                    .foregroundColor(result.success ? .green : .red)
            }
        }
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
                        message: "Found \(goals.count) goals"
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
    ContentView()
}
