import SwiftData
import Foundation

@Model
final class Habit {
    var id: UUID
    var name: String
    var emoji: String
    /// Accent color stored as "#RRGGBB" hex string.
    var accentColorHex: String
    /// `Frequency` enum JSON-encoded here because SwiftData cannot persist
    /// enums with associated values directly.
    var frequencyJSON: String
    var createdAt: Date
    var sortOrder: Int
    /// If true, this habit can be logged multiple times per day.
    var allowsMultiple: Bool = false
    /// The daily target count. Only meaningful when allowsMultiple is true.
    var dailyTarget: Int = 8
    /// Whether a daily local notification is scheduled for this habit.
    var notificationsEnabled: Bool = false
    /// The time-of-day at which the notification fires (only hour/minute are used).
    var notificationTime: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry]

    /// Transient computed property for convenient access.
    var frequency: Frequency {
        get {
            guard
                let data = frequencyJSON.data(using: .utf8),
                let decoded = try? JSONDecoder().decode(Frequency.self, from: data)
            else { return .daily }
            return decoded
        }
        set {
            let encoded = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) }
            frequencyJSON = encoded ?? "{}"
        }
    }

    init(
        name: String,
        emoji: String = "✅",
        accentColorHex: String = "#007AFF",
        frequency: Frequency = .daily,
        sortOrder: Int = 0,
        allowsMultiple: Bool = false,
        dailyTarget: Int = 8,
        notificationsEnabled: Bool = false,
        notificationTime: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.accentColorHex = accentColorHex
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.allowsMultiple = allowsMultiple
        self.dailyTarget = dailyTarget
        self.notificationsEnabled = notificationsEnabled
        // Default notification time: 9:00 AM today
        self.notificationTime = notificationTime
            ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            ?? Date()
        self.entries = []
        let encoded = (try? JSONEncoder().encode(frequency)).flatMap { String(data: $0, encoding: .utf8) }
        self.frequencyJSON = encoded ?? "{}"
    }
}
