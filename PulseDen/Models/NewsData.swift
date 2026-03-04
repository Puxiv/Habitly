import Foundation

// MARK: - News Article (UI Model)

struct NewsArticle: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let url: String
    let imageURL: String?
    let publishedAt: Date
    let sourceName: String

    /// Relative time string (e.g. "2h ago", "3d ago")
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(publishedAt)
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 1 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - GNews API Response Models

struct GNewsResponse: Codable {
    let totalArticles: Int?
    let articles: [GNewsArticle]?
}

struct GNewsArticle: Codable {
    let title: String?
    let description: String?
    let url: String?
    let image: String?
    let publishedAt: String?
    let source: GNewsSource?

    func toNewsArticle() -> NewsArticle? {
        guard let title = title, let url = url else { return nil }

        // Parse ISO 8601 date
        let date: Date
        if let dateStr = publishedAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.date(from: dateStr)
                ?? ISO8601DateFormatter().date(from: dateStr)
                ?? Date()
        } else {
            date = Date()
        }

        return NewsArticle(
            title: title,
            description: description ?? "",
            url: url,
            imageURL: image,
            publishedAt: date,
            sourceName: source?.name ?? ""
        )
    }
}

struct GNewsSource: Codable {
    let name: String?
    let url: String?
}

// MARK: - Load State

enum NewsLoadState {
    case idle
    case loading
    case loaded
    case error(String)
}
