import WidgetKit
import SwiftUI

struct GoalEntry: TimelineEntry {
    let date: Date
    let goal: GoalSnapshot?
    let configuration: ConfigurationAppIntent
}

struct GoalSnapshot {
    let slug: String
    let title: String
    let safebuf: Int
    let timeRemaining: String
    let baremin: String?

    var urgencyColor: Color {
        if safebuf <= 0 {
            return .red
        } else if safebuf == 1 {
            return .orange
        } else if safebuf <= 3 {
            return .blue
        } else {
            return .green
        }
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(
            date: Date(),
            goal: GoalSnapshot(
                slug: "exercise",
                title: "Exercise",
                safebuf: 2,
                timeRemaining: "2d 5h",
                baremin: "+1 today"
            ),
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> GoalEntry {
        await getEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<GoalEntry> {
        let entry = await getEntry(configuration: configuration)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        [AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "Most Urgent Goal")]
    }

    private func getEntry(configuration: ConfigurationAppIntent) async -> GoalEntry {
        guard UserSettings.shared.isConfigured else {
            return GoalEntry(date: Date(), goal: nil, configuration: configuration)
        }

        do {
            let goals = try await BeeminderAPI.shared.fetchGoals()
            if let firstGoal = goals.first {
                let snapshot = GoalSnapshot(
                    slug: firstGoal.slug,
                    title: firstGoal.title,
                    safebuf: firstGoal.safebuf ?? 0,
                    timeRemaining: formatTimeRemaining(losedate: firstGoal.losedate ?? 0),
                    baremin: firstGoal.baremin
                )
                return GoalEntry(date: Date(), goal: snapshot, configuration: configuration)
            }
        } catch {
            print("Failed to fetch goals for complication: \(error)")
        }

        return GoalEntry(date: Date(), goal: nil, configuration: configuration)
    }

    private func formatTimeRemaining(losedate: Double) -> String {
        let date = Date(timeIntervalSince1970: losedate)
        let interval = date.timeIntervalSince(Date())

        if interval <= 0 {
            return "Now!"
        }

        let hours = Int(interval / 3600)
        let days = hours / 24
        let remainingHours = hours % 24

        if days > 0 {
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        } else {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        }
    }
}

import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "BeeWatch Goal"
    static var description = IntentDescription("Shows your most urgent Beeminder goal")
}

struct BeeWatchComplicationEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            if let goal = entry.goal {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(goal.safebuf)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(goal.urgencyColor)
                    Text("days")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            } else {
                AccessoryWidgetBackground()
                Image(systemName: "target")
                    .font(.title2)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let goal = entry.goal {
                HStack {
                    Circle()
                        .fill(goal.urgencyColor)
                        .frame(width: 8, height: 8)
                    Text(goal.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(goal.timeRemaining)
                    .font(.caption)
                    .foregroundColor(goal.urgencyColor)

                if let baremin = goal.baremin {
                    Text(baremin)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("BeeWatch")
                    .font(.headline)
                Text("Set up API key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cornerView: some View {
        Group {
            if let goal = entry.goal {
                Text("\(goal.safebuf)d")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(goal.urgencyColor)
                    .widgetCurvesContent()
            } else {
                Image(systemName: "target")
            }
        }
    }

    private var inlineView: some View {
        Group {
            if let goal = entry.goal {
                Text("\(goal.title): \(goal.timeRemaining)")
            } else {
                Text("BeeWatch")
            }
        }
    }
}

struct BeeWatchComplication: Widget {
    let kind: String = "BeeWatchComplication"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            BeeWatchComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("BeeWatch")
        .description("Shows your most urgent Beeminder goal")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryRectangular) {
    BeeWatchComplication()
} timeline: {
    GoalEntry(
        date: Date(),
        goal: GoalSnapshot(
            slug: "exercise",
            title: "Exercise",
            safebuf: 2,
            timeRemaining: "2d 5h",
            baremin: "+1 today"
        ),
        configuration: ConfigurationAppIntent()
    )
    GoalEntry(
        date: Date(),
        goal: GoalSnapshot(
            slug: "reading",
            title: "Reading",
            safebuf: 0,
            timeRemaining: "3h 20m",
            baremin: "+30 pages"
        ),
        configuration: ConfigurationAppIntent()
    )
}
