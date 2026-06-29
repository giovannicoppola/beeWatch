import Foundation
import SwiftData

@Model
final class Goal: Identifiable, Hashable {
    // Equality and hash are keyed on `slug` only. The slug is the stable identity
    // of a goal; other fields (safebuf, losedate, baremin) change on every refresh
    // and including them breaks NavigationStack/SwiftUI diffing after refresh.
    static func == (lhs: Goal, rhs: Goal) -> Bool {
        lhs.slug == rhs.slug
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(slug)
    }

    @Attribute(.unique) var slug: String
    var title: String
    var goalType: String
    var goaldate: Date?
    var goalval: Double?
    var rate: Double
    var runits: String
    var pledge: Double
    var safebuf: Int
    var losedate: Date
    var lastUpdated: Date
    var thumbUrl: String?
    var graphUrl: String?
    var yaw: Int
    var limsum: String?
    var baremin: String?
    // True while Beeminder is recomputing this goal's stats. When true,
    // safebuf / losedate / baremin / limsum should be treated as stale.
    var queued: Bool = false
    // Server-side modification timestamp (unix seconds). Used to detect when
    // an async recompute has actually finished.
    var updatedAt: Double = 0
    // Absolute y-axis value the goal needs to reach for one more safe day.
    // For kyoom (cumulative) goals this is the running total to reach, NOT
    // the value to enter as a single datapoint. Use `amountNeededToday` for
    // the actual delta the user should enter.
    var safebump: Double?
    // Most recent datapoint value (cumulative total for kyoom, latest reading
    // otherwise). Needed to convert `safebump` into a usable delta.
    var curval: Double?
    // True for cumulative / auto-summing goals (Do More, Do Less).
    var kyoom: Bool = false
    // Human-readable delta text, e.g. "+1 within 2 days".
    var deltaText: String?
    // When true, the app has just submitted a datapoint and the server-reported
    // stats have not yet been confirmed fresh. UI should avoid rendering
    // alarming states (skull, red) based on the potentially stale values.
    var isOptimisticallyRefreshed: Bool = false

    var id: String { slug }

    init(slug: String, title: String, goalType: String = "", rate: Double = 0, runits: String = "d", pledge: Double = 0, safebuf: Int = 0, losedate: Date = Date(), yaw: Int = 1) {
        self.slug = slug
        self.title = title
        self.goalType = goalType
        self.rate = rate
        self.runits = runits
        self.pledge = pledge
        self.safebuf = safebuf
        self.losedate = losedate
        self.lastUpdated = Date()
        self.yaw = yaw
    }

    /// True if this goal has *definitely* derailed according to the freshest
    /// server data we have. Returns false while we're waiting for a recompute
    /// to avoid flashing 💀 during the async Beeminder stats update.
    var isDerailed: Bool {
        if isOptimisticallyRefreshed || queued { return false }
        if safebuf < 0 { return true }
        return losedate.timeIntervalSince(Date()) <= 0
    }

    var urgencyColor: UrgencyLevel {
        if isOptimisticallyRefreshed || queued {
            // Optimistically treat as safe while server is recomputing.
            return safebuf >= 3 ? .green : .blue
        }
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

    var timeRemaining: String {
        let now = Date()
        let interval = losedate.timeIntervalSince(now)

        if interval <= 0 {
            return isOptimisticallyRefreshed || queued ? "Updating…" : "Derailed!"
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

    var formattedRate: String {
        let rateStr = rate.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rate)) : String(format: "%.1f", rate)
        return "\(rateStr)/\(runits)"
    }

    /// The best "how much do I need" string to display: prefer the explicit
    /// `limsum`/`delta_text` if present (these are what Beeminder itself shows
    /// on the web UI), falling back to `baremin`.
    var needText: String? {
        if let limsum, !limsum.isEmpty { return limsum }
        if let deltaText, !deltaText.isEmpty { return deltaText }
        if let baremin, !baremin.isEmpty { return baremin }
        return nil
    }

    /// Numeric amount the user should enter today as a single datapoint to
    /// gain one more safe day. Returns `nil` when we can't compute it (missing
    /// `safebump` or `curval`, or the goal is already safe so the answer is
    /// not "today"). Result is positive for "do more"-style goals, negative
    /// for "do less"-style goals.
    ///
    /// `safebump` is the absolute y-axis value the cumulative graph needs to
    /// reach; for kyoom (cumulative) goals you must subtract the current
    /// running total (`curval`) to get the delta that should be entered.
    /// For non-kyoom goals (e.g. weight), the user enters absolute readings,
    /// so the delta vs the current reading is also `safebump - curval`.
    var amountNeededToday: Double? {
        guard let safebump, let curval else { return nil }
        let delta = safebump - curval
        // If the goal isn't due today (safebuf > 0), this isn't a "today"
        // ask and the number would be misleading.
        guard safebuf <= 0 else { return nil }
        // Filter out absurd values (sometimes the server can transiently
        // return mismatched safebump/curval during recompute).
        if delta.magnitude > 1_000_000 { return nil }
        return delta
    }
}

enum UrgencyLevel {
    case red, orange, blue, green
}
