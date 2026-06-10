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
        // Sla over als recent gecontroleerd — vóór Keychain-read om onnodige I/O te vermijden
        if let checkedAt = item.factCheckCheckedAt,
           Date().timeIntervalSince(checkedAt) < AppConfiguration.factCheckCacheDays * 86_400 { return }

        guard
            let apiKey = KeychainService.load(forKey: AppConfiguration.KeychainKeys.googleFactCheckAPIKey),
            !apiKey.isEmpty
        else { return }

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
                    guard !review.textualRating.isEmpty else { continue }
                    let result = FactCheckResult(
                        claim: claim.text,
                        verdict: review.textualRating,
                        rater: review.publisher.name,
                        resultURL: review.url
                    )
                    context.insert(result)  // insert vóór relationship voor SwiftData-garantie
                    result.feedItem = item
                    item.factCheckResults.append(result)
                }
            }

            item.factCheckCheckedAt = Date()
            try? context.save()
            logger.info("Fact-check klaar voor '\(item.title.prefix(40))': \(item.factCheckResults.count) claim(s)")

        } catch let error as DecodingError {
            switch error {
            case .keyNotFound(let key, _):
                logger.error("Fact-check decode fout: veld '\(key.stringValue)' ontbreekt in API-response")
            case .typeMismatch(_, let ctx), .valueNotFound(_, let ctx), .dataCorrupted(let ctx):
                logger.error("Fact-check decode fout: \(ctx.debugDescription)")
            @unknown default:
                logger.error("Fact-check decode fout: \(error.localizedDescription)")
            }
        } catch {
            logger.error("Fact-check fout: \(error.localizedDescription)")
        }
    }
}

// MARK: - Google Fact Check Tools API response

private struct FCAPIResponse: Decodable {
    var claims: [FCClaim] = []  // default [] zodat {} (lege API-response) niet gooit
    struct FCClaim: Decodable {
        let text: String
        var claimReview: [FCReview] = []  // afwezig als claim geen reviews heeft
    }
    struct FCReview: Decodable {
        let publisher: FCPublisher
        let url: String?
        var textualRating: String = ""    // optioneel in Google API
    }
    struct FCPublisher: Decodable {
        let name: String
    }
}
