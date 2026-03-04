import Foundation
import Observation

// MARK: - News View Model

@MainActor
@Observable
final class NewsViewModel {
    static let shared = NewsViewModel()

    var worldNews: [NewsArticle] = []
    var bulgarianNews: [NewsArticle] = []
    var loadState: NewsLoadState = .idle

    private let service = NewsService.shared
    private let apiKeyKey = "gnews_api_key"

    private init() {}

    // MARK: - API Key

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
    }

    var hasApiKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: - Fetch

    func fetchAll() async {
        guard hasApiKey else {
            loadState = .error("No API key. Add your GNews key in Settings.")
            return
        }

        loadState = .loading
        let key = apiKey

        do {
            async let worldResult = service.fetchTopHeadlines(
                category: "world", lang: "en", max: 5, apiKey: key
            )
            async let bgResult = service.fetchTopHeadlines(
                country: "bg", max: 5, apiKey: key
            )

            worldNews = try await worldResult
            bulgarianNews = try await bgResult
            loadState = .loaded
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    func refresh() async {
        loadState = .idle
        await fetchAll()
    }

    // MARK: - Dashboard Helpers

    var dashboardValue: String {
        let total = worldNews.count + bulgarianNews.count
        guard total > 0 else { return "—" }
        return "\(total)"
    }

    var dashboardSubtitle: String {
        guard hasApiKey else { return "Add API key" }
        let total = worldNews.count + bulgarianNews.count
        if total > 0 {
            return "\(total) articles"
        }
        return "No articles"
    }
}
