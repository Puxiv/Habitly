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

            SettingsView()
                .tabItem {
                    Label(lang.settings, systemImage: "slider.horizontal.3")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitEntry.self, Reminder.self, StuffItem.self], inMemory: true)
        .environment(LanguageManager.shared)
}
