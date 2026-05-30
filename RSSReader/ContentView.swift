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

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedListView(
                refreshService: refreshService,
                onRefreshComplete: { await regenerateSummaries() }
            )
            .tabItem { Label("Feeds", systemImage: "list.bullet.rectangle") }
            .tag(0)

            SummaryListView(
                clusters: $clusters,
                isLoading: clusteringService.isClustering || refreshService.isRefreshing
            )
            .tabItem { Label("Summaries", systemImage: "newspaper") }
            .tag(1)

            TopicsManagementView()
                .tabItem { Label("Topics", systemImage: "tag") }
                .tag(2)

            SavedArticlesView()
                .tabItem { Label("Bewaard", systemImage: "bookmark") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
        .task {
            await refreshAndCluster()
        }
        .onOpenURL { url in
            // Mastodon OAuth callback: rssreader://oauth/mastodon?code=...
            OAuthCallbackHandler.shared.handle(url: url)
        }
    }

    private func refreshAndCluster() async {
        await refreshService.refreshAll(feeds: feeds, context: modelContext)
        await regenerateSummaries()
    }

    private func regenerateSummaries() async {
        let allItems = feeds.flatMap { $0.items }
        // Lees API-sleutel uit Keychain (veilig), val terug op UserDefaults (legacy)
        let apiKey = KeychainService.load(forKey: AppConfiguration.KeychainKeys.claudeAPIKey)
            ?? UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKeys.claudeAPIKey)
            ?? ""
        clusters = await clusteringService.cluster(
            items: allItems,
            savedTopics: topics,
            claudeAPIKey: apiKey.isEmpty ? nil : apiKey
        )
    }
}
