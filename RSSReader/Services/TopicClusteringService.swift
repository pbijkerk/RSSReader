import Foundation
import NaturalLanguage
import Observation
import SwiftData
import OSLog

struct TopicCluster {
    var topicName: String
    var keywords: [String]
    var items: [FeedItem]
    var summary: String
}

/// Snapshot of a FeedItem's text — safe to pass across actor boundaries.
private struct ItemSnapshot: Sendable {
    let title: String
    let plainDescription: String
    var fullText: String { "\(title) \(plainDescription)" }
}

@MainActor
@Observable
class TopicClusteringService {
    var isClustering = false
    
    private let logger = Logger(
        subsystem: AppConfiguration.LogSubsystem.main,
        category: AppConfiguration.LogSubsystem.Category.clustering
    )

    private let defaultTopics: [(name: String, keywords: [String])] = [
        ("Artificial Intelligence", ["ai", "artificial intelligence", "machine learning", "llm",
                                     "chatgpt", "openai", "gpt", "neural", "deep learning", "claude",
                                     "gemini", "copilot", "ml", "generative", "transformer", "model"]),
        ("Technology", ["tech", "software", "hardware", "app", "code", "programming", "developer",
                        "startup", "silicon valley", "computer", "digital", "cloud", "saas", "api", "platform"]),
        ("Politics", ["president", "election", "government", "congress", "senate", "democrat",
                      "republican", "political", "vote", "policy", "law", "minister", "parliament", "legislation"]),
        ("Science", ["research", "study", "scientist", "discovery", "space", "nasa", "experiment",
                     "physics", "biology", "climate", "environment", "gene", "medicine", "quantum"]),
        ("Business", ["market", "stock", "economy", "investment", "revenue", "profit", "startup",
                      "ipo", "acquisition", "merger", "ceo", "company", "finance", "trade", "economic"]),
        ("Sports", ["game", "match", "tournament", "championship", "player", "team", "score",
                    "season", "league", "win", "lose", "football", "soccer", "basketball", "tennis"]),
        ("Health", ["health", "medical", "disease", "treatment", "vaccine", "hospital", "doctor",
                    "drug", "clinical", "mental health", "fda", "cancer", "virus", "pandemic"]),
        ("Entertainment", ["movie", "film", "music", "album", "artist", "celebrity", "award",
                           "streaming", "netflix", "disney", "show", "series", "tv", "gaming", "game"])
    ]

    func cluster(
        items: [FeedItem],
        savedTopics: [Topic],
        claudeAPIKey: String?
    ) async -> [TopicCluster] {
        isClustering = true
        defer { isClustering = false }
        
        logger.info("Starting clustering of \(items.count) items")

        // --- Snapshot model data on MainActor BEFORE any async work ---
        let snapshots: [ItemSnapshot] = items.map {
            ItemSnapshot(title: $0.title, plainDescription: $0.plainDescription)
        }

        let likedTopics = savedTopics.filter { $0.isLiked }
        let usingLikedOnly = !likedTopics.isEmpty

        var topicMap: [(name: String, keywords: [String])]
        if usingLikedOnly {
            topicMap = likedTopics.map { ($0.name, $0.keywords) }
        } else {
            topicMap = savedTopics.map { ($0.name, $0.keywords) }
            let savedNames = Set(savedTopics.map { $0.name.lowercased() })
            for dt in defaultTopics where !savedNames.contains(dt.name.lowercased()) {
                topicMap.append(dt)
            }
        }
        
        logger.debug("Using \(topicMap.count) topics for clustering")

        // --- Assign items to topics using snapshots (no SwiftData access) ---
        var indexMap: [String: [Int]] = [:]        // topicName → indices into `items`
        var topicKeywordsMap: [String: [String]] = [:]

        for (name, keywords) in topicMap {
            indexMap[name] = []
            topicKeywordsMap[name] = keywords
        }

        for (idx, snapshot) in snapshots.enumerated() {
            let text = snapshot.fullText.lowercased()
            var bestTopic: String?
            var bestScore = 0

            for (name, keywords) in topicMap {
                let score = keywords.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
                if score > bestScore { bestScore = score; bestTopic = name }
            }

            if bestScore > 0, let topic = bestTopic {
                indexMap[topic, default: []].append(idx)
            }
        }

        // --- Build clusters ---
        var result: [TopicCluster] = []

        for (name, indices) in indexMap {
            guard !indices.isEmpty else { continue }

            let topicItems   = indices.map { items[$0] }
            let topicSnaps   = indices.map { snapshots[$0] }
            let keywords     = topicKeywordsMap[name] ?? []

            let summary: String
            if let apiKey = claudeAPIKey, !apiKey.isEmpty {
                logger.debug("Generating Claude summary for topic: \(name)")
                // Pass only Sendable snapshots to async Claude call
                summary = await generateSummaryWithClaude(
                    topicName: name,
                    snapshots: topicSnaps,
                    apiKey: apiKey
                )
            } else {
                summary = localSummary(topicName: name, snapshots: topicSnaps)
            }

            let sorted = topicItems.sorted {
                ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast)
            }

            result.append(TopicCluster(
                topicName: name,
                keywords: keywords,
                items: sorted,
                summary: summary
            ))
        }
        
