import SwiftUI

struct CalendarGridView: View {
    let month: Date
    let completedDates: Set<Date>
    let isScheduled: (Date) -> Bool
    let accentColor: Color

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let daySymbols = Calendar.current.veryShortWeekdaySymbols

    private var monthTitle: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    private var days: [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var result: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                result.append(calendar.startOfDay(for: date))
            }
        }
        return result
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Weekday header
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daySymbols.indices, id: \.self) { index in
                    Text(daySymbols[index])
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let completed = completedDates.contains(date)
        let scheduled = isScheduled(date)
        let isFuture = date > today
        let isMissed = scheduled && !completed && !isFuture && date != today
        let dayNumber = calendar.component(.day, from: date)

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(cellBackground(completed: completed, isMissed: isMissed, isFuture: isFuture, scheduled: scheduled))
                .frame(height: 32)

            Text("\(dayNumber)")
                .font(.caption2.weight(date == today ? .bold : .regular))
                .foregroundStyle(cellForeground(completed: completed, isMissed: isMissed, isFuture: isFuture))
        }
    }

    private func cellBackground(completed: Bool, isMissed: Bool, isFuture: Bool, scheduled: Bool) -> Color {
        if completed { return accentColor }
        if isMissed { return Theme.cardElevated }
        return Color.clear
    }

    private func cellForeground(completed: Bool, isMissed: Bool, isFuture: Bool) -> Color {
        if completed { return .white }
        if isMissed { return Color(.tertiaryLabel) }
        if isFuture { return Color(.tertiaryLabel) }
        return .primary
    }
}
