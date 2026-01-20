import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var showingClearConfirmation = false
    @State private var isSyncing = false

    private let settings = UserSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusSection
                    syncSection
                    if settings.isConfigured {
                        connectionInfoSection
                        clearSection
                    } else {
                        instructionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Clear Settings",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    settings.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your API key and sign you out.")
            }
        }
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            if settings.isConfigured {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Connected")
                            .font(.headline)
                        Text("User: \(settings.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Not Configured")
                            .font(.headline)
                        Text("Set up on iPhone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }

    private var syncSection: some View {
        VStack(spacing: 8) {
            Button {
                syncFromPhone()
            } label: {
                if isSyncing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Sync from iPhone", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing)

            HStack {
                Circle()
                    .fill(connectivityManager.isReachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(connectivityManager.isReachable ? "iPhone reachable" : "iPhone not reachable")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setup Instructions")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Label("Open beeWatch on iPhone", systemImage: "1.circle.fill")
                    .font(.caption2)
                Label("Enter your Beeminder API key", systemImage: "2.circle.fill")
                    .font(.caption2)
                Label("Tap 'Save Settings'", systemImage: "3.circle.fill")
                    .font(.caption2)
                Label("Tap 'Sync from iPhone' here", systemImage: "4.circle.fill")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var connectionInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API Key")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(maskedApiKey)
                .font(.caption2)
                .foregroundColor(.secondary)

            if !settings.defaultComment.isEmpty {
                Text("Default Comment")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Text(settings.defaultComment)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }

    private var maskedApiKey: String {
        let key = settings.apiKey
        if key.count > 8 {
            return String(key.prefix(4)) + "..." + String(key.suffix(4))
        }
        return "****"
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

    private func syncFromPhone() {
        isSyncing = true
        connectivityManager.requestSettingsFromPhone()

        // Give it a moment to receive the settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSyncing = false
            settings.reloadSettings()
        }
    }
}

#Preview {
    SettingsView()
}
