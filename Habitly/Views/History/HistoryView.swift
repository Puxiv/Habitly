import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    let habit: Habit

    private var accentColor: Color { Color(hex: habit.accentColorHex) }

    /// Dates on which this habit was fully completed (count >= dailyTarget for multi-count).
    private var completedDates: Set<Date> {
        Set(habit.entries.compactMap { entry in
            if habit.allowsMultiple {
                return entry.count >= habit.dailyTarget ? entry.date : nil
            } else {
                return entry.date
            }
        })
    }

    private var viewModel: HabitsViewModel {
        HabitsViewModel(modelContext: modelContext)
    }

    private var months: [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<6).compactMap {
            calendar.date(byAdding: .month, value: -$0, to: today)
        }.reversed()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statsHeader
                Divider()
                ForEach(months, id: \.self) { month in
                    CalendarGridView(
                        month: month,
                        completedDates: completedDates,
                        isScheduled: { habit.frequency.isScheduled(on: $0) },
                        accentColor: accentColor
                    )
                }
            }
            .padding()
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(label: lang.streakLabel,
                     value: "\(viewModel.currentStreak(for: habit))",
                     icon: "🔥")
            Divider().frame(height: 44)
            statCell(label: lang.bestLabel,
                     value: "\(viewModel.bestStreak(for: habit))",
                     icon: "🏆")
            Divider().frame(height: 44)
            if habit.allowsMultiple {
                statCell(label: lang.todayLabel,
                         value: "\(viewModel.countToday(habit))/\(habit.dailyTarget)",
                         icon: "💧")
            } else {
                statCell(label: lang.thirtyDays,
                         value: "\(Int(viewModel.completionRate(for: habit) * 100))%",
                         icon: "📊")
            }
        }
        .padding(.vertical, 12)
        .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.title2)
            Text(value).font(.title3.bold()).foregroundStyle(accentColor)
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
