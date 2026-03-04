import SwiftUI

struct NewsView: View {
    @Environment(LanguageManager.self) var lang
    @Environment(NewsViewModel.self) var newsVM
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Group {
                if !newsVM.hasApiKey {
                    noApiKeyState
                } else {
                    newsContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lang.newsTitle)
            .refreshable {
                await newsVM.refresh()
            }
        }
        .task {
            let needsFetch: Bool = {
                if case .idle = newsVM.loadState { return true }
                return newsVM.worldNews.isEmpty && newsVM.bulgarianNews.isEmpty
            }()
            if needsFetch && newsVM.hasApiKey {
                await newsVM.fetchAll()
            }
        }
    }

    // MARK: - No API Key State

    private var noApiKeyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.48, blue: 0.85),
                                 Color(red: 0.15, green: 0.35, blue: 0.70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(lang.newsEmpty)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("gnews.io")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }

    // MARK: - News Content

    @ViewBuilder
    private var newsContent: some View {
        if case .loading = newsVM.loadState, newsVM.worldNews.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            }
        } else if case .error(let msg) = newsVM.loadState, newsVM.worldNews.isEmpty && newsVM.bulgarianNews.isEmpty {
            errorView(msg)
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    // World News
                    newsSection(
                        title: lang.newsWorldTitle,
                        icon: "globe",
                        articles: newsVM.worldNews
                    )

                    // Bulgarian News
                    newsSection(
                        title: lang.newsBulgarianTitle,
                        icon: "flag.fill",
                        articles: newsVM.bulgarianNews
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - News Section

    private func newsSection(title: String, icon: String, articles: [NewsArticle]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.25, green: 0.48, blue: 0.85))
                Text(title)
                    .font(.title3.weight(.bold))
            }
            .padding(.leading, 4)

            if articles.isEmpty {
                Text(lang.newsNoArticles)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(articles) { article in
                    articleRow(article)
                }
            }
        }
    }

    // MARK: - Article Row

    private func articleRow(_ article: NewsArticle) -> some View {
        Button {
            if let url = URL(string: article.url) {
                openURL(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Text content
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if !article.description.isEmpty {
                        Text(article.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        if !article.sourceName.isEmpty {
                            Text(article.sourceName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color(red: 0.25, green: 0.48, blue: 0.85))
                        }
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(article.timeAgoText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)

                // Thumbnail
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .failure:
                            imagePlaceholder
                        case .empty:
                            ProgressView()
                                .frame(width: 72, height: 72)
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.tertiarySystemGroupedBackground))
            .frame(width: 72, height: 72)
            .overlay {
                Image(systemName: "newspaper")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
            }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(lang.healthRetry) {
                Task { await newsVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.25, green: 0.48, blue: 0.85))
        }
        .padding(.top, 60)
    }
}
