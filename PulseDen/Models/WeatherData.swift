import Foundation

// MARK: - Weather Condition

enum WeatherCondition {
    case clearSky, mainlyClear, partlyCloudy, overcast
    case fog, drizzle, rain, heavyRain, snow, thunderstorm, unknown

    var displayName: String {
        switch self {
        case .clearSky:      return "Clear"
        case .mainlyClear:   return "Mainly Clear"
        case .partlyCloudy:  return "Partly Cloudy"
        case .overcast:      return "Overcast"
        case .fog:           return "Fog"
        case .drizzle:       return "Drizzle"
        case .rain:          return "Rain"
        case .heavyRain:     return "Heavy Rain"
        case .snow:          return "Snow"
        case .thunderstorm:  return "Thunderstorm"
        case .unknown:       return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .clearSky, .mainlyClear: return "sun.max.fill"
        case .partlyCloudy:           return "cloud.sun.fill"
        case .overcast:               return "cloud.fill"
        case .fog:                    return "cloud.fog.fill"
        case .drizzle:                return "cloud.drizzle.fill"
        case .rain:                   return "cloud.rain.fill"
        case .heavyRain:              return "cloud.heavyrain.fill"
        case .snow:                   return "cloud.snow.fill"
        case .thunderstorm:           return "cloud.bolt.rain.fill"
        case .unknown:                return "cloud"
        }
    }

    static func from(code: Int) -> WeatherCondition {
        switch code {
        case 0:               return .clearSky
        case 1:               return .mainlyClear
        case 2:               return .partlyCloudy
        case 3:               return .overcast
        case 45, 48:          return .fog
        case 51...55:         return .drizzle
        case 61, 63:          return .rain
        case 65, 80...82:     return .heavyRain
        case 71...77, 85, 86: return .snow
        case 95...99:         return .thunderstorm
        default:              return .unknown
        }
    }
}

// MARK: - Current Weather

struct CurrentWeather {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windspeed: Double
    let weatherCode: Int
    let isDay: Bool
    let cityName: String

    var condition: WeatherCondition { .from(code: weatherCode) }
    var temperatureText: String { "\(Int(temperature.rounded()))°C" }
    var feelsLikeText: String { "\(Int(feelsLike.rounded()))°C" }
    var windText: String { "\(Int(windspeed.rounded())) km/h" }
}

// MARK: - Daily Forecast

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let maxTemp: Double
    let minTemp: Double
    let weatherCode: Int

    var condition: WeatherCondition { .from(code: weatherCode) }

    var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Hourly Forecast

struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let weatherCode: Int
    let precipProb: Int

    var condition: WeatherCondition { .from(code: weatherCode) }

    var hourText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }
}

// MARK: - Open-Meteo API Response Models

struct OpenMeteoResponse: Decodable {
    let currentWeather: OpenMeteoCurrentWeather
    let hourly: OpenMeteoHourly
    let daily: OpenMeteoDaily

    enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
        case hourly, daily
    }
}

struct OpenMeteoCurrentWeather: Decodable {
    let temperature: Double
    let windspeed: Double
    let weathercode: Int
    let isDay: Int

    enum CodingKeys: String, CodingKey {
        case temperature, windspeed, weathercode
        case isDay = "is_day"
    }
}

struct OpenMeteoHourly: Decodable {
    let time: [String]
    let temperature2m: [Double]
    let precipitationProbability: [Int?]
    let weathercode: [Int]
    let relativehumidity2m: [Int]
    let apparentTemperature: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m            = "temperature_2m"
        case precipitationProbability = "precipitation_probability"
        case weathercode
        case relativehumidity2m       = "relativehumidity_2m"
        case apparentTemperature      = "apparent_temperature"
    }
}

struct OpenMeteoDaily: Decodable {
    let time: [String]
    let weathercode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]

    enum CodingKeys: String, CodingKey {
        case time, weathercode
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
    }
}
