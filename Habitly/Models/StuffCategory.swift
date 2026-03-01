import Foundation

enum StuffCategory: String, Codable, CaseIterable {
    case recipe   = "recipe"
    case article  = "article"
    case idea     = "idea"
    case place    = "place"
    case product  = "product"
    case other    = "other"

    var emoji: String {
        switch self {
        case .recipe:  return "🍳"
        case .article: return "📰"
        case .idea:    return "💡"
        case .place:   return "📍"
        case .product: return "🛒"
        case .other:   return "📦"
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .recipe:
            switch language {
            case .english:      return "Recipe"
            case .bulgarian:    return "Рецепта"
            case .northwestern: return "Рецепта"
            case .shopluk:      return "Рецепта"
            }
        case .article:
            switch language {
            case .english:      return "Article"
            case .bulgarian:    return "Статия"
            case .northwestern: return "Статия"
            case .shopluk:      return "Статия"
            }
        case .idea:
            switch language {
            case .english:      return "Idea"
            case .bulgarian:    return "Идея"
            case .northwestern: return "Идея"
            case .shopluk:      return "Идея"
            }
        case .place:
            switch language {
            case .english:      return "Place"
            case .bulgarian:    return "Място"
            case .northwestern: return "Место"
            case .shopluk:      return "Место"
            }
        case .product:
            switch language {
            case .english:      return "Product"
            case .bulgarian:    return "Продукт"
            case .northwestern: return "Продукт"
            case .shopluk:      return "Продукт"
            }
        case .other:
            switch language {
            case .english:      return "Other"
            case .bulgarian:    return "Друго"
            case .northwestern: return "Друго"
            case .shopluk:      return "Друго"
            }
        }
    }
}
