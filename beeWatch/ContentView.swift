import SwiftUI

struct ContentView: View {
    @State private var apiKey: String = ""
    @State private var username: String = ""
    @State private var defaultComment: String = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showingFailedAlert = false
    @State private var showingClearConfirmation = false
    @State private var showingSavedAlert = false

    private let settings = UserSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                if settings.isVerified {
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
                        .onChange(of: apiKey) { _, newValue in
                            // Accept the whole auth_token.json page, not just the key
                            if let page = AuthTokenPage(pasted: newValue) {
                                apiKey = page.authToken
                                username = page.username
                            }
                        }

                    TextField("Username (optional)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Beeminder Account")
                } footer: {
                    Text("Paste your API key, or the whole page from \"Get API Key from Beeminder\" below. The username is filled in once Beeminder accepts the key.")
                }

                Section {
                    TextField("Default comment", text: $defaultComment)
                        .autocorrectionDisabled()
                } header: {
                    Text("Watch Data Entry")
                } footer: {
                    Text("This comment will be added to data entries from the Watch. You can still edit it before submitting.")
                }

                Section {
                    Button {
                        testConnection(showAlert: false)
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
                        testConnection(showAlert: true)
                    } label: {
                        HStack {
                            Text("Save Settings")
                            Spacer()
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    .disabled(apiKey.isEmpty || isTesting)
                }

                Section {
                    Link(destination: URL(string: "https://www.beeminder.com/api/v1/auth_token.json")!) {
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
                    Text("Sign in to Beeminder if asked. The page shows your username and API key; copy all of it and paste it above.")
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
                Text("Beeminder accepted your API key. Open the Watch app to see your goals.")
            }
            .alert("Couldn't Connect", isPresented: $showingFailedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(testResult?.message ?? "Beeminder didn't accept this API key.")
            }
            .onAppear {
                apiKey = settings.apiKey
                username = settings.username == "me" ? "" : settings.username
                defaultComment = settings.defaultComment
                // A key saved by an earlier build, or sent from the watch, hasn't been checked yet
                if settings.isConfigured && !settings.isVerified {
                    testConnection(showAlert: false)
                }
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
                    defaultComment = "from my Apple Watch"
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
            if settings.isVerified {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected as \(settings.username)")
            } else if isTesting {
                ProgressView()
                Text("Checking with Beeminder…")
            } else if settings.isConfigured {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Not verified")
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
        settings.defaultComment = defaultComment

        // Sync to Watch
        WatchConnectivityManager.shared.sendSettingsToWatch()
    }

    /// Checks the key with Beeminder before calling the connection good, then saves
    /// the account's real username so requests don't rely on "me".
    private func testConnection(showAlert: Bool) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = key
        isTesting = true
        testResult = nil

        Task {
            do {
                let owner = try await BeeminderAPI.shared.verify(apiKey: key)
                await MainActor.run {
                    username = owner
                    saveSettings()
                    settings.verifiedKey = key
                    testResult = TestResult(success: true, message: "Connected as \(owner)")
                    if showAlert { showingSavedAlert = true }
                }
            } catch {
                await MainActor.run {
                    testResult = TestResult(success: false, message: Self.describe(error))
                    if showAlert { showingFailedAlert = true }
                }
            }
            await MainActor.run {
                isTesting = false
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        if case APIError.httpError(let code, _) = error, code == 401 || code == 404 {
            return "Beeminder didn't accept this API key. Check that you copied all of it."
        }
        return error.localizedDescription
    }
}

struct TestResult {
    let success: Bool
    let message: String
}

#Preview {
    ContentView()
}
