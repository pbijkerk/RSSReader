import SwiftUI

struct SummaryListView: View {
    @Binding var clusters: [TopicCluster]
    let isLoading: Bool

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if clusters.isEmpty {
                    emptyView
                } else {
                    clusterList
                }
            }
            .navigationTitle("Summaries")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your feeds…")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Summaries Yet")
                .font(.title2.bold())
            Text("Add RSS feeds and summaries will appear here grouped by topic.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private var clusterList: some View {
        List(clusters, id: \.topicName) { cluster in
            NavigationLink(destination: SummaryDetailView(cluster: cluster)) {
                TopicClusterRowView(cluster: cluster)
            }
        }
    }
}

struct TopicClusterRowView: View {
    let cluster: TopicCluster

    private var accent: Color { Theme.brandColor(for: cluster.topicName) }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(cluster.topicName)
                        .font(.headline)
                    Spacer()
                    Text("\(cluster.items.count) articles")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent, in: Capsule())
                }

                Text(cluster.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                if let latest = cluster.items.first?.pubDate {
                    Text("Latest: \(latest, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
