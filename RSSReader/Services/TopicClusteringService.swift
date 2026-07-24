import Foundation
import NaturalLanguage
import Observation
import SwiftData
import OSLog

/// Eén bewering uit een samenvatting, gekoppeld aan de bronartikelen (FeedItem.id)
/// die de bewering onderbouwen. `sourceItemIDs` bevat altijd >= 1 stabiele id.
struct SummaryStatement: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let sourceItemIDs: [UUID]

    /// R11-borging: een bewering is onconstrueerbaar zonder tekst én >= 1 bron-id.
    /// Levert `nil` bij een lege tekst of ontbrekende bron, zodat een bronloze
    /// bewering nooit ontstaat en dus nooit gerenderd wordt.
    init?(text: String, sourceItemIDs: [UUID]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sourceItemIDs.isEmpty else { return nil }
        self.text = trimmed
        self.sourceItemIDs = sourceItemIDs
    }
}

struct TopicCluster {
    var topicName: String
    var keywords: [String]
    var items: [FeedItem]
    /// Gestructureerde beweringen met bron-ids — renderpunt voor inline bronverwijzingen.
    var statements: [SummaryStatement]
    /// Platte previewtekst (samengevoegde beweringen) voor lijstweergaven.
    var summary: String { statements.map(\.text).joined(separator: " ") }
}

/// Snapshot of a FeedItem's text — safe to pass across actor boundaries.
/// `id` draagt FeedItem.id zodat bron-ids stabiel zijn (geen positienummer).
private struct ItemSnapshot: Sendable {
    let id: UUID
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
            ItemSnapshot(id: $0.id, title: $0.title, plainDescription: $0.plainDescription)
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

            let statements: [SummaryStatement]
            if let apiKey = claudeAPIKey, !apiKey.isEmpty {
                logger.debug("Generating Claude summary for topic: \(name)")
                // Pass only Sendable snapshots to async Claude call
                statements = await generateSummaryWithClaude(
                    topicName: name,
                    snapshots: topicSnaps,
                    apiKey: apiKey
                )
            } else {
                statements = localSummary(topicName: name, snapshots: topicSnaps)
            }

