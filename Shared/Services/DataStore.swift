import Foundation
import SwiftData
import WidgetKit

@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var goals: [Goal] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var frequentValues: [String: [FrequentValue]] = [:]
    private let frequentValuesKey = "com.beewatch.frequentValues"

    private init() {
        loadFrequentValues()
    }

    // MARK: - Goals

    func refreshGoals() async {
        isLoading = true
        error = nil

        do {
            let responses = try await BeeminderAPI.shared.fetchGoals()
            // Sort by losedate ascending (most urgent first) so the app list and
            // the complication cache are always in the same order, regardless of
            // the server's returned ordering.
            let sortedResponses = responses.sorted {
                ($0.losedate ?? .infinity) < ($1.losedate ?? .infinity)
            }
            goals = sortedResponses.map { $0.toGoal() }

            cacheGoalsForComplications(sortedResponses)

            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func cacheGoalsForComplications(_ goals: [GoalResponse]) {
        let defaults = UserDefaults(suiteName: "group.com.beewatch") ?? UserDefaults.standard
        let snapshots = goals.prefix(5).map { goal -> [String: Any] in
            [
                "slug": goal.slug,
                "title": goal.title,
                "safebuf": goal.safebuf ?? 0,
                "losedate": goal.losedate ?? 0,
                "baremin": goal.baremin ?? "",
                "limsum": goal.limsum ?? "",
                "deltaText": goal.deltaText ?? ""
            ]
        }
        defaults.set(snapshots, forKey: "com.beewatch.goalCache")
        UserDefaults.standard.set(snapshots, forKey: "com.beewatch.goalCache")
    }

    func getGoal(slug: String) -> Goal? {
        goals.first { $0.slug == slug }
    }

    // MARK: - Datapoints

    func fetchDatapoints(for goalSlug: String) async throws -> [Datapoint] {
        let responses = try await BeeminderAPI.shared.fetchDatapoints(goalSlug: goalSlug)
        return responses.map { $0.toDatapoint(goalSlug: goalSlug) }
    }

    /// Submits a datapoint and returns only once we have server-confirmed fresh
    /// goal stats (or a best-effort optimistic local state on timeout). This
    /// avoids the "enter 20, still needs 3" bug where we'd otherwise refresh
    /// the UI with stale baremin/safebuf/losedate before Beeminder's async
    /// recompute has finished.
    func submitDatapoint(goalSlug: String, value: Double, comment: String? = nil) async throws -> Datapoint {
        let finalComment = comment ?? UserSettings.shared.defaultComment

        // Remember the server-side state before we mutate, so we can detect
        // when the async recompute has finished (updated_at advances).
        let previousUpdatedAt = getGoal(slug: goalSlug)?.updatedAt ?? 0

        // Optimistically mark the goal as refreshing so the UI stops showing
        // any stale "derailed" / red indicators while we wait for the server.
        applyOptimisticUpdate(slug: goalSlug, submittedValue: value)

        let response = try await BeeminderAPI.shared.createDatapoint(
            goalSlug: goalSlug,
            value: value,
            comment: finalComment
        )

        recordFrequentValue(goalSlug: goalSlug, value: value)

        // Wait for Beeminder to finish recomputing before we touch the stats
        // the UI shows. If it times out, we fall back to whatever the server
        // gave us on the last poll (the optimistic flag stays set so stale
        // numbers still won't flash a skull).
        do {
            let fresh = try await BeeminderAPI.shared.waitForRecompute(
                slug: goalSlug,
                previousUpdatedAt: previousUpdatedAt
            )
            mergeFreshGoal(fresh, clearOptimistic: !(fresh.queued ?? false))
        } catch {
            // Network error while polling — keep optimistic state and let the
            // next refreshGoals() clear it.
        }

        // Refresh the full list (uses current server state, sorted). If the
        // goal we just submitted is still queued, its optimistic flag remains
        // set so we don't render stale derail indicators.
        await refreshGoals()

        WidgetCenter.shared.reloadAllTimelines()

        // Safety net: some recomputes take longer than our poll window. Kick
        // the complications again shortly so they pick up any late update.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await self?.lateRefreshAfterSubmission(slug: goalSlug)
        }

        return response.toDatapoint(goalSlug: goalSlug)
    }

    /// Called ~15s after a datapoint submission to pick up slow server
    /// recomputes and push fresh stats to the widgets.
    private func lateRefreshAfterSubmission(slug: String) async {
        await refreshGoals()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Applies an optimistic local update so the UI doesn't momentarily show
    /// stale "derailed" state between the POST and the server's recompute.
    /// The real values will overwrite this shortly via `mergeFreshGoal` /
    /// `refreshGoals`.
    private func applyOptimisticUpdate(slug: String, submittedValue: Double) {
        guard let goal = getGoal(slug: slug) else { return }
        goal.isOptimisticallyRefreshed = true
        // If the user entered at least the numeric amount needed to be safe
        // today, project the goal forward by ~1 safe day so the complication
        // and list don't keep showing "due today" until the server catches up.
        if let safebump = goal.safebump, submittedValue >= safebump {
            if goal.safebuf < 1 { goal.safebuf = 1 }
            if goal.losedate <= Date() {
                goal.losedate = Date().addingTimeInterval(24 * 3600)
            }
        }
    }

    /// Merges a freshly-fetched server response into the in-memory goal.
    private func mergeFreshGoal(_ response: GoalResponse, clearOptimistic: Bool) {
        guard let goal = getGoal(slug: response.slug) else { return }
        goal.title = response.title
        goal.goalType = response.goalType ?? goal.goalType
        goal.rate = response.rate ?? goal.rate
        goal.runits = response.runits ?? goal.runits
        goal.pledge = response.pledge ?? goal.pledge
        goal.safebuf = response.safebuf ?? goal.safebuf
        if let losedate = response.losedate {
            goal.losedate = Date(timeIntervalSince1970: losedate)
        }
        goal.yaw = response.yaw ?? goal.yaw
        goal.limsum = response.limsum
        goal.baremin = response.baremin
        goal.queued = response.queued ?? false
        goal.updatedAt = response.updatedAt ?? goal.updatedAt
        goal.safebump = response.safebump
        goal.deltaText = response.deltaText
        if clearOptimistic {
            goal.isOptimisticallyRefreshed = false
        }
        goal.lastUpdated = Date()
        // Trigger SwiftUI update for @Published array of class refs.
        objectWillChange.send()
    }

    // MARK: - Frequent Values

    func getFrequentValues(for goalSlug: String, limit: Int = 3) -> [FrequentValue] {
        let values = frequentValues[goalSlug] ?? []
        return Array(values.sorted { $0.count > $1.count }.prefix(limit))
    }

    private func recordFrequentValue(goalSlug: String, value: Double) {
        var values = frequentValues[goalSlug] ?? []

        if let index = values.firstIndex(where: { $0.value == value }) {
            values[index].count += 1
        } else {
            values.append(FrequentValue(goalSlug: goalSlug, value: value, count: 1))
        }

        frequentValues[goalSlug] = values
        saveFrequentValues()
    }

    private func loadFrequentValues() {
        guard let data = UserDefaults.standard.data(forKey: frequentValuesKey),
              let decoded = try? JSONDecoder().decode([String: [FrequentValue]].self, from: data) else {
            return
        }
        frequentValues = decoded
    }

    private func saveFrequentValues() {
        if let encoded = try? JSONEncoder().encode(frequentValues) {
            UserDefaults.standard.set(encoded, forKey: frequentValuesKey)
        }
    }

    // MARK: - Most Urgent Goal

    var mostUrgentGoal: Goal? {
        goals.first
    }
}
