import Foundation
import Observation
import SwiftData

// MARK: - Chat View Model

@MainActor
@Observable
final class ChatViewModel {
    static let shared = ChatViewModel()

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    private let service = ClaudeAPIService.shared

    private init() {}

    // MARK: - Send Message

    func sendMessage(
        lang: LanguageManager,
        habits: [Habit],
        reminders: [Reminder],
        stuffItems: [StuffItem]
    ) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isLoading = true

        do {
            let systemPrompt = buildSystemPrompt(
                lang: lang,
                habits: habits,
                reminders: reminders,
                stuffItems: stuffItems
            )
            let reply = try await service.sendMessage(
                systemPrompt: systemPrompt,
                messages: messages
            )
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch let error as ChatError {
            errorMessage = error.errorDescription
            // Add a friendly error bubble so user sees it in chat
            messages.append(ChatMessage(role: .assistant, content: "⚠️ \(error.errorDescription ?? "Something went wrong.")"))
        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatMessage(role: .assistant, content: "⚠️ \(error.localizedDescription)"))
        }

        isLoading = false
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(
        lang: LanguageManager,
        habits: [Habit],
        reminders: [Reminder],
        stuffItems: [StuffItem]
    ) -> String {
        var parts: [String] = []

        // Base personality
        parts.append("""
        You are the built-in AI assistant for PulseDen — a personal organizer app with habits, reminders, and saved items.
        Be fun, friendly, and helpful! Use emojis generously 🌱✨💪. Keep answers concise but useful.
        The user is chatting with you inside the app. You can reference their data below to give personalized advice.
        """)

        // Dialect instructions
        switch lang.current {
        case .northwestern:
            parts.append("""
            IMPORTANT: The user has selected Northwestern Bulgarian dialect (Vratchanski).
            You MUST respond in Bulgarian using Vratchanski dialect words and style.
            Use these dialect words naturally: Арно (добре/хубаво), Оти (защото), Де (къде),
            Тури (сложи), Цъкни (натисни), Епа (е/ами), Па (пък), Секи (всеки),
            Нема (няма), Сакам (искам/обичам).
            Write in Cyrillic. Be warm and folksy, like talking to a neighbor. Use 'А' instead of 'ъ' in words like 'днескА', 'съм' → 'сам'.
            """)
        case .shopluk:
            parts.append("""
            IMPORTANT: The user has selected Pernishko dialect (Shopluk).
            You MUST respond in Bulgarian using Pernishko dialect words and style.
            Use these dialect words naturally: Епа (е/ами), Шо (какво/що), У (в),
            Сабале (сутрин/утре), Арно (добре), Немой (недей), Саглам (здраво/яко),
            Нема (няма), Туке (тук), Ше (ще).
            Write in Cyrillic. Be direct and lively, like a Pernik local.
            """)
        case .bulgarian:
            parts.append("""
            The user has selected Bulgarian language. Respond in standard Bulgarian (Cyrillic).
            Be friendly and use a conversational Bulgarian tone.
            """)
        case .english:
            break // Default English, no extra instruction
        }

        // Habits context
        if !habits.isEmpty {
            let habitLines = habits.prefix(15).map { h in
                "\(h.emoji) \(h.name)"
            }.joined(separator: ", ")
            parts.append("USER'S HABITS: \(habitLines)")
        } else {
            parts.append("The user has no habits yet. Encourage them to create some!")
        }

        // Reminders context
        let upcoming = reminders.filter { !$0.isCompleted && $0.dateTime >= Date() }
        let overdue = reminders.filter { !$0.isCompleted && $0.dateTime < Date() }
        if !upcoming.isEmpty {
            let lines = upcoming.prefix(10).map { "\($0.emoji) \($0.title)" }.joined(separator: ", ")
            parts.append("UPCOMING REMINDERS: \(lines)")
        }
        if !overdue.isEmpty {
            let lines = overdue.prefix(5).map { "\($0.emoji) \($0.title)" }.joined(separator: ", ")
            parts.append("⚠️ OVERDUE REMINDERS: \(lines)")
        }

        // Stuff context
        let active = stuffItems.filter { !$0.isArchived }
        if !active.isEmpty {
            let lines = active.prefix(10).map { "\($0.emoji) \($0.title)" }.joined(separator: ", ")
            parts.append("SAVED ITEMS: \(lines)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Dashboard Fun Prompts

    static func randomPrompt(lang: LanguageManager) -> String {
        let prompts: [String]
        switch lang.current {
        case .english:
            prompts = [
                "Ask me about your habits! 🌱",
                "Need motivation? I got you! 💪",
                "What should I remind you about? 🔔",
                "Let's chat about your goals! 🎯",
                "I'm your personal cheerleader! 📣",
            ]
        case .bulgarian:
            prompts = [
                "Питай ме за навиците си! 🌱",
                "Нуждаеш се от мотивация? 💪",
                "За какво да ти напомня? 🔔",
                "Да поговорим за целите ти! 🎯",
                "Аз съм твоят фен #1! 📣",
            ]
        case .northwestern:
            prompts = [
                "Епа питай ме нещо! 🌱",
                "Де ти е мотивацията? Тука сам! 💪",
                "Сакаш ли да поприказваме? 🎯",
                "Арно, кажи шо ти треа! 📣",
                "Секи ден сам тука за теа! 🔔",
            ]
        case .shopluk:
            prompts = [
                "Епа питай нещо! 🌱",
                "Шо ше правим днеска? 💪",
                "Немой се притеснявай, питай! 🎯",
                "Арно, кажи шо ти треа! 📣",
                "Туке сам за теа! 🔔",
            ]
        }
        return prompts.randomElement() ?? prompts[0]
    }
}
