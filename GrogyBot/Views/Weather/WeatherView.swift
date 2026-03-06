import SwiftUI

struct WeatherView: View {
    @Environment(LanguageManager.self) var lang
    @Environment(WeatherViewModel.self) var weatherVM

    var body: some View {
        NavigationStack {
            Group {
                switch weatherVM.loadState {
                case .idle:
                    idleView
                case .loading:
                    loadingView
                case .loaded:
                    if let weather = weatherVM.currentWeather {
                        weatherContent(weather)
                    }
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle(lang.weatherTab)
            .background(Theme.background)
        }
        .task {
            await weatherVM.fetchWeather()
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)
            Text(lang.weatherCheckLocation)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Theme.accent)
                .scaleEffect(1.4)
            Text(lang.weatherLoading)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            Text(lang.weatherErrorTitle)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(lang.weatherRetry) {
                Task { await weatherVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main Weather Content

    @ViewBuilder
    private func weatherContent(_ weather: CurrentWeather) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                currentWeatherCard(weather)
                if !weatherVM.hourlyForecasts.isEmpty {
                    hourlyForecastCard
                }
                if !weatherVM.dailyForecasts.isEmpty {
                    dailyForecastCard
                }
                detailsCard(weather)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable {
            await weatherVM.refresh()
        }
    }

    // MARK: - Current Weather Card

    private func currentWeatherCard(_ weather: CurrentWeather) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: gradientColors(for: weather.condition, isDay: weather.isDay),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 150, height: 150)
                .offset(x: 45, y: -45)

            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 100, height: 100)
                .offset(x: -25, y: 25)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weather.cityName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(weather.condition.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    Image(systemName: weather.condition.systemImage)
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(weather.temperatureText)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 18) {
                    Label(lang.weatherFeelsLike + " " + weather.feelsLikeText,
                          systemImage: "thermometer.medium")
                    Label("\(weather.humidity)%", systemImage: "humidity.fill")
                    Label(weather.windText, systemImage: "wind")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .symbolRenderingMode(.hierarchical)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(minHeight: 230)
    }

    // MARK: - Hourly Forecast

    private var hourlyForecastCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(lang.weatherHourly, systemImage: "clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(weatherVM.hourlyForecasts) { hour in
                        VStack(spacing: 8) {
                            Text(hour.hourText)
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                            Image(systemName: hour.condition.systemImage)
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.accent)
                                .symbolRenderingMode(.hierarchical)
                            Text("\(Int(hour.temperature.rounded()))°")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            if hour.precipProb > 0 {
                                Text("\(hour.precipProb)%")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 7-Day Forecast

    private var dailyForecastCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(lang.weatherDaily, systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ForEach(Array(weatherVM.dailyForecasts.enumerated()), id: \.element.id) { idx, day in
                VStack(spacing: 0) {
                    HStack {
                        Text(idx == 0 ? lang.weatherToday : day.dayName)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(width: 52, alignment: .leading)

                        Image(systemName: day.condition.systemImage)
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.accent)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 28)

                        Text(day.condition.displayName)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Spacer()

                        HStack(spacing: 8) {
                            Text("\(Int(day.minTemp.rounded()))°")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 36, alignment: .trailing)
                            Text("\(Int(day.maxTemp.rounded()))°")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)

                    if idx < weatherVM.dailyForecasts.count - 1 {
                        Divider()
                            .overlay(Theme.textTertiary.opacity(0.3))
                            .padding(.leading, 16)
                    }
                }
            }

            Spacer().frame(height: 16)
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Details Grid

    private func detailsCard(_ weather: CurrentWeather) -> some View {
        let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: cols, spacing: 14) {
            detailCell(icon: "thermometer.medium",
                       iconBg: Theme.negative,
                       title: lang.weatherFeelsLike,
                       value: weather.feelsLikeText)
            detailCell(icon: "humidity.fill",
                       iconBg: Color(red: 0.25, green: 0.55, blue: 0.95),
                       title: lang.weatherHumidity,
                       value: "\(weather.humidity)%")
            detailCell(icon: "wind",
                       iconBg: .teal,
                       title: lang.weatherWind,
                       value: weather.windText)
            detailCell(icon: weather.isDay ? "sun.max.fill" : "moon.stars.fill",
                       iconBg: weather.isDay ? .yellow : .indigo,
                       title: lang.weatherDayNight,
                       value: weather.isDay ? lang.weatherDay : lang.weatherNight)
        }
    }

    private func detailCell(icon: String, iconBg: Color,
                            title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBg.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconBg)
                    .symbolRenderingMode(.hierarchical)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Gradient Helpers

    private func gradientColors(for condition: WeatherCondition, isDay: Bool) -> [Color] {
        if !isDay {
            return [Color(red: 0.08, green: 0.08, blue: 0.22),
                    Color(red: 0.04, green: 0.04, blue: 0.14)]
        }
        switch condition {
        case .clearSky, .mainlyClear:
            return [Color(red: 0.15, green: 0.50, blue: 0.90),
                    Color(red: 0.08, green: 0.35, blue: 0.70)]
        case .partlyCloudy:
            return [Color(red: 0.25, green: 0.48, blue: 0.80),
                    Color(red: 0.18, green: 0.35, blue: 0.65)]
        case .overcast, .fog:
            return [Color(red: 0.30, green: 0.30, blue: 0.38),
                    Color(red: 0.20, green: 0.20, blue: 0.28)]
        case .drizzle, .rain:
            return [Color(red: 0.18, green: 0.25, blue: 0.42),
                    Color(red: 0.12, green: 0.18, blue: 0.32)]
        case .heavyRain, .thunderstorm:
            return [Color(red: 0.12, green: 0.15, blue: 0.28),
                    Color(red: 0.06, green: 0.08, blue: 0.18)]
        case .snow:
            return [Color(red: 0.40, green: 0.55, blue: 0.70),
                    Color(red: 0.30, green: 0.42, blue: 0.58)]
        case .unknown:
            return [Color(red: 0.28, green: 0.32, blue: 0.40),
                    Color(red: 0.18, green: 0.22, blue: 0.30)]
        }
    }
}
