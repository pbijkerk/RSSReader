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
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
