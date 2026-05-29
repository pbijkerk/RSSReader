import SwiftUI
import SwiftData

struct SavedArticlesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<FeedItem> { $0.isSaved },
        sort: \FeedItem.pubDate,
        order: .reverse
    )
    private var savedItems: [FeedItem]

    var body: some View {
        NavigationStack {
            Group {
                if savedItems.isEmpty {
                    ContentUnavailableView(
                        "Geen bewaarde artikelen",
                        systemImage: "bookmark",
                        description: Text("Swipe een artikel naar rechts om het te bewaren.")
                    )
                } else {
                    List {
                        ForEach(savedItems) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                FeedItemRowView(item: item)
                            }
                            .listRowBackground(item.isRead ? Color.clear : Color.blue.opacity(0.05))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    item.isSaved = false
                                    try? modelContext.save()
                                } label: {
                                    Label("Verwijder", systemImage: "bookmark.slash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Bewaard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
