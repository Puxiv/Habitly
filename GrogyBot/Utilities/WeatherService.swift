import Foundation
import CoreLocation

// MARK: - Weather Errors

enum WeatherError: LocalizedError {
    case locationDenied
    case locationTimeout
    case networkError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .locationDenied:
            return "Location access is required to fetch weather. Enable it in Settings → GrogyBot."
        case .locationTimeout:
            return "Could not determine your location. Please try again."
        case .networkError:
            return "Couldn't connect to the weather service. Check your internet connection."
        case .decodingError:
            return "Received unexpected data from the weather service."
        }
    }
}

// MARK: - Weather Service

@MainActor
final class WeatherService: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Location

    func requestLocation() async throws -> CLLocation {
        // Cancel any stale continuation before starting a new one
        locationContinuation?.resume(throwing: CancellationError())
        locationContinuation = nil
        timeoutTask?.cancel()

        return try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont

            // Safety timeout — 15 seconds
            self.timeoutTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(throwing: WeatherError.locationTimeout)
                    self.locationContinuation = nil
                }
            }

            switch self.locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.requestLocation()
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            default:
                self.resumeContinuation(throwing: WeatherError.locationDenied)
            }
        }
    }

    /// Safely resume and nil out the continuation exactly once.
    private func resumeContinuation(returning location: CLLocation) {
        timeoutTask?.cancel()
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    private func resumeContinuation(throwing error: Error) {
        timeoutTask?.cancel()
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            self.resumeContinuation(returning: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resumeContinuation(throwing: error)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.locationContinuation != nil {
                    manager.requestLocation()
                }
            case .denied, .restricted:
                self.resumeContinuation(throwing: WeatherError.locationDenied)
            default:
                break
            }
        }
    }

    // MARK: - Reverse Geocoding

    func cityName(for location: CLLocation) async -> String {
        await withCheckedContinuation { cont in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                let name = placemarks?.first?.locality
                    ?? placemarks?.first?.administrativeArea
                    ?? "Unknown"
                cont.resume(returning: name)
            }
        }
    }

    // MARK: - Open-Meteo API

    func fetchWeather(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude",       value: "\(latitude)"),
            .init(name: "longitude",      value: "\(longitude)"),
            .init(name: "current_weather", value: "true"),
            .init(name: "hourly", value: "temperature_2m,precipitation_probability,weathercode,relativehumidity_2m,apparent_temperature"),
            .init(name: "daily",  value: "weathercode,temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone",      value: "auto"),
            .init(name: "forecast_days", value: "7"),
        ]

        do {
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            return try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch is DecodingError {
            throw WeatherError.decodingError
        } catch {
            throw WeatherError.networkError
        }
    }
}