        logger.info("Clustering complete: created \(result.count) clusters")

        return result.sorted { $0.items.count > $1.items.count }
    }

    // MARK: - Summary helpers

    private func localSummary(topicName: String, snapshots: [ItemSnapshot]) -> String {
        let snippets = snapshots.prefix(5).map { s -> String in
            let snippet = String(s.plainDescription.prefix(200))
            return snippet.isEmpty ? s.title : "\(s.title): \(snippet)"
        }
        let joined = snippets.joined(separator: ". ")
        let isEnglish = (UserDefaults.standard.string(
            forKey: AppConfiguration.UserDefaultsKeys.summaryLanguage) ?? "nl") == "en"
        let intro = isEnglish
            ? "Recent coverage of \(topicName) includes \(snapshots.count) article(s). "
            : "Recente berichtgeving over \(topicName) omvat \(snapshots.count) artikel(en). "
        return intro + joined + (joined.hasSuffix(".") ? "" : ".")
    }

    private func generateSummaryWithClaude(
        topicName: String,
        snapshots: [ItemSnapshot],
        apiKey: String
    ) async -> String {
        let articleList = snapshots
            .prefix(AppConfiguration.maxArticlesPerSummary)
            .enumerated()
            .map { idx, s in
                let desc = String(s.plainDescription.prefix(300))
                return "\(idx + 1). Title: \(s.title)\(desc.isEmpty ? "" : "\n   Description: \(desc)")"
            }
            .joined(separator: "\n\n")

        let isEnglish = (UserDefaults.standard.string(
            forKey: AppConfiguration.UserDefaultsKeys.summaryLanguage) ?? "nl") == "en"
        let instruction = isEnglish
            ? "Write a summary of 4 to 6 sentences in English describing the main themes and developments. Be factual and objective."
            : "Schrijf een samenvatting van 4 tot 6 zinnen in het Nederlands die de belangrijkste thema's en ontwikkelingen beschrijft. Wees feitelijk en objectief."

        let prompt = """
        You are summarizing news articles grouped by topic. The topic is: "\(topicName)"

        Here are the articles:
        \(articleList)

        \(instruction)
        """

        struct Msg:  Encodable { let role: String; let content: String }
        struct Req:  Encodable { let model: String; let max_tokens: Int; let messages: [Msg] }
        struct RCnt: Decodable { let text: String }
        struct Res:  Decodable { let content: [RCnt] }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            logger.error("Invalid Claude API URL")
            return localSummary(topicName: topicName, snapshots: snapshots)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",        forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONEncoder().encode(
                Req(
                    model: "claude-haiku-4-5-20251001",
                    max_tokens: AppConfiguration.claudeMaxTokens,
                    messages: [Msg(role: "user", content: prompt)]
                )
            )
            let (data, _) = try await URLSession.shared.data(for: request)
            let response  = try JSONDecoder().decode(Res.self, from: data)
            
            if let summary = response.content.first?.text {
                logger.info("Claude summary generated for \(topicName): \(summary.count) chars")
                return summary
            } else {
                logger.warning("Empty Claude response for topic: \(topicName)")
                return localSummary(topicName: topicName, snapshots: snapshots)
            }
        } catch {
            logger.error("Claude API call failed for \(topicName): \(error.localizedDescription)")
            return localSummary(topicName: topicName, snapshots: snapshots)
        }
    }

    func extractKeywords(from text: String, limit: Int = 10) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text.lowercased()

        let stopWords = Set(["the","a","an","and","or","but","in","on","at","to","for","of",
                             "with","by","from","is","was","are","were","be","been","have","has",
                             "had","do","does","did","will","would","could","should","may","might",
                             "this","that","these","those","it","its"])
        var wordCounts: [String: Int] = [:]

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            if let tag, tag == .noun || tag == .adjective {
                let word = String(text[range]).lowercased()
                if word.count > 3, !stopWords.contains(word) {
                    wordCounts[word, default: 0] += 1
                }
            }
            return true
        }

        return wordCounts.sorted { $0.value > $1.value }.prefix(limit).map(\.key)
    }
}
