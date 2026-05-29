import SwiftData
import Foundation

@Model
class Topic {
    var id: UUID
    var name: String
    var keywords: [String]
    var isLiked: Bool
    var isUserDefined: Bool
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var summaries: [TopicSummary] = []

    init(name: String, keywords: [String] = [], isLiked: Bool = false, isUserDefined: Bool = false) {
        self.id = UUID()
        self.name = name
        self.keywords = keywords
        self.isLiked = isLiked
        self.isUserDefined = isUserDefined
        self.createdAt = Date()
    }
}

@Model
class TopicSummary {
    var id: UUID
    var topicName: String
    var summaryText: String
    var createdAt: Date
    var itemTitles: [String]
    var itemLinks: [String]
    var topic: Topic?

    init(
        topicName: String,
        summaryText: String,
        itemTitles: [String],
        itemLinks: [String]
    ) {
        self.id = UUID()
        self.topicName = topicName
        self.summaryText = summaryText
        self.createdAt = Date()
        self.itemTitles = itemTitles
        self.itemLinks = itemLinks
    }
}
