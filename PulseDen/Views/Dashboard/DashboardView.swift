import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Environment(WeatherViewModel.self) var weatherVM
    @Environment(HealthViewModel.self) var healthVM
    @Environment(StocksViewModel.self) var stocksVM
    @Environment(NewsViewModel.self) var newsVM
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
                VStack(spacing: 16) {
                    weatherCard
                    aiTeaserCard
                    gridCards
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle(greeting)
            .task {
                // Prefetch only enabled modules
                async let h: () = lang.moduleHealth ? prefetchHealth() : ()
                async let s: () = lang.moduleStocks ? prefetchStocks() : ()
                async let n: () = lang.moduleNews ? prefetchNews() : ()
                _ = await (h, s, n)
            }
        }
    }

    // MARK: - Prefetch Helpers

    private func prefetchHealth() async {
        guard healthVM.summary == nil else { return }
        if healthVM.isAuthorized {
            await healthVM.fetchAll()
        } else {
            await healthVM.requestAccess()
        }
    }

    private func prefetchStocks() async {
        guard stocksVM.quotes.isEmpty, !stocksVM.symbols.isEmpty else { return }
        await stocksVM.fetchAll()
    }

    private func prefetchNews() async {
        guard newsVM.worldNews.isEmpty, newsVM.bulgarianNews.isEmpty, newsVM.hasApiKey else { return }
        await newsVM.fetchAll()
    }

    // MARK: - Weather Card

    private var weatherCard: some View {
        Button { selectedTab = 8 } label: {
            HStack(spacing: 14) {
                Image(systemName: weatherVM.currentWeather?.condition.systemImage ?? "cloud.sun.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.dashWeatherTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)

                    if let w = weatherVM.currentWeather {
                        Text(w.temperatureText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(w.cityName + " · " + w.condition.displayName)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(weatherLoadLabel)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Theme.accent.opacity(0.12), lineWidth: 1)
            )
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

    // MARK: - AI Teaser Card

    private var aiTeaserCard: some View {
        Button { selectedTab = 4 } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.accent)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.dashAiTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text(ChatViewModel.randomPrompt(lang: lang))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Theme.accent.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid Cards

    private var gridCards: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            if lang.moduleReminders {
                gridCard(
                    icon: "bell.badge",
                    iconBg: Color.orange,
                    title: lang.dashRemindersTitle,
                    value: reminders.isEmpty ? "—" : "\(remindersVM.upcomingCount(from: reminders))",
                    subtitle: reminders.isEmpty ? lang.dashNoRemindersYet : upcomingSubtitle,
                    tab: 2
                )
            }

            if lang.moduleHabits {
                gridCard(
                    icon: "checkmark.seal.fill",
                    iconBg: Theme.accent,
                    title: lang.dashHabitsTitle,
                    value: habits.isEmpty ? "—" : "\(completedToday)/\(scheduledToday.count)",
                    subtitle: habits.isEmpty ? lang.dashNoHabitsYet : lang.dashHabitsDone(completedToday, scheduledToday.count),
                    tab: 1
                )
            }

            if lang.moduleStuff {
                gridCard(
                    icon: "bookmark.fill",
                    iconBg: Color.purple,
                    title: lang.dashStuffTitle,
                    value: stuffItems.isEmpty ? "—" : "\(stuffVM.activeCount(from: stuffItems))",
                    subtitle: stuffItems.isEmpty ? lang.dashNoStuffYet : recentStuffSubtitle,
                    tab: 3
                )
            }

            if lang.moduleHealth {
                gridCard(
                    icon: "heart.fill",
                    iconBg: Theme.negative,
                    title: lang.dashHealthTitle,
                    value: healthVM.dashboardValue,
                    subtitle: healthVM.dashboardSubtitle,
                    tab: 5
                )
            }

            if lang.moduleStocks {
                gridCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconBg: Theme.accent,
                    title: lang.dashStocksTitle,
                    value: stocksVM.dashboardValue,
                    subtitle: stocksVM.dashboardSubtitle,
                    tab: 6
                )
            }

            if lang.moduleNews {
                gridCard(
                    icon: "newspaper.fill",
                    iconBg: Color(red: 0.25, green: 0.48, blue: 0.85),
                    title: lang.dashNewsTitle,
                    value: newsVM.dashboardValue,
                    subtitle: newsVM.dashboardSubtitle,
                    tab: 7
                )
            }
        }
    }

    // MARK: - Grid Card Component

    private func gridCard(icon: String, iconBg: Color, title: String,
                          value: String, subtitle: String,
                          tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconBg.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconBg)
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
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
