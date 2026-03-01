import SwiftUI

// MARK: - Health Summary

struct HealthSummary {
    let sleepHours: Double?
    let restingHeartRate: Double?
    let latestHeartRate: Double?
    let steps: Int?
    let activeCalories: Double?
    let lastUpdated: Date

    // MARK: Formatted Strings

    var sleepText: String {
        guard let h = sleepHours else { return "—" }
        let hours = Int(h)
        let mins  = Int((h - Double(hours)) * 60)
        return "\(hours)h \(mins)m"
    }

    var restingHRText: String {
        guard let hr = restingHeartRate else { return "—" }
        return "\(Int(hr)) bpm"
    }

    var latestHRText: String {
        guard let hr = latestHeartRate else { return "—" }
        return "\(Int(hr)) bpm"
    }

    var stepsText: String {
        guard let s = steps else { return "—" }
        return s.formatted()
    }

    var caloriesText: String {
        guard let c = activeCalories else { return "—" }
        return "\(Int(c)) kcal"
    }
}

// MARK: - Health Status

enum HealthStatus {
    case good(String)
    case warning(String)
    case alert(String)
    case noData

    var color: Color {
        switch self {
        case .good:    return .green
        case .warning: return .orange
        case .alert:   return .red
        case .noData:  return .gray
        }
    }

    var icon: String {
        switch self {
        case .good:    return "checkmark.heart.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .alert:   return "heart.fill"
        case .noData:  return "heart.slash"
        }
    }

    var message: String {
        switch self {
        case .good(let msg):    return msg
        case .warning(let msg): return msg
        case .alert(let msg):   return msg
        case .noData:           return "No health data"
        }
    }

    /// Derive status from a health summary.
    static func from(_ summary: HealthSummary?) -> HealthStatus {
        guard let s = summary else { return .noData }

        // Alert: resting HR above 100 bpm
        if let rhr = s.restingHeartRate, rhr > 100 {
            return .alert("HR: \(Int(rhr)) bpm ⚠️")
        }

        // Warning: sleep under 7 hours
        if let sleep = s.sleepHours, sleep > 0, sleep < 7 {
            return .warning("Low sleep: \(s.sleepText)")
        }

        // Good: have sleep data and it's ≥ 7h
        if let sleep = s.sleepHours, sleep >= 7 {
            return .good("\(s.sleepText) sleep ✅")
        }

        // Have some data but no sleep
        if s.steps != nil || s.restingHeartRate != nil {
            return .good("Looking good! ✅")
        }

        return .noData
    }
}
