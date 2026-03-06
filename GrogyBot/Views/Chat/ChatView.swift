import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Environment(ChatViewModel.self) var chatVM
    @Environment(HealthViewModel.self) var healthVM
    @Environment(StocksViewModel.self) var stocksVM
    @Environment(NewsViewModel.self) var newsVM
    @Environment(WeatherViewModel.self) var weatherVM

    @Query(sort: \Habit.sortOrder, order: .forward) private var habits: [Habit]
    @Query(sort: \Reminder.dateTime, order: .forward) private var reminders: [Reminder]
    @Query(sort: \StuffItem.createdAt, order: .reverse) private var noteItems: [StuffItem]

    @FocusState private var isInputFocused: Bool
    @State private var speechManager = SpeechManager()
    @State private var animatingActionType: ChatMessage.ToolAction.ActionType?

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
                        // Scroll without withAnimation to avoid animation transaction
                        // conflicts with the typing indicator's repeating animation.
                        if chatVM.isLoading {
                            proxy.scrollTo("loading", anchor: .bottom)
                        } else if let last = chatVM.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: chatVM.isLoading) { wasLoading, isLoading in
                        // Scroll to latest
                        if isLoading {
                            proxy.scrollTo("loading", anchor: .bottom)
                        } else if let last = chatVM.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                        // Auto-TTS: speak response when loading finishes (voice mode OR autoSpeak)
                        if wasLoading && !isLoading,
                           let last = chatVM.messages.last, last.role == .assistant,
                           !last.content.isEmpty, !last.content.hasPrefix("⚠️") {
                            if speechManager.voiceChatMode || lang.autoSpeak {
                                speechManager.speak(last.content, locale: speechLocale, messageId: last.id)
                            }
                        }
                        // Tool action animation: play video when a tool action is created
                        if wasLoading && !isLoading,
                           let last = chatVM.messages.last,
                           let firstAction = last.toolActions.first {
                            withAnimation(.spring(duration: 0.35)) {
                                animatingActionType = firstAction.type
                            }
                        }
                    }
                }

                Divider().overlay(Theme.textTertiary.opacity(0.3))

                inputBar
            }
            .background(Theme.background)
            .navigationTitle(lang.chatTitle)
            .onAppear {
                speechManager.requestAuthorization()
                // Wire up the voice chat auto-send callback
                speechManager.onSpeechFinished = { finalText in
                    guard speechManager.voiceChatMode, !finalText.isEmpty else { return }
                    if chatVM.isLoading {
                        // Previous request still in flight — keep transcript visible
                        chatVM.inputText = finalText
                        return
                    }
                    chatVM.inputText = finalText
                    sendChat()
                }
            }
            // Loop-closing: restart listening after TTS finishes
            .onChange(of: speechManager.isSpeaking) { wasSpeaking, isSpeaking in
                if wasSpeaking && !isSpeaking && speechManager.voiceChatMode {
                    speechManager.restartListeningAfterTTS(locale: speechLocale)
                }
            }
            .toolbar {
                if !chatVM.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            exitVoiceChatMode()
                            speechManager.stopSpeaking()
                            chatVM.clearChat()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .overlay {
                ToolActionAnimationView(actionType: $animatingActionType)
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image("GrogyBotIcon")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(Circle())

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
            // Mic error banner
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

            // Voice mode status overlay
            if speechManager.voiceChatMode {
                voiceModeOverlay
            } else if speechManager.isListening, !speechManager.transcript.isEmpty {
                // Legacy dictation transcript indicator
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
                // Text field (dimmed in voice mode)
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
                    .disabled(speechManager.voiceChatMode)
                    .opacity(speechManager.voiceChatMode ? 0.4 : 1.0)

                // Stop speaking button — shown when TTS is active (not in voice mode)
                if speechManager.isSpeaking && !speechManager.voiceChatMode {
                    Button {
                        speechManager.stopSpeaking()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.red)
                    }
                }

                // Mic / Voice button
                Button {
                    handleMicTap()
                } label: {
                    Image(systemName: voiceMicIcon)
                        .font(.system(size: speechManager.voiceChatMode ? 24 : 20))
                        .foregroundStyle(voiceMicColor)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .symbolEffect(.pulse, isActive: speechManager.voiceChatMode && speechManager.isListening)
                }

                // Send button (hidden in voice mode and when speaking)
                if !speechManager.voiceChatMode && !speechManager.isSpeaking {
                    Button {
                        if speechManager.isListening {
                            let text = speechManager.stopListening()
                            if !text.isEmpty {
                                chatVM.inputText += (chatVM.inputText.isEmpty ? "" : " ") + text
                            }
                        }
                        sendChat()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? Theme.accent : Theme.textTertiary.opacity(0.4))
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
    }

    // MARK: - Voice Mode Overlay

    private var voiceModeOverlay: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(speechManager.isListening ? Theme.accent : Theme.textTertiary)
                    .frame(width: 10, height: 10)
                    .scaleEffect(speechManager.isListening ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: speechManager.isListening
                    )

                Text(voiceModeStatusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)

                Spacer()
            }

            if speechManager.isListening, !speechManager.transcript.isEmpty {
                Text(speechManager.transcript)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.card)
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

    // MARK: - Voice Chat Mode

    private func enterVoiceChatMode() {
        speechManager.voiceChatMode = true
        isInputFocused = false     // dismiss keyboard
        speechManager.startListening(locale: speechLocale)
    }

    private func exitVoiceChatMode() {
        speechManager.voiceChatMode = false
        if speechManager.isListening {
            speechManager.stopListening()
        }
        speechManager.stopSpeaking()
    }

    private func handleMicTap() {
        if speechManager.voiceChatMode {
            if speechManager.isSpeaking {
                // Interrupt TTS → start listening (stay in voice mode)
                speechManager.stopSpeaking()
                speechManager.restartListeningAfterTTS(locale: speechLocale)
            } else {
                // Exit voice mode
                exitVoiceChatMode()
            }
        } else if speechManager.isListening {
            // Legacy dictation: stop and append transcript
            let text = speechManager.stopListening()
            if !text.isEmpty {
                chatVM.inputText += (chatVM.inputText.isEmpty ? "" : " ") + text
            }
        } else {
            // Enter voice chat mode
            enterVoiceChatMode()
        }
    }

    private var voiceMicIcon: String {
        if speechManager.voiceChatMode {
            return "waveform.circle.fill"
        }
        return speechManager.isListening ? "mic.fill" : "mic"
    }

    private var voiceMicColor: Color {
        if speechManager.voiceChatMode {
            return Theme.accent
        }
        return speechManager.isListening ? .red : Theme.textSecondary
    }

    private var voiceModeStatusText: String {
        if speechManager.isListening {
            return lang.voiceListening
        } else if speechManager.isSpeaking {
            return lang.voiceSpeaking
        } else if chatVM.isLoading {
            return lang.voiceThinking
        } else {
            return lang.voiceActive
        }
    }

    // MARK: - Send

    private func sendChat() {
        // Cancel any previous in-flight request before starting a new one
        chatVM.activeTask?.cancel()

        let task = Task {
            await chatVM.sendMessage(
                lang: lang,
                habits: habits,
                reminders: reminders,
                noteItems: noteItems,
                healthVM: healthVM,
                stocksVM: stocksVM,
                newsVM: newsVM,
                weatherVM: weatherVM,
                modelContext: modelContext
            )
        }
        chatVM.activeTask = task
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
            return ["\(n), how are my habits?",
                    "What did I miss?",
                    "\(n), motivate me!"]
        case .bulgarian:
            return ["\(n), как съм с навиците?",
                    "Какво съм пропуснал?",
                    "\(n), мотивирай ме!"]
        case .northwestern:
            return ["\(n), как сам с навиците?",
                    "Шо сам пропуснАл?",
                    "\(n), мотивирай ме!"]
        case .shopluk:
            return ["\(n), как съм с навиците?",
                    "Шо съм пропуснал?",
                    "\(n), мотивирай ме!"]
        case .plovdiv:
            return ["\(n), как съм с навиците бе?",
                    "Кво съм пропуснал бе?",
                    "\(n), майна, мотивирай ме!"]
        case .burgas:
            return ["\(n), как съм с навиците батка?",
                    "Кво съм пропуснал батка?",
                    "\(n), море, мотивирай ме!"]
        }
    }
}
