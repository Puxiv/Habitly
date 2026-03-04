import Foundation
import Observation

// MARK: - Stocks View Model

@MainActor
@Observable
final class StocksViewModel {
    static let shared = StocksViewModel()

    var quotes: [StockQuote] = []
    var loadState: StocksLoadState = .idle

    // Search
    var searchQuery: String = ""
    var searchResults: [StockSearchResult] = []
    var isSearching: Bool = false

    var symbols: [String] {
        didSet { saveSymbols() }
    }

    private let service = StockService.shared
    private let symbolsKey = "stock_symbols"
    private var searchTask: Task<Void, Never>?

    private init() {
        symbols = UserDefaults.standard.stringArray(forKey: "stock_symbols") ?? []
    }

    // MARK: - Persistence

    private func saveSymbols() {
        UserDefaults.standard.set(symbols, forKey: symbolsKey)
    }

    // MARK: - Add / Remove

    func addSymbol(_ raw: String) {
        let symbol = raw.uppercased().trimmingCharacters(in: .whitespaces)
        guard !symbol.isEmpty, !symbols.contains(symbol) else { return }
        symbols.append(symbol)
        Task { await fetchAll() }
    }

    func removeSymbol(_ symbol: String) {
        symbols.removeAll { $0 == symbol }
        quotes.removeAll { $0.symbol == symbol }
    }

    // MARK: - Search

    func triggerSearch(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce 400ms
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            let results = await service.searchSymbols(query: trimmed)
            guard !Task.isCancelled else { return }

            // Filter out symbols already in watchlist
            searchResults = results.filter { !symbols.contains($0.symbol) }
            isSearching = false
        }
    }

    // MARK: - Fetch

    func fetchAll() async {
        guard !symbols.isEmpty else {
            quotes = []
            loadState = .loaded
            return
        }

        loadState = .loading

        do {
            let fetched = try await service.fetchQuotes(symbols: symbols)

            // Maintain watchlist order
            var ordered: [StockQuote] = []
            for sym in symbols {
                if let q = fetched.first(where: { $0.symbol == sym }) {
                    ordered.append(q)
                }
            }
            quotes = ordered
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

    /// Top 5 stocks sorted by biggest absolute change percent.
    var topMovers: [StockQuote] {
        Array(
            quotes.sorted { abs($0.changePercent) > abs($1.changePercent) }
                  .prefix(5)
        )
    }

    var dashboardValue: String {
        guard let top = topMovers.first else { return "—" }
        return top.changePercentText
    }

    var dashboardSubtitle: String {
        guard !symbols.isEmpty else { return "Add stocks" }
        if let top = topMovers.first {
            return "\(top.symbol) · \(symbols.count) tracked"
        }
        return "\(symbols.count) stocks"
    }
}
