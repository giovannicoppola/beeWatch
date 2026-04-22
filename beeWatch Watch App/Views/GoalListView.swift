import SwiftUI
import WidgetKit

struct GoalListView: View {
    @StateObject private var dataStore = DataStore.shared
    @State private var showingSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var deepLinkGoalSlug: String?

    private var settings: UserSettings { UserSettings.shared }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
            .navigationDestination(for: Goal.self) { goal in
                GoalDetailView(goal: goal)
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                if settings.isConfigured {
                    Task {
                        await dataStore.refreshGoals()
                        // Refresh complications after settings change
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }) {
                SettingsView()
            }
        }
        .task {
            if settings.isConfigured {
                await dataStore.refreshGoals()
                // Refresh complications when goals are loaded
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onChange(of: deepLinkGoalSlug) { _, newSlug in
            if let slug = newSlug, let goal = dataStore.goals.first(where: { $0.slug == slug }) {
                navigationPath.append(goal)
                deepLinkGoalSlug = nil
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle URLs like beewatch://goal/exercise
        guard url.scheme == "beewatch",
              url.host == "goal",
              let goalSlug = url.pathComponents.dropFirst().first else {
            return
        }

        // If goals are loaded, navigate immediately
        if let goal = dataStore.goals.first(where: { $0.slug == goalSlug }) {
            navigationPath.append(goal)
        } else {
            // Store for later when goals load
            deepLinkGoalSlug = goalSlug
        }
    }

    private var goalsList: some View {
        List {
            ForEach(dataStore.goals) { goal in
                NavigationLink(value: goal) {
                    GoalRowView(goal: goal)
                }
            }

            // Refresh button after goals
            Button {
                Task {
                    await dataStore.refreshGoals()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(dataStore.isLoading ? "Refreshing..." : "Refresh")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(dataStore.isLoading)
            .listRowBackground(Color.clear)

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
        .refreshable {
            await dataStore.refreshGoals()
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
                if goal.isDerailed {
                    Text("💀")
                        .font(.caption)
                } else {
                    urgencyIndicator
                }
                Text(goal.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack {
                if goal.isDerailed {
                    Text("Derailed!")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if goal.isOptimisticallyRefreshed || goal.queued {
                    Text("Updating…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(goal.losedate, style: .relative)
                        .font(.caption)
                        .foregroundColor(urgencyColor)
                }

                Spacer()

                if let need = goal.needText {
                    Text(need)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
