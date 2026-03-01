import SwiftUI

struct ReminderRowView: View {
    let reminder: Reminder
    let lang: LanguageManager

    private var stateColor: Color {
        switch reminder.state {
        case .upcoming:  return .blue
        case .overdue:   return .red
        case .completed: return .green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji circle
            ZStack {
                Circle()
                    .fill(stateColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(reminder.emoji)
                    .font(.title3)
            }

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
                    .foregroundStyle(.blue)
            case .overdue:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
