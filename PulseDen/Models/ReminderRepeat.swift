import Foundation

enum ReminderRepeat: Codable, Equatable {
    case once
    case daily
    case weekly(weekdays: [Int])    // Calendar.weekday: 1=Sun … 7=Sat
    case monthly(dayOfMonth: Int)   // 1-31

    // MARK: - Display

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .once:
            switch language {
            case .english:      return "Once"
            case .bulgarian:    return "Веднъж"
            case .northwestern: return "Еднъш"
            case .shopluk:      return "Еднъж"
            }
        case .daily:
            switch language {
            case .english:      return "Every day"
            case .bulgarian:    return "Всеки ден"
            case .northwestern: return "Секи ден"
            case .shopluk:      return "Секи ден"
            }
        case .weekly(let days):
            if days.isEmpty {
                switch language {
                case .english:      return "No days selected"
                case .bulgarian:    return "Няма избрани дни"
                case .northwestern: return "Нема избрани дни"
                case .shopluk:      return "Нема избрани дни"
                }
            }
            var cal = Calendar.current
            cal.locale = Locale(identifier: language == .english ? "en" : "bg")
            let symbols = cal.shortWeekdaySymbols
            return days.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
        case .monthly(let day):
            switch language {
            case .english:      return "Monthly (day \(day))"
            case .bulgarian:    return "Месечно (ден \(day))"
            case .northwestern: return "На месец (ден \(day))"
            case .shopluk:      return "На месец (ден \(day))"
            }
        }
    }

    // MARK: - Next Occurrence

    func nextOccurrence(after date: Date) -> Date? {
        let cal = Calendar.current
        switch self {
        case .once:
            return nil
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date)
        case .weekly(let weekdays):
            for offset in 1...7 {
                if let candidate = cal.date(byAdding: .day, value: offset, to: date) {
                    let wd = cal.component(.weekday, from: candidate)
                    if weekdays.contains(wd) { return candidate }
                }
            }
            return nil
        case .monthly(let dayOfMonth):
            guard let nextMonth = cal.date(byAdding: .month, value: 1, to: date) else { return nil }
            var comps = cal.dateComponents([.year, .month], from: nextMonth)
            let maxDay = cal.range(of: .day, in: .month, for: nextMonth)?.count ?? 28
            comps.day = min(dayOfMonth, maxDay)
            comps.hour = cal.component(.hour, from: date)
            comps.minute = cal.component(.minute, from: date)
            return cal.date(from: comps)
        }
    }
}
