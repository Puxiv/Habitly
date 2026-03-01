import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Environment(WeatherViewModel.self) var weatherVM
    @Environment(HealthViewModel.self) var healthVM
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weatherCard
                    aiTeaserCard
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

    // MARK: - Weather Card

    private var weatherCard: some View {
        Button { selectedTab = 6 } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: weatherGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 100, height: 100)
                    .offset(x: 30, y: -30)

                HStack(spacing: 14) {
                    // Condition icon
                    Image(systemName: weatherVM.currentWeather?.condition.systemImage ?? "cloud.sun.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.9))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.dashWeatherTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))

                        if let w = weatherVM.currentWeather {
                            Text(w.temperatureText)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(w.cityName + " · " + w.condition.displayName)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            Text(weatherLoadLabel)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .frame(height: 88)
        }
        .buttonStyle(.plain)
        .task { await weatherVM.fetchWeather() }
    }

    private var weatherLoadLabel: String {
        switch weatherVM.loadState {
        case .loading: return lang.weatherLoading
        case .error:   return lang.weatherErrorTitle
        default:       return lang.dashWeatherTap
        }
    }

    private var weatherGradient: [Color] {
        guard let w = weatherVM.currentWeather else {
            return [Color(red: 0.25, green: 0.60, blue: 0.95),
                    Color(red: 0.15, green: 0.45, blue: 0.80)]
        }
        if !w.isDay {
            return [Color(red: 0.10, green: 0.10, blue: 0.30),
                    Color(red: 0.05, green: 0.05, blue: 0.20)]
        }
        switch w.condition {
        case .clearSky, .mainlyClear:
            return [Color(red: 0.25, green: 0.65, blue: 1.00),
                    Color(red: 0.10, green: 0.45, blue: 0.85)]
        case .partlyCloudy:
            return [Color(red: 0.40, green: 0.65, blue: 0.95),
                    Color(red: 0.30, green: 0.50, blue: 0.80)]
        case .overcast, .fog:
            return [Color(red: 0.50, green: 0.50, blue: 0.60),
                    Color(red: 0.35, green: 0.35, blue: 0.45)]
        case .drizzle, .rain:
            return [Color(red: 0.30, green: 0.40, blue: 0.60),
                    Color(red: 0.20, green: 0.30, blue: 0.50)]
        case .heavyRain, .thunderstorm:
            return [Color(red: 0.20, green: 0.25, blue: 0.40),
                    Color(red: 0.10, green: 0.15, blue: 0.30)]
        case .snow:
            return [Color(red: 0.65, green: 0.80, blue: 0.95),
                    Color(red: 0.50, green: 0.65, blue: 0.85)]
        case .unknown:
            return [Color(red: 0.45, green: 0.55, blue: 0.65),
                    Color(red: 0.35, green: 0.45, blue: 0.55)]
        }
    }

    // MARK: - AI Teaser Card

    private var aiTeaserCard: some View {
        Button { selectedTab = 4 } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.45, green: 0.40, blue: 0.90),
                                     Color(red: 0.60, green: 0.35, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 90, height: 90)
                    .offset(x: 25, y: -25)

                HStack(spacing: 14) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.9))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.dashAiTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(ChatViewModel.randomPrompt(lang: lang))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .frame(height: 80)
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

            // Habits
            gridCard(
                icon: "checkmark.seal.fill",
                iconBg: Color(red: 0.35, green: 0.75, blue: 0.65),
                title: lang.dashHabitsTitle,
                value: habits.isEmpty ? "—" : "\(completedToday)/\(scheduledToday.count)",
                subtitle: habits.isEmpty ? lang.dashNoHabitsYet : lang.dashHabitsDone(completedToday, scheduledToday.count),
                accentColor: Color(red: 0.35, green: 0.75, blue: 0.65),
                tab: 1
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

            // Health
            gridCard(
                icon: "heart.fill",
                iconBg: Color(red: 1.0, green: 0.30, blue: 0.35),
                title: lang.dashHealthTitle,
                value: healthVM.dashboardValue,
                subtitle: healthVM.dashboardSubtitle,
                accentColor: Color(red: 1.0, green: 0.30, blue: 0.35),
                tab: 5
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

    private var recentStuffSubtitle: String {
        let recent = stuffVM.recentItems(from: stuffItems, limit: 2)
        if recent.isEmpty { return lang.dashRecentlyAdded }
        return recent.map { "\($0.emoji) \($0.title)" }.joined(separator: ", ")
    }
}
