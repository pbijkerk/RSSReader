import SwiftUI
import SwiftData

struct TopicsManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.name) private var topics: [Topic]

    @State private var showAddTopic = false
    @State private var topicToEdit: Topic?

    var body: some View {
        NavigationStack {
            Group {
                if topics.isEmpty {
                    emptyState
                } else {
                    topicList
                }
            }
            .navigationTitle("Topics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Topic", systemImage: "plus") {
                        showAddTopic = true
                    }
                }
            }
            .sheet(isPresented: $showAddTopic) {
                TopicEditView(topic: nil)
            }
            .sheet(item: $topicToEdit) { topic in
                TopicEditView(topic: topic)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Saved Topics")
                .font(.title2.bold())
            Text("Topics you like from summaries will appear here. You can also add custom topics.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Add Topic") { showAddTopic = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var topicList: some View {
        List {
            ForEach(topics) { topic in
                TopicRowView(topic: topic)
                    .contentShape(Rectangle())
                    .onTapGesture { topicToEdit = topic }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(topic)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            topic.isLiked.toggle()
                            try? modelContext.save()
                        } label: {
                            Label(
                                topic.isLiked ? "Unlike" : "Like",
                                systemImage: topic.isLiked ? "heart.slash" : "heart.fill")
                        }
                        .tint(topic.isLiked ? .gray : .pink)
                    }
            }
        }
    }
}

struct TopicRowView: View {
    let topic: Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(topic.name)
                    .font(.headline)
                if topic.isLiked {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .font(.caption)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !topic.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(topic.keywords.prefix(8), id: \.self) { kw in
                            Text(kw)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
