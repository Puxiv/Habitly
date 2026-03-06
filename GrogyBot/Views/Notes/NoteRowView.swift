import SwiftUI

struct NoteRowView: View {
    let item: StuffItem

    var body: some View {
        HStack(spacing: 12) {
            // Emoji circle
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(item.emoji)
                    .font(.title3)
            }

            // Title + body preview + date
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(item.isArchived ? .secondary : .primary)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                }

                if !item.plainTextBody.isEmpty {
                    Text(item.plainTextBody)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Text(item.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(item.isArchived ? 0.6 : 1.0)
    }
}
