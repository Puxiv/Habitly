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

    /// Raw API conversation (includes tool_use / tool_result plumbing invisible to user).
    /// Not observed by any view — marked ignored to prevent observation overhead / deadlock.
    @ObservationIgnored private var apiMessages: [ClaudeMessagePayload] = []

    /// Keep reference so user can cancel a running request
    @ObservationIgnored var activeTask: Task<Void, Never>?

    @ObservationIgnored private let service = ClaudeAPIService.shared

    /// Max API messages to keep (prevents context overflow)
    @ObservationIgnored private let maxApiMessages = 40

    private init() {}

    // MARK: - Send Message

    func sendMessage(
        lang: LanguageManager,
        habits: [Habit],
        reminders: [Reminder],
        noteItems: [StuffItem],
        healthVM: HealthViewModel,
        stocksVM: StocksViewModel,
        newsVM: NewsViewModel,
        weatherVM: WeatherViewModel,
        modelContext: ModelContext
    ) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        print("[Chat] sendMessage start — text: \(text.prefix(50))")

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        apiMessages.append(ClaudeMessagePayload(role: "user", content: .text(text)))

        // Trim old messages to avoid context overflow
        trimApiMessages()

        isLoading = true

        // Build system prompt (snapshot data now, before await)
        let systemPrompt = buildSystemPrompt(
            lang: lang,
            habits: habits,
            reminders: reminders,
            noteItems: noteItems,
            healthVM: healthVM,
            stocksVM: stocksVM,
            newsVM: newsVM,
            weatherVM: weatherVM
        )

        // Snapshot apiMessages for the API call (value copy, avoids mutation during await)
        let currentMessages = apiMessages
        // Capture service locally to avoid accessing self across actor boundaries
        let svc = service

        print("[Chat] calling API with \(currentMessages.count) messages")

        do {
            // Tool-use loop (also handles pause_turn for server-side tools like web search)
            var toolActions: [ChatMessage.ToolAction] = []
            var iterations = 0
            let maxIterations = 5  // increased from 3 to accommodate pause_turn continuations
            var workingMessages = currentMessages

            while iterations < maxIterations {
                // Check for cancellation
                try Task.checkCancellation()

                print("[Chat] API call iteration \(iterations)")

                // ClaudeAPIService is an actor — this call hops to its background
                // executor. Main actor is suspended (not blocked) during await.
                let result = try await svc.sendMessageWithTools(
                    systemPrompt: systemPrompt,
                    messages: workingMessages,
                    tools: ClaudeAPIService.grogyBotTools
                )

                print("[Chat] API response received — stopReason: \(result.stopReason)")

                if result.stopReason == "tool_use" {
                    // --- Client-side tool execution (create_reminder, create_note, create_habit) ---
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

                    // Append to working copy for next iteration
                    workingMessages.append(ClaudeMessagePayload(role: "assistant", content: .blocks(assistantBlocks)))
                    workingMessages.append(ClaudeMessagePayload(role: "user", content: .blocks(toolResultBlocks)))

                    iterations += 1

                } else if result.stopReason == "pause_turn" {
                    // --- Server tool still running (e.g. web search) — echo back and continue ---
                    print("[Chat] pause_turn — continuing server tool execution")
                    workingMessages.append(ClaudeMessagePayload(
                        role: "assistant",
                        content: .rawJSON(result.rawContentJSON)
                    ))
                    // Empty user message signals "continue"
                    workingMessages.append(ClaudeMessagePayload(
                        role: "user",
                        content: .text("")
                    ))
                    iterations += 1

                } else {
                    // --- end_turn: extract text, create final display message ---
                    let textParts = result.contentBlocks.compactMap { block -> String? in
                        if case .text(let t) = block { return t }
                        return nil
                    }
                    let finalText = textParts.joined()

                    let assistantMessage = ChatMessage(role: .assistant, content: finalText, toolActions: toolActions)
                    messages.append(assistantMessage)

                    // Commit working messages + final assistant to canonical apiMessages.
                    // Use rawJSON when response includes server tool blocks (web search)
                    // to preserve encrypted_content and citations for follow-up context.
                    apiMessages = workingMessages
                    let hasServerToolBlocks = result.rawContentJSON.contains { block in
                        if case .object(let dict) = block,
                           case .string(let type) = dict["type"] {
                            return type == "server_tool_use" || type == "web_search_tool_result"
                        }
                        return false
                    }
                    if hasServerToolBlocks {
                        apiMessages.append(ClaudeMessagePayload(
                            role: "assistant",
                            content: .rawJSON(result.rawContentJSON)
                        ))
                    } else {
                        apiMessages.append(ClaudeMessagePayload(
                            role: "assistant",
                            content: .text(finalText)
                        ))
                    }

                    print("[Chat] assistant reply added (\(finalText.count) chars)")
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
                // Commit everything so apiMessages stays consistent
                apiMessages = workingMessages
                apiMessages.append(ClaudeMessagePayload(role: "assistant", content: .text(msg.content)))
            }

        } catch is CancellationError {
            print("[Chat] request cancelled")
            let errMsg = "Request cancelled."
            messages.append(ChatMessage(role: .assistant, content: errMsg))
            // Keep apiMessages consistent: add placeholder assistant reply
            apiMessages.append(ClaudeMessagePayload(role: "assistant", content: .text(errMsg)))
        } catch let error as ChatError {
            let errText = error.errorDescription ?? "Something went wrong."
            print("[Chat] ChatError: \(errText)")
            errorMessage = errText
            messages.append(ChatMessage(role: .assistant, content: errText))
            // Keep apiMessages consistent: add placeholder assistant reply so next user msg is valid
            apiMessages.append(ClaudeMessagePayload(role: "assistant", content: .text(errText)))
        } catch {
            let errText = error.localizedDescription
            print("[Chat] error: \(errText)")
            errorMessage = errText
            messages.append(ChatMessage(role: .assistant, content: errText))
            apiMessages.append(ClaudeMessagePayload(role: "assistant", content: .text(errText)))
        }

        isLoading = false
        print("[Chat] sendMessage done — isLoading = false")
    }

    /// Cancel the current in-flight request
    func cancelRequest() {
        activeTask?.cancel()
        activeTask = nil
    }

    /// Trim API messages to prevent context window overflow
    private func trimApiMessages() {
        guard apiMessages.count > maxApiMessages else { return }
        // Keep the most recent messages, drop oldest
        let excess = apiMessages.count - maxApiMessages
        apiMessages.removeFirst(excess)
        // Ensure first message is from "user" (API requirement)
        while let first = apiMessages.first, first.role != "user" {
            apiMessages.removeFirst()
        }
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

    // MARK: Create Note

    private func executeCreateNote(
        _ input: [String: JSONValue],
        modelContext: ModelContext
    ) -> (Bool, ChatMessage.ToolAction?) {
        guard let title = input["title"]?.stringValue else { return (false, nil) }

        let emoji = input["emoji"]?.stringValue ?? "📝"
        let note = input["note"]?.stringValue ?? ""

        let vm = NotesViewModel(modelContext: modelContext)
        vm.addItem(title: title, emoji: emoji, note: note)

        return (true, ChatMessage.ToolAction(
            type: .noteCreated,
            title: title,
            emoji: emoji,
            subtitle: note.isEmpty ? "Note created" : String(note.prefix(40))
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
        noteItems: [StuffItem],
        healthVM: HealthViewModel,
        stocksVM: StocksViewModel,
        newsVM: NewsViewModel,
        weatherVM: WeatherViewModel
    ) -> String {
        var parts: [String] = []

        // Base personality
        let name = lang.aiName
        parts.append("""
        You are \(name) — the fun, loyal AI sidekick built into GrogyBot, a personal life dashboard app.
        \(name) is cheerful, witty, a bit cheeky, and always encouraging. You talk like a supportive best friend, not a robot.
        NEVER use emojis in your text responses — no emoticons, no unicode symbols, no emoji characters at all. NEVER use markdown formatting — no asterisks, no bold, no headers, no bullet points. Write plain text only. Keep answers concise, punchy, and fun.
        You know the user's habits, reminders, saved items, health data, stocks, and news — reference them to give personalized advice.
        You help with: habit coaching, reminder management, health insights, stock analysis, news chat, and general motivation.
        Always introduce yourself as \(name) if the user asks your name.
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

        // Web search instructions
        parts.append("""
        You also have web search capability. When the user asks about current events, recent news, real-time information, live scores, or anything outside your training data, use the web_search tool to find up-to-date information. You do not need to ask permission — just search when it would help answer the question accurately. Cite your sources when using search results.
        """)

        // Dialect instructions
        switch lang.current {
        case .northwestern:
            var dialectPrompt = """
            IMPORTANT: Ти си асистент, който говори изключително на врачански диалект (Български Пустиняк).

            ПРАВИЛА:
            1. Използвай САМО одобрените диалектни думи от речника по-долу.
            2. Никога не заменяй диалектни думи с книжовни еквиваленти, освен ако диалектна дума не съществува.
            3. Поддържай автентичния тон — пряк, експресивен, колоритен.
            4. Местоимения: язе/я (аз), тизе (ти), тава (това).
            5. Глаголи: яла (ела), сакам/очем (искам), оти (защо), лазда (може би).
            6. Обръщения: баце (към всеки), жено мънинка (гальовно).
            7. Пиши на кирилица. Бъди пряк и автентичен, като на съсед.
            8. Use 'А' instead of 'ъ' in words like 'днескА', 'съм' → 'сам'.

            ПРИМЕРИ:
            User: Как си?
            Assistant: Е па язе съм си добре, баце! А тизе кво?

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
            IMPORTANT: Ти си асистент, който говори изключително на пернишко-шопски диалект (Български Винкел).

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
        case .plovdiv:
            var dialectPrompt = """
            IMPORTANT: Ти си асистент, който говори изключително на пловдивски диалект (Български Майна, Тракийски говор).

            ЗАДЪЛЖИТЕЛНИ ПРАВИЛА:
            1. Използвай широко „а" от ят (ѣ) под ударение: хл'аб (хляб), мл'ако (мляко), б'ал (бял).
            2. Изпускай „х" в началото на думи: убаво (хубаво), ора (хора), айде (хайде).
            3. Използвай „кво" вместо „какво", „тъй" вместо „така".
            4. Обръщения: „бе" като универсална частица (към всеки).
            5. „Майна" — характерно пловдивско възклицание за учудване, одобрение, недоволство.
            6. Използвай „бая" (много), „мальо" (малко), „убаво" (хубаво), „арно" (добре).
            7. „Пусто" като интензификатор за недоволство.
            8. „Сабале" (сутрин), „вечерта" (тази вечер).
            9. Пиши на кирилица. Бъди топъл, приятелски, с типичния пловдивски шарм.
            10. Тонът е по-мек и мелодичен от западните диалекти.

            ПРИМЕРИ:
            User: Как си?
            Assistant: Майна, убаво съм бе! Ти кво правиш?

            User: Какво правиш?
            Assistant: Ей, тъй, нагоре-надолу. Бая работа има днеска.

            User: Яко е горещо днес.
            Assistant: Пусто, жега е бе! Айде на тепето вечерта, там е убаво.

            User: Довиждане!
            Assistant: Арно бе, арно! До утре!
            """
            if let vocab = Self.loadPlovdivVocabulary() {
                dialectPrompt += "\n\nОДОБРЕН РЕЧНИК:\n\(vocab)"
            }
            parts.append(dialectPrompt)
        case .burgas:
            var dialectPrompt = """
            IMPORTANT: Ти си асистент, който говори изключително на бургаски диалект (Български Батка, Крайморски говор).

            ЗАДЪЛЖИТЕЛНИ ПРАВИЛА:
            1. „е" от ят: бел (бял), хлеб (хляб), млеко (мляко), сено (сяно).
            2. Изпускай „х" в началото: убаво (хубаво), айде (хайде), ора (хора).
            3. Използвай „кво" вместо „какво", „тъй" вместо „така".
            4. „Батка" — основно обръщение (вместо „бате"), „море" — емоционално възклицание.
            5. „Ей" и „де" като чести частици.
            6. Използвай „бая" (много), „мальо" (малко), „арно" (добре), „кат" (като).
            7. „Ей сега" (веднага), „барабар" (заедно).
            8. Морска/крайбрежна лексика: хамсия, рибата, морето.
            9. Пиши на кирилица. Бъди спокоен, релаксиран, с типичния бургаски кеф.
            10. Тонът е по-протяжен, спокоен, морски.

            ПРИМЕРИ:
            User: Как си?
            Assistant: Море, батка, арно съм! Ти кво?

            User: Какво правиш?
            Assistant: Ей, тъй, на рахат съм. Бая убаво е днеска.

            User: Горещо е.
            Assistant: Море, батка, айде на морето! Ей сега тръгваме!

            User: Довиждане!
            Assistant: Арно де, батка! Ей, до утре!
            """
            if let vocab = Self.loadBurgasVocabulary() {
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

        // Habits context (if module enabled)
        if lang.moduleHabits {
            if !habits.isEmpty {
                let habitLines = habits.prefix(15).map { h in
                    h.name
                }.joined(separator: ", ")
                parts.append("USER'S HABITS: \(habitLines)")
            } else {
                parts.append("The user has no habits yet. Encourage them to create some!")
            }
        }

        // Reminders context (if module enabled)
        if lang.moduleReminders {
            let upcoming = reminders.filter { !$0.isCompleted && $0.dateTime >= Date() }
            let overdue = reminders.filter { !$0.isCompleted && $0.dateTime < Date() }
            if !upcoming.isEmpty {
                let lines = upcoming.prefix(10).map { $0.title }.joined(separator: ", ")
                parts.append("UPCOMING REMINDERS: \(lines)")
            }
            if !overdue.isEmpty {
                let lines = overdue.prefix(5).map { $0.title }.joined(separator: ", ")
                parts.append("OVERDUE REMINDERS: \(lines)")
            }
        }

        // Notes context (if module enabled)
        if lang.moduleNotes {
            let active = noteItems.filter { !$0.isArchived }
            if !active.isEmpty {
                let lines = active.prefix(10).map { $0.title }.joined(separator: ", ")
                parts.append("NOTES: \(lines)")
            }
        }

        // Health context (if module enabled)
        if lang.moduleHealth {
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
        }

        // Stocks context (if module enabled)
        if lang.moduleStocks {
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
        }

        // News context (if module enabled)
        if lang.moduleNews {
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
        }

        // Weather context (always included when available)
        if weatherVM.isLoaded, let w = weatherVM.currentWeather {
            var weatherLines: [String] = []
            weatherLines.append("Location: \(w.cityName)")
            weatherLines.append("Current: \(w.temperatureText), feels like \(Int(w.feelsLike.rounded()))°C")
            weatherLines.append("Condition: \(w.condition.displayName)")
            weatherLines.append("Humidity: \(w.humidity)%, Wind: \(Int(w.windspeed.rounded())) km/h")

            // Today's forecast
            if let today = weatherVM.dailyForecasts.first {
                weatherLines.append("Today: high \(Int(today.maxTemp.rounded()))°C, low \(Int(today.minTemp.rounded()))°C")
            }

            // Tomorrow's forecast
            if weatherVM.dailyForecasts.count > 1 {
                let tmrw = weatherVM.dailyForecasts[1]
                weatherLines.append("Tomorrow: high \(Int(tmrw.maxTemp.rounded()))°C, low \(Int(tmrw.minTemp.rounded()))°C, \(WeatherCondition.from(code: tmrw.weatherCode).displayName)")
            }

            parts.append("WEATHER DATA:\n" + weatherLines.joined(separator: "\n"))
            parts.append("When discussing weather: comment on the current conditions, suggest clothing or activities based on the forecast. You are not a meteorologist — keep it casual and helpful.")
        } else {
            parts.append("Weather data: not available. Location access may not be granted.")
        }

        // Custom user instructions (name, interests, preferences)
        let instructions = lang.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !instructions.isEmpty {
            parts.append("USER'S CUSTOM INSTRUCTIONS (follow these closely):\n\(instructions)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Dashboard Prompts 🐾

    static func randomPrompt(lang: LanguageManager) -> String {
        let n = lang.aiName
        let prompts: [String]
        switch lang.current {
        case .english:
            prompts = [
                "\(n) knows your habits! Ask me",
                "Need motivation? \(n)'s got you!",
                "Let's check those stocks together!",
                "\(n) says: check your health stats!",
                "Hey! Want me to set a reminder?",
                "Tell \(n) what to save!",
                "\(n) is bored. Talk to me!",
                "Your sidekick is ready! What's up?",
            ]
        case .bulgarian:
            prompts = [
                "\(n) знае навиците ти! Питай ме",
                "Трябва ти мотивация? \(n) е тук!",
                "Да видим как са акциите!",
                "\(n) казва: провери здравето си!",
                "Искаш ли напомняне? Кажи на \(n)!",
                "Кажи на \(n) какво да запише!",
                "\(n) скучае. Говори ми!",
                "Помощникът ти е готов! Какво има?",
            ]
        case .northwestern:
            prompts = [
                "Яла, баце! \(n) е тука!",
                "Е па къ, \(n) сам тука за теа!",
                "Кеф на буци! Как са акциите?",
                "\(n) а ти каже нешту арно!",
                "Секи ден \(n) е тука, баце!",
                "Епа кво онодваш, сакаш помощ?",
                "Дии, яла да видим навиците!",
                "Живота е сурав и курав!",
                "\(n) е наглъфан с лафове за теа!",
                "Пълен сам с акъл, баце!",
            ]
        case .shopluk:
            prompts = [
                "\(n) е тука, питай!",
                "Са какво че правим? \(n) чека!",
                "\(n) чека да видим акциите!",
                "Яз че ти помогнем! \(n) е верен!",
                "Кой се млого вали, он не пали!",
                "Емчи се ко вол у яръм!",
                "Дунята че се сврши, будалете че остану!",
                "Живее ко бубрег у мас!",
                "Огняне, \(n) че ти го обясни!",
                "Са да си опраймо есапите!",
            ]
        case .plovdiv:
            prompts = [
                "Майна, \(n) е тука бе!",
                "Ей, \(n) те чека! Питай нещо бе!",
                "Айде да видим акциите, убаво е!",
                "\(n) казва: провери здравето бе!",
                "Бая работа има, \(n) ще помогне!",
                "Майна, кво убаво е с \(n)!",
                "Арно бе, \(n) е тука за теб!",
                "Пусто, \(n) скучае! Говори ми бе!",
                "Нагоре-надолу, \(n) е с теб!",
                "На тепето е убаво, питай \(n)!",
            ]
        case .burgas:
            prompts = [
                "Море, батка! \(n) е тука!",
                "Ей, батка, \(n) те чека!",
                "Айде да видим акциите, батка!",
                "\(n) казва: провери здравето батка!",
                "Море, \(n) е на рахат, питай!",
                "Батка, \(n) е тука за теб!",
                "Арно де, \(n) скучае! Кажи нещо!",
                "Ей сега, \(n) ще помогне!",
                "Мерак ми е да помогна, батка!",
                "Барабар ще се справим! \(n) е верен!",
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

    private static func loadPlovdivVocabulary() -> String? {
        guard let url = Bundle.main.url(forResource: "plovdiv_vocabulary", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content
    }

    private static func loadBurgasVocabulary() -> String? {
        guard let url = Bundle.main.url(forResource: "burgas_vocabulary", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content
    }
}
