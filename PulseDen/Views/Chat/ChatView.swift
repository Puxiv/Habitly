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
                                ChatBubbleView(message: msg, speechManager: speechManager, speechLocale: speechLocale)
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

                Divider().overlay(Theme.textTertiary.opacity(0.3))

                inputBar
            }
            .background(Theme.background)
            .navigationTitle(lang.chatTitle)
            .onAppear { speechManager.requestAuthorization() }
            .onChange(of: chatVM.isLoading) { wasLoading, isLoading in
                if wasLoading && !isLoading && lang.autoSpeak,
                   let last = chatVM.messages.last, last.role == .assistant,
                   !last.content.isEmpty, !last.content.hasPrefix("⚠️") {
                    speechManager.speak(last.content, locale: speechLocale, messageId: last.id)
                }
            }
            .toolbar {
                if !chatVM.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            speechManager.stopSpeaking()
                            chatVM.clearChat()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(lang.chatWelcome)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 40)

            if !hasApiKey {
                noApiKeyBanner
            }

            VStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        chatVM.inputText = prompt
                    } label: {
                        Text(prompt)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Theme.card, in: Capsule())
                            .foregroundStyle(.white)
                            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.2), lineWidth: 1))
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
                .foregroundStyle(Theme.textSecondary)
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
            if let micError = speechManager.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(micError)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button {
                        speechManager.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
            }

            if speechManager.isListening, !speechManager.transcript.isEmpty {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text(speechManager.transcript)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Theme.card)
            }

            HStack(spacing: 8) {
                TextField(lang.chatPlaceholder, text: $vm.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Theme.textTertiary.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isInputFocused)

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
                        .foregroundStyle(speechManager.isListening ? .red : Theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }

                Button {
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
                        .foregroundStyle(canSend ? Theme.accent : Theme.textTertiary.opacity(0.4))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.accent.opacity(0.5))
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
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
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
        case .bulgarian, .northwestern, .shopluk, .plovdiv, .burgas: return Locale(identifier: "bg-BG")
        }
    }

    private var quickPrompts: [String] {
        let n = lang.aiName
        switch lang.current {
        case .english:
            return ["\(n), how are my habits? 🌱",
                    "What did I miss? ⏰",
                    "\(n), motivate me! 💪"]
        case .bulgarian:
            return ["\(n), как съм с навиците? 🌱",
                    "Какво съм пропуснал? ⏰",
                    "\(n), мотивирай ме! 💪"]
        case .northwestern:
            return ["\(n), как сам с навиците? 🌱",
                    "Шо сам пропуснАл? ⏰",
                    "\(n), мотивирай ме! 💪"]
        case .shopluk:
            return ["\(n), как съм с навиците? 🌱",
                    "Шо съм пропуснал? ⏰",
                    "\(n), мотивирай ме! 💪"]
        case .plovdiv:
            return ["\(n), как съм с навиците бе? 🌱",
                    "Кво съм пропуснал бе? ⏰",
                    "\(n), майна, мотивирай ме! 💪"]
        case .burgas:
            return ["\(n), как съм с навиците батка? 🌱",
                    "Кво съм пропуснал батка? ⏰",
                    "\(n), море, мотивирай ме! 💪"]
        }
    }
}
