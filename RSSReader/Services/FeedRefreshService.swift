import Foundation
import Observation
import SwiftData
import OSLog

@MainActor
@Observable
class FeedRefreshService {
    var isRefreshing = false
    var lastError: String?
    
    private let logger = Logger(
        subsystem: AppConfiguration.LogSubsystem.main,
        category: AppConfiguration.LogSubsystem.Category.feed
    )

    // Each refresh gets its own parser instance — no shared mutable state
    func refreshAll(feeds: [Feed], context: ModelContext) async {
        isRefreshing = true
        lastError = nil
        
        logger.info("Starting refresh of \(feeds.count) feeds")

        // Parallel refresh voor betere performance, met limiet
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            
            for feed in feeds {
                // Wacht als we de limiet hebben bereikt
                if activeCount >= AppConfiguration.maxParallelRefreshes {
                    await group.next()
                    activeCount -= 1
                }
                
                group.addTask { @MainActor in
                    await self.refresh(feed: feed, context: context)
                }
                activeCount += 1
            }
            
            // Wacht tot alle tasks klaar zijn
            await group.waitForAll()
        }

        // Mastodon accounts ook vernieuwen (sequentieel om rate limiting te respecteren)
        let mastodonDescriptor = FetchDescriptor<MastodonAccount>()
        let accounts = (try? context.fetch(mastodonDescriptor)) ?? []
        
        logger.info("Refreshing \(accounts.count) Mastodon accounts")
        
        for account in accounts {
            guard let feed = account.feed else { continue }
            do {
                try await MastodonService.shared.refreshFeed(account: account, feed: feed, context: context)
            } catch let e as MastodonError {
                logger.error("Mastodon refresh failed: \(e.localizedDescription ?? "Unknown error")")
                if case .httpError(let code, _) = e, code == 401 {
                    account.needsReauth = true
                    try? context.save()
                }
                lastError = e.errorDescription
            } catch {
                logger.error("Mastodon refresh failed: \(error.localizedDescription)")
                lastError = "Mastodon: \(error.localizedDescription)"
            }
        }

