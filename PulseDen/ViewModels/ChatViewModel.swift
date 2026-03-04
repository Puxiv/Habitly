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

    /// Raw API conversation (includes tool_use / tool_result plumbing invisible to user)
    private var apiMessages: [ClaudeMessagePayload] = []

    private let service = ClaudeAPIService.shared

    private init() {}

    // MARK: - Send Message

    func sendMessage(
        lang: LanguageManager,
        habits: [Habit],
        reminders: [Reminder],
        stuffItems: [StuffItem],
        healthVM: HealthViewModel,
        stocksVM: StocksViewModel,
        newsVM: NewsViewModel,
        modelContext: ModelContext
    ) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        apiMessages.append(ClaudeMessagePayload(role: "user", content: .text(text)))
        isLoading = true

        do {
            let systemPrompt = buildSystemPrompt(
                lang: lang,
                habits: habits,
                reminders: reminders,
                stuffItems: stuffItems,
                healthVM: healthVM,
                stocksVM: stocksVM,
                newsVM: newsVM
            )

            // Tool-use loop
            var toolActions: [ChatMessage.ToolAction] = []
            var iterations = 0
            let maxIterations = 3

            while iterations < maxIterations {
                let result = try await service.sendMessageWithTools(
                    systemPrompt: systemPrompt,
                    messages: apiMessages,
                    tools: ClaudeAPIService.pulseDenTools
                )

                if result.stopReason == "tool_use" {
                    // Build assistant content blocks to echo back
                    var assistantBlocks: [ClaudeMessagePayload.ContentBlock] = []
                    var toolResultBlocks: [ClaudeMessagePayload.ContentBlock] = []

                    for block in result.contentBlocks {
                        switch block {
                        case .text(let t):
                            assistantBlocks.append(.text(t))
                        case .toolUse(let tu):
                            // Echo the tool_use block back
                            assistantBlocks.append(.toolUse(id: tu.id, name: tu.name, input: tu.input))

                            // Execute the tool
                            let (success, action) = executeToolUse(tu, modelContext: modelContext)
                            if let action { toolActions.append(action) }

                            // Build tool_result
                            toolResultBlocks.append(.toolResult(
                                toolUseId: tu.id,
                                content: success ? "Success: \(action?.title ?? "done")" : "Error: could not create item"
                            ))
                        }
                    }

                    // Append assistant message with tool_use to API conversation
                    apiMessages.append(ClaudeMessagePayload(role: "assistant", content: .blocks(assistantBlocks)))
                    // Append tool results as user message
                    apiMessages.append(ClaudeMessagePayload(role: "user", content: .blocks(toolResultBlocks)))

                    iterations += 1
                } else {
                    // end_turn: extract text, create final display message
                    let textParts = result.contentBlocks.compactMap { block -> String? in
                        if case .text(let t) = block { return t }
                        return nil
                    }
                    let finalText = textParts.joined()

                    let assistantMessage = ChatMessage(role: .assistant, content: finalText, toolActions: toolActions)
                    messages.append(assistantMessage)

                    // Also track in API messages for future turns
                    apiMessages.append(ClaudeMessagePayload(role: "assistant", content: .text(finalText)))
                    break
                }
            }

            // Safety: if we hit max iterations, show what we have
            if iterations >= maxIterations {
                let msg = ChatMessage(
                    role: .assistant,
                    content: toolActions.isEmpty ? "I tried to help but ran into a loop. Please try again." : "Done!",
                    toolActions: toolActions
                )
                messages.append(msg)
                apiMessages.append(ClaudeMessagePayload(role: "assistant", content: .text(msg.content)))
            }

        } catch let error as ChatError {
            errorMessage = error.errorDescription
            messages.append(ChatMessage(role: .assistant, content: "⚠️ \(error.errorDescription ?? "Something went wrong.")"))
        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatMessage(role: .assistant, content: "⚠️ \(error.localizedDescription)"))
        }

        isLoading = false
    }

    func clearChat() {
        messages.removeAll()
        apiMessages.removeAll()
        errorMessage = nil
    }

    // MARK: - Tool Executors

    private func executeToolUse(
        _ toolUse: ClaudeToolUse,
        modelContext: ModelContext
    ) -> (success: Bool, action: ChatMessage.ToolAction?) {
        switch toolUse.name {
        case "create_reminder":
            return executeCreateReminder(toolUse.input, modelContext: modelContext)
        case "create_note":
            return executeCreateNote(toolUse.input, modelContext: modelContext)
        case "create_habit":
            return executeCreateHabit(toolUse.input, modelContext: modelContext)
        default:
            return (false, nil)
        }
    }

    // MARK: Create Reminder

    private func executeCreateReminder(
        _ input: [String: JSONValue],
        modelContext: ModelContext
    ) -> (Bool, ChatMessage.ToolAction?) {
        guard let title = input["title"]?.stringValue else { return (false, nil) }

        let emoji = input["emoji"]?.stringValue ?? "🔔"
        let note = input["note"]?.stringValue ?? ""

        guard let dateStr = input["date_time"]?.stringValue,
              let dateTime = parseFlexibleDate(dateStr) else {
            return (false, nil)
        }

        let repeatOption: ReminderRepeat = {
            switch input["repeat_option"]?.stringValue {
            case "daily":   return .daily
            case "weekly":  return .weekly(weekdays: [2, 3, 4, 5, 6]) // Mon-Fri default
            case "monthly": return .monthly(dayOfMonth: Calendar.current.component(.day, from: dateTime))
            default:        return .once
            }
        }()

        let vm = RemindersViewModel(modelContext: modelContext)
        vm.addReminder(title: title, emoji: emoji, note: note, dateTime: dateTime, repeatOption: repeatOption)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let subtitle = formatter.string(from: dateTime)

        return (true, ChatMessage.ToolAction(
            type: .reminderCreated,
            title: title,
            emoji: emoji,
            subtitle: subtitle
        ))
    }

    // MARK: Create Note (Stuff Item)

    private func executeCreateNote(
        _ input: [String: JSONValue],
        modelContext: ModelContext
    ) -> (Bool, ChatMessage.ToolAction?) {
        guard let title = input["title"]?.stringValue else { return (false, nil) }

        let emoji = input["emoji"]?.stringValue ?? "📌"
        let note = input["note"]?.stringValue ?? ""
        let rating = input["rating"]?.intValue ?? 3

        let category: StuffCategory = {
            guard let raw = input["category"]?.stringValue else { return .other }
            return StuffCategory(rawValue: raw) ?? .other
        }()

        let vm = StuffViewModel(modelContext: modelContext)
        vm.addItem(title: title, emoji: emoji, note: note, category: category, rating: rating, imageData: nil)

        let subtitle = "\(category.emoji) \(category.rawValue.capitalized)"

        return (true, ChatMessage.ToolAction(
            type: .noteCreated,
            title: title,
            emoji: emoji,
            subtitle: subtitle
        ))
    }

    // MARK: Create Habit

    private func executeCreateHabit(
        _ input: [String: JSONValue],
        modelContext: ModelContext
    ) -> (Bool, ChatMessage.ToolAction?) {
        guard let name = input["name"]?.stringValue else { return (false, nil) }

        let emoji = input["emoji"]?.stringValue ?? "✅"

        let frequency: Frequency = {
            if input["frequency"]?.stringValue == "weekdays",
               let days = input["weekdays"]?.arrayValue {
                let intDays = days.compactMap { $0.intValue }
                return intDays.isEmpty ? .daily : .weekdays(intDays)
            }
            return .daily
        }()

        let vm = HabitsViewModel(modelContext: modelContext)
        vm.addHabit(
            name: name,
            emoji: emoji,
            accentColorHex: "#007AFF",
            frequency: frequency,
            sortOrder: 0,
            allowsMultiple: false,
            dailyTarget: 8
        )

        let subtitle = frequency.displayName

        return (true, ChatMessage.ToolAction(
            type: .habitCreated,
            title: name,
            emoji: emoji,
            subtitle: subtitle
        ))
    }

    // MARK: - Date Parsing

    private func parseFlexibleDate(_ string: String) -> Date? {
        // Try ISO 8601 first
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: string) { return d }

        // Try without timezone
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        for fmt in formats {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_US_POSIX")
            if let d = df.date(from: string) { return d }
        }
        return nil
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(
        lang: LanguageManager,
        habits: [Habit],
        reminders: [Reminder],
        stuffItems: [StuffItem],
        healthVM: HealthViewModel,
        stocksVM: StocksViewModel,
        newsVM: NewsViewModel
    ) -> String {
        var parts: [String] = []

        // Base personality — Пучо
        parts.append("""
        You are Pucho (Пучо) — the fun, loyal AI sidekick built into PulseDen, a personal life dashboard app.
        Pucho is cheerful, witty, a bit cheeky, and always encouraging. You talk like a supportive best friend, not a robot.
        Use emojis generously 🐾🌱✨💪📈❤️🔥. Keep answers concise, punchy, and fun.
        You know the user's habits, reminders, saved items, health data, stocks, and news — reference them to give personalized advice.
        You help with: habit coaching, reminder management, health insights, stock analysis, news chat, and general motivation.
        Always introduce yourself as Pucho if the user asks your name.
        """)

        // Tool usage instructions
        let now = ISO8601DateFormatter().string(from: Date())
        parts.append("""
        You have tools available to create reminders, notes (saved items), and habits for the user.
        When the user asks you to create, add, save, remind, or track something, use the appropriate tool.
        Always respond naturally alongside the tool use — confirm what you did.
        The current date and time is: \(now).
        When the user says "tomorrow", compute the actual date. When they say "9am", use the appropriate time.
        Pick an appropriate emoji for items when the user doesn't specify one.
        """)

        // Dialect instructions
        switch lang.current {
        case .northwestern:
            var dialectPrompt = """
            IMPORTANT: Ти си асистент, който говори изключително на врачански диалект от Северозападна България.

            ПРАВИЛА:
            1. Използвай САМО одобрените диалектни думи от речника по-долу.
            2. Никога не заменяй диалектни думи с книжовни еквиваленти, освен ако диалектна дума не съществува.
            3. Поддържай автентичния тон — пряк, експресивен, колоритен.
            4. Местоимения: язе/я (аз), тизе (ти), тава (това).
            5. Глаголи: яла (ела), сакам/очем (искам), оти (защо), лазда (може би).
            6. Обръщения: баче (към всеки), жено мънинка (гальовно).
            7. Пиши на кирилица. Бъди пряк и автентичен, като на съсед.
            8. Use 'А' instead of 'ъ' in words like 'днескА', 'съм' → 'сам'.

            ПРИМЕРИ:
            User: Как си?
            Assistant: Е па язе съм си добре, баче! А тизе кво?

            User: Какво правиш?
            Assistant: Онодвам тука, лазда ше излезна удвъде малко.

            User: Защо закъсня?
            Assistant: Оти са спрепах на тоя ръпаяк, дееба го!

            User: Довиждане
            Assistant: Връй пикай, па легай! Яла сам утре пак.
            """
            if let vocab = Self.loadVrachanskiVocabulary() {
                dialectPrompt += "\n\nОДОБРЕН РЕЧНИК:\n\(vocab)"
            }
            parts.append(dialectPrompt)
        case .shopluk:
            var dialectPrompt = """
            IMPORTANT: Ти си асистент, който говори изключително на пернишко-шопски диалект.

            ЗАДЪЛЖИТЕЛНИ ГРАМАТИЧНИ ПРАВИЛА:
            1. "яз" вместо "аз" (ВИНАГИ).
            2. Бъдеще с "че": "яз че дойдем" вместо "ще дойда" (НИКОГА не ползвай "ще"!).
            3. Само "е" от ят: "бел", "снег", "лево" (НИКОГА "бял", "сняг", "ляво").
            4. "ч" вместо "шт": "ноч", "свеч".
            5. "у" от старото носово: "зуп", "рука", "нугу".
            6. Членна форма -о за мъжки: "путето", "братко".
            7. "он/она/оно" вместо "той/тя/то".
            8. Пиши на кирилица. Бъди пряк и жив, като перничанин.

            ПРИМЕРИ:
            User: Как си?
            Assistant: Яз съм добре, а ти? Са какво правиш?

            User: Какво ще правиш довечера?
            Assistant: Яз че седим вкъщи синочка. Млого съм уморен.

            User: Кога ще дойдеш?
            Assistant: Че дойдем са, само чакай малко.

            User: Довиждане!
            Assistant: Ела пак! Яз че съм тука.
            """
            if let vocab = Self.loadPernikVocabulary() {
                dialectPrompt += "\n\nОДОБРЕН РЕЧНИК:\n\(vocab)"
            }
            parts.append(dialectPrompt)
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

        // Health context
        if healthVM.isAuthorized, let s = healthVM.summary {
            var healthLines: [String] = []
            if let sleep = s.sleepHours {
                let status = sleep >= 7 ? "✅ good" : sleep >= 5 ? "⚠️ low" : "🔴 very low"
                healthLines.append("Sleep last night: \(s.sleepText) (\(status))")
            }
            if let rhr = s.restingHeartRate {
                let status = rhr > 100 ? "⚠️ elevated" : "✅ normal"
                healthLines.append("Resting heart rate: \(Int(rhr)) bpm (\(status))")
            }
            if let hr = s.latestHeartRate {
                healthLines.append("Latest heart rate: \(Int(hr)) bpm")
            }
            if let steps = s.steps {
                healthLines.append("Steps today: \(steps.formatted())")
            }
            if let cal = s.activeCalories {
                healthLines.append("Active calories: \(Int(cal)) kcal")
            }
            if !healthLines.isEmpty {
                parts.append("HEALTH DATA (from Apple Health):\n" + healthLines.joined(separator: "\n"))
                parts.append("""
                When discussing health: note if sleep is low (<7h), praise good sleep (≥7h), flag elevated heart rate (>100 bpm).
                You can suggest better sleep habits, activity goals, or comment on their step count.
                Always remind the user you're not a doctor and they should consult a medical professional for health concerns.
                """)
            }
        } else {
            parts.append("Health data: not connected. The user hasn't linked Apple Health yet.")
        }

        // Stocks context
        if !stocksVM.quotes.isEmpty {
            let stockLines = stocksVM.quotes.prefix(20).map { q in
                "\(q.symbol) (\(q.shortName)): \(q.priceText) \(q.changePercentText)"
            }.joined(separator: "\n")
            parts.append("STOCK WATCHLIST:\n" + stockLines)

            let movers = stocksVM.topMovers
            if !movers.isEmpty {
                parts.append("TOP MOVERS TODAY: " + movers.map { "\($0.symbol) \($0.changePercentText)" }.joined(separator: ", "))
            }

            parts.append("""
            When discussing stocks: mention notable movers, comment on big gains/losses, and relate to the user's portfolio.
            You can discuss general market trends but always remind the user this is not financial advice.
            Never recommend specific buy/sell actions — only provide observations and general information.
            """)
        } else if !stocksVM.symbols.isEmpty {
            parts.append("The user has stocks in their watchlist (\(stocksVM.symbols.joined(separator: ", "))) but quotes haven't loaded yet.")
        } else {
            parts.append("The user has no stocks in their watchlist yet.")
        }

        // News context
        let allNews = newsVM.worldNews + newsVM.bulgarianNews
        if !allNews.isEmpty {
            var newsLines: [String] = []
            if !newsVM.worldNews.isEmpty {
                newsLines.append("WORLD NEWS:")
                for article in newsVM.worldNews.prefix(5) {
                    newsLines.append("• \(article.title) (\(article.sourceName), \(article.timeAgoText))")
                }
            }
            if !newsVM.bulgarianNews.isEmpty {
                newsLines.append("BULGARIAN NEWS:")
                for article in newsVM.bulgarianNews.prefix(5) {
                    newsLines.append("• \(article.title) (\(article.sourceName), \(article.timeAgoText))")
                }
            }
            parts.append(newsLines.joined(separator: "\n"))
            parts.append("When discussing news: you can reference these headlines, summarize key events, and offer context. Do not fabricate news or claim sources you haven't seen.")
        } else if newsVM.hasApiKey {
            parts.append("The user has a news feed configured but no articles have loaded yet.")
        } else {
            parts.append("The user has not set up the news feed yet.")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Pucho Dashboard Prompts 🐾

    static func randomPrompt(lang: LanguageManager) -> String {
        let prompts: [String]
        switch lang.current {
        case .english:
            prompts = [
                "Pucho knows your habits! Ask me 🐾",
                "Need motivation? Pucho's got you! 💪",
                "Let's check those stocks together! 📈",
                "Pucho says: check your health stats! ❤️",
                "Hey! Want me to set a reminder? 🔔",
                "Tell Pucho what to save! 📌",
                "Pucho is bored. Talk to me! 🐾",
                "Your sidekick is ready! What's up? 🔥",
            ]
        case .bulgarian:
            prompts = [
                "Пучо знае навиците ти! Питай ме 🐾",
                "Трябва ти мотивация? Пучо е тук! 💪",
                "Да видим как са акциите! 📈",
                "Пучо казва: провери здравето си! ❤️",
                "Искаш ли напомняне? Кажи на Пучо! 🔔",
                "Кажи на Пучо какво да запише! 📌",
                "Пучо скучае. Говори ми! 🐾",
                "Помощникът ти е готов! Какво има? 🔥",
            ]
        case .northwestern:
            prompts = [
                "Яла, баче! Пучо е тука! 🐾",
                "Е па къ, Пучо сам тука за теа! 💪",
                "Кеф на буци! Как са акциите? 📈",
                "Пучо а ти каже нешту арно! 📣",
                "Секи ден Пучо е тука, баче! 🔔",
                "Епа кво онодваш, сакаш помощ? 🌱",
                "Дии, яла да видим навиците! ✅",
                "Живота е сурав и курав! 😄",
                "Пучо е наглъфан с лафове за теа! 🗣️",
                "Пълен сам с акъл, баче! 🧠",
            ]
        case .shopluk:
            prompts = [
                "Пучо е тука, питай! 🐾",
                "Са какво че правим? Пучо чека! 💪",
                "Пучо чека да видим акциите! 📈",
                "Яз че ти помогнем! Пучо е верен! 📣",
                "Кой се млого вали, он не пали! 🗣️",
                "Емчи се ко вол у яръм! 😄",
                "Дунята че се сврши, будалете че остану! 🌍",
                "Живее ко бубрег у мас! 💎",
                "Огняне, Пучо че ти го обясни! 🔥",
                "Са да си опраймо есапите! ✅",
            ]
        }
        return prompts.randomElement() ?? prompts[0]
    }

    // MARK: - Vrachanski Vocabulary Loader

    private static func loadVrachanskiVocabulary() -> String? {
        guard let url = Bundle.main.url(forResource: "vrachanski_vocabulary", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content
    }

    private static func loadPernikVocabulary() -> String? {
        guard let url = Bundle.main.url(forResource: "pernik_vocabulary", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content
    }
}
