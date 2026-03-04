import Foundation

// MARK: - Stock Quote (UI Model)

struct StockQuote: Identifiable {
    let id = UUID()
    let symbol: String
    let shortName: String
    let price: Double
    let change: Double
    let changePercent: Double
    let previousClose: Double
    let currency: String

    var isPositive: Bool { change >= 0 }

    var priceText: String {
        switch currency {
        case "USD":
            return "$\(String(format: "%.2f", price))"
        case "EUR":
            return "\(String(format: "%.2f", price))\u{20AC}"
        case "GBP":
            return "\u{00A3}\(String(format: "%.2f", price))"
        case "GBp", "GBX":
            // LSE prices are in pence
            return "\(String(format: "%.1f", price))p"
        case "JPY":
            return "\u{00A5}\(String(format: "%.0f", price))"
        case "CHF":
            return "CHF \(String(format: "%.2f", price))"
        case "SEK", "NOK", "DKK":
            return "\(String(format: "%.2f", price)) kr"
        case "INR":
            return "\u{20B9}\(String(format: "%.2f", price))"
        case "HKD":
            return "HK$\(String(format: "%.2f", price))"
        case "CAD":
            return "CA$\(String(format: "%.2f", price))"
        case "AUD":
            return "A$\(String(format: "%.2f", price))"
        case "CNY":
            return "\u{00A5}\(String(format: "%.2f", price))"
        default:
            return "\(String(format: "%.2f", price)) \(currency)"
        }
    }

    var changeText: String {
        let sign = isPositive ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))"
    }

    var changePercentText: String {
        let sign = isPositive ? "+" : ""
        return "\(sign)\(String(format: "%.1f", changePercent))%"
    }
}

// MARK: - Stock Search Result (UI Model)

struct StockSearchResult: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let exchange: String
    let quoteType: String
}

// MARK: - Yahoo Finance v8 Chart API Models

struct YahooChartResponse: Codable {
    let chart: YahooChartData
}

struct YahooChartData: Codable {
    let result: [YahooChartResult]?
    let error: YahooChartError?
}

struct YahooChartError: Codable {
    let code: String?
    let description: String?
}

struct YahooChartResult: Codable {
    let meta: YahooChartMeta
}

struct YahooChartMeta: Codable {
    let symbol: String?
    let shortName: String?
    let longName: String?
    let regularMarketPrice: Double?
    let chartPreviousClose: Double?
    let currency: String?

    func toStockQuote() -> StockQuote? {
        guard let symbol = symbol,
              let price = regularMarketPrice else { return nil }

        let prevClose = chartPreviousClose ?? price
        let change = price - prevClose
        let changePct = prevClose > 0 ? (change / prevClose) * 100 : 0

        return StockQuote(
            symbol: symbol,
            shortName: shortName ?? longName ?? symbol,
            price: price,
            change: change,
            changePercent: changePct,
            previousClose: prevClose,
            currency: currency ?? "USD"
        )
    }
}

// MARK: - Yahoo Finance Search API Models

struct YahooSearchResponse: Codable {
    let quotes: [YahooSearchQuote]?
}

struct YahooSearchQuote: Codable {
    let symbol: String?
    let shortname: String?
    let longname: String?
    let exchDisp: String?
    let quoteType: String?

    func toSearchResult() -> StockSearchResult? {
        guard let symbol = symbol else { return nil }
        return StockSearchResult(
            symbol: symbol,
            name: longname ?? shortname ?? symbol,
            exchange: exchDisp ?? "",
            quoteType: quoteType ?? "EQUITY"
        )
    }
}

// MARK: - Load State

enum StocksLoadState {
    case idle
    case loading
    case loaded
    case error(String)
}
