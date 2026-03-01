import SwiftData
import Foundation

@Model
final class StuffItem {
    var id: UUID
    var title: String
    var emoji: String
    var note: String
    var categoryRaw: String
    var rating: Int
    @Attribute(.externalStorage) var imageData: Data?
    var isArchived: Bool
    var createdAt: Date

    // MARK: - Computed

    var category: StuffCategory {
        get { StuffCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        title: String,
        emoji: String = "📌",
        note: String = "",
        category: StuffCategory = .other,
        rating: Int = 3,
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.emoji = emoji
        self.note = note
        self.categoryRaw = category.rawValue
        self.rating = rating
        self.imageData = imageData
        self.isArchived = false
        self.createdAt = Date()
    }
}
