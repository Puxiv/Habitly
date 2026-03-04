import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Environment(ChatViewModel.self) var chatVM
    @Environment(HealthViewModel.self) var healthVM
    @Environment(StocksViewModel.self) var stocksVM
    @Environment(NewsViewModel.self) var newsVM

    @Query(sort: \Habit.sortOrder, order: .forward) private var habits: [Habit]
    @Query(sort: \Reminder.dateTime, order: .forward) private var reminders: [Reminder]
    @Query(sort: \StuffItem.createdAt, order: .reverse) private var stuffItems: [StuffItem]

    @FocusState private var isInputFocused: Bool
    @State private var speechManager = SpeechManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if chatVM.messages.isEmpty {
                                welcomeView
                                    .padding(.top, 40)
                            }

                            ForEach(chatVM.messages) { msg in
                                ChatBubbleView(message: msg)
                                    .id(msg.id)
                            }

                            if chatVM.isLoading {
                                typingIndicator
                                    .id("loading")
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: chatVM.messages.count) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            if chatVM.isLoading {
                                proxy.scrollTo("loading", anchor: .bottom)
                            } else if let last = chatVM.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: chatVM.isLoading) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            if chatVM.isLoading {
                                proxy.scrollTo("loading", anchor: .bottom)
                            } else if let last = chatVM.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lang.chatTitle)
            .onAppear { speechManager.requestAuthorization() }
            .toolbar {
                if !chatVM.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            chatVM.clearChat()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.45, green: 0.40, blue: 0.90),
                                 Color(red: 0.60, green: 0.35, blue: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(lang.chatWelcome)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            if !hasApiKey {
                noApiKeyBanner
            }

            // Quick prompt suggestions
            VStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        chatVM.inputText = prompt
                    } label: {
                        Text(prompt)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - No API Key Banner

    private var noApiKeyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
            Text(lang.chatNoApiKey)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Input Bar

    @ViewBuilder
    private var inputBar: some View {
        @Bindable var vm = chatVM
        VStack(spacing: 0) {
            // Live transcript overlay
            if speechManager.isListening, !speechManager.transcript.isEmpty {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text(speechManager.transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground))
            }

            HStack(spacing: 8) {
                TextField(lang.chatPlaceholder, text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)

                // Mic button
                Button {
                    if speechManager.isListening {
                        let text = speechManager.stopListening()
                        if !text.isEmpty {
                            chatVM.inputText += (chatVM.inputText.isEmpty ? "" : " ") + text
                        }
                    } else {
                        speechManager.startListening(locale: speechLocale)
                    }
                } label: {
                    Image(systemName: speechManager.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 20))
                        .foregroundStyle(speechManager.isListening ? .red : .secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }

                // Send button
                Button {
                    // Stop speech if active before sending
                    if speechManager.isListening {
                        let text = speechManager.stopListening()
                        if !text.isEmpty {
                            chatVM.inputText += (chatVM.inputText.isEmpty ? "" : " ") + text
                        }
                    }
                    Task {
                        await chatVM.sendMessage(
                            lang: lang,
                            habits: habits,
                            reminders: reminders,
                            stuffItems: stuffItems,
                            healthVM: healthVM,
                            stocksVM: stocksVM,
                            newsVM: newsVM,
                            modelContext: modelContext
                        )
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? Color(red: 0.35, green: 0.75, blue: 0.65) : .gray.opacity(0.4))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .scaleEffect(chatVM.isLoading ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: chatVM.isLoading
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !chatVM.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !chatVM.isLoading
        && hasApiKey
    }

    private var hasApiKey: Bool {
        guard let key = UserDefaults.standard.string(forKey: "claude_api_key") else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var speechLocale: Locale {
        switch lang.current {
        case .english: return Locale(identifier: "en-US")
        case .bulgarian, .northwestern, .shopluk: return Locale(identifier: "bg-BG")
        }
    }

    private var quickPrompts: [String] {
        switch lang.current {
        case .english:
            return ["Pucho, how are my habits? 🌱",
                    "What did I miss? ⏰",
                    "Pucho, motivate me! 💪"]
        case .bulgarian:
            return ["Пучо, как съм с навиците? 🌱",
                    "Какво съм пропуснал? ⏰",
                    "Пучо, мотивирай ме! 💪"]
        case .northwestern:
            return ["Пучо, как сам с навиците? 🌱",
                    "Шо сам пропуснАл? ⏰",
                    "Пучо, мотивирай ме! 💪"]
        case .shopluk:
            return ["Пучо, как съм с навиците? 🌱",
                    "Шо съм пропуснал? ⏰",
                    "Пучо, мотивирай ме! 💪"]
        }
    }
}
