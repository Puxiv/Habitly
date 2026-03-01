import SwiftUI
import SwiftData

@main
struct HabitlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(LanguageManager.shared)
                .environment(WeatherViewModel.shared)
                .task {
                    // Request notification permission early so the first toggle in-app
                    // triggers the system prompt rather than silently failing.
                    await NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(for: [Habit.self, HabitEntry.self, Reminder.self, StuffItem.self])
    }
}
