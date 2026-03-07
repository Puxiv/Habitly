import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    private var statsViewModel: StatisticsViewModel {
        StatisticsViewModel(modelContext: modelContext)
    }
    private var habitsViewModel: HabitsViewModel {
        HabitsViewModel(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if habits.isEmpty {
                        emptyState
                    } else {
                        overallCard
                        habitsList
                    }
                }
                .padding()
            }
            .navigationTitle(lang.statsNavTitle)
        }
    }

    private var overallCard: some View {
        let rate = statsViewModel.overallCompletionRate(habits: habits)
        return VStack(spacing: 8) {
            Text(lang.statsLast30)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(Int(rate * 100))%")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.cardElevated)
                        .frame(height: 10)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * rate, height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var habitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.statsPerHabit)
                .font(.headline)

            ForEach(habits) { habit in
                habitRow(habit)
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let rate = statsViewModel.completionRate(for: habit)
        let accent = Color(hex: habit.accentColorHex)
        let streak = habitsViewModel.currentStreak(for: habit)
        let best = habitsViewModel.bestStreak(for: habit)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(habit.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(rate * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.cardElevated)
                        .frame(height: 8)
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * rate, height: 8)
                }
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                Label(lang.dayStreak(streak), systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(lang.bestStreak(best), systemImage: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(lang.statsEmptyTitle)
                .font(.headline)
            Text(lang.statsEmptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: Habit.self, inMemory: true)
        .environment(LanguageManager.shared)
}
