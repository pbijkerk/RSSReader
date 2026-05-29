import SwiftUI
import SwiftData

struct TopicEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let topic: Topic?

    @State private var name = ""
    @State private var keywordsText = ""
    @State private var isLiked = true
    @State private var newKeyword = ""

    private var isEditing: Bool { topic != nil }

    var keywords: [String] {
        keywordsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                likedSection
                addKeywordSection
                keywordListSection
            }
            .navigationTitle(isEditing ? "Edit Topic" : "New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { loadTopic() }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Topic Name") {
            TextField("e.g. Artificial Intelligence", text: $name)
        }
    }

    private var likedSection: some View {
        Section {
            Toggle("Mark as Liked", isOn: $isLiked)
        } footer: {
            Text("Liked topics are prioritised in your summaries.")
        }
    }

    private var addKeywordSection: some View {
        Section {
            HStack {
                TextField("Add keyword…", text: $newKeyword)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit { addKeyword() }
                Button("Add", action: addKeyword)
                    .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Keywords")
        } footer: {
            Text("Articles containing these keywords will be grouped under this topic.")
        }
    }

    private var keywordListSection: some View {
        Section {
            if keywords.isEmpty {
                Text("No keywords yet")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(keywords, id: \.self) { kw in
                    HStack {
                        Label(kw, systemImage: "tag")
                            .font(.callout)
                        Spacer()
                        Button {
                            removeKeyword(kw)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete { indexSet in
                    var updated = keywords
                    updated.remove(atOffsets: indexSet)
                    keywordsText = updated.joined(separator: ", ")
                }
            }
        }
    }

    // MARK: - Actions

    private func loadTopic() {
        guard let topic else { return }
        name = topic.name
        keywordsText = topic.keywords.joined(separator: ", ")
        isLiked = topic.isLiked
    }

    private func addKeyword() {
        let kw = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty, !keywords.contains(kw) else { return }
        keywordsText = keywordsText.isEmpty ? kw : keywordsText + ", \(kw)"
        newKeyword = ""
    }

    private func removeKeyword(_ kw: String) {
        keywordsText = keywords.filter { $0 != kw }.joined(separator: ", ")
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let topic {
            topic.name = trimmedName
            topic.keywords = keywords
            topic.isLiked = isLiked
            topic.isUserDefined = true
        } else {
            let newTopic = Topic(
                name: trimmedName,
                keywords: keywords,
                isLiked: isLiked,
                isUserDefined: true
            )
            modelContext.insert(newTopic)
        }
        try? modelContext.save()
        dismiss()
    }
}
