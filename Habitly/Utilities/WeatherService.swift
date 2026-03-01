import Foundation
import CoreLocation

// MARK: - Weather Errors

enum WeatherError: LocalizedError {
    case locationDenied
    case networkError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .locationDenied:
            return "Location access is required to fetch weather. Enable it in Settings → Habitly."
        case .networkError:
            return "Couldn't connect to the weather service. Check your internet connection."
        case .decodingError:
            return "Received unexpected data from the weather service."
        }
    }
}

// MARK: - Weather Service
//
// WeatherService wraps CLLocationManager and the Open-Meteo API.
// CLLocationManager must be created and used on the main thread;
// since this singleton is first accessed from the @MainActor WeatherViewModel,
// all operations naturally occur on the main thread.

final class WeatherService: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    private let locationManager = CLLocationManager()
    // Stores the in-flight continuation for a single location request.
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Location

    func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont
            switch self.locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.requestLocation()
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            default:
                cont.resume(throwing: WeatherError.locationDenied)
                self.locationContinuation = nil
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        locationContinuation?.resume(returning: loc)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if locationContinuation != nil {
                manager.requestLocation()
            }
        case .denied, .restricted:
            locationContinuation?.resume(throwing: WeatherError.locationDenied)
            locationContinuation = nil
        default:
            break
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
