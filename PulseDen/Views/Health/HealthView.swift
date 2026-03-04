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
                                .tint(Theme.accent)
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
            .background(Theme.background)
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
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "heart.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
            }

            Text(lang.healthConnect)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)

            Text(lang.healthConnectSubtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                Task { await healthVM.requestAccess() }
            } label: {
                Text(lang.healthConnect)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
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
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button(lang.healthRetry) {
                Task { await healthVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(.top, 40)
    }

    // MARK: - Health Cards

    private var healthCards: some View {
        VStack(spacing: 14) {
            // Sleep Card
            healthCard(
                icon: "bed.double.fill",
                iconColor: Color(red: 0.55, green: 0.40, blue: 0.95),
                title: lang.healthSleep,
                value: healthVM.summary?.sleepText ?? "—",
                subtitle: lang.healthLastNight,
                statusColor: sleepStatusColor
            )

            HStack(spacing: 14) {
                smallCard(
                    icon: "heart.fill",
                    iconColor: Theme.negative,
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

            HStack(spacing: 14) {
                smallCard(
                    icon: "figure.walk",
                    iconColor: Theme.accent,
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
        title: String,
        value: String,
        subtitle: String,
        statusColor: Color
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
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
                .foregroundStyle(Theme.textSecondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private var sleepStatusColor: Color {
        guard let h = healthVM.summary?.sleepHours else { return Theme.textTertiary }
        if h >= 7 { return Theme.accent }
        if h >= 5 { return .orange }
        return Theme.negative
    }
}
