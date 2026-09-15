import SwiftUI
import SwiftData

struct AllArticlesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConfiguration.UserDefaultsKeys.hideReadArticles) private var hideReadArticles = false
    @AppStorage(AppConfiguration.UserDefaultsKeys.articlesFolderFilter) private var folderFilterID = ""

    @Query(sort: \FeedFolder.sortOrder) private var folders: [FeedFolder]
    @Query private var feeds: [Feed]

    var refreshService: FeedRefreshService
    var onRefreshComplete: () async -> Void

    @State private var showFeedManagement = false

    /// Lege string of een verwijderde map betekent: geen filter.
    private var activeFolder: FeedFolder? {
        guard !folderFilterID.isEmpty else { return nil }
        return folders.first { $0.id.uuidString == folderFilterID }
    }

    /// De id's van de feeds in de actieve map, of `nil` als er geen mapfilter staat.
    /// Dit loopt over de feeds (tientallen), niet over de artikelen (duizenden): het
    /// artikelenscherm filterde eerder per artikel op `$0.feed?.folder?.id`, en elke
    /// stap daarvan laadde een `Feed` en een `FeedFolder` in vanuit de database — op
    /// de main thread (#108).
    private var activeFeedIDs: [UUID]? {
        guard let activeFolder else { return nil }
        return feeds.filter { $0.folder?.id == activeFolder.id }.map(\.id)
    }

    var body: some View {
        NavigationStack {
            ArticleListView(
                hideRead: hideReadArticles,
                feedIDs: activeFeedIDs,
                onRefresh: { await refreshFeeds() },
                emptyState: { emptyState }
            )
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !folders.isEmpty {
                        filterBar
                    }
                }
                .background(Theme.background.ignoresSafeArea())
                .navigationTitle("Artikelen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if refreshService.isRefreshing {
                            ProgressView()
                        } else {
                            Button("Vernieuwen", systemImage: "arrow.clockwise") {
                                Task { await refreshFeeds() }
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Feeds beheren", systemImage: "list.bullet.rectangle") {
                                showFeedManagement = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .navigationDestination(isPresented: $showFeedManagement) {
                    FeedListView(
                        refreshService: refreshService,
                        onRefreshComplete: onRefreshComplete
                    )
                }
        }
    }

    /// Drie situaties met een eigen uitleg: geen feeds, een filter dat niets oplevert,
    /// of feeds die (nog) geen artikelen hebben.
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            if feeds.isEmpty {
                Text("Nog geen feeds")
                    .font(.title2.bold())
                Text("Voeg RSS-feeds toe; hun artikelen verschijnen hier.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Feeds beheren") { showFeedManagement = true }
                    .buttonStyle(.borderedProminent)
            } else if let activeFolder {
                Text("Geen artikelen in \(activeFolder.name)")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("De feeds in deze map hebben nog geen artikelen. Kies \"Alle\" om alles te zien.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Toon alle artikelen") { folderFilterID = "" }
                    .buttonStyle(.bordered)
            } else {
                Text("Nog geen artikelen")
                    .font(.title2.bold())
                Text(
                    hideReadArticles
                        ? "Alles is gelezen. Vernieuw om nieuwe artikelen op te halen."
                        : "Vernieuw om artikelen op te halen."
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }
        }
        .padding()
    }

    private func refreshFeeds() async {
        await refreshService.refreshAll(feeds: feeds, context: modelContext)
        await onRefreshComplete()
    }

    /// Staat buiten het scrollgebied (safe-area inset), dus blijft staan tijdens het scrollen.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Alle", id: "")
                ForEach(folders) { folder in
                    filterChip(title: folder.name, id: folder.id.uuidString)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func filterChip(title: String, id: String) -> some View {
        let isActive = (activeFolder?.id.uuidString ?? "") == id

        return Button {
            folderFilterID = id
        } label: {
            Text(title)
                .font(Theme.categoryLabel(13))
                .foregroundStyle(isActive ? Color.white : Theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if isActive {
                        Capsule().fill(Theme.accent)
                    } else {
                        Capsule().fill(Theme.card)
                            .overlay(Capsule().strokeBorder(Theme.textSecondary.opacity(0.25), lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// De artikelenlijst zelf, met een `@Query` die het filteren aan SQLite overlaat.
///
/// Waarom dit een eigen view is: `@Query` krijgt zijn predicaat bij initialisatie, en
/// `@AppStorage`-waarden zijn daar nog niet beschikbaar. `AllArticlesView` leest de
/// instellingen en geeft ze hier als gewone parameters door; de `init` bouwt daarmee het
/// predicaat. Wijzigt een van die parameters, dan maakt SwiftUI de view opnieuw aan en
/// draait de query met het nieuwe predicaat (#108).
private struct ArticleListView<EmptyState: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [FeedItem]

    private let onRefresh: () async -> Void
    private let emptyState: () -> EmptyState

    init(
        hideRead: Bool,
        feedIDs: [UUID]?,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder emptyState: @escaping () -> EmptyState
    ) {
        self.onRefresh = onRefresh
        self.emptyState = emptyState

        _items = Query(
            filter: ArticleFilter.predicate(hideRead: hideRead, feedIDs: feedIDs),
            sort: \FeedItem.pubDate,
            order: .reverse
        )
    }

    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ZStack {
                    FeedItemCard(item: item)
                    NavigationLink(destination: ArticlePageView(items: items, initialIndex: index)) {
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
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await onRefresh() }
        // Overlay in plaats van een vervangende view: de lijst blijft bestaan, dus
        // pull-to-refresh werkt ook wanneer er nog niets te tonen is.
        .overlay {
            if items.isEmpty {
                emptyState()
            }
        }
    }
}

/// Bouwt het predicaat voor de artikelenlijst.
///
/// Los van de view, en met opzet niet `private`: een fout in een `#Predicate` blijkt pas
/// als hij draait, niet bij het compileren. Zo kan een test hem tegen een echte
/// in-memory store uitvoeren en vangt CI een stukgelopen predicaat (#108).
enum ArticleFilter {

    /// - Parameters:
    ///   - hideRead: gelezen artikelen weglaten.
    ///   - feedIDs: alleen artikelen uit deze feeds; `nil` betekent geen mapfilter.
    static func predicate(hideRead: Bool, feedIDs: [UUID]?) -> Predicate<FeedItem> {
        // Een verse id matcht geen enkele feed, dus een artikel zonder feed valt buiten
        // een mapfilter. Zo hoeft het predicaat niet over een optionele relatie te
        // redeneren, wat SwiftData niet in alle vormen aankan.
        let geenFeed = UUID()

        switch (hideRead, feedIDs) {
        case (true, .some(let ids)):
            return #Predicate<FeedItem> { item in
                item.isRead == false && ids.contains(item.feed?.id ?? geenFeed)
            }
        case (false, .some(let ids)):
            return #Predicate<FeedItem> { item in
                ids.contains(item.feed?.id ?? geenFeed)
            }
        case (true, .none):
            return #Predicate<FeedItem> { item in item.isRead == false }
        case (false, .none):
            return #Predicate<FeedItem> { _ in true }
        }
    }
}
