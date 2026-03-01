import SwiftUI

struct StuffRowView: View {
    let item: StuffItem
    let lang: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            // Emoji circle
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(item.emoji)
                    .font(.title3)
            }

            // Title + category + rating
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(item.isArchived ? .secondary : .primary)

                HStack(spacing: 6) {
                    // Category badge
                    HStack(spacing: 3) {
                        Text(item.category.emoji)
                            .font(.caption2)
                        Text(item.category.displayName(language: lang.current))
                            .font(.caption)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())

                    // Star rating (compact)
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= item.rating ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(star <= item.rating ? .yellow : Color(.tertiaryLabel))
                        }
                    }
                }
            }

            Spacer()

            // Thumbnail if image exists
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
        .opacity(item.isArchived ? 0.6 : 1.0)
    }
}
