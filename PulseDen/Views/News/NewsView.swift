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
            .background(Theme.background)
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
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
            }

            Text(lang.newsEmpty)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("gnews.io")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
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
                    .tint(Theme.accent)
                    .scaleEffect(1.2)
                Spacer()
            }
        } else if case .error(let msg) = newsVM.loadState, newsVM.worldNews.isEmpty && newsVM.bulgarianNews.isEmpty {
            errorView(msg)
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    newsSection(
                        title: lang.newsWorldTitle,
                        icon: "globe",
                        articles: newsVM.worldNews
                    )

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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.title3.weight(.bold))
            }
            .padding(.leading, 4)

            if articles.isEmpty {
                Text(lang.newsNoArticles)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if !article.description.isEmpty {
                        Text(article.description)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        if !article.sourceName.isEmpty {
                            Text(article.sourceName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                        Text(article.timeAgoText)
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Spacer(minLength: 0)

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
                                .tint(Theme.accent)
                                .frame(width: 72, height: 72)
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Theme.cardElevated)
            .frame(width: 72, height: 72)
            .overlay {
                Image(systemName: "newspaper")
                    .font(.title3)
                    .foregroundStyle(Theme.textTertiary)
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
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(lang.healthRetry) {
                Task { await newsVM.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(.top, 60)
    }
}
