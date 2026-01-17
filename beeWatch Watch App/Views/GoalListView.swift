import SwiftUI

struct GoalListView: View {
    @StateObject private var dataStore = DataStore.shared
    @State private var showingSettings = false

    private var settings: UserSettings { UserSettings.shared }

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured {
                    notConfiguredView
                } else if dataStore.isLoading && dataStore.goals.isEmpty {
                    ProgressView("Loading...")
                } else if let error = dataStore.error, dataStore.goals.isEmpty {
                    errorView(error)
                } else if dataStore.goals.isEmpty {
                    emptyView
                } else {
                    goalsList
                }
            }
            .navigationTitle("beeWatch 🐝")
            .sheet(isPresented: $showingSettings, onDismiss: {
                if settings.isConfigured {
                    Task {
                        await dataStore.refreshGoals()
                    }
                }
            }) {
                SettingsView()
            }
            .refreshable {
                await dataStore.refreshGoals()
            }
        }
        .task {
            if settings.isConfigured {
                await dataStore.refreshGoals()
            }
        }
    }

    private var goalsList: some View {
        List {
            ForEach(dataStore.goals) { goal in
                NavigationLink(destination: GoalDetailView(goal: goal)) {
                    GoalRowView(goal: goal)
                }
            }

            Button {
                showingSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                    Text("Settings")
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.carousel)
        .onAppear {
            Task {
                await dataStore.refreshGoals()
            }
        }
    }

    private var notConfiguredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Setup Required")
                .font(.headline)

            Text("Add your Beeminder API key to get started")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)

            Text("Error")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Retry") {
                Task {
                    await dataStore.refreshGoals()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundColor(.gray)

            Text("No Goals")
                .font(.headline)

            Text("Create goals on beeminder.com")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct GoalRowView: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                urgencyIndicator
                Text(goal.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack {
                Text(goal.timeRemaining)
                    .font(.caption)
                    .foregroundColor(urgencyColor)

                Spacer()

                if let baremin = goal.baremin, !baremin.isEmpty {
                    Text(baremin)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if goal.pledge > 0 {
                Text("$\(Int(goal.pledge)) at risk")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var urgencyIndicator: some View {
        Circle()
            .fill(urgencyColor)
            .frame(width: 10, height: 10)
    }

    private var urgencyColor: Color {
        switch goal.urgencyColor {
        case .red: return .red
        case .orange: return .orange
        case .blue: return .blue
        case .green: return .green
        }
    }
}

#Preview {
    GoalListView()
}
