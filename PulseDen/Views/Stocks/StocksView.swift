import SwiftUI

struct StocksView: View {
    @Environment(LanguageManager.self) var lang
    @Environment(StocksViewModel.self) var stocksVM

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Group {
                    if stocksVM.symbols.isEmpty {
                        emptyState
                    } else {
                        stocksList
                    }
                }
                .background(Theme.background)

                if !stocksVM.searchResults.isEmpty && isSearchFocused {
                    searchOverlay
                }
            }
            .navigationTitle(lang.stocksTitle)
            .refreshable {
                await stocksVM.refresh()
            }
        }
        .task {
            let needsFetch: Bool = {
                if case .idle = stocksVM.loadState { return true }
                return stocksVM.quotes.isEmpty
            }()
            if needsFetch {
                await stocksVM.fetchAll()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
            }

            Text(lang.stocksEmpty)
                .font(.title3.weight(.medium))

            searchBar
                .padding(.horizontal, 20)
        }
        .padding(.top, 40)
    }

    // MARK: - Stocks List

    @ViewBuilder
    private var stocksList: some View {
        ScrollView {
            VStack(spacing: 14) {
                searchBar

                if case .loading = stocksVM.loadState, stocksVM.quotes.isEmpty {
                    ProgressView()
                        .tint(Theme.accent)
                        .padding(.top, 40)
                } else if case .error(let msg) = stocksVM.loadState, stocksVM.quotes.isEmpty {
                    errorView(msg)
                } else {
                    stockRows
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBar: some View {
        @Bindable var vm = stocksVM

        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.subheadline)

                TextField(lang.stocksSearchPlaceholder, text: $vm.searchQuery)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.done)
                    .focused($isSearchFocused)
                    .onSubmit { addManualSymbol() }
                    .onChange(of: stocksVM.searchQuery) { _, newValue in
                        stocksVM.triggerSearch(query: newValue)
                    }

                if !stocksVM.searchQuery.isEmpty {
                    Button {
                        stocksVM.searchQuery = ""
                        stocksVM.searchResults = []
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.textTertiary.opacity(0.3), lineWidth: 1)
            )

            Button {
                addManualSymbol()
            } label: {
                Text(lang.stocksAdd)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(stocksVM.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addManualSymbol() {
        let symbol = stocksVM.searchQuery
        stocksVM.searchQuery = ""
        stocksVM.searchResults = []
        isSearchFocused = false
        stocksVM.addSymbol(symbol)
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)

            ScrollView {
                VStack(spacing: 0) {
                    if stocksVM.isSearching {
                        HStack {
                            ProgressView()
                                .tint(Theme.accent)
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(stocksVM.searchResults) { result in
                            Button {
                                stocksVM.searchQuery = ""
                                stocksVM.searchResults = []
                                isSearchFocused = false
                                stocksVM.addSymbol(result.symbol)
                            } label: {
                                searchResultRow(result)
                            }
                            .buttonStyle(.plain)

                            if result.id != stocksVM.searchResults.last?.id {
                                Divider()
                                    .overlay(Theme.textTertiary.opacity(0.3))
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.textTertiary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    private func searchResultRow(_ result: StockSearchResult) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(result.name)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(result.exchange)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Stock Rows

    private var stockRows: some View {
        ForEach(stocksVM.quotes) { quote in
            stockRow(quote)
        }
    }

    private func stockRow(_ q: StockQuote) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(q.symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(q.shortName)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(q.priceText)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Text(q.changePercentText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    q.isPositive ? Theme.positive : Theme.negative,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                stocksVM.removeSymbol(q.symbol)
            } label: {
                Label(lang.stocksRemove, systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                stocksVM.removeSymbol(q.symbol)
            } label: {
                Label(lang.stocksRemove, systemImage: "trash")
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button(lang.healthRetry) {
                Task { await stocksVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(.top, 40)
    }
}
