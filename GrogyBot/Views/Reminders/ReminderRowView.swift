import SwiftUI

struct ReminderRowView: View {
    let reminder: Reminder
    let lang: LanguageManager

    private var stateColor: Color {
        switch reminder.state {
        case .upcoming:  return Theme.accent
        case .overdue:   return Theme.negative
        case .completed: return Theme.accent.opacity(0.6)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Title + details
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(reminder.repeatOption.displayName(language: lang.current))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(reminder.dateTime, style: .relative)
                        .font(.caption)
                        .foregroundStyle(reminder.state == .overdue ? .red : .secondary)
                }
            }

            Spacer()

            // State indicator
            switch reminder.state {
            case .upcoming:
                Image(systemName: "clock")
                    .foregroundStyle(Theme.accent)
            case .overdue:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Theme.negative)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}