        logger.info("Refresh completed")
        isRefreshing = false
    }

    func refresh(feed: Feed, context: ModelContext) async {
        if feed.isMastodonFeed {
            await refreshMastodonFeed(feed, context: context)
            return
        }
        guard let url = URL(string: feed.url) else {
            logger.warning("Invalid feed URL: \(feed.url)")
            return
        }

        do {
            logger.debug("Fetching feed: \(feed.title)")
            let (data, _) = try await URLSession.shared.data(from: url)

            // Parse on a background thread with a fresh parser, return plain structs
            let parsed: ParsedFeed = try await Task.detached(priority: .utility) {
                RSSParser().parse(data: data)
            }.value

            // All model mutations back on MainActor (we already are, but explicit for clarity)
            applyParsedFeed(parsed, to: feed, context: context)
            try context.save()
            
            logger.info("Successfully refreshed feed: \(feed.title)")

        } catch {
            logger.error("Failed to refresh \(feed.title): \(error.localizedDescription)")
            lastError = "Failed to refresh \(feed.title): \(error.localizedDescription)"
        }
    }

    /// All writes to SwiftData happen here, synchronously on MainActor.
    private func applyParsedFeed(_ parsed: ParsedFeed, to feed: Feed, context: ModelContext) {
        if (feed.title == "New Feed" || feed.title.isEmpty), !parsed.title.isEmpty {
            feed.title = parsed.title
        }
        if feed.feedDescription == nil || feed.feedDescription?.isEmpty == true,
           !parsed.description.isEmpty {
            feed.feedDescription = parsed.description
        }

        let existingGuids  = Set(feed.items.compactMap { $0.guid })
        let existingLinks  = Set(feed.items.compactMap { $0.link })
        let existingTitles = Set(feed.items.map { $0.title })

        for parsedItem in parsed.items {
            let isNew: Bool
            if !parsedItem.guid.isEmpty {
                isNew = !existingGuids.contains(parsedItem.guid)
            } else if !parsedItem.link.isEmpty {
                isNew = !existingLinks.contains(parsedItem.link)
            } else {
                isNew = !existingTitles.contains(parsedItem.title)
            }

            guard isNew else { continue }

            let item = FeedItem(
                title: parsedItem.title,
                link: parsedItem.link.isEmpty ? nil : parsedItem.link,
                itemDescription: parsedItem.description.isEmpty ? nil : parsedItem.description,
                pubDate: parsedItem.pubDate,
                guid: parsedItem.guid.isEmpty ? nil : parsedItem.guid,
                enclosureURL: parsedItem.enclosureURL,
                enclosureMIMEType: parsedItem.enclosureMIMEType,
                imageURL: parsedItem.imageURL
            )
            item.feed = feed
            feed.items.append(item)
            context.insert(item)
        }

        // Verwijder artikelen die ouder zijn dan de bewaarperiode
        pruneOldItems(feed: feed, context: context)

        feed.lastRefreshed = Date()

        // Pas bronbeoordeling toe als nog niet beoordeeld of ouder dan 30 dagen
        let ratingAge = feed.biasRatedAt.map { Date().timeIntervalSince($0) } ?? .infinity
        if ratingAge > 30 * 24 * 3_600 {
            SourceRatingService.shared.applyRating(to: feed)
        }

        // Auto-assign to system folder if not already in a folder
        if feed.folder == nil {
            detectAndAssignFolder(feed: feed, parsed: parsed, context: context)
        }
    }

    /// Verwijdert artikelen ouder dan de effectieve bewaarperiode (feed-instelling of globale standaard).
    func pruneOldItems(feed: Feed, context: ModelContext) {
        let globalDefault = UserDefaults.standard.object(
            forKey: AppConfiguration.UserDefaultsKeys.retentionDays
        ) as? Int ?? AppConfiguration.defaultRetentionDays
        
        let effective = feed.retentionDays ?? globalDefault
        guard effective > 0 else { return }
        
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -effective, to: Date()) else {
            logger.warning("Failed to calculate cutoff date for pruning")
            return
        }
        
        let toDelete = feed.items.filter { ($0.pubDate ?? .distantFuture) < cutoff && !$0.isSaved }
        
        if !toDelete.isEmpty {
            logger.debug("Pruning \(toDelete.count) old items from \(feed.title)")
        }
        
        for item in toDelete {
            feed.items.removeAll { $0.id == item.id }
            context.delete(item)
        }
    }

    private func detectAndAssignFolder(feed: Feed, parsed: ParsedFeed, context: ModelContext) {
        let mediaType = detectMediaType(url: feed.url, parsed: parsed)
        guard mediaType != .unknown else { return }
        let folderName = mediaType == .video ? "Video" : "Audio"
        feed.folder = getOrCreateSystemFolder(name: folderName, context: context)
    }

    private func detectMediaType(url: String, parsed: ParsedFeed) -> FeedMediaType {
        let lower = url.lowercased()
        let videoPatterns = ["youtube.com", "youtu.be", "vimeo.com", "dailymotion.com"]
        let audioPatterns = ["anchor.fm", "buzzsprout.com", "libsyn.com", "transistor.fm",
                             "podbean.com", "spreaker.com", "simplecast.com", "megaphone.fm"]
        if videoPatterns.contains(where: { lower.contains($0) }) { return .video }
        if audioPatterns.contains(where: { lower.contains($0) }) { return .audio }
        return parsed.detectedMediaType
    }

    private func getOrCreateSystemFolder(name: String, context: ModelContext) -> FeedFolder {
        let descriptor = FetchDescriptor<FeedFolder>(
            predicate: #Predicate { $0.name == name && $0.isSystem == true }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let allDescriptor = FetchDescriptor<FeedFolder>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let maxOrder = (try? context.fetch(allDescriptor).first?.sortOrder) ?? -1
        let folder = FeedFolder(name: name, sortOrder: maxOrder + 1, isSystem: true)
        context.insert(folder)
        return folder
    }

    private func refreshMastodonFeed(_ feed: Feed, context: ModelContext) async {
        // Fetch all Mastodon accounts en filter in-memory
        // (Predicates met optional relationships zijn complex in SwiftData)
        let descriptor = FetchDescriptor<MastodonAccount>()
        
        guard let accounts = try? context.fetch(descriptor),
              let account = accounts.first(where: { $0.feed?.url == feed.url }) else {
            logger.warning("No Mastodon account found for feed: \(feed.url)")
            return
        }
        
        do {
            try await MastodonService.shared.refreshFeed(account: account, feed: feed, context: context)
        } catch let e as MastodonError {
            logger.error("Mastodon feed refresh failed: \(e.localizedDescription ?? "Unknown")")
            if case .httpError(let code, _) = e, code == 401 {
                account.needsReauth = true
                try? context.save()
            }
            lastError = e.errorDescription
        } catch {
            logger.error("Mastodon feed refresh failed: \(error.localizedDescription)")
            lastError = "Mastodon: \(error.localizedDescription)"
        }
    }

    func fetchFeedTitle(url: String) async throws -> String {
        guard let feedURL = URL(string: url) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        let parsed = try await Task.detached(priority: .utility) {
            RSSParser().parse(data: data)
        }.value
        return parsed.title.isEmpty ? url : parsed.title
    }
}
