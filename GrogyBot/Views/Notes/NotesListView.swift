import SwiftUI
import SwiftData

enum NoteSortOption: String, CaseIterable {
    case date, title
}

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Query(sort: \StuffItem.createdAt, order: .reverse) private var allItems: [StuffItem]

    @State private var showNewNote = false
    @State private var itemToEdit: StuffItem?
    @State private var sortOption: NoteSortOption = .date
    @State private var showArchived = false
    @State private var searchText = ""

    private var viewModel: NotesViewModel {
        NotesViewModel(modelContext: modelContext)
    }

    // MARK: - Filtered & Sorted

    private var filteredItems: [StuffItem] {
        var items = allItems.filter { showArchived || !$0.isArchived }
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.plainTextBody.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    private var pinnedItems: [StuffItem] {
        var items = filteredItems.filter { $0.isPinned }
        sortItems(&items)
        return items
    }

    private var unpinnedItems: [StuffItem] {
        var items = filteredItems.filter { !$0.isPinned }
        sortItems(&items)
        return items
    }

    private func sortItems(_ items: inout [StuffItem]) {
        switch sortOption {
        case .date:  items.sort { $0.createdAt > $1.createdAt }
        case .title: items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if allItems.isEmpty {
                    emptyState
                } else {
                    List {
                        if !pinnedItems.isEmpty {
                            Section(lang.notesPinned) {
                                noteRows(pinnedItems)
                            }
                        }

                        Section(pinnedItems.isEmpty ? "" : lang.notesTab) {
                            noteRows(unpinnedItems)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle(lang.notesTab)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker(lang.sortByDate, selection: $sortOption) {
                            Label(lang.sortByDate, systemImage: "calendar").tag(NoteSortOption.date)
                            Label(lang.sortByTitle, systemImage: "textformat").tag(NoteSortOption.title)
                        }

                        Divider()

                        Toggle(lang.noteShowArchived, isOn: $showArchived)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showNewNote) {
                NavigationStack {
                    NoteEditorView(itemToEdit: nil, modelContext: modelContext)
                }
            }
            .sheet(item: $itemToEdit) { item in
                NavigationStack {
                    NoteEditorView(itemToEdit: item, modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Note Rows

    @ViewBuilder
    private func noteRows(_ items: [StuffItem]) -> some View {
        ForEach(items) { item in
            Button {
                itemToEdit = item
            } label: {
                NoteRowView(item: item)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.deleteItem(item)
                } label: {
                    Label(lang.delete, systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    withAnimation { viewModel.togglePin(item) }
                } label: {
                    Label(item.isPinned ? lang.noteUnpin : lang.notePin,
                          systemImage: item.isPinned ? "pin.slash" : "pin")
                }
                .tint(Theme.accent)

                Button {
                    withAnimation { viewModel.toggleArchive(item) }
                } label: {
                    Label(item.isArchived ? lang.noteUnarchive : lang.noteArchive,
                          systemImage: item.isArchived ? "tray.and.arrow.up" : "archivebox")
                }
                .tint(.orange)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(lang.emptyNotesTitle)
                .font(.title3.weight(.medium))
            Text(lang.emptyNotesSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(lang.createFirstNote) {
                showNewNote = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
