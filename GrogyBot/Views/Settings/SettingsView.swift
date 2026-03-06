import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lang
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "claude_api_key") ?? ""
    @State private var gnewsApiKey: String = UserDefaults.standard.string(forKey: "gnews_api_key") ?? ""

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
}
