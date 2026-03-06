import SwiftData
import SwiftUI
import Observation

@MainActor
@Observable
final class HabitsViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Helpers

    private func entry(for habit: Habit, on day: Date) -> HabitEntry? {
        habit.entries.first { $0.date == day }
    }

    func isCompleted(_ habit: Habit, on day: Date) -> Bool {
        guard let e = entry(for: habit, on: day) else { return false }
        return habit.allowsMultiple ? e.count >= habit.dailyTarget : true
    }

    // MARK: - Today's Status

    func isCompletedToday(_ habit: Habit) -> Bool {
        isCompleted(habit, on: Calendar.current.startOfDay(for: Date()))
    }

    func countToday(_ habit: Habit) -> Int {
        entry(for: habit, on: Calendar.current.startOfDay(for: Date()))?.count ?? 0
    }

    // MARK: - Toggling / Incrementing

    func toggleToday(_ habit: Habit) {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = entry(for: habit, on: today) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(HabitEntry(date: today, habit: habit))
        }
        try? modelContext.save()
    }

    func incrementToday(_ habit: Habit) {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = entry(for: habit, on: today) {
            existing.count += 1
        } else {
            modelContext.insert(HabitEntry(date: today, habit: habit, count: 1))
        }
        try? modelContext.save()
    }

    func decrementToday(_ habit: Habit) {
        let today = Calendar.current.startOfDay(for: Date())
        guard let existing = entry(for: habit, on: today) else { return }
        if existing.count <= 1 {
            modelContext.delete(existing)
        } else {
            existing.count -= 1
        }
        try? modelContext.save()
    }

    // MARK: - Streak Calculation

    func currentStreak(for habit: Habit) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        var streak = 0
        var date = today

        while date >= Calendar.current.startOfDay(for: habit.createdAt) {
            if habit.frequency.isScheduled(on: date) {
                if isCompleted(habit, on: date) {
                    streak += 1
                } else if date == today {
                    // partial day — don't break streak
                } else {
                    break
                }
            }
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    func bestStreak(for habit: Habit) -> Int {
        let start = Calendar.current.startOfDay(for: habit.createdAt)
        let end   = Calendar.current.startOfDay(for: Date())
        let scheduled = Calendar.current.scheduledDates(from: start, through: end, frequency: habit.frequency)
        guard !scheduled.isEmpty else { return 0 }

        var best = 0, current = 0
        for day in scheduled {
            if isCompleted(habit, on: day) {
                current += 1
                best = max(best, current)
            } else if day < Calendar.current.startOfDay(for: Date()) {
                current = 0
            }
        }
        return best
    }

    // MARK: - Habit CRUD

    func addHabit(name: String, emoji: String, accentColorHex: String,
                  frequency: Frequency, sortOrder: Int,
                  allowsMultiple: Bool, dailyTarget: Int,
                  notificationsEnabled: Bool = false, notificationTime: Date? = nil) {
        let habit = Habit(
            name: name, emoji: emoji, accentColorHex: accentColorHex,
            frequency: frequency, sortOrder: sortOrder,
            allowsMultiple: allowsMultiple, dailyTarget: dailyTarget,
            notificationsEnabled: notificationsEnabled, notificationTime: notificationTime
        )
        modelContext.insert(habit)
        try? modelContext.save()
        NotificationManager.shared.schedule(for: habit)
    }

    func deleteHabit(_ habit: Habit) {
        NotificationManager.shared.cancel(for: habit)
        modelContext.delete(habit)
        try? modelContext.save()
    }

    func saveHabit(_ habit: Habit, name: String, emoji: String,
                   accentColorHex: String, frequency: Frequency,
                   allowsMultiple: Bool, dailyTarget: Int,
                   notificationsEnabled: Bool, notificationTime: Date) {
        habit.name = name
        habit.emoji = emoji
        habit.accentColorHex = accentColorHex
        habit.frequency = frequency
        habit.allowsMultiple = allowsMultiple
        habit.dailyTarget = dailyTarget
        habit.notificationsEnabled = notificationsEnabled
        habit.notificationTime = notificationTime
        try? modelContext.save()
        NotificationManager.shared.schedule(for: habit)
    }

    // MARK: - Completion Rate

    func completionRate(for habit: Habit, days: Int = 30) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        guard let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: today) else { return 0 }
        let effectiveStart = max(start, Calendar.current.startOfDay(for: habit.createdAt))
        let scheduled = Calendar.current.scheduledDates(from: effectiveStart, through: today, frequency: habit.frequency)
        guard !scheduled.isEmpty else { return 0 }
        let completed = scheduled.filter { isCompleted(habit, on: $0) }.count
        return Double(completed) / Double(scheduled.count)
    }
}
