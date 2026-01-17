import Foundation
import SwiftData

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
            goals = responses.map { $0.toGoal() }.sorted { $0.losedate < $1.losedate }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func getGoal(slug: String) -> Goal? {
        goals.first { $0.slug == slug }
    }

    // MARK: - Datapoints

    func fetchDatapoints(for goalSlug: String) async throws -> [Datapoint] {
        let responses = try await BeeminderAPI.shared.fetchDatapoints(goalSlug: goalSlug)
        return responses.map { $0.toDatapoint(goalSlug: goalSlug) }
    }

    func submitDatapoint(goalSlug: String, value: Double, comment: String = "") async throws -> Datapoint {
        let response = try await BeeminderAPI.shared.createDatapoint(
            goalSlug: goalSlug,
            value: value,
            comment: comment
        )

        recordFrequentValue(goalSlug: goalSlug, value: value)
        await refreshGoals()

        return response.toDatapoint(goalSlug: goalSlug)
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
