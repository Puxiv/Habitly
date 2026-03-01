import SwiftUI

struct ContentView: View {
    @Environment(LanguageManager.self) var lang
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label(lang.dashboardTab, systemImage: "house.fill")
                }
                .tag(0)

            HabitsListView()
                .tabItem {
                    Label(lang.habitsTab, systemImage: "checkmark.seal.fill")
                }
                .tag(1)

            RemindersListView()
                .tabItem {
                    Label(lang.remindersTab, systemImage: "bell.badge")
                }
                .tag(2)

            StuffListView()
                .tabItem {
                    Label(lang.stuffTab, systemImage: "bookmark.fill")
                }
                .tag(3)

            ChatView()
                .tabItem {
                    Label(lang.chatTab, systemImage: "bubble.left.and.text.bubble.right.fill")
                }
                .tag(4)

            HealthView()
                .tabItem {
                    Label(lang.healthTab, systemImage: "heart.fill")
                }
                .tag(5)

            WeatherView()
                .tabItem {
                    Label(lang.weatherTab, systemImage: "cloud.sun.fill")
                }
                .tag(6)

            SettingsView()
                .tabItem {
                    Label(lang.settings, systemImage: "slider.horizontal.3")
                }
                .tag(7)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitEntry.self, Reminder.self, StuffItem.self], inMemory: true)
        .environment(LanguageManager.shared)
}
