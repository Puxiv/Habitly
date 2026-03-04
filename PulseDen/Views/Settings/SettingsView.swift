import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lang
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "claude_api_key") ?? ""
    @State private var gnewsApiKey: String = UserDefaults.standard.string(forKey: "gnews_api_key") ?? ""

    var body: some View {
        NavigationStack {
            Form {
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
