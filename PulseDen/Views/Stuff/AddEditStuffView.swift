import SwiftUI
import SwiftData
import PhotosUI

private struct StuffDraft {
    var title: String = ""
    var emoji: String = "📌"
    var note: String = ""
    var category: StuffCategory = .other
    var rating: Int = 3
    var imageData: Data?
    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct AddEditStuffView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) var lang

    let itemToEdit: StuffItem?
    private var viewModel: StuffViewModel

    @State private var draft = StuffDraft()
    @State private var selectedPhoto: PhotosPickerItem?

    init(itemToEdit: StuffItem? = nil, modelContext: ModelContext) {
        self.itemToEdit = itemToEdit
        self.viewModel = StuffViewModel(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang.sectionNameIcon) {
                    TextField(lang.stuffNamePlaceholder, text: $draft.title)
                    EmojiPickerView(emoji: $draft.emoji)
                }

                Section(lang.stuffSectionDetails) {
                    TextField(lang.stuffNotePlaceholder, text: $draft.note, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section(lang.stuffSectionCategory) {
                    Picker(lang.stuffSectionCategory, selection: $draft.category) {
                        ForEach(StuffCategory.allCases, id: \.self) { cat in
                            HStack {
                                Text(cat.emoji)
                                Text(cat.displayName(language: lang.current))
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(lang.stuffSectionRating) {
                    StarRatingView(rating: $draft.rating)
                        .padding(.vertical, 4)
                }

                Section(lang.stuffSectionPhoto) {
                    if let imageData = draft.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button(role: .destructive) {
                            withAnimation { draft.imageData = nil }
                        } label: {
                            Label(lang.stuffRemovePhoto, systemImage: "trash")
                        }
                    }

                    let addLabel = lang.stuffAddPhoto
                    let changeLabel = lang.stuffChangePhoto
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(draft.imageData == nil ? addLabel : changeLabel,
                              systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                draft.imageData = data
                            }
                        }
                    }
                }
            }
            .navigationTitle(itemToEdit == nil ? lang.newStuffTitle : lang.editStuffTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.save) { save() }
                        .disabled(!draft.isValid)
                }
            }
            .onAppear { populateDraftIfEditing() }
        }
    }

    private func populateDraftIfEditing() {
        guard let item = itemToEdit else { return }
        draft.title = item.title
        draft.emoji = item.emoji
        draft.note = item.note
        draft.category = item.category
        draft.rating = item.rating
        draft.imageData = item.imageData
    }

    private func save() {
        if let item = itemToEdit {
            viewModel.saveItem(item,
                               title: draft.title.trimmingCharacters(in: .whitespaces),
                               emoji: draft.emoji,
                               note: draft.note,
                               category: draft.category,
                               rating: draft.rating,
                               imageData: draft.imageData)
        } else {
            viewModel.addItem(title: draft.title.trimmingCharacters(in: .whitespaces),
                              emoji: draft.emoji,
                              note: draft.note,
                              category: draft.category,
                              rating: draft.rating,
                              imageData: draft.imageData)
        }
        dismiss()
    }
}
