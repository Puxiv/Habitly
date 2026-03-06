import SwiftData
import SwiftUI
import Observation

@MainActor
@Observable
final class StatisticsViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Overall completion rate across all habits for the last 30 days.
    func overallCompletionRate(habits: [Habit]) -> Double {
        guard !habits.isEmpty else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        guard let start = Calendar.current.date(byAdding: .day, value: -29, to: today) else { return 0 }

        var totalScheduled = 0
        var totalCompleted = 0

        for habit in habits {
            let effectiveStart = max(start, Calendar.current.startOfDay(for: habit.createdAt))
            let scheduled = Calendar.current.scheduledDates(from: effectiveStart, through: today, frequency: habit.frequency)
            let completedDays = Set(habit.entries.map { $0.date })
            totalScheduled += scheduled.count
            totalCompleted += scheduled.filter { completedDays.contains($0) }.count
        }

        guard totalScheduled > 0 else { return 0 }
        return Double(totalCompleted) / Double(totalScheduled)
    }

    func completionRate(for habit: Habit, days: Int = 30) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        guard let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: today) else { return 0 }
        let effectiveStart = max(start, Calendar.current.startOfDay(for: habit.createdAt))

        let scheduled = Calendar.current.scheduledDates(from: effectiveStart, through: today, frequency: habit.frequency)
        guard !scheduled.isEmpty else { return 0 }

        let completedDays = Set(habit.entries.map { $0.date })
        let completed = scheduled.filter { completedDays.contains($0) }.count
        return Double(completed) / Double(scheduled.count)
    }
}
