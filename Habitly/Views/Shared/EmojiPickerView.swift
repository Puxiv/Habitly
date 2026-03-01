import SwiftUI

// MARK: - Preset emoji list (72 across 9 categories)

private let presetEmojis: [String] = [
    // 🔥 Motivation
    "✅", "⭐", "🏆", "🎯", "🔥", "💡", "🚀", "⚡",
    // 💪 Fitness
    "💪", "🏃", "🧘", "🏋️", "🚴", "🏊", "🤸", "🥊",
    // 🌿 Outdoors
    "🚶", "🧗", "⛰️", "🌲", "🌿", "🌸", "🌊", "☀️",
    // 💧 Food & Drink
    "💧", "🍎", "🥗", "🥦", "☕", "🍵", "🥤", "🫐",
    "🥑", "🍳", "🥜", "🍇",
    // 🧠 Mind & Skills
    "📚", "📖", "✍️", "🧠", "🎨", "🎵", "🎮", "🧩",
    "💻", "📝", "🗓️", "⏰",
    // 😴 Wellness
    "😴", "🌙", "🌅", "💊", "💆", "🧹", "🪥", "🛁",
    // 🎉 Good Vibes
    "🎉", "🙏", "❤️", "😊", "🌈", "🦋", "🥰", "🫶",
    // 🐾 Animals
    "🐕", "🐈", "🐠", "🦁", "🐨", "🦊", "🐸", "🐧",
    // 🏠 Life
    "💰", "📱", "🏠", "🚗", "✈️", "🎓", "👔", "🎁",
]

// MARK: - Emoji grid sheet

private struct EmojiGridSheet: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool
    @Environment(LanguageManager.self) var lang

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(presetEmojis, id: \.self) { e in
                        Button {
                            selectedEmoji = e
                            isPresented = false
                        } label: {
                            Text(e)
                                .font(.system(size: 30))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(
                                    selectedEmoji == e
                                        ? Color.blue.opacity(0.15)
                                        : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            selectedEmoji == e ? Color.blue : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(lang.pickEmoji)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.done) { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Public view

struct EmojiPickerView: View {
    @Binding var emoji: String
    @Environment(LanguageManager.self) var lang
    @State private var showPicker = false

    var body: some View {
        HStack(spacing: 16) {
            // Emoji preview button
            Button { showPicker = true } label: {
                Text(emoji)
                    .font(.system(size: 34))
                    .frame(width: 56, height: 56)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Label button
            Button { showPicker = true } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.emojiLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lang.tapToChange)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) {
            EmojiGridSheet(selectedEmoji: $emoji, isPresented: $showPicker)
        }
    }
}
