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

    /// Slugs of goals awaiting post-submission confirmation, mapped to the time
    /// after which we stop suppressing their real (possibly still-overdue)
    /// state. While a goal is in here and the server hasn't confirmed the
    /// recompute, `refreshGoals()` keeps its non-alarming "updating" appearance
    /// instead of rebuilding it as a stale "Derailed!". Bounded so a genuine
    /// derail still surfaces if the recompute never settles in our favour.
    private var optimisticDeadlines: [String: Date] = [:]
    private let optimisticWindow: TimeInterval = 90

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
            let newGoals = sortedResponses.map { $0.toGoal() }

            // `toGoal()` produces fresh objects with `isOptimisticallyRefreshed
            // == false`, which would otherwise discard the "updating" state we
            // set right after a submission — flashing a stale "Derailed!" while
            // Beeminder is still recomputing. Re-apply that state (bounded by
            // `optimisticWindow`) until the server confirms the goal is settled.
            let now = Date()
            for goal in newGoals {
                guard let deadline = optimisticDeadlines[goal.slug] else { continue }
                if now < deadline && (goal.queued || goal.losedate <= now) {
                    goal.isOptimisticallyRefreshed = true
                } else {
                    // Confirmed settled (losedate in the future, not queued) or
                    // the window elapsed — let the real state show from now on.
                    optimisticDeadlines.removeValue(forKey: goal.slug)
                }
            }
            goals = newGoals

            cacheGoalsForComplications(sortedResponses)

            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func cacheGoalsForComplications(_ goals: [GoalResponse]) {
        let defaults = UserDefaults(suiteName: "group.com.beewatch") ?? UserDefaults.standard
        let cachedAt = Date().timeIntervalSince1970
        let snapshots = goals.prefix(5).map { goal -> [String: Any] in
            [
                "slug": goal.slug,
                "title": goal.title,
                "safebuf": goal.safebuf ?? 0,
                "losedate": goal.losedate ?? 0,
                "baremin": goal.baremin ?? "",
                "limsum": goal.limsum ?? "",
                "deltaText": goal.deltaText ?? "",
                "cachedAt": cachedAt
            ]
        }
        defaults.set(snapshots, forKey: "com.beewatch.goalCache")
        UserDefaults.standard.set(snapshots, forKey: "com.beewatch.goalCache")
    }

    func getGoal(slug: String) -> Goal? {
        goals.first { $0.slug == slug }
    }

    /// Refreshes a single goal's stats from the server and merges them into the
    /// in-memory goal. Used when opening a goal (e.g. via a complication deep
    /// link) so we don't render stale `losedate`/`needText`/derail state that
    /// was captured in a previous session. Cheaper than a full `refreshGoals()`
    /// and safe to call from a detail view's `.task`.
    func refreshGoal(slug: String) async {
        do {
            let response = try await BeeminderAPI.shared.fetchGoal(slug: slug)
            // Only clear the optimistic flag if the server is done recomputing.
            mergeFreshGoal(response, clearOptimistic: !(response.queued ?? false))
        } catch {
            // Leave existing in-memory state in place on failure; the list-level
            // refresh and complication reloads will catch up.
        }
    }

    // MARK: - Datapoints

    func fetchDatapoints(for goalSlug: String) async throws -> [Datapoint] {
        let responses = try await BeeminderAPI.shared.fetchDatapoints(goalSlug: goalSlug)
        // Beeminder returns datapoints in ascending timestamp order, so a naive
        // `prefix(5)` in the UI would show the oldest of the fetched window.
        // Sort newest-first here so "Recent Entries" is actually recent.
        return responses
            .map { $0.toDatapoint(goalSlug: goalSlug) }
            .sorted { $0.timestamp > $1.timestamp }
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

        // Self-healing safety net: Beeminder's recompute can finish well after
        // our initial poll window, and we don't want the list left stuck on a
        // stale "overdue" state (the bug where the complication updates but the
        // app list doesn't). Keep refreshing on a backoff until the server
        // confirms the goal is settled, or we exhaust the schedule. The last
        // delay intentionally extends past `optimisticWindow` so that, if the
        // goal never settles, the final refresh surfaces its real state rather
        // than leaving it perpetually "updating".
        Task { [weak self] in
            let delaysSeconds: [UInt64] = [3, 5, 8, 15, 25, 40]
            for delay in delaysSeconds {
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                guard let self else { return }
                let settled = await self.refreshAfterSubmission(slug: goalSlug)
                if settled { break }
            }
        }

        return response.toDatapoint(goalSlug: goalSlug)
    }

    /// Refreshes the full list + complications after a submission and reports
    /// whether the given goal's server stats look settled (recompute finished
    /// and it's no longer overdue), so the retry loop can stop early.
    private func refreshAfterSubmission(slug: String) async -> Bool {
        await refreshGoals()
        WidgetCenter.shared.reloadAllTimelines()
        guard let goal = getGoal(slug: slug) else { return true }
        return !goal.queued && goal.losedate > Date()
    }

    /// Applies an optimistic local update so the UI doesn't momentarily show
    /// stale "derailed" state between the POST and the server's recompute.
    /// The real values will overwrite this shortly via `mergeFreshGoal` /
    /// `refreshGoals`.
    private func applyOptimisticUpdate(slug: String, submittedValue: Double) {
        guard let goal = getGoal(slug: slug) else { return }
        goal.isOptimisticallyRefreshed = true
        // Suppress a false "Derailed!" for this goal across subsequent refreshes
        // until the server confirms the recompute or this window elapses.
        optimisticDeadlines[slug] = Date().addingTimeInterval(optimisticWindow)
        // Project forward only if we know how much was needed and the user
        // entered at least that. `amountNeededToday` already returns the
        // correct delta (it accounts for kyoom vs non-kyoom by subtracting
        // `curval` from `safebump`).
        if let needed = goal.amountNeededToday, needed > 0,
           submittedValue >= needed {
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
        goal.curval = response.curval
        goal.kyoom = response.kyoom ?? goal.kyoom
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
