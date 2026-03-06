import SwiftUI
import SwiftData
import PhotosUI

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) var lang

    let itemToEdit: StuffItem?
    private let modelContext: ModelContext

    @State private var title: String = ""
    @State private var emoji: String = "📝"
    @State private var attributedBody = NSAttributedString()
    @State private var isPinned = false
    @State private var showEmojiPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var formatter = RichTextFormatter()
    @FocusState private var isTitleFocused: Bool

    private var viewModel: NotesViewModel { NotesViewModel(modelContext: modelContext) }

    init(itemToEdit: StuffItem?, modelContext: ModelContext) {
        self.itemToEdit = itemToEdit
        self.modelContext = modelContext
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Emoji + Title
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            showEmojiPicker = true
                        } label: {
                            Text(emoji)
                                .font(.system(size: 36))
                        }

                        TextField(lang.noteTitlePlaceholder, text: $title, axis: .vertical)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .focused($isTitleFocused)
                    }

                    // Date
                    if let item = itemToEdit {
                        Text(item.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }

                    // Rich text body
                    RichTextEditor(
                        attributedText: $attributedBody,
                        formatter: formatter,
                        placeholder: lang.noteBodyPlaceholder
                    )
                    .frame(minHeight: 300)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 60)
            }

            // Formatting toolbar
            formattingToolbar
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(lang.cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(lang.save) {
                    save()
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isPinned.toggle()
                    } label: {
                        Label(isPinned ? lang.noteUnpin : lang.notePin,
                              systemImage: isPinned ? "pin.slash" : "pin")
                    }

                    if let item = itemToEdit {
                        Button {
                            viewModel.toggleArchive(item)
                            dismiss()
                        } label: {
                            Label(item.isArchived ? lang.noteUnarchive : lang.noteArchive,
                                  systemImage: item.isArchived ? "tray.and.arrow.up" : "archivebox")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(emoji: $emoji)
        }
        .onAppear { populateIfEditing() }
    }

    // MARK: - Formatting Toolbar

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Bold
                toolbarButton(icon: "bold", isActive: formatter.isBold) {
                    formatter.toggleBold()
                }
                // Italic
                toolbarButton(icon: "italic", isActive: formatter.isItalic) {
                    formatter.toggleItalic()
                }
                // Underline
                toolbarButton(icon: "underline", isActive: formatter.isUnderline) {
                    formatter.toggleUnderline()
                }
                // Strikethrough
                toolbarButton(icon: "strikethrough", isActive: formatter.isStrikethrough) {
                    formatter.toggleStrikethrough()
                }

                Divider().frame(height: 20).overlay(Theme.textTertiary.opacity(0.3))

                // Heading picker
                Menu {
                    ForEach(RichTextFormatter.HeadingLevel.allCases, id: \.self) { level in
                        Button {
                            formatter.setHeading(level)
                        } label: {
                            HStack {
                                Text(level.displayName)
                                if formatter.currentHeading == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(formatter.currentHeading != .body ? Theme.accent : .white)
                        .frame(width: 32, height: 32)
                }

                Divider().frame(height: 20).overlay(Theme.textTertiary.opacity(0.3))

                // Bullet list
                toolbarButton(icon: "list.bullet", isActive: false) {
                    formatter.insertBulletList()
                }
                // Numbered list
                toolbarButton(icon: "list.number", isActive: false) {
                    formatter.insertNumberedList()
                }
                // Checklist
                toolbarButton(icon: "checklist", isActive: false) {
                    formatter.insertChecklist()
                }

                Divider().frame(height: 20).overlay(Theme.textTertiary.opacity(0.3))

                // Photo
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            formatter.insertImage(image)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.card)
        .overlay(alignment: .top) {
            Divider().overlay(Theme.textTertiary.opacity(0.3))
        }
    }

    private func toolbarButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? Theme.accent : .white)
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Data

    private func populateIfEditing() {
        guard let item = itemToEdit else {
            isTitleFocused = true
            return
        }
        title = item.title
        emoji = item.emoji
        isPinned = item.isPinned
        if let body = item.attributedBody {
            attributedBody = body
        } else if !item.note.isEmpty {
            // Migrate plain text to attributed string
            attributedBody = NSAttributedString(
                string: item.note,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 17),
                    .foregroundColor: UIColor.white
                ]
            )
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        // Archive rich text body (non-secure coding for UIFont/UIColor compat)
        var bodyDataArchived: Data? = nil
        if attributedBody.length > 0 {
            bodyDataArchived = try? NSKeyedArchiver.archivedData(
                withRootObject: attributedBody, requiringSecureCoding: false
            )
        }

        if let item = itemToEdit {
            item.title = trimmedTitle
            item.emoji = emoji
            item.isPinned = isPinned
            item.bodyData = bodyDataArchived
            item.note = attributedBody.string
        } else {
            let item = StuffItem(
                title: trimmedTitle,
                emoji: emoji,
                note: attributedBody.string,
                bodyData: bodyDataArchived,
                isPinned: isPinned
            )
            modelContext.insert(item)
        }

        do {
            try modelContext.save()
        } catch {
            print("[NoteEditor] Save failed: \(error)")
        }
    }
}
