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

    /// Value-type snapshots of what each row displays. `ForEach` must iterate
    /// over these (not the `Goal` class) because `Goal` is Equatable by slug
    /// only, so SwiftUI's `ForEach`/view diffing treats a refreshed goal as
    /// unchanged and never re-renders the row. Value structs diff by content, so
    /// a changed safebuf/losedate/need reliably updates the list.
    private var goalRows: [GoalRow] {
        dataStore.goals.map { goal in
            GoalRow(
                id: goal.slug,
                title: goal.title,
                urgency: goal.urgencyColor,
                isDerailed: goal.isDerailed,
                isUpdating: goal.isOptimisticallyRefreshed || goal.queued,
                losedate: goal.losedate,
                needText: goal.needText,
                pledge: goal.pledge
            )
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
            ForEach(goalRows) { row in
                if let goal = dataStore.getGoal(slug: row.id) {
                    NavigationLink(value: goal) {
                        GoalRowView(row: row)
                    }
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

/// Value-type snapshot of a goal's row appearance. See `goalRows`.
struct GoalRow: Identifiable, Equatable {
    let id: String            // slug
    let title: String
    let urgency: UrgencyLevel
    let isDerailed: Bool
    let isUpdating: Bool
    let losedate: Date
    let needText: String?
    let pledge: Double
}

struct GoalRowView: View {
    let row: GoalRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if row.isDerailed {
                    Text("💀")
                        .font(.caption)
                } else {
                    urgencyIndicator
                }
                Text(row.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack {
                if row.isDerailed {
                    Text("Derailed!")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if row.isUpdating {
                    Text("Updating…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(row.losedate, style: .relative)
                        .font(.caption)
                        .foregroundColor(urgencyColor)
                }

                Spacer()

                if let need = row.needText {
                    Text(need)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if row.pledge > 0 {
                Text("$\(Int(row.pledge)) at risk")
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
        switch row.urgency {
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
