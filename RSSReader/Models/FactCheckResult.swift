import SwiftData
import Foundation

@Model
class FactCheckResult {
    var id: UUID
    var claim: String
    var verdict: String
    var rater: String
    var resultURL: String?
    var fetchedAt: Date
    var feedItem: FeedItem?

    init(claim: String, verdict: String, rater: String, resultURL: String? = nil) {
        self.id = UUID()
        self.claim = claim
        self.verdict = verdict
        self.rater = rater
        self.resultURL = resultURL
        self.fetchedAt = Date()
    }
}
