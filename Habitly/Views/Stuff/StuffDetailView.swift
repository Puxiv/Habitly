import SwiftUI

struct StuffDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    let item: StuffItem

    @State private var showEdit = false

    private var viewModel: StuffViewModel {
        StuffViewModel(modelContext: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header: emoji + title
                VStack(spacing: 8) {
                    Text(item.emoji)
                        .font(.system(size: 64))
                    Text(item.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Category + rating
                HStack(spacing: 12) {
                    // Category badge
                    HStack(spacing: 4) {
                        Text(item.category.emoji)
                        Text(item.category.displayName(language: lang.current))
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: Capsule())

                    // Star rating
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= item.rating ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundStyle(star <= item.rating ? .yellow : Color(.tertiaryLabel))
                        }
                    }
                }

                // Note
                if !item.note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.note)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(item.note)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                // Image
                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Created date
                Text(item.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation { viewModel.toggleArchive(item) }
                    } label: {
                        Image(systemName: item.isArchived ? "tray.and.arrow.up" : "archivebox")
                    }

                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditStuffView(itemToEdit: item, modelContext: modelContext)
        }
    }
}
