import Foundation
import SwiftData

@Model
final class Goal: Identifiable, Hashable {
    static func == (lhs: Goal, rhs: Goal) -> Bool {
        lhs.slug == rhs.slug &&
        lhs.safebuf == rhs.safebuf &&
        lhs.losedate == rhs.losedate &&
        lhs.baremin == rhs.baremin
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(slug)
        hasher.combine(safebuf)
        hasher.combine(losedate)
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

    var isDerailed: Bool {
        losedate.timeIntervalSince(Date()) <= 0
    }

    var urgencyColor: UrgencyLevel {
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
            return "Derailed!"
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
}

enum UrgencyLevel {
    case red, orange, blue, green
}
