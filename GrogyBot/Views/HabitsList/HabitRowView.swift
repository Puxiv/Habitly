import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    @Bindable var viewModel: HabitsViewModel
    @Environment(LanguageManager.self) var lang

    private var accentColor: Color { Color(hex: habit.accentColorHex) }
    private var isCompleted: Bool { viewModel.isCompletedToday(habit) }
    private var streak: Int { viewModel.currentStreak(for: habit) }

    var body: some View {
        HStack(spacing: 12) {
            // Name + streak
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(habit.frequency.displayName(language: lang.current))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StreakBadgeView(count: streak, color: accentColor)
                }
            }

            Spacer()

            // Single vs. multi-count control
            if habit.allowsMultiple {
                multiCounter
            } else {
                singleToggle
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Single toggle (checkmark)

    private var singleToggle: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                viewModel.toggleToday(habit)
            }
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompleted ? accentColor : Color(.tertiaryLabel))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Multi-count counter  [-]  3/8  [+]

    private var multiCounter: some View {
        let count  = viewModel.countToday(habit)
        let target = habit.dailyTarget
        let done   = count >= target

        return HStack(spacing: 6) {
            // Minus
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.decrementToday(habit)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(count > 0 ? accentColor : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
            .disabled(count == 0)

            // Count / target
            VStack(spacing: 0) {
                Text("\(count)")
                    .font(.callout.bold())
                    .foregroundStyle(done ? accentColor : .primary)
                Text("/\(target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 30)

            // Plus
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.incrementToday(habit)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
        }
    }
}
