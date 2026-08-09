import SwiftUI
import SwiftData

struct FeedItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConfiguration.UserDefaultsKeys.hideReadArticles) private var hideReadArticles = false
    let feed: Feed
    var refreshService: FeedRefreshService

    var sortedItems: [FeedItem] {
        feed.items
            .filter { hideReadArticles ? !$0.isRead : true }
            .sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
    }

    var body: some View {
        List {
            ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                ZStack {
                    FeedItemCard(item: item)
                    // Onzichtbare NavigationLink zonder disclosure-chevron
                    NavigationLink(destination: ArticlePageView(items: sortedItems, initialIndex: index)) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        item.isRead.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            item.isRead ? "Ongelezen" : "Gelezen",
                            systemImage: item.isRead ? "envelope.badge" : "envelope.open"
                        )
                    }
                    .tint(.gray)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        item.isSaved.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            item.isSaved ? "Niet bewaard" : "Bewaar",
                            systemImage: item.isSaved ? "bookmark.slash" : "bookmark"
                        )
                    }
                    .tint(Theme.accentSecondary)
                }
                .contextMenu {
                    Button {
                        item.isSaved.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            item.isSaved ? "Verwijder uit bewaard" : "Bewaar",
                            systemImage: item.isSaved ? "bookmark.slash" : "bookmark")
                    }
                    Button {
                        item.isRead.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            item.isRead ? "Markeer als ongelezen" : "Markeer als gelezen",
                            systemImage: item.isRead ? "envelope.badge" : "envelope.open")
                    }
                    if let link = item.link, let url = URL(string: link) {
                        ShareLink(item: url) { Label("Delen", systemImage: "square.and.arrow.up") }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .refreshable {
            await refreshService.refresh(feed: feed, context: modelContext)
        }
        .navigationTitle(feed.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        await refreshService.refresh(feed: feed, context: modelContext)
                    }
                }
                .disabled(refreshService.isRefreshing)
            }
        }
    }
}

/// Dunne wrapper zodat bestaande aanroepen (`FeedItemRowView`) de nieuwe card tonen.
struct FeedItemRowView: View {
    let item: FeedItem
    var body: some View { FeedItemCard(item: item) }
}

/// Magazine-card voor één artikel — "Glass Magazine"-stijl uit de PDF.
/// Afbeelding als banner bovenaan (indien aanwezig), Charter-titel, brand-accent per bron.
struct FeedItemCard: View {
    let item: FeedItem
    @AppStorage(AppConfiguration.UserDefaultsKeys.previewLineCount) private var previewLineCount = 2
    @AppStorage(AppConfiguration.UserDefaultsKeys.showArticleThumbnails) private var showArticleThumbnails = true
    @AppStorage(AppConfiguration.UserDefaultsKeys.articleFontSize) private var articleFontSize = AppConfiguration
        .defaultArticleFontSize
    @AppStorage(AppConfiguration.UserDefaultsKeys.showBiasIndicators) private var showBiasIndicators = true

    /// Basisschaal die meebeweegt met Dynamic Type, met behoud van de gebruikersvoorkeur.
    @ScaledMetric(relativeTo: .body) private var scaledBase: CGFloat = 17

    private var titleSize: CGFloat { scaledBase * CGFloat(articleFontSize) / 17 }
    private var captionSize: CGFloat { max(titleSize - 4, 9) }
    private var metaSize: CGFloat { max(titleSize - 5, 8) }

    private var brand: Color {
        Theme.brandColor(for: item.feed?.title ?? item.feed?.url ?? "")
    }

    private var hasBanner: Bool {
        showArticleThumbnails && item.imageURL.flatMap { URL(string: $0) } != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasBanner, let urlString = item.imageURL, let url = URL(string: urlString) {
                bannerImage(url: url)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Categorie- / bron-label + ongelezen-indicator
                HStack(spacing: 6) {
                    if !item.isRead {
                        Circle().fill(brand).frame(width: 7, height: 7)
                    }
                    if let feedTitle = item.feed?.title {
                        Text(feedTitle.uppercased())
                            .font(Theme.categoryLabel(metaSize))
                            .tracking(0.8)
                            .foregroundStyle(brand)
                            .lineLimit(1)
                    }
                    if item.isVideoItem {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: metaSize))
                            .foregroundStyle(brand)
                    }
                    if item.isAudioItem {
                        Image(systemName: "waveform")
                            .font(.system(size: metaSize))
                            .foregroundStyle(brand)
                    }
                    Spacer(minLength: 0)
                    if item.isSaved {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: metaSize))
                            .foregroundStyle(Theme.accentSecondary)
                    }
                }

                // Titel in Charter (serif magazine-look)
                Text(item.title)
                    .font(Theme.title(titleSize + 1, relativeTo: .headline))
                    .foregroundStyle(Theme.text)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Korte beschrijving
                if previewLineCount > 0, !item.plainDescription.isEmpty {
                    Text(item.plainDescription)
                        .font(.system(size: captionSize))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(previewLineCount)
                }

                // Metadata
                if let date = item.pubDate {
                    Text(Self.relativeTime(for: date))
                        .font(.system(size: metaSize))
                        .foregroundStyle(Theme.textSecondary)
                }

                // Bronanalyse: bias-balk + betrouwbaarheidsbadge
                if showBiasIndicators, let feed = item.feed, let score = feed.biasScore {
                    HStack(alignment: .center, spacing: 8) {
                        BiasBarView(
                            biasScore: score,
                            feedName: feed.title,
                            reliabilityLevel: feed.reliabilityLevel,
                            ratingSource: feed.ratingSource,
                            biasRatedAt: feed.biasRatedAt
                        )
                        ReliabilityBadgeView(level: feed.reliabilityLevel)
                    }
                    .padding(.top, 2)
                }

                // Fact-check chip — alleen als resultaten beschikbaar zijn
                if showBiasIndicators, !item.factCheckResults.isEmpty {
                    FactCheckChipView(results: item.factCheckResults)
                        .padding(.top, 2)
                }
            }
            .padding(16)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .opacity(item.isRead ? 0.72 : 1)
    }

    @ViewBuilder
    private func bannerImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .empty:
                ZStack {
                    brand.opacity(0.12)
                    ProgressView()
                }
            case .failure:
                ZStack {
                    brand.opacity(0.12)
                    Image(systemName: "photo").foregroundStyle(brand.opacity(0.5))
                }
            @unknown default:
                brand.opacity(0.12)
            }
        }
        .frame(height: 168)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    /// Relatieve tijd zonder seconden: onder een minuut → "Zojuist".
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private static func relativeTime(for date: Date) -> String {
        guard abs(date.timeIntervalSinceNow) >= 60 else { return "Zojuist" }
        return relativeDateFormatter.localizedString(for: date, relativeTo: .now)
    }
}

struct ArticlePageView: View {
    let items: [FeedItem]
    @State private var currentIndex: Int

    init(items: [FeedItem], initialIndex: Int) {
        self.items = items
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemDetailView(item: item)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
    }
}
