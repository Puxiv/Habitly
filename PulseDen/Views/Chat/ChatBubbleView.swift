import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Text bubble
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(isUser ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            isUser
                                ? Color(red: 0.35, green: 0.75, blue: 0.65)
                                : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }

                // Tool action confirmation cards
                ForEach(message.toolActions) { action in
                    ToolActionCardView(action: action)
                }

                // Timestamp
                Text(timeText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
    }

    private var timeText: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: message.timestamp)
    }
}

// MARK: - Tool Action Card

struct ToolActionCardView: View {
    let action: ChatMessage.ToolAction

    var body: some View {
        HStack(spacing: 10) {
            Text(action.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(action.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: iconName)
                .foregroundStyle(accentColor)
                .font(.body.weight(.semibold))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch action.type {
        case .reminderCreated:  return "bell.badge.fill"
        case .noteCreated:      return "bookmark.fill"
        case .habitCreated:     return "checkmark.seal.fill"
        }
    }

    private var accentColor: Color {
        switch action.type {
        case .reminderCreated:  return .orange
        case .noteCreated:      return .blue
        case .habitCreated:     return .green
        }
    }
}
