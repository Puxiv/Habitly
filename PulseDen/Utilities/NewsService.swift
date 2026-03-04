import Foundation

// MARK: - News Errors

enum NewsError: LocalizedError {
    case noApiKey
    case networkError
    case decodingError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey:           return "No GNews API key. Add one in Settings."
        case .networkError:       return "Couldn't connect to the news service. Check your internet."
        case .decodingError:      return "Couldn't parse the news data."
        case .apiError(let msg):  return "News API error: \(msg)"
        }
    }
}

// MARK: - News Service

@MainActor
final class NewsService {
    static let shared = NewsService()

    private init() {}

    /// Fetch top headlines from GNews API.
    /// - Parameters:
    ///   - category: Optional category filter (e.g. "world", "business", "technology")
    ///   - country: Optional 2-letter country code (e.g. "bg" for Bulgaria)
    ///   - lang: Optional 2-letter language code (e.g. "en")
    ///   - max: Maximum articles to return (1-10 on free tier)
    ///   - apiKey: GNews API key
    nonisolated func fetchTopHeadlines(
        category: String? = nil,
        country: String? = nil,
        lang: String? = nil,
        max: Int = 5,
        apiKey: String
    ) async throws -> [NewsArticle] {
        guard !apiKey.isEmpty else { throw NewsError.noApiKey }

        var components = URLComponents(string: "https://gnews.io/api/v4/top-headlines")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "max", value: "\(max)"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let country = country {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }
        if let lang = lang {
            queryItems.append(URLQueryItem(name: "lang", value: lang))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw NewsError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200: break
                case 403: throw NewsError.apiError("API key invalid or daily limit reached.")
                case 429: throw NewsError.apiError("Too many requests. Try again later.")
                default:  throw NewsError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }

            let gnewsResponse = try JSONDecoder().decode(GNewsResponse.self, from: data)
            return gnewsResponse.articles?.compactMap { $0.toNewsArticle() } ?? []
        } catch let error as NewsError {
            throw error
        } catch is DecodingError {
            throw NewsError.decodingError
        } catch {
            print("News fetch failed: \(error.localizedDescription)")
            throw NewsError.networkError
        }
    }
}
