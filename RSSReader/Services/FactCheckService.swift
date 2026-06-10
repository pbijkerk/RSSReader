import Foundation
import SwiftData
import OSLog

@MainActor
final class FactCheckService {
    static let shared = FactCheckService()

    private let logger = Logger(
        subsystem: AppConfiguration.LogSubsystem.main,
        category: "factcheck"
    )

    private init() {}

    func checkItem(_ item: FeedItem, context: ModelContext) async {
        guard
            let apiKey = KeychainService.load(forKey: AppConfiguration.KeychainKeys.googleFactCheckAPIKey),
            !apiKey.isEmpty
        else { return }

        // Sla over als recent gecontroleerd
        if let checkedAt = item.factCheckCheckedAt,
           Date().timeIntervalSince(checkedAt) < AppConfiguration.factCheckCacheDays * 86_400 { return }

        var components = URLComponents(string: "https://factchecktools.googleapis.com/v1alpha1/claims:search")!
        components.queryItems = [
            URLQueryItem(name: "query",    value: String(item.title.prefix(120))),
            URLQueryItem(name: "key",      value: apiKey),
            URLQueryItem(name: "pageSize", value: "3"),
        ]
        guard let url = components.url else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                logger.error("Fact Check API HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }

            let parsed = try JSONDecoder().decode(FCAPIResponse.self, from: data)

            // Verwijder verouderde resultaten
            for old in item.factCheckResults { context.delete(old) }
            item.factCheckResults.removeAll()

            for claim in parsed.claims.prefix(3) {
                guard !claim.text.isEmpty else { continue }
                for review in claim.claimReview.prefix(1) {
                    let result = FactCheckResult(
                        claim: claim.text,
                        verdict: review.textualRating,
                        rater: review.publisher.name,
                        resultURL: review.url
                    )
                    result.feedItem = item
                    item.factCheckResults.append(result)
                    context.insert(result)
                }
            }

            item.factCheckCheckedAt = Date()
            try? context.save()
            logger.info("Fact-check klaar voor '\(item.title.prefix(40))': \(item.factCheckResults.count) claim(s)")

        } catch {
            logger.error("Fact-check fout: \(error.localizedDescription)")
        }
    }
}

// MARK: - Google Fact Check Tools API response

private struct FCAPIResponse: Decodable {
    let claims: [FCClaim]
    struct FCClaim: Decodable {
        let text: String
        let claimReview: [FCReview]
    }
    struct FCReview: Decodable {
        let publisher: FCPublisher
        let url: String?
        let textualRating: String
    }
    struct FCPublisher: Decodable {
        let name: String
    }
}
