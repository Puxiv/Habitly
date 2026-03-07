import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let speechManager: SpeechManager
    let speechLocale: Locale

    private var isUser: Bool { message.role == .user }
    private var isSpeakingThis: Bool { speechManager.speakingMessageId == message.id }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Text bubble
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(isUser ? .white : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            isUser
                                ? Theme.accent
                                : Theme.card,
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .overlay(
                            !isUser
                                ? RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(Theme.textTertiary.opacity(0.2), lineWidth: 1)
                                : nil
                        )
                }

                // Tool action confirmation cards
                ForEach(message.toolActions) { action in
                    ToolActionCardView(action: action)
                }

                // Timestamp + speaker button row
                HStack(spacing: 6) {
                    Text(timeText)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)

                    if !isUser, !message.content.isEmpty {
                        Button {
                            if isSpeakingThis {
                                speechManager.stopSpeaking()
                            } else {
                                speechManager.speak(message.content, locale: speechLocale, messageId: message.id)
                            }
                        } label: {
                            Image(systemName: isSpeakingThis ? "speaker.wave.2.fill" : "speaker.fill")
                                .font(.caption2)
                                .foregroundStyle(isSpeakingThis ? Theme.accent : Theme.textSecondary)
                                .symbolEffect(.variableColor.iterative, isActive: isSpeakingThis)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(action.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: iconName)
                .foregroundStyle(accentColor)
                .font(.body.weight(.semibold))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.card)
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
        case .noteCreated:      return Theme.accent
        case .habitCreated:     return Theme.accent
        }
    }
}
