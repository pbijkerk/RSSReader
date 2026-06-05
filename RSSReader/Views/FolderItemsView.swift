import SwiftUI
import SwiftData

struct FolderItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConfiguration.UserDefaultsKeys.hideReadArticles) private var hideReadArticles = false
    let folder: FeedFolder

    var sortedItems: [FeedItem] {
        folder.feeds
            .flatMap { $0.items }
            .filter { hideReadArticles ? !$0.isRead : true }
            .sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
    }

    var body: some View {
        List {
            ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                ZStack {
                    FeedItemCard(item: item)
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
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
