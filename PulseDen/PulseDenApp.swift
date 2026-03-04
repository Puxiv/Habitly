import SwiftUI
import SwiftData

@main
struct PulseDenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .environment(LanguageManager.shared)
                .environment(WeatherViewModel.shared)
                .environment(ChatViewModel.shared)
                .environment(HealthViewModel.shared)
                .environment(StocksViewModel.shared)
                .environment(NewsViewModel.shared)
                .task {
                    // Request notification permission early so the first toggle in-app
                    // triggers the system prompt rather than silently failing.
                    await NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(for: [Habit.self, HabitEntry.self, Reminder.self, StuffItem.self])
    }
}
