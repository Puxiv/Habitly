import SwiftData
import Foundation
import UIKit

@Model
final class StuffItem {
    var id: UUID
    var title: String
    var emoji: String
    var note: String
    var categoryRaw: String
    var rating: Int
    @Attribute(.externalStorage) var imageData: Data?
    var bodyData: Data?
    var isPinned: Bool = false
    var isArchived: Bool
    var createdAt: Date

    // MARK: - Computed (legacy — kept for data compat)

    var category: StuffCategory {
        get { StuffCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: - Rich Text Helpers

    var attributedBody: NSAttributedString? {
        get {
            guard let data = bodyData,
                  let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
            unarchiver.requiresSecureCoding = false
            let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
            unarchiver.finishDecoding()
            return result
        }
        set {
            if let attr = newValue {
                bodyData = try? NSKeyedArchiver.archivedData(
                    withRootObject: attr, requiringSecureCoding: false
                )
                note = attr.string // keep plain text in sync
            } else {
                bodyData = nil
            }
        }
    }

    var plainTextBody: String {
        attributedBody?.string ?? note
    }

    // MARK: - Init

    init(
        title: String,
        emoji: String = "📝",
        note: String = "",
        category: StuffCategory = .other,
        rating: Int = 3,
        imageData: Data? = nil,
        bodyData: Data? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.emoji = emoji
        self.note = note
        self.categoryRaw = category.rawValue
        self.rating = rating
        self.imageData = imageData
        self.bodyData = bodyData
        self.isPinned = isPinned
        self.isArchived = false
        self.createdAt = Date()
    }
}
