import WidgetKit
import SwiftUI

// MARK: - Shared Types

struct GoalSnapshot {
    let slug: String
    let title: String
    let safebuf: Int
    /// Absolute timestamp at which this goal derails. Stored as a `Date` so the
    /// complication view can use `Text(date, style: .relative)` / `.timer`,
    /// which auto-updates every second without needing a new timeline entry.
    let losedate: Date
    let needText: String?
}

extension GoalSnapshot {
    /// Computed per-render: true if `losedate` has passed by `now`.
    func isDerailed(at now: Date) -> Bool {
        losedate <= now
    }
}

struct GoalEntry: TimelineEntry {
    let date: Date
    let goal: GoalSnapshot?
    let goalIndex: Int // Which goal position (0 = most urgent, 1 = second, etc.)
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Goal Caching

private let goalCacheKey = "com.beewatch.goalCache"

private func sharedDefaults() -> UserDefaults {
    UserDefaults(suiteName: "group.com.beewatch") ?? UserDefaults.standard
}

private func readGoalCache() -> [[String: Any]]? {
    if let cached = sharedDefaults().array(forKey: goalCacheKey) as? [[String: Any]] {
        return cached
    }
    return UserDefaults.standard.array(forKey: goalCacheKey) as? [[String: Any]]
}

func cachedGoalName(at index: Int) -> String {
    if let cached = readGoalCache(),
       index < cached.count,
       let title = cached[index]["title"] as? String,
       !title.isEmpty {
        return title
    }
    return "Goal #\(index + 1)"
}

/// Stores up to 5 goals in shared UserDefaults, sorted by urgency (losedate asc)
/// so that Goal1/Goal2/... always correspond to the same ordering the user sees
/// in the app list.
func cacheGoals(_ goals: [GoalResponse]) {
    let sorted = goals.sorted {
        ($0.losedate ?? .infinity) < ($1.losedate ?? .infinity)
    }
    let snapshots = sorted.prefix(5).map { goal -> [String: Any] in
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
    sharedDefaults().set(snapshots, forKey: goalCacheKey)
    UserDefaults.standard.set(snapshots, forKey: goalCacheKey)
}

func getCachedGoal(at index: Int) -> GoalSnapshot? {
    guard let cached = readGoalCache(), index < cached.count else { return nil }
    let data = cached[index]
    let losedate = data["losedate"] as? Double ?? 0
    let limsum = data["limsum"] as? String
    let deltaText = data["deltaText"] as? String
    let baremin = data["baremin"] as? String
    return GoalSnapshot(
        slug: data["slug"] as? String ?? "",
        title: data["title"] as? String ?? "Goal \(index + 1)",
        safebuf: data["safebuf"] as? Int ?? 0,
        losedate: Date(timeIntervalSince1970: losedate),
        needText: firstNonEmpty(limsum, deltaText, baremin)
    )
}

private func firstNonEmpty(_ strings: String?...) -> String? {
    for s in strings {
        if let s, !s.isEmpty { return s }
    }
    return nil
}

// MARK: - Shared Goal Fetching

/// Fetches the goal at `index` in urgency order (most urgent = 0).
/// Always sorts the response locally so the index is stable even if Beeminder
/// changes its server-side ordering.
func fetchGoalEntry(at index: Int) async -> GoalEntry {
    UserSettings.shared.reloadSettings()

    let apiKey = sharedDefaults().string(forKey: "com.beewatch.apikey")
        ?? UserDefaults.standard.string(forKey: "com.beewatch.apikey")
        ?? ""

    guard !apiKey.isEmpty else {
        if let cached = getCachedGoal(at: index) {
            return GoalEntry(date: Date(), goal: cached, goalIndex: index)
        }
        return GoalEntry(date: Date(), goal: nil, goalIndex: index)
    }

    do {
        let goals = try await BeeminderAPI.shared.fetchGoals()
        cacheGoals(goals)

        let sorted = goals.sorted {
            ($0.losedate ?? .infinity) < ($1.losedate ?? .infinity)
        }

        if let goal = sorted[safe: index] {
            return GoalEntry(
                date: Date(),
                goal: snapshot(from: goal),
                goalIndex: index
            )
        }
    } catch {
        if let cached = getCachedGoal(at: index) {
            return GoalEntry(date: Date(), goal: cached, goalIndex: index)
        }
    }

    return GoalEntry(date: Date(), goal: nil, goalIndex: index)
}

func fetchMostUrgentGoalEntry() async -> GoalEntry {
    UserSettings.shared.reloadSettings()

    let apiKey = sharedDefaults().string(forKey: "com.beewatch.apikey")
        ?? UserDefaults.standard.string(forKey: "com.beewatch.apikey")
        ?? ""

    guard !apiKey.isEmpty else {
        if let cached = getCachedGoal(at: 0) {
            return GoalEntry(date: Date(), goal: cached, goalIndex: -1)
        }
        return GoalEntry(date: Date(), goal: nil, goalIndex: -1)
    }

    do {
        let goals = try await BeeminderAPI.shared.fetchGoals()
        cacheGoals(goals)

        let sorted = goals.sorted {
            ($0.losedate ?? .infinity) < ($1.losedate ?? .infinity)
        }

        if let mostUrgent = sorted.first {
            return GoalEntry(
                date: Date(),
                goal: snapshot(from: mostUrgent),
                goalIndex: -1
            )
        }
    } catch {
        if let cached = getCachedGoal(at: 0) {
            return GoalEntry(date: Date(), goal: cached, goalIndex: -1)
        }
    }

    return GoalEntry(date: Date(), goal: nil, goalIndex: -1)
}

private func snapshot(from goal: GoalResponse) -> GoalSnapshot {
    GoalSnapshot(
        slug: goal.slug,
        title: goal.title,
        safebuf: goal.safebuf ?? 0,
        losedate: Date(timeIntervalSince1970: goal.losedate ?? 0),
        needText: firstNonEmpty(goal.limsum, goal.deltaText, goal.baremin)
    )
}

// MARK: - Timeline helpers

/// Builds a small timeline for a goal entry so that:
///   - The complication re-renders at the derailment moment (isDerailed flips
///     from false to true without waiting for the next 15-minute reload).
///   - The countdown text (rendered via `Text(date, style: .relative)`)
///     already updates every second in the view body itself.
///
/// We always include a final "refresh hint" entry whose date tells WidgetKit
/// when to fetch a new timeline.
private func buildTimeline(for entry: GoalEntry) -> Timeline<GoalEntry> {
    let now = Date()
    // Urgent goals poll more often; safe ones less often to save battery.
    let nextRefresh: Date
    if let goal = entry.goal {
        let secondsToDerail = goal.losedate.timeIntervalSince(now)
        if secondsToDerail <= 0 {
            nextRefresh = now.addingTimeInterval(15 * 60)
        } else if secondsToDerail < 3600 {
            nextRefresh = now.addingTimeInterval(5 * 60)
        } else if goal.safebuf <= 1 {
            nextRefresh = now.addingTimeInterval(10 * 60)
        } else {
            nextRefresh = now.addingTimeInterval(30 * 60)
        }
    } else {
        nextRefresh = now.addingTimeInterval(15 * 60)
    }

    var entries: [GoalEntry] = [entry]

    // If the goal derails between now and the next scheduled refresh, insert
    // a transition entry so the skull appears at the right moment.
    if let goal = entry.goal {
        let derailMoment = goal.losedate
        if derailMoment > now && derailMoment < nextRefresh {
            entries.append(GoalEntry(
                date: derailMoment,
                goal: goal,
                goalIndex: entry.goalIndex
            ))
        }
    }

    return Timeline(entries: entries, policy: .after(nextRefresh))
}

// MARK: - 1. APP LAUNCHER COMPLICATION

struct AppLauncherEntry: TimelineEntry {
    let date: Date
}

struct AppLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> AppLauncherEntry {
        AppLauncherEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AppLauncherEntry) -> Void) {
        completion(AppLauncherEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AppLauncherEntry>) -> Void) {
        let entry = AppLauncherEntry(date: Date())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 24, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct AppLauncherView: View {
    let entry: AppLauncherEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Text("🐝")
                    .font(.system(size: 32))
            }
        case .accessoryRectangular:
            HStack {
                Text("🐝")
                    .font(.largeTitle)
                VStack(alignment: .leading) {
                    Text("BeeWatch")
                        .font(.headline)
                    Text("Open app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("🐝 BeeWatch")
        case .accessoryCorner:
            Text("🐝")
                .font(.title)
                .widgetCurvesContent()
                .widgetLabel("BeeWatch")
        default:
            Text("🐝")
        }
    }
}

struct AppLauncherComplication: Widget {
    let kind = "AppLauncher"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AppLauncherProvider()) { entry in
            AppLauncherView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("BeeWatch")
        .description("Open the BeeWatch app")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - Goal Complication View (shared by all goal complications)

struct GoalComplicationView: View {
    let entry: GoalEntry
    @Environment(\.widgetFamily) var family

    /// Whether this goal is currently derailed, evaluated per-render against
    /// the entry's `date` (which WidgetKit sets to the re-render time).
    private var isDerailed: Bool {
        entry.goal?.isDerailed(at: entry.date) ?? false
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryInline:
                inlineView
            case .accessoryCorner:
                cornerView
            default:
                circularView
            }
        }
        .widgetURL(URL(string: "beewatch://goal/\(entry.goal?.slug ?? "")")!)
    }

    private var circularView: some View {
        Group {
            if let goal = entry.goal {
                if goal.safebuf <= 0 || isDerailed {
                    Gauge(value: 1.0) {
                        Text("")
                    } currentValueLabel: {
                        VStack(spacing: 0) {
                            Text(isDerailed ? "💀" : "0")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text(shortenedTitle(goal.title))
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(.red)
                } else {
                    Gauge(value: Double(min(goal.safebuf, 7)), in: 0...7) {
                        Text("")
                    } currentValueLabel: {
                        VStack(spacing: 0) {
                            Text("\(goal.safebuf)")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text(shortenedTitle(goal.title))
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(goal.safebuf <= 1 ? .orange : .green)
                }
            } else {
                VStack(spacing: 0) {
                    Text("?")
                        .font(.title2)
                    Text("Goal \(entry.goalIndex + 1)")
                        .font(.system(size: 9))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AccessoryWidgetBackground())
                .clipShape(Circle())
            }
        }
    }

    private func shortenedTitle(_ title: String) -> String {
        if title.count <= 8 {
            return title
        }
        return String(title.prefix(7)) + "…"
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let goal = entry.goal {
                HStack {
                    Text(isDerailed ? "💀" : (goal.safebuf <= 0 ? "🔴" : "🐝"))
                    Text(goal.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(goal.safebuf <= 0 || isDerailed ? .red : .primary)
                }
                // Live-updating countdown via .relative style: recomputes every
                // second without needing a new timeline entry.
                if isDerailed {
                    Text("Derailed!")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text(goal.losedate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(goal.safebuf <= 0 ? .red : .primary)
                }
                if let need = goal.needText {
                    Text(need).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("🐝 Goal \(entry.goalIndex + 1)").font(.headline)
                Text("No data").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inlineView: some View {
        Group {
            if let goal = entry.goal {
                let icon = isDerailed ? "💀" : (goal.safebuf <= 0 ? "🔴" : "🐝")
                if isDerailed {
                    Text("\(icon) \(goal.title): Derailed!")
                } else {
                    Text("\(icon) \(goal.title): ") + Text(goal.losedate, style: .relative)
                }
            } else {
                Text("🐝 Goal \(entry.goalIndex + 1)")
            }
        }
    }

    private var cornerView: some View {
        let isUrgent = (entry.goal?.safebuf ?? 0) <= 0 || isDerailed
        return Text(entry.goal.map { isDerailed ? "💀" : "\($0.safebuf)" } ?? "?")
            .font(.system(.title, design: .rounded, weight: .bold))
            .foregroundStyle(isUrgent ? .red : .primary)
            .widgetCurvesContent()
            .widgetLabel {
                if let goal = entry.goal {
                    Gauge(value: Double(min(goal.safebuf, 7)), in: 0...7) {
                        Label(goal.title, systemImage: "target")
                    }
                    .tint(goal.safebuf <= 0 || isDerailed ? .red : (goal.safebuf <= 1 ? .orange : .green))
                } else {
                    Label("Goal \(entry.goalIndex + 1)", systemImage: "target")
                }
            }
    }
}

// MARK: - Placeholder helper

private func placeholderSnapshot(title: String, safebuf: Int, daysAhead: Int) -> GoalSnapshot {
    GoalSnapshot(
        slug: title.lowercased(),
        title: title,
        safebuf: safebuf,
        losedate: Date().addingTimeInterval(TimeInterval(daysAhead) * 24 * 3600),
        needText: nil
    )
}

// MARK: - 2. GOAL 1 (Most Urgent)

struct Goal1Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: placeholderSnapshot(title: "Goal 1", safebuf: 3, daysAhead: 3), goalIndex: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 0)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 0)
            completion(buildTimeline(for: entry))
        }
    }
}

struct Goal1Complication: Widget {
    let kind = "Goal1"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Goal1Provider()) { entry in
            GoalComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(cachedGoalName(at: 0))
        .description("Most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 3. GOAL 2

struct Goal2Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: placeholderSnapshot(title: "Goal 2", safebuf: 5, daysAhead: 5), goalIndex: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 1)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 1)
            completion(buildTimeline(for: entry))
        }
    }
}

struct Goal2Complication: Widget {
    let kind = "Goal2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Goal2Provider()) { entry in
            GoalComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(cachedGoalName(at: 1))
        .description("2nd most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 4. GOAL 3

struct Goal3Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: placeholderSnapshot(title: "Goal 3", safebuf: 7, daysAhead: 7), goalIndex: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 2)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 2)
            completion(buildTimeline(for: entry))
        }
    }
}

