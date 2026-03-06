import SwiftData
import SwiftUI
import Observation

@MainActor
@Observable
final class NotesViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    func addItem(title: String, emoji: String = "📝", note: String = "",
                 category: StuffCategory = .other, rating: Int = 3,
                 imageData: Data? = nil, bodyData: Data? = nil) {
        let item = StuffItem(title: title, emoji: emoji, note: note,
                             category: category, rating: rating,
                             imageData: imageData, bodyData: bodyData)
        modelContext.insert(item)
        try? modelContext.save()
    }

    func saveItem(_ item: StuffItem) {
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

    func togglePin(_ item: StuffItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }

    // MARK: - Dashboard Helpers

    func activeCount(from items: [StuffItem]) -> Int {
        items.filter { !$0.isArchived }.count
    }

    func recentItems(from items: [StuffItem], limit: Int = 3) -> [StuffItem] {
        Array(
            items.filter { !$0.isArchived }
                .sorted {
                    if $0.isPinned != $1.isPinned { return $0.isPinned }
                    return $0.createdAt > $1.createdAt
                }
                .prefix(limit)
        )
    }
}
