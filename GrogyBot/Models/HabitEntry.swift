import SwiftData
import Foundation

@Model
final class HabitEntry {
    var id: UUID
    /// Always stored as startOfDay (midnight) for reliable equality checks.
    var date: Date
    /// Actual timestamp of the completion tap.
    var completedAt: Date
    /// Number of times completed on this day. Always 1 for single habits; 1+ for multi-count habits.
    var count: Int = 1

    var habit: Habit?

    init(date: Date, habit: Habit, count: Int = 1) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = Date()
        self.count = count
        self.habit = habit
    }
}