struct Goal3Complication: Widget {
    let kind = "Goal3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Goal3Provider()) { entry in
            GoalComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(cachedGoalName(at: 2))
        .description("3rd most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 5. GOAL 4

struct Goal4Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: placeholderSnapshot(title: "Goal 4", safebuf: 10, daysAhead: 10), goalIndex: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 3)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 3)
            completion(buildTimeline(for: entry))
        }
    }
}

struct Goal4Complication: Widget {
    let kind = "Goal4"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Goal4Provider()) { entry in
            GoalComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(cachedGoalName(at: 3))
        .description("4th most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 6. GOAL 5

struct Goal5Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: placeholderSnapshot(title: "Goal 5", safebuf: 14, daysAhead: 14), goalIndex: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 4)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let entry = await fetchGoalEntry(at: 4)
            completion(buildTimeline(for: entry))
        }
    }
}

struct Goal5Complication: Widget {
    let kind = "Goal5"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Goal5Provider()) { entry in
            GoalComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(cachedGoalName(at: 4))
        .description("5th most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 7. MOST URGENT GOAL (Dynamic)

struct MostUrgentProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(
            date: Date(),
            goal: GoalSnapshot(
                slug: "urgent",
                title: "Most Urgent",
                safebuf: 0,
                losedate: Date().addingTimeInterval(3600),
                needText: nil
            ),
            goalIndex: -1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        Task {
            let entry = await fetchMostUrgentGoalEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let entry = await fetchMostUrgentGoalEntry()
            completion(buildTimeline(for: entry))
        }
    }
}

struct MostUrgentComplication: Widget {
    let kind = "MostUrgent"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MostUrgentProvider()) { entry in
            GoalComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Most Urgent Goal")
        .description("Always shows the goal closest to derailing")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
