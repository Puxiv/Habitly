import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
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
