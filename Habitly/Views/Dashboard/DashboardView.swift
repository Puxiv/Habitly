import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Binding var selectedTab: Int

    @Query(sort: \Habit.sortOrder, order: .forward) private var habits: [Habit]
    @Query(sort: \Reminder.dateTime, order: .forward) private var reminders: [Reminder]
    @Query(sort: \StuffItem.createdAt, order: .reverse) private var stuffItems: [StuffItem]

    private var habitsVM: HabitsViewModel { HabitsViewModel(modelContext: modelContext) }
    private var remindersVM: RemindersViewModel { RemindersViewModel(modelContext: modelContext) }
    private var stuffVM: StuffViewModel { StuffViewModel(modelContext: modelContext) }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6:   return lang.greetingNight
        case 6..<12:  return lang.greetingMorning
        case 12..<17: return lang.greetingAfternoon
        case 17..<21: return lang.greetingEvening
        default:      return lang.greetingNight
        }
    }

    // MARK: - Habits Helpers

    private var scheduledToday: [Habit] {
        habits.filter { $0.frequency.isScheduled(on: Date()) }
    }

    private var completedToday: Int {
        scheduledToday.filter { habitsVM.isCompletedToday($0) }.count
    }

    private var topStreak: Int {
        habits.map { habitsVM.currentStreak(for: $0) }.max() ?? 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    gridCards
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        Button { selectedTab = 1 } label: {
            ZStack(alignment: .bottomTrailing) {
                // Gradient background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.75, blue: 0.65),
                                     Color(red: 0.20, green: 0.55, blue: 0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Decorative circle in top-right
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .offset(x: 40, y: -40)

                // Another smaller decorative circle
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 90, height: 90)
                    .offset(x: -20, y: 20)

                // Content
                VStack(alignment: .leading, spacing: 16) {
                    // Top row: icon + label
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                        Text(lang.dashHabitsTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }

                    if habits.isEmpty {
                        Text(lang.dashNoHabitsYet)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        // Big stat
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(completedToday)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("/ \(scheduledToday.count)")
                                .font(.title2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        HStack(spacing: 12) {
                            Text(lang.dashHabitsDone(completedToday, scheduledToday.count))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))

                            if topStreak > 0 {
                                HStack(spacing: 4) {
                                    Text("🔥")
                                        .font(.caption)
                                    Text("\(topStreak)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                    Text(lang.dashBestStreak)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid Cards

    private var gridCards: some View {
        let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

        return LazyVGrid(columns: columns, spacing: 14) {
            // Reminders — Upcoming
            gridCard(
                icon: "bell.badge",
                iconBg: Color.orange,
                title: lang.dashRemindersTitle,
                value: reminders.isEmpty ? "—" : "\(remindersVM.upcomingCount(from: reminders))",
                subtitle: reminders.isEmpty ? lang.dashNoRemindersYet : upcomingSubtitle,
                accentColor: .orange,
                tab: 2
            )

            // Reminders — Overdue
            gridCard(
                icon: "exclamationmark.triangle.fill",
                iconBg: Color.red,
                title: lang.remindersOverdue.replacingOccurrences(of: " 🔴", with: ""),
                value: "\(remindersVM.overdueCount(from: reminders))",
                subtitle: overdueSubtitle,
                accentColor: .red,
                tab: 2
            )

            // Stuff — Items
            gridCard(
                icon: "bookmark.fill",
                iconBg: Color.purple,
                title: lang.dashStuffTitle,
                value: stuffItems.isEmpty ? "—" : "\(stuffVM.activeCount(from: stuffItems))",
                subtitle: stuffItems.isEmpty ? lang.dashNoStuffYet : recentStuffSubtitle,
                accentColor: .purple,
                tab: 3
            )

            // Best Streak
            gridCard(
                icon: "flame.fill",
                iconBg: Color(red: 1.0, green: 0.45, blue: 0.2),
                title: lang.dashBestStreak,
                value: topStreak > 0 ? "\(topStreak)" : "—",
                subtitle: topStreak > 0 ? lang.streakLabel : lang.dashNoHabitsYet,
                accentColor: Color(red: 1.0, green: 0.45, blue: 0.2),
                tab: 1
            )
        }
    }

    // MARK: - Grid Card Component

    private func gridCard(icon: String, iconBg: Color, title: String,
                          value: String, subtitle: String, accentColor: Color,
                          tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(iconBg.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconBg)
                }

                // Title
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Big value
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                // Subtitle
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subtitle Helpers

    private var upcomingSubtitle: String {
        if let next = remindersVM.nextUpcoming(from: reminders) {
            return "\(next.emoji) \(next.title)"
        }
        return lang.dashUpcoming(remindersVM.upcomingCount(from: reminders))
    }

    private var overdueSubtitle: String {
        let count = remindersVM.overdueCount(from: reminders)
        if count == 0 { return "✅" }
        return lang.dashOverdue(count)
    }

    private var recentStuffSubtitle: String {
        let recent = stuffVM.recentItems(from: stuffItems, limit: 2)
        if recent.isEmpty { return lang.dashRecentlyAdded }
        return recent.map { "\($0.emoji) \($0.title)" }.joined(separator: ", ")
    }
}
