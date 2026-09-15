//
//  ArticleFilterTests.swift
//  RSSReaderTests
//

import SwiftData
import XCTest

@testable import RSSReader

/// Voert het predicaat van de artikelenlijst uit tegen een echte in-memory store (#108).
///
/// Waarom tegen een echte store: een fout in een `#Predicate` blijkt pas als hij draait.
/// Compileren zegt niets — SwiftData vertaalt het predicaat pas bij het ophalen naar een
/// query, en struikelt daar over vormen die de compiler wel accepteert.
@MainActor
final class ArticleFilterTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Feed.self, FeedItem.self, FeedFolder.self, Topic.self,
            TopicSummary.self, FactCheckResult.self, MastodonAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDownWithError() throws {
        container = nil
    }

    /// Twee mappen, elk met één feed, plus een losse feed zonder map.
    /// Titels: "tech-gelezen", "tech-ongelezen", "sport-ongelezen", "los-ongelezen".
    @discardableResult
    private func maakTestdata() -> (techFeed: Feed, sportFeed: Feed, losseFeed: Feed) {
        let context = container.mainContext

        let techMap = FeedFolder(name: "Tech", sortOrder: 0)
        let sportMap = FeedFolder(name: "Sport", sortOrder: 1)
        context.insert(techMap)
        context.insert(sportMap)

        let tech = Feed(url: "https://tech.example/rss", title: "Tech")
        tech.folder = techMap
        let sport = Feed(url: "https://sport.example/rss", title: "Sport")
        sport.folder = sportMap
        let los = Feed(url: "https://los.example/rss", title: "Los")
        for feed in [tech, sport, los] { context.insert(feed) }

        func voegToe(_ titel: String, aan feed: Feed, gelezen: Bool) {
            let item = FeedItem(title: titel, pubDate: Date(timeIntervalSince1970: 1_700_000_000))
            item.isRead = gelezen
            item.feed = feed
            feed.items.append(item)
            context.insert(item)
        }

        voegToe("tech-gelezen", aan: tech, gelezen: true)
        voegToe("tech-ongelezen", aan: tech, gelezen: false)
        voegToe("sport-ongelezen", aan: sport, gelezen: false)
        voegToe("los-ongelezen", aan: los, gelezen: false)

        return (tech, sport, los)
    }

    private func titels(hideRead: Bool, feedIDs: [UUID]?) throws -> Set<String> {
        let descriptor = FetchDescriptor<FeedItem>(
            predicate: ArticleFilter.predicate(hideRead: hideRead, feedIDs: feedIDs)
        )
        return Set(try container.mainContext.fetch(descriptor).map(\.title))
    }

    func testZonderFiltersKomtAllesTerug() throws {
        maakTestdata()
        XCTAssertEqual(
            try titels(hideRead: false, feedIDs: nil),
            ["tech-gelezen", "tech-ongelezen", "sport-ongelezen", "los-ongelezen"])
    }

    func testGelezenVerbergenLaatAlleenOngelezenZien() throws {
        maakTestdata()
        XCTAssertEqual(
            try titels(hideRead: true, feedIDs: nil),
            ["tech-ongelezen", "sport-ongelezen", "los-ongelezen"])
    }

    func testMapfilterLaatAlleenDeFeedsUitDieMapZien() throws {
        let feeds = maakTestdata()
        XCTAssertEqual(
            try titels(hideRead: false, feedIDs: [feeds.techFeed.id]),
            ["tech-gelezen", "tech-ongelezen"])
    }

    func testMapfilterEnGelezenVerbergenSamen() throws {
        let feeds = maakTestdata()
        XCTAssertEqual(
            try titels(hideRead: true, feedIDs: [feeds.techFeed.id]),
            ["tech-ongelezen"])
    }

    func testMeerdereFeedsInEenMap() throws {
        let feeds = maakTestdata()
        XCTAssertEqual(
            try titels(hideRead: false, feedIDs: [feeds.techFeed.id, feeds.sportFeed.id]),
            ["tech-gelezen", "tech-ongelezen", "sport-ongelezen"])
    }

    /// Een lege map hoort niets te tonen, niet stiekem alles.
    func testLegeMapLevertNiets() throws {
        maakTestdata()
        XCTAssertTrue(try titels(hideRead: false, feedIDs: []).isEmpty)
    }

    /// Een artikel zonder feed hoort buiten elke mapfilter te vallen. Dat is de `else`-tak
    /// van het predicaat.
    func testArtikelZonderFeedValtBuitenEenMapfilter() throws {
        let feeds = maakTestdata()
        let wees = FeedItem(title: "zonder feed", pubDate: Date(timeIntervalSince1970: 1_700_000_000))
        container.mainContext.insert(wees)

        XCTAssertFalse(try titels(hideRead: false, feedIDs: [feeds.techFeed.id]).contains("zonder feed"))
        XCTAssertTrue(
            try titels(hideRead: false, feedIDs: nil).contains("zonder feed"),
            "Zonder mapfilter hoort het artikel er gewoon bij te staan")
    }
}
