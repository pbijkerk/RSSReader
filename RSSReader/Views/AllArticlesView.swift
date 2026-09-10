import SwiftUI
import SwiftData

struct AllArticlesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConfiguration.UserDefaultsKeys.hideReadArticles) private var hideReadArticles = false
    @AppStorage(AppConfiguration.UserDefaultsKeys.articlesFolderFilter) private var folderFilterID = ""

    @Query(sort: \FeedItem.pubDate, order: .reverse) private var allItems: [FeedItem]
    @Query(sort: \FeedFolder.sortOrder) private var folders: [FeedFolder]

    var refreshService: FeedRefreshService
    var onRefreshComplete: () async -> Void

    @State private var showFeedManagement = false

    /// Lege string of een verwijderde map betekent: geen filter.
    private var activeFolder: FeedFolder? {
        guard !folderFilterID.isEmpty else { return nil }
        return folders.first { $0.id.uuidString == folderFilterID }
    }

    var sortedItems: [FeedItem] {
        var items = hideReadArticles ? allItems.filter { !$0.isRead } : allItems
        if let activeFolder {
            items = items.filter { $0.feed?.folder?.id == activeFolder.id }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            articleList
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !folders.isEmpty {
                        filterBar
                    }
                }
                .background(Theme.background.ignoresSafeArea())
                .navigationTitle("Artikelen")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
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

    private var articleList: some View {
        // Eén keer berekenen per hertekening: in de ForEach-body zou zowel de rij als
        // elke NavigationLink-bestemming de hele lijst opnieuw filteren (O(n²)).
        let items = sortedItems

        return List {
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