            let sorted = topicItems.sorted {
                ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast)
            }

            result.append(TopicCluster(
                topicName: name,
                keywords: keywords,
                items: sorted,
                statements: validated(statements, topicName: name)
            ))
        }
        
        logger.info("Clustering complete: created \(result.count) clusters")

        return result.sorted { $0.items.count > $1.items.count }
    }

    // MARK: - Summary helpers

    /// R11-validatiegate: borgt dat elke bewering >= 1 bron-id draagt. De failable
    /// `SummaryStatement`-init maakt bronloze beweringen onmogelijk; deze gate vangt
    /// een eventuele regressie zichtbaar af (foutlog + assertie in debug) en filtert
    /// bronloze beweringen weg zodat ze in release nooit gerenderd worden.
    private func validated(_ statements: [SummaryStatement], topicName: String) -> [SummaryStatement] {
        // De failable init maakt deze tak in de praktijk onbereikbaar; hij blijft
        // opzettelijk als regressievanger voor toekomstige constructiepaden.
        let sourceless = statements.filter { $0.sourceItemIDs.isEmpty }
        guard sourceless.isEmpty else {
            logger.error("R11-schending: \(sourceless.count) bronloze bewering(en) voor topic: \(topicName)")
            assertionFailure("R11: bewering zonder bron-id in gegenereerde samenvatting")
            return statements.filter { !$0.sourceItemIDs.isEmpty }
        }
        return statements
    }

    private func currentSummaryLength() -> AppConfiguration.SummaryLength {
        let raw = UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKeys.summaryLength)
            ?? AppConfiguration.defaultSummaryLength
        return AppConfiguration.SummaryLength(rawValue: raw) ?? .normaal
    }

    /// Fallback zonder AI: één bewering per bronartikel, elk gekoppeld aan zijn
    /// eigen FeedItem.id. Levert altijd >= 1 bron-id per bewering.
    private func localSummary(topicName: String, snapshots: [ItemSnapshot]) -> [SummaryStatement] {
        let length = currentSummaryLength()
        let isEnglish = (UserDefaults.standard.string(
            forKey: AppConfiguration.UserDefaultsKeys.summaryLanguage) ?? "nl") == "en"

        let selected = Array(snapshots.prefix(length.localSnippetCount))

        // Geen bronnen beschikbaar: één introbewering met alle ids. Zonder ids
        // levert de failable init nil en blijft de samenvatting bronloos-vrij.
        guard !selected.isEmpty else {
            let intro = isEnglish
                ? "Recent coverage of \(topicName) includes \(snapshots.count) article(s)."
                : "Recente berichtgeving over \(topicName) omvat \(snapshots.count) artikel(en)."
            return [SummaryStatement(text: intro, sourceItemIDs: snapshots.map(\.id))]
                .compactMap { $0 }
        }

        return selected.compactMap { s in
            let snippet = String(s.plainDescription.prefix(200))
            let text = snippet.isEmpty ? s.title : "\(s.title): \(snippet)"
            return SummaryStatement(text: text, sourceItemIDs: [s.id])
        }
    }

    private func generateSummaryWithClaude(
        topicName: String,
        snapshots: [ItemSnapshot],
        apiKey: String
    ) async -> [SummaryStatement] {
        let length = currentSummaryLength()
        // Beperk tot de eerste N artikelen; bewaar deze snapshots zodat het
        // 1-based bronnummer dat Claude teruggeeft naar FeedItem.id te mappen is.
        let usedSnapshots = Array(snapshots.prefix(AppConfiguration.maxArticlesPerSummary))
        let articleList = usedSnapshots
            .enumerated()
            .map { idx, s in
                let desc = String(s.plainDescription.prefix(300))
                return "[\(idx + 1)] Title: \(s.title)\(desc.isEmpty ? "" : "\n    Description: \(desc)")"
            }
            .joined(separator: "\n\n")

        let isEnglish = (UserDefaults.standard.string(
            forKey: AppConfiguration.UserDefaultsKeys.summaryLanguage) ?? "nl") == "en"
        let instruction = isEnglish ? length.sentenceInstruction.en : length.sentenceInstruction.nl

        let prompt = """
        You are summarizing news articles grouped by topic. The topic is: "\(topicName)"

        Each article is prefixed with a bracketed source number, e.g. [1], [2].

        Here are the articles:
        \(articleList)

        \(instruction)

        Break the summary into individual statements. Every statement MUST cite \
        at least one source number of the article(s) it is based on. Do not invent \
        source numbers; only use numbers that appear above.

        Respond with ONLY a JSON object, no prose and no markdown fences, in exactly \
        this shape:
        {"statements":[{"text":"<one sentence>","sources":[1,2]}]}
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
                    max_tokens: length.maxTokens,
                    messages: [Msg(role: "user", content: prompt)]
                )
            )
            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            guard let http = httpResponse as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                let code = (httpResponse as? HTTPURLResponse)?.statusCode ?? -1
                logger.error("Claude API returned status \(code) for topic: \(topicName)")
                return localSummary(topicName: topicName, snapshots: snapshots)
            }

            let response = try JSONDecoder().decode(Res.self, from: data)

            guard let rawText = response.content.first?.text else {
                logger.warning("Empty Claude response for topic: \(topicName)")
                return localSummary(topicName: topicName, snapshots: snapshots)
            }

            let statements = parseStatements(from: rawText, snapshots: usedSnapshots)
            guard !statements.isEmpty else {
                logger.warning("No usable statements decoded for topic: \(topicName)")
                return localSummary(topicName: topicName, snapshots: snapshots)
            }

            logger.info("Claude summary generated for \(topicName): \(statements.count) statement(s)")
            return statements
        } catch {
            logger.error("Claude API call failed for \(topicName): \(error.localizedDescription)")
            return localSummary(topicName: topicName, snapshots: snapshots)
        }
    }

    /// Decodeert Claude's JSON-respons naar beweringen en mapt de 1-based
    /// bronnummers naar stabiele FeedItem.id's. Beweringen zonder geldige bron
    /// worden weggelaten zodat elke bewering >= 1 bron-id houdt.
    private func parseStatements(
        from rawText: String,
        snapshots: [ItemSnapshot]
    ) -> [SummaryStatement] {
        struct ClaudeStatement: Decodable { let text: String; let sources: [Int] }
        struct ClaudeSummary:   Decodable { let statements: [ClaudeStatement] }

        // Verwijder eventuele markdown-fences en isoleer het JSON-object.
        var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
                         .replacingOccurrences(of: "```", with: "")
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return []
        }
        let jsonSlice = String(cleaned[start...end])

        guard let data = jsonSlice.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ClaudeSummary.self, from: data) else {
            return []
        }

        return decoded.statements.compactMap { st -> SummaryStatement? in
            // 1-based bronnummer → FeedItem.id; ongeldige nummers negeren.
            let ids = st.sources.compactMap { num -> UUID? in
                let idx = num - 1
                guard snapshots.indices.contains(idx) else { return nil }
                return snapshots[idx].id
            }
            // Failable init weigert lege tekst of ontbrekende bron (R11).
            return SummaryStatement(text: st.text, sourceItemIDs: ids)
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
