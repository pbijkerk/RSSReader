import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var feeds: [Feed]
    @Query private var topics: [Topic]

    @State private var refreshService = FeedRefreshService()
    @State private var clusteringService = TopicClusteringService()

    @State private var clusters: [TopicCluster] = []
    @State private var selectedTab = 0
    @State private var lastClusteredAt: Date? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            SummaryListView(
                clusters: $clusters,
                isLoading: clusteringService.isClustering || refreshService.isRefreshing,
                onRefresh: { await refreshAndCluster(force: true) }
            )
            .tag(0)

            AllArticlesView(
                refreshService: refreshService,
                onRefreshComplete: { await regenerateSummaries() }
            )
            .tag(1)

            SavedArticlesView()
                .tag(2)
        }
        .floatingTabBar(selection: $selectedTab)
        .tint(Theme.accent)
        .task {
            await refreshAndCluster()
        }
        .onOpenURL { url in
            OAuthCallbackHandler.shared.handle(url: url)
        }
    }

    /// `force` slaat de debounce over: bij een expliciete pull vraagt de gebruiker er zelf
    /// om en hoort hij een nieuw resultaat te zien, ook binnen twee minuten.
    private func refreshAndCluster(force: Bool = false) async {
        await refreshService.refreshAll(feeds: feeds, context: modelContext)

        let now = Date()
        let shouldCluster =
            force || (lastClusteredAt.map { now.timeIntervalSince($0) > AppConfiguration.clusteringDebounce } ?? true)
        guard shouldCluster else { return }

        await regenerateSummaries()
        lastClusteredAt = now
    }

    private func regenerateSummaries() async {
        let allItems = feeds.flatMap { $0.items }
        let apiKey =
            KeychainService.load(forKey: AppConfiguration.KeychainKeys.claudeAPIKey)
            ?? UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKeys.claudeAPIKey)
            ?? ""
        clusters = await clusteringService.cluster(
            items: allItems,
            savedTopics: topics,
            claudeAPIKey: apiKey.isEmpty ? nil : apiKey
        )
        lastClusteredAt = Date()
    }
}
