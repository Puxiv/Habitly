import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lang

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
            }
            .navigationTitle(lang.settings)
        }
    }
}
