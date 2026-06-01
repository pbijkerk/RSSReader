import SwiftUI
import SwiftData

struct AllArticlesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConfiguration.UserDefaultsKeys.hideReadArticles) private var hideReadArticles = false

    @Query(sort: \FeedItem.pubDate, order: .reverse) private var allItems: [FeedItem]

    var sortedItems: [FeedItem] {
        hideReadArticles ? allItems.filter { !$0.isRead } : allItems
    }

    var body: some View {
        List(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
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
        .navigationTitle("All")
        .navigationBarTitleDisplayMode(.large)
    }
}
