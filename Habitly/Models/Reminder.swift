import SwiftData
import Foundation

@Model
final class Reminder {
    var id: UUID
    var title: String
    var emoji: String
    var note: String
    var dateTime: Date
    var repeatJSON: String
    var isCompleted: Bool
    var createdAt: Date

    // MARK: - Computed

    var repeatOption: ReminderRepeat {
        get {
            guard let data = repeatJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(ReminderRepeat.self, from: data)
            else { return .once }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                repeatJSON = json
            }
        }
    }

    var state: ReminderState {
        if isCompleted { return .completed }
        if dateTime < Date() { return .overdue }
        return .upcoming
    }

    // MARK: - Init

    init(
        title: String,
        emoji: String = "🔔",
        note: String = "",
        dateTime: Date,
        repeatOption: ReminderRepeat = .once
    ) {
        self.id = UUID()
        self.title = title
        self.emoji = emoji
        self.note = note
        self.dateTime = dateTime
        self.isCompleted = false
        self.createdAt = Date()
        if let data = try? JSONEncoder().encode(repeatOption),
           let json = String(data: data, encoding: .utf8) {
            self.repeatJSON = json
        } else {
            self.repeatJSON = "\"once\""
        }
    }
}

enum ReminderState {
    case upcoming, overdue, completed
}
