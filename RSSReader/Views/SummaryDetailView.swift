import SwiftUI
import SwiftData

struct SummaryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var topics: [Topic]

    let cluster: TopicCluster

    @AppStorage(AppConfiguration.UserDefaultsKeys.articleFontSize)
    private var fontSize = AppConfiguration.defaultArticleFontSize

    @AppStorage(AppConfiguration.UserDefaultsKeys.articleFontFamily)
    private var fontFamily = AppConfiguration.defaultArticleFontFamily

    private var accent: Color { Theme.brandColor(for: cluster.topicName) }

    private var summaryFont: Font {
        switch fontFamily {
        case "charter":   return .custom("Charter", size: CGFloat(fontSize))
        case "newyork":   return .custom("New York", size: CGFloat(fontSize))
        case "georgia":   return .custom("Georgia", size: CGFloat(fontSize))
        default:          return .system(size: CGFloat(fontSize))
        }
    }

    @State private var showTopicPrompt = false
    @State private var topicAlreadySaved = false
    @State private var savedTopic: Topic?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topicHeader
                summarySection
                articlesSection
            }
            .padding()
        }
        .navigationTitle(cluster.topicName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            checkIfTopicSaved()
        }
        .task {
            // Use .task so the delay is automatically cancelled if the view disappears
            guard !topicAlreadySaved else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, !topicAlreadySaved else { return }
            withAnimation { showTopicPrompt = true }
        }
        .safeAreaInset(edge: .bottom) {
            if showTopicPrompt && !topicAlreadySaved {
                topicPromptBanner
            }
        }
    }

    private var topicHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(cluster.items.count) articles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if topicAlreadySaved {
                    Label("Saved topic", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            if topicAlreadySaved {
                Button {
                    removeTopic()
                } label: {
                    Label("Remove", systemImage: "heart.slash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    /// FeedItem's uit deze cluster, opzoekbaar via id voor de bronverwijzingen.
    private var itemsByID: [UUID: FeedItem] {
        Dictionary(cluster.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "doc.text")
                .font(.headline)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(cluster.statements) { statement in
                        statementRow(statement)
                    }
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func statementRow(_ statement: SummaryStatement) -> some View {
        let sources = statement.sourceItemIDs.compactMap { itemsByID[$0] }

        VStack(alignment: .leading, spacing: 6) {
            Text(statement.text)
                .font(summaryFont)
                .lineSpacing(4)

            if !sources.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(sources) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            sourceChip(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sourceChip(for item: FeedItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .imageScale(.small)
            Text(item.feed?.title ?? item.title)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(accent.opacity(0.12), in: Capsule())
    }

    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Articles in this summary", systemImage: "list.bullet")
                .font(.headline)

            ForEach(cluster.items) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ArticleRowView(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var topicPromptBanner: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Do you like this topic?")
                        .font(.subheadline.bold())
                    Text("Save \"\(cluster.topicName)\" for future summaries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { showTopicPrompt = false }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                Button("Save") {
                    saveTopic()
                    withAnimation { showTopicPrompt = false }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func checkIfTopicSaved() {
        savedTopic = topics.first { $0.name.lowercased() == cluster.topicName.lowercased() }
        topicAlreadySaved = savedTopic != nil
    }

    private func saveTopic() {
        let topic = Topic(
            name: cluster.topicName,
            keywords: cluster.keywords,
            isLiked: true,
            isUserDefined: false
        )
        modelContext.insert(topic)
        try? modelContext.save()
        topicAlreadySaved = true
        savedTopic = topic
    }

    private func removeTopic() {
        if let topic = savedTopic {
            modelContext.delete(topic)
            try? modelContext.save()
            topicAlreadySaved = false
            savedTopic = nil
        }
    }
}

/// Eenvoudige wrap-layout die subviews op regels plaatst en doorbreekt bij de
/// beschikbare breedte — gebruikt voor de rij bronverwijzingen per bewering.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ArticleRowView: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.subheadline.bold())
                .lineLimit(2)
                .foregroundStyle(.primary)
            HStack {
                if let feedTitle = item.feed?.title {
                    Text(feedTitle)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                Spacer()
                if let date = item.pubDate {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
