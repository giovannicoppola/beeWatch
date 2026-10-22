import Foundation

#if DEBUG
/// Invented goals, for seeing the app work without a Beeminder account: the simulator, screenshots
/// and the app tour video (`tools/tour`). Debug builds only, and only when launched with
/// `-sample YES`. `BeeminderAPI` answers from here instead of the network, and a logged value stays
/// in memory: nothing reaches Beeminder, and nothing of anyone's real account can appear.
struct SampleGoals {
    /// Set by the `-sample YES` launch argument (the argument domain of UserDefaults).
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "sample") }

    private(set) var goals: [GoalResponse]
    private var datapoints: [String: [DatapointResponse]]

    init(now: Date = Date()) {
        // slug, title, units a day, days of buffer, running total, typical entries (newest first)
        let specs: [(String, String, Double, Int, Double, [Double])] = [
            ("pushups", "Pushups", 5, 0, 1_240, [10, 5, 10, 5, 5]),
            ("water", "Glasses of water", 8, 1, 2_310, [8, 6, 8, 8, 4]),
            ("reading", "Pages read", 20, 3, 4_875, [25, 20, 30, 20, 15]),
            ("meditate", "Meditation minutes", 10, 4, 1_520, [10, 15, 10, 10, 20]),
            ("walk", "Walks", 1, 6, 212, [1, 1, 1, 1, 1]),
            ("french", "French lessons", 1, 9, 148, [1, 2, 1, 1, 1]),
        ]
        let day: TimeInterval = 86_400
        goals = specs.map { slug, title, rate, safebuf, total, _ in
            Self.goal(slug: slug, title: title, rate: rate, safebuf: safebuf, curval: total,
                      losedate: now.addingTimeInterval(Double(safebuf) * day + 5 * 3_600),
                      updatedAt: now.timeIntervalSince1970 - 3_600)
        }
        datapoints = Dictionary(uniqueKeysWithValues: specs.map { slug, _, _, _, _, values in
            (slug, values.enumerated().map { index, value in
                Self.datapoint(value: value, at: now.addingTimeInterval(-Double(index + 1) * day))
            })
        })
    }

    func goal(slug: String) -> GoalResponse? {
        goals.first { $0.slug == slug }
    }

    /// Oldest first, as Beeminder returns them.
    func datapoints(slug: String) -> [DatapointResponse] {
        (datapoints[slug] ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    /// Logs a value as Beeminder would: the running total grows, and each day's worth of it
    /// buys a day of buffer, pushing the derail date out.
    mutating func log(_ value: Double, slug: String, comment: String, now: Date = Date()) -> DatapointResponse {
        let point = Self.datapoint(value: value, at: now, comment: comment)
        datapoints[slug, default: []].append(point)
        if let index = goals.firstIndex(where: { $0.slug == slug }) {
            let old = goals[index]
            let rate = max(old.rate ?? 1, 0.0001)
            let earned = Int((value / rate).rounded(.down))
            let safebuf = (old.safebuf ?? 0) + earned
            goals[index] = Self.goal(
                slug: old.slug, title: old.title, rate: rate, safebuf: safebuf,
                curval: (old.curval ?? 0) + value,
                losedate: Date(timeIntervalSince1970: old.losedate ?? now.timeIntervalSince1970)
                    .addingTimeInterval(Double(earned) * 86_400),
                updatedAt: now.timeIntervalSince1970)
        }
        return point
    }

    // MARK: - Building responses

    private static func goal(slug: String, title: String, rate: Double, safebuf: Int, curval: Double,
                             losedate: Date, updatedAt: Double) -> GoalResponse {
        let amount = rate.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rate)) : String(rate)
        let when = safebuf <= 0 ? "today" : safebuf == 1 ? "by tomorrow" : "in \(safebuf) days"
        return GoalResponse(
            slug: slug, title: title, goalType: "hustler", goaldate: nil, goalval: nil,
            rate: rate, runits: "d", pledge: 5, safebuf: safebuf,
            losedate: losedate.timeIntervalSince1970, thumbUrl: nil, graphUrl: nil, yaw: 1,
            limsum: "+\(amount) \(when)", baremin: "+\(amount)", queued: false, updatedAt: updatedAt,
            safebump: curval + rate * Double(max(1 - safebuf, 1)), curval: curval, kyoom: true,
            deltaText: nil)
    }

    private static func datapoint(value: Double, at date: Date, comment: String = "from my Apple Watch") -> DatapointResponse {
        DatapointResponse(
            id: UUID().uuidString, timestamp: date.timeIntervalSince1970,
            daystamp: Datapoint.formatDaystamp(from: date), value: value, comment: comment,
            updatedAt: date.timeIntervalSince1970, requestid: nil)
    }
}
#endif
