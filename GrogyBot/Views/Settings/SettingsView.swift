import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(LanguageManager.self) var lang
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "claude_api_key") ?? ""
    @State private var gnewsApiKey: String = UserDefaults.standard.string(forKey: "gnews_api_key") ?? ""
    @State private var speechManager = SpeechManager()

    var body: some View {
        @Bindable var langBinding = lang
        NavigationStack {
            Form {
                // AI Assistant Name & Voice
                Section {
                    TextField("Grogy", text: $langBinding.aiName)
                        .autocorrectionDisabled()
                    Toggle(lang.autoSpeakLabel, isOn: $langBinding.autoSpeak)
                } header: {
                    Text(lang.aiNameLabel)
                } footer: {
                    Text(lang.t("Give your AI sidekick a custom name. Toggle voice to hear responses read aloud.",
                                "Дай на AI помощника си име по избор. Включи гласа, за да чуеш отговорите на глас.",
                                "Тури на помощника си име. Пусни гласа да чуеш отговорите.",
                                "Тури на помощника си име. Пусни гласа да чуеш отговорите.",
                                "Тури име на помощника. Пусни гласа да чуеш отговорите бе.",
                                "Тури име на помощника. Пусни гласа да чуеш отговорите батка."))
                }

                // Custom Instructions
                Section {
                    TextEditor(text: $langBinding.customInstructions)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                } header: {
                    Text(lang.customInstructionsLabel)
                } footer: {
                    Text(lang.t("Tell the assistant about yourself — your name, interests, preferences. It will use this context in every conversation.",
                                "Разкажи на асистента за себе си — име, интереси, предпочитания. Ще използва тази информация във всеки разговор.",
                                "Кажи на помощника за себе си — име, интереси. Ше го ползва във всеки разговор.",
                                "Кажи на помощника за себе си — име, интереси. Ше го ползва във всеки разговор.",
                                "Кажи на помощника за себе си бе — име, интереси. Ще го ползва във всеки разговор.",
                                "Кажи на помощника за себе си батка — име, интереси. Ще го ползва във всеки разговор."))
                }

                // Voice Picker
                Section {
                    // Auto option
                    Button {
                        lang.selectedVoiceId = ""
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            Text(lang.voiceAuto)
                                .foregroundStyle(.primary)
                            Spacer()
                            if lang.selectedVoiceId.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    // Available voices for current language
                    ForEach(voicesForCurrentLanguage, id: \.identifier) { voice in
                        Button {
                            lang.selectedVoiceId = voice.identifier
                            speechManager.previewVoice(voice, greeting: voicePreviewText)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: voice.gender == .male ? "person.fill" : "person.fill")
                                    .foregroundStyle(voice.gender == .male ? .cyan : .pink)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.name)
                                        .foregroundStyle(.primary)
                                    Text(voiceQualityLabel(voice))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                if lang.selectedVoiceId == voice.identifier {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(lang.voiceLabel)
                }

                // Module Toggles
                Section {
                    Toggle(lang.habitsTab, isOn: $langBinding.moduleHabits)
                    Toggle(lang.remindersTab, isOn: $langBinding.moduleReminders)
                    Toggle(lang.notesTab, isOn: $langBinding.moduleNotes)
                    Toggle(lang.healthTab, isOn: $langBinding.moduleHealth)
                    Toggle(lang.stocksTab, isOn: $langBinding.moduleStocks)
                    Toggle(lang.newsTab, isOn: $langBinding.moduleNews)
                } header: {
                    Text(lang.modulesLabel)
                } footer: {
                    Text(lang.t("Disabled modules are hidden from Dashboard, tabs, and AI chat.",
                                "Изключените модули са скрити от Табло, табове и AI чат.",
                                "Изключените модули са скрити от Таблото, табовете и AI чата.",
                                "Изключените модули са скрити от Таблото, табовете и AI чата.",
                                "Изключените модули са скрити от Таблото, табовете и AI чата.",
                                "Изключените модули са скрити от Таблото, табовете и AI чата."))
                }

                Section {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button {
                            lang.current = language
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if lang.current == language {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(lang.language)
                }

                Section {
                    SecureField(lang.chatApiKeyPlaceholder, text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: apiKey) {
                            UserDefaults.standard.set(apiKey, forKey: "claude_api_key")
                        }
                } header: {
                    Text(lang.chatApiKeyTitle)
                } footer: {
                    Text(lang.chatApiKeyFooter)
                }

                Section {
                    SecureField(lang.newsApiKeyPlaceholder, text: $gnewsApiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: gnewsApiKey) {
                            UserDefaults.standard.set(gnewsApiKey, forKey: "gnews_api_key")
                        }
                } header: {
                    Text(lang.newsApiKeyTitle)
                } footer: {
                    Text(lang.newsApiKeyFooter)
                }
            }
            .navigationTitle(lang.settings)
        }
    }

    // MARK: - Voice Helpers

    private var voicesForCurrentLanguage: [AVSpeechSynthesisVoice] {
        let locale: Locale = switch lang.current {
        case .english: Locale(identifier: "en-US")
        case .bulgarian, .northwestern, .shopluk, .plovdiv, .burgas: Locale(identifier: "bg-BG")
        }
        return SpeechManager.availableVoices(for: locale)
    }

    private var voicePreviewText: String {
        lang.t("Hi! I'm \(lang.aiName), your personal assistant!",
               "Здравей! Аз съм \(lang.aiName), твоят личен асистент!",
               "Яла! Аз съм \(lang.aiName), твоя помощник!",
               "Епа! Яз съм \(lang.aiName), твоя помощник!",
               "Майна! Аз съм \(lang.aiName), помощникът ти!",
               "Ей! Аз съм \(lang.aiName), помощникът ти батка!")
    }

    private func voiceQualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        let gender = voice.gender == .male
            ? lang.t("Male", "Мъжки", "Мъжки", "Мъжки", "Мъжки", "Мъжки")
            : voice.gender == .female
                ? lang.t("Female", "Женски", "Женски", "Женски", "Женски", "Женски")
                : ""
        let quality = (voice.quality == .enhanced || voice.quality == .premium)
            ? lang.t("Enhanced", "Подобрен", "Подобрен", "Подобрен", "Подобрен", "Подобрен")
            : lang.t("Default", "Стандартен", "Стандартен", "Стандартен", "Стандартен", "Стандартен")
        return [gender, quality].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
