import Foundation
import HealthKit

// MARK: - Health Errors

enum HealthError: LocalizedError {
    case notAvailable
    case authDenied
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Health data is not available on this device."
        case .authDenied:   return "Health access was not granted."
        case .queryFailed(let msg): return "Health query failed: \(msg)"
        }
    }
}

// MARK: - Health Service

@MainActor
final class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {}

    // MARK: - Authorization

    /// Request read-only access to the health data types we need.
    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.notAvailable }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKCategoryType(.sleepAnalysis),
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Sleep (last night)

    /// Returns total sleep hours from last night (8 PM yesterday → now).
    func fetchSleepLastNight() async -> Double? {
        let sleepType = HKCategoryType(.sleepAnalysis)

        let calendar = Calendar.current
        let now = Date()
        guard let yesterday8PM = calendar.date(
            bySettingHour: 20, minute: 0, second: 0,
            of: calendar.date(byAdding: .day, value: -1, to: now)!
        ) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: yesterday8PM, end: now, options: .strictStartDate)
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDesc]
            ) { _, results, _ in
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            self.store.execute(query)
        }

        // Sum all "asleep" sample durations (filter out "inBed" and "awake")
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]

        let totalSeconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        return totalSeconds > 0 ? totalSeconds / 3600.0 : nil
    }

    // MARK: - Resting Heart Rate

    /// Returns the most recent resting heart rate sample (looks back up to 7 days).
    func fetchRestingHeartRate() async -> Double? {
        await fetchLatestQuantity(
            type: HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            since: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        )
    }

    // MARK: - Latest Heart Rate

    /// Returns the most recent heart rate reading (looks back up to 24 hours).
    func fetchLatestHeartRate() async -> Double? {
        await fetchLatestQuantity(
            type: HKQuantityType(.heartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            since: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        )
    }

    // MARK: - Steps

    /// Returns today's total step count.
    func fetchSteps() async -> Int? {
        let stepType = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: .count())
                cont.resume(returning: value.map { Int($0) })
            }
            self.store.execute(query)
        }
    }

    // MARK: - Active Calories

    /// Returns today's total active energy burned.
    func fetchActiveCalories() async -> Double? {
        let calType = HKQuantityType(.activeEnergyBurned)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: calType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
                cont.resume(returning: value)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Helpers

    /// Fetch the most recent quantity sample of a given type since a start date.
    private func fetchLatestQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        since start: Date
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDesc]
            ) { _, results, _ in
                let value = (results?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            self.store.execute(query)
        }
    }
}
