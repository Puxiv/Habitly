import SwiftUI

struct ContentView: View {
    @Environment(LanguageManager.self) var lang
    @State private var selectedTab = 0
    @State private var showStartup = true

    var body: some View {
        ZStack {
            // Main app (always rendered, preloads while startup is visible)
            TabView(selection: $selectedTab) {
                DashboardView(selectedTab: $selectedTab)
                    .tabItem {
                        Label(lang.dashboardTab, systemImage: "house.fill")
                    }
                    .tag(0)

                if lang.moduleHabits {
                    HabitsListView()
                        .tabItem {
                            Label(lang.habitsTab, systemImage: "checkmark.seal.fill")
                        }
                        .tag(1)
                }

                if lang.moduleReminders {
                    RemindersListView()
                        .tabItem {
                            Label(lang.remindersTab, systemImage: "bell.badge")
                        }
                        .tag(2)
                }

                if lang.moduleNotes {
                    NotesListView()
                        .tabItem {
                            Label(lang.notesTab, systemImage: "note.text")
                        }
                        .tag(3)
                }

                ChatView()
                    .tabItem {
                        Label(lang.chatTab, systemImage: "bubble.left.and.text.bubble.right.fill")
                    }
                    .tag(4)

                if lang.moduleHealth {
                    HealthView()
                        .tabItem {
                            Label(lang.healthTab, systemImage: "heart.fill")
                        }
                        .tag(5)
                }

                if lang.moduleStocks {
                    StocksView()
                        .tabItem {
                            Label(lang.stocksTab, systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .tag(6)
                }

                if lang.moduleNews {
                    NewsView()
                        .tabItem {
                            Label(lang.newsTab, systemImage: "newspaper.fill")
                        }
                        .tag(7)
                }

                WeatherView()
                    .tabItem {
                        Label(lang.weatherTab, systemImage: "cloud.sun.fill")
                    }
                    .tag(8)

                SettingsView()
                    .tabItem {
                        Label(lang.settings, systemImage: "slider.horizontal.3")
                    }
                    .tag(9)
            }
            .tint(Theme.accent)

            // Startup overlay (shown every launch)
            if showStartup {
                StartupView(showStartup: $showStartup, selectedTab: $selectedTab)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitEntry.self, Reminder.self, StuffItem.self], inMemory: true)
        .environment(LanguageManager.shared)
}
