import Foundation
import Observation

// MARK: - Load State

enum HealthLoadState {
    case idle
    case loading
    case loaded
    case unauthorized
    case error(String)
}

// MARK: - Health View Model

@MainActor
@Observable
final class HealthViewModel {
    static let shared = HealthViewModel()

    var summary: HealthSummary?
    var loadState: HealthLoadState = .idle
    var isAuthorized: Bool = false

    private let service = HealthService.shared

    private init() {}

    // MARK: - Authorization

    func requestAccess() async {
        guard service.isAvailable else {
            loadState = .error("Health data is not available on this device.")
            return
        }

        do {
            try await service.requestAuthorization()
            isAuthorized = true
            await fetchAll()
        } catch {
            loadState = .unauthorized
        }
    }

    // MARK: - Fetch All Metrics

    func fetchAll() async {
        loadState = .loading

        async let sleep = service.fetchSleepLastNight()
        async let restingHR = service.fetchRestingHeartRate()
        async let latestHR = service.fetchLatestHeartRate()
        async let steps = service.fetchSteps()
        async let calories = service.fetchActiveCalories()

        summary = await HealthSummary(
            sleepHours: sleep,
            restingHeartRate: restingHR,
            latestHeartRate: latestHR,
            steps: steps,
            activeCalories: calories,
            lastUpdated: Date()
        )

        loadState = .loaded
    }

    func refresh() async {
        loadState = .idle
        await fetchAll()
    }

    // MARK: - Status

    var status: HealthStatus {
        HealthStatus.from(summary)
    }

    // MARK: - Dashboard Helpers

    var dashboardValue: String {
        guard isAuthorized else { return "—" }
        guard let s = summary else { return "…" }

        // Prioritize sleep for the big value
        if let _ = s.sleepHours {
            return s.sleepText
        }
        // Fallback to steps
        if let steps = s.steps {
            return steps.formatted()
        }
        return "—"
    }

    var dashboardSubtitle: String {
        guard isAuthorized else { return "Tap to connect" }
        return status.message
    }
}
