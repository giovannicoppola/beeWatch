import Foundation
import SwiftData

@Model
final class Datapoint: Identifiable {
    @Attribute(.unique) var datapointId: String
    var goalSlug: String
    var timestamp: Date
    var daystamp: String
    var value: Double
    var comment: String
    var updatedAt: Date
    var requestId: String?

    var id: String { datapointId }

    init(datapointId: String = UUID().uuidString, goalSlug: String, timestamp: Date = Date(), daystamp: String = "", value: Double, comment: String = "", requestId: String? = nil) {
        self.datapointId = datapointId
        self.goalSlug = goalSlug
        self.timestamp = timestamp
        self.daystamp = daystamp.isEmpty ? Datapoint.formatDaystamp(from: timestamp) : daystamp
        self.value = value
        self.comment = comment
        self.updatedAt = Date()
        self.requestId = requestId
    }

    static func formatDaystamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedValue: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.2f", value)
        }
    }
}

struct FrequentValue: Codable, Identifiable {
    var id: String { "\(goalSlug)-\(value)" }
    let goalSlug: String
    let value: Double
    var count: Int

    var formattedValue: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }
}
