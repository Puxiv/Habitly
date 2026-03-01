import Foundation

extension Calendar {
    /// Returns all dates (as startOfDay) between two dates (inclusive) that match the given frequency.
    func scheduledDates(from start: Date, through end: Date, frequency: Frequency) -> [Date] {
        var result: [Date] = []
        var current = startOfDay(for: start)
        let endDay = startOfDay(for: end)
        while current <= endDay {
            if frequency.isScheduled(on: current) {
                result.append(current)
            }
            guard let next = self.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    /// Returns the count of scheduled days between two dates (inclusive).
    func scheduledDayCount(from start: Date, through end: Date, frequency: Frequency) -> Int {
        scheduledDates(from: start, through: end, frequency: frequency).count
    }
}
