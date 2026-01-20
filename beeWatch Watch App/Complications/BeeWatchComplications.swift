import WidgetKit
import SwiftUI

// MARK: - Shared Types

struct GoalSnapshot {
    let slug: String
    let title: String
    let safebuf: Int
    let timeRemaining: String
    let baremin: String?
    let isDerailed: Bool
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

// MARK: - Shared Goal Fetching

func fetchGoalEntry(at index: Int) async -> GoalEntry {
    UserSettings.shared.reloadSettings()

    guard UserSettings.shared.isConfigured else {
        return GoalEntry(date: Date(), goal: nil, goalIndex: index)
    }

    do {
        let goals = try await BeeminderAPI.shared.fetchGoals()

        if let goal = goals[safe: index] {
            let losedate = goal.losedate ?? 0
            let snapshot = GoalSnapshot(
                slug: goal.slug,
                title: goal.title,
                safebuf: goal.safebuf ?? 0,
                timeRemaining: formatTime(losedate),
                baremin: goal.baremin,
                isDerailed: Date(timeIntervalSince1970: losedate) <= Date()
            )
            return GoalEntry(date: Date(), goal: snapshot, goalIndex: index)
        }
    } catch {}

    return GoalEntry(date: Date(), goal: nil, goalIndex: index)
}

func formatTime(_ losedate: Double) -> String {
    let interval = Date(timeIntervalSince1970: losedate).timeIntervalSince(Date())
    if interval <= 0 { return "Derailed!" }
    let hours = Int(interval / 3600)
    let days = hours / 24
    let remainingHours = hours % 24
    if days > 0 { return "\(days)d \(remainingHours)h" }
    if hours > 0 { return "\(hours)h" }
    return "\(Int(interval / 60))m"
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
        Gauge(value: Double(min(entry.goal?.safebuf ?? 0, 7)), in: 0...7) {
            Text("🐝")
        } currentValueLabel: {
            if let goal = entry.goal {
                Text(goal.isDerailed ? "💀" : "\(goal.safebuf)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
            } else {
                Text("?")
            }
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let goal = entry.goal {
                HStack {
                    Text(goal.isDerailed ? "💀" : "🐝")
                    Text(goal.title).font(.headline).lineLimit(1)
                }
                Text(goal.timeRemaining).font(.caption)
                if let baremin = goal.baremin {
                    Text(baremin).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
                Text("\(goal.isDerailed ? "💀" : "🐝") \(goal.title): \(goal.timeRemaining)")
            } else {
                Text("🐝 Goal \(entry.goalIndex + 1)")
            }
        }
    }

    private var cornerView: some View {
        Text(entry.goal.map { $0.isDerailed ? "💀" : "\($0.safebuf)" } ?? "?")
            .font(.system(.title, design: .rounded, weight: .bold))
            .widgetCurvesContent()
            .widgetLabel {
                if let goal = entry.goal {
                    Label(goal.title, systemImage: "target")
                } else {
                    Label("Goal \(entry.goalIndex + 1)", systemImage: "target")
                }
            }
    }
}

// MARK: - 2. GOAL 1 (Most Urgent)

struct Goal1Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: GoalSnapshot(
            slug: "goal1", title: "Goal 1", safebuf: 3,
            timeRemaining: "3d", baremin: nil, isDerailed: false
        ), goalIndex: 0)
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
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
        .configurationDisplayName("Goal #1")
        .description("Shows your most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 3. GOAL 2

struct Goal2Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: GoalSnapshot(
            slug: "goal2", title: "Goal 2", safebuf: 5,
            timeRemaining: "5d", baremin: nil, isDerailed: false
        ), goalIndex: 1)
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
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
        .configurationDisplayName("Goal #2")
        .description("Shows your 2nd most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 4. GOAL 3

struct Goal3Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: GoalSnapshot(
            slug: "goal3", title: "Goal 3", safebuf: 7,
            timeRemaining: "7d", baremin: nil, isDerailed: false
        ), goalIndex: 2)
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
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
        .configurationDisplayName("Goal #3")
        .description("Shows your 3rd most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 5. GOAL 4

struct Goal4Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: GoalSnapshot(
            slug: "goal4", title: "Goal 4", safebuf: 10,
            timeRemaining: "10d", baremin: nil, isDerailed: false
        ), goalIndex: 3)
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
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
        .configurationDisplayName("Goal #4")
        .description("Shows your 4th most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 6. GOAL 5

struct Goal5Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: GoalSnapshot(
            slug: "goal5", title: "Goal 5", safebuf: 14,
            timeRemaining: "14d", baremin: nil, isDerailed: false
        ), goalIndex: 4)
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
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
        .configurationDisplayName("Goal #5")
        .description("Shows your 5th most urgent goal")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
