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
                .background(Color(.systemGroupedBackground))

                // Search results overlay
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
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.78, blue: 0.45),
                                 Color(red: 0.10, green: 0.60, blue: 0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

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
                    .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            Button {
                addManualSymbol()
            } label: {
                Text(lang.stocksAdd)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.20, green: 0.78, blue: 0.45), in: RoundedRectangle(cornerRadius: 10))
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
            // Spacer to push below search bar (~60pt for bar + padding)
            Spacer().frame(height: 56)

            ScrollView {
                VStack(spacing: 0) {
                    if stocksVM.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .padding(.horizontal, 16)
        }
    }

    private func searchResultRow(_ result: StockSearchResult) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(result.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(result.exchange)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
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
            // Symbol + Name
            VStack(alignment: .leading, spacing: 3) {
                Text(q.symbol)
                    .font(.headline.weight(.bold))
                Text(q.shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Price
            Text(q.priceText)
                .font(.system(.body, design: .rounded, weight: .semibold))

            // Change pill
            Text(q.changePercentText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    q.isPositive
                        ? Color(red: 0.20, green: 0.72, blue: 0.40)
                        : Color(red: 0.90, green: 0.25, blue: 0.25),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
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
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(lang.healthRetry) {
                Task { await stocksVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.20, green: 0.78, blue: 0.45))
        }
        .padding(.top, 40)
    }
}
