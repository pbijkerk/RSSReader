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
                NavigationLink(destination: ArticlePageView(items: sortedItems, initialIndex: index)) {
                    FeedItemRowView(item: item)
                }
                .listRowBackground(item.isRead ? Color.clear : Color.blue.opacity(0.05))
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
                    .tint(.blue)
                }
            }
        }
        .refreshable {
            await refreshService.refresh(feed: feed, context: modelContext)
        }
        .navigationTitle(feed.title)
        .navigationBarTitleDisplayMode(.large)
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

struct FeedItemRowView: View {
    let item: FeedItem
    @AppStorage(AppConfiguration.UserDefaultsKeys.previewLineCount) private var previewLineCount = 2
    @AppStorage(AppConfiguration.UserDefaultsKeys.showArticleThumbnails) private var showArticleThumbnails = true
    @AppStorage(AppConfiguration.UserDefaultsKeys.articleFontSize) private var articleFontSize = AppConfiguration.defaultArticleFontSize

    /// Basisschaal die meebeweegt met de iOS-toegankelijkheidslettergrootte (Dynamic Type).
    /// De verhouding met `articleFontSize` blijft behouden, zodat gebruikersvoorkeur én
    /// systeemvoorkeur samen werken.
    @ScaledMetric(relativeTo: .body) private var scaledBase: CGFloat = 17

    private var titleSize:   CGFloat { scaledBase * CGFloat(articleFontSize) / 17 }
    private var captionSize: CGFloat { max(titleSize - 4, 9) }
    private var metaSize:    CGFloat { max(titleSize - 5, 8) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Linker kolom: Metadata + Titel + beschrijving
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let feedTitle = item.feed?.title {
                        Text(feedTitle)
                            .font(.system(size: metaSize))
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    if let date = item.pubDate {
                        Text(Self.relativeTime(for: date))
                            .font(.system(size: metaSize))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: titleSize, weight: item.isRead ? .regular : .bold))
                        .lineLimit(3)
                    if item.isVideoItem {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: captionSize))
                            .padding(.top, 2)
                    }
                }

                if !item.plainDescription.isEmpty {
                    Text(item.plainDescription)
                        .font(.system(size: captionSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(previewLineCount)
                }
            }
            
            // Rechter kolom: Thumbnail afbeelding (indien beschikbaar en instelling aan)
            if showArticleThumbnails, let imageURLString = item.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        placeholderImage
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    @unknown default:
                        placeholderImage
                    }
                }
                .frame(width: 80, height: 80)
            }
        }
        .padding(.vertical, 4)
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

    @ViewBuilder
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.1))
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary.opacity(0.5))
            }
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
