import SwiftUI
import SwiftData

@main
struct GrogyBotApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Habit.self, HabitEntry.self, Reminder.self, StuffItem.self])
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            // Migration failed — delete the old store and recreate
            print("[GrogyBot] ModelContainer migration failed: \(error). Recreating store.")
            let config = ModelConfiguration()
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            // Also remove external-storage and journal files
            let storePath = storeURL.path()
            try? FileManager.default.removeItem(atPath: storePath + "-wal")
            try? FileManager.default.removeItem(atPath: storePath + "-shm")
            let externalDir = storeURL.deletingLastPathComponent().appendingPathComponent(".default_SUPPORT")
            try? FileManager.default.removeItem(at: externalDir)
            modelContainer = try! ModelContainer(for: schema)
        }
    }

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
        .modelContainer(modelContainer)
    }
}
