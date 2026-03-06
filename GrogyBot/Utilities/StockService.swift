import Foundation

// MARK: - Stock Errors

enum StockError: LocalizedError {
    case noSymbols
    case networkError
    case decodingError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noSymbols:          return "No stock symbols to fetch."
        case .networkError:       return "Couldn't connect to the stock service. Check your internet."
        case .decodingError:      return "Couldn't parse the stock data."
        case .apiError(let msg):  return "Stock API error: \(msg)"
        }
    }
}

// MARK: - Stock Service

@MainActor
final class StockService {
    static let shared = StockService()

    private init() {}

    // MARK: - Fetch Quotes

    /// Fetch quotes for the given symbols using Yahoo Finance v8 chart endpoint.
    /// Each symbol is fetched individually and results are combined.
    func fetchQuotes(symbols: [String]) async throws -> [StockQuote] {
        guard !symbols.isEmpty else { throw StockError.noSymbols }

        // Fetch all symbols concurrently
        return await withTaskGroup(of: StockQuote?.self) { group in
            for symbol in symbols {
                group.addTask { [self] in
                    await self.fetchSingle(symbol: symbol)
                }
            }

            var results: [StockQuote] = []
            for await quote in group {
                if let q = quote {
                    results.append(q)
                }
            }
            return results
        }
    }

    /// Fetch a single symbol's quote from the v8 chart endpoint.
    private nonisolated func fetchSingle(symbol: String) async -> StockQuote? {
        guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=1d"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)

            if let err = response.chart.error {
                print("Yahoo error for \(symbol): \(err.description ?? "unknown")")
                return nil
            }

            return response.chart.result?.first?.meta.toStockQuote()
        } catch {
            print("Fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Symbol Search

    /// Search for stock symbols using Yahoo Finance search API.
    nonisolated func searchSymbols(query: String) async -> [StockSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let urlString = "https://query2.finance.yahoo.com/v1/finance/search?q=\(encoded)&quotesCount=8&newsCount=0"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(YahooSearchResponse.self, from: data)
            return response.quotes?.compactMap { $0.toSearchResult() }
                .filter { $0.quoteType == "EQUITY" || $0.quoteType == "ETF" } ?? []
        } catch {
            print("Search failed for '\(query)': \(error.localizedDescription)")
            return []
        }
    }
}
