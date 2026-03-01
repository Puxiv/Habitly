import SwiftData
import SwiftUI
import Observation

@MainActor
@Observable
final class StuffViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    func addItem(title: String, emoji: String, note: String,
                 category: StuffCategory, rating: Int, imageData: Data?) {
        let item = StuffItem(title: title, emoji: emoji, note: note,
                             category: category, rating: rating, imageData: imageData)
        modelContext.insert(item)
        try? modelContext.save()
    }

    func saveItem(_ item: StuffItem, title: String, emoji: String,
                  note: String, category: StuffCategory, rating: Int,
                  imageData: Data?) {
        item.title = title
        item.emoji = emoji
        item.note = note
        item.category = category
        item.rating = rating
        item.imageData = imageData
        try? modelContext.save()
    }

    func deleteItem(_ item: StuffItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    func toggleArchive(_ item: StuffItem) {
        item.isArchived.toggle()
        try? modelContext.save()
    }

    // MARK: - Dashboard Helpers

    func activeCount(from items: [StuffItem]) -> Int {
        items.filter { !$0.isArchived }.count
    }

    func recentItems(from items: [StuffItem], limit: Int = 3) -> [StuffItem] {
        Array(
            items.filter { !$0.isArchived }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
        )
    }
}
