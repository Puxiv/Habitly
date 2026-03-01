import Foundation

enum Frequency: Codable, Equatable {
    case daily
    case weekdays([Int]) // Calendar.weekday values: 1=Sun, 2=Mon, ... 7=Sat

    func isScheduled(on date: Date) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekdays(let days):
            let weekday = Calendar.current.component(.weekday, from: date)
            return days.contains(weekday)
        }
    }

    var displayName: String { displayName(language: .english) }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .daily:
            switch language {
            case .english:      return "Every day"
            case .bulgarian:    return "Всеки ден"
            case .northwestern: return "Секи ден"
            case .shopluk:      return "Секи ден"
            }
        case .weekdays(let days):
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
        }
    }
}
