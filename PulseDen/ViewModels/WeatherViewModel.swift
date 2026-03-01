import Foundation
import Observation

// MARK: - Load State

enum WeatherLoadState {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - Weather View Model

@MainActor
@Observable
final class WeatherViewModel {
    static let shared = WeatherViewModel()

    var currentWeather: CurrentWeather?
    var dailyForecasts: [DailyForecast] = []
    var hourlyForecasts: [HourlyForecast] = []
    var loadState: WeatherLoadState = .idle

    private let service = WeatherService.shared

    var isLoaded: Bool {
        if case .loaded = loadState { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let msg) = loadState { return msg }
        return nil
    }

    private init() {}

    // MARK: - Fetch

    func fetchWeather() async {
        guard !isLoaded else { return }
        loadState = .loading
        do {
            let location = try await service.requestLocation()
            async let cityName = service.cityName(for: location)
            async let response = service.fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let (city, data) = try await (cityName, response)
            processResponse(data, cityName: city)
            loadState = .loaded
        } catch let err as WeatherError {
            loadState = .error(err.errorDescription ?? "Unknown error")
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    func refresh() async {
        loadState = .idle
        await fetchWeather()
    }

    // MARK: - Processing

    private func processResponse(_ response: OpenMeteoResponse, cityName: String) {
        let cw = response.currentWeather

        // Find the hourly slot closest to now for humidity / feels-like
        let now = Date()
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let hourlyDates = response.hourly.time.map { isoFormatter.date(from: $0) }
        let currentIdx = hourlyDates.firstIndex { ($0 ?? .distantFuture) >= now.addingTimeInterval(-3600) } ?? 0

        let humidity   = response.hourly.relativehumidity2m[safe: currentIdx] ?? 0
        let feelsLike  = response.hourly.apparentTemperature[safe: currentIdx] ?? cw.temperature

        currentWeather = CurrentWeather(
            temperature: cw.temperature,
            feelsLike:   feelsLike,
            humidity:    humidity,
            windspeed:   cw.windspeed,
            weatherCode: cw.weathercode,
            isDay:       cw.isDay == 1,
            cityName:    cityName
        )

        // Daily forecasts (7 days)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dailyForecasts = zip(response.daily.time,
                             zip(response.daily.weathercode,
                                 zip(response.daily.temperature2mMax,
                                     response.daily.temperature2mMin)))
            .compactMap { (timeStr, rest) -> DailyForecast? in
                let (code, (maxT, minT)) = rest
                guard let date = dayFormatter.date(from: timeStr) else { return nil }
                return DailyForecast(date: date, maxTemp: maxT, minTemp: minT, weatherCode: code)
            }

        // Hourly forecasts — next 24 h
        hourlyForecasts = zip(hourlyDates,
                              zip(response.hourly.temperature2m,
                                  zip(response.hourly.weathercode,
                                      response.hourly.precipitationProbability)))
            .compactMap { (optDate, rest) -> HourlyForecast? in
                let (temp, (code, precip)) = rest
                guard let date = optDate, date >= now, date <= now.addingTimeInterval(24 * 3600) else { return nil }
                return HourlyForecast(time: date, temperature: temp, weatherCode: code, precipProb: precip ?? 0)
            }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
