import SwiftUI

struct HealthView: View {
    @Environment(LanguageManager.self) var lang
    @Environment(HealthViewModel.self) var healthVM

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !healthVM.isAuthorized {
                        connectCard
                    } else {
                        switch healthVM.loadState {
                        case .loading:
                            ProgressView()
                                .padding(.top, 60)
                        case .error(let msg):
                            errorView(msg)
                        default:
                            healthCards
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lang.healthTitle)
            .refreshable {
                if healthVM.isAuthorized {
                    await healthVM.refresh()
                }
            }
        }
        .task {
            if healthVM.isAuthorized && healthVM.summary == nil {
                await healthVM.fetchAll()
            }
        }
    }

    // MARK: - Connect Card

    private var connectCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.35, blue: 0.40),
                                 Color(red: 0.90, green: 0.20, blue: 0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(lang.healthConnect)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)

            Text(lang.healthConnectSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                Task { await healthVM.requestAccess() }
            } label: {
                Text(lang.healthConnect)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.35, blue: 0.40),
                                     Color(red: 0.90, green: 0.20, blue: 0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 40)
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
                Task { await healthVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.top, 40)
    }

    // MARK: - Health Cards

    private var healthCards: some View {
        VStack(spacing: 14) {
            // Sleep Card
            healthCard(
                icon: "bed.double.fill",
                iconColor: Color(red: 0.35, green: 0.30, blue: 0.80),
                gradientColors: [Color(red: 0.35, green: 0.30, blue: 0.80),
                                 Color(red: 0.50, green: 0.35, blue: 0.90)],
                title: lang.healthSleep,
                value: healthVM.summary?.sleepText ?? "—",
                subtitle: lang.healthLastNight,
                statusColor: sleepStatusColor
            )

            // Heart Rate Card
            HStack(spacing: 14) {
                smallCard(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: lang.healthRestingHR,
                    value: healthVM.summary?.restingHRText ?? "—"
                )
                smallCard(
                    icon: "waveform.path.ecg",
                    iconColor: Color(red: 1.0, green: 0.40, blue: 0.45),
                    title: lang.healthHeartRate,
                    value: healthVM.summary?.latestHRText ?? "—"
                )
            }

            // Activity Card
            HStack(spacing: 14) {
                smallCard(
                    icon: "figure.walk",
                    iconColor: .green,
                    title: lang.healthSteps,
                    value: healthVM.summary?.stepsText ?? "—"
                )
                smallCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: lang.healthCalories,
                    value: healthVM.summary?.caloriesText ?? "—"
                )
            }
        }
    }

    // MARK: - Health Card Component

    private func healthCard(
        icon: String,
        iconColor: Color,
        gradientColors: [Color],
        title: String,
        value: String,
        subtitle: String,
        statusColor: Color
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 100, height: 100)
                .offset(x: 30, y: -30)

            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(height: 110)
    }

    // MARK: - Small Card Component

    private func smallCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private var sleepStatusColor: Color {
        guard let h = healthVM.summary?.sleepHours else { return .gray }
        if h >= 7 { return .green }
        if h >= 5 { return .orange }
        return .red
    }
}
