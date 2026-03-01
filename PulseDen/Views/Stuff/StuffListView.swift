import SwiftUI
import SwiftData

enum StuffSortOption: String, CaseIterable {
    case rating, date, category
}

struct StuffListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Query(sort: \StuffItem.createdAt, order: .reverse) private var allItems: [StuffItem]

    @State private var showAddItem = false
    @State private var itemToEdit: StuffItem?
    @State private var sortOption: StuffSortOption = .rating
    @State private var showArchived = false
    @State private var searchText = ""

    private var viewModel: StuffViewModel {
        StuffViewModel(modelContext: modelContext)
    }

    private var filteredItems: [StuffItem] {
        var items = allItems.filter { showArchived || !$0.isArchived }
        if !searchText.isEmpty {
            items = items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        switch sortOption {
        case .rating:   items.sort { $0.rating > $1.rating }
        case .date:     items.sort { $0.createdAt > $1.createdAt }
        case .category: items.sort { $0.categoryRaw < $1.categoryRaw }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            Group {
                if allItems.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: StuffDetailView(item: item)) {
                                StuffRowView(item: item, lang: lang)
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
                                    withAnimation { viewModel.toggleArchive(item) }
                                } label: {
                                    Label(item.isArchived ? lang.stuffUnarchive : lang.stuffArchive,
                                          systemImage: item.isArchived ? "tray.and.arrow.up" : "archivebox")
                                }
                                .tint(.orange)

                                Button {
                                    itemToEdit = item
                                } label: {
                                    Label(lang.edit, systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle(lang.stuffTab)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker(lang.sortByRating, selection: $sortOption) {
                            Label(lang.sortByRating, systemImage: "star").tag(StuffSortOption.rating)
                            Label(lang.sortByDate, systemImage: "calendar").tag(StuffSortOption.date)
                            Label(lang.sortByCategory, systemImage: "tag").tag(StuffSortOption.category)
                        }

                        Divider()

                        Toggle(lang.stuffShowArchived, isOn: $showArchived)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddEditStuffView(modelContext: modelContext)
            }
            .sheet(item: $itemToEdit) { item in
                AddEditStuffView(itemToEdit: item, modelContext: modelContext)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(lang.emptyStuffTitle)
                .font(.title3.weight(.medium))
            Text(lang.emptyStuffSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(lang.createFirstStuff) {
                showAddItem = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
