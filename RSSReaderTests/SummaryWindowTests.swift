//
//  SummaryWindowTests.swift
//  RSSReaderTests
//

import SwiftData
import XCTest

@testable import RSSReader

/// Toetst het recentheidsvenster van de samenvatting en de terugval op `fetchedAt` (#89).
///
/// De kern: een artikel zonder `pubDate` mag niet permanent binnen het venster vallen
/// (dan komt het in élke samenvatting terug) én niet permanent erbuiten (dan verschijnt
/// het nergens). `fetchedAt` geeft zo'n artikel een eigen klok.
@MainActor
final class SummaryWindowTests: XCTestCase {

    private var container: ModelContainer!
    /// Vast ijkpunt, zodat de tests niet van de echte klok afhangen.
    private let nu = Date(timeIntervalSince1970: 1_800_000_000)

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

    @discardableResult
    private func maakItem(titel: String, pubDate: Date?, fetchedAt: Date?) -> FeedItem {
        let item = FeedItem(title: titel, pubDate: pubDate, fetchedAt: fetchedAt)
        container.mainContext.insert(item)
        return item
    }

    private func urenGeleden(_ uren: Double) -> Date {
        nu.addingTimeInterval(-uren * 3600)
    }

    // MARK: - Het venster

    func testArtikelBinnenHetVensterTeltMee() {
        let item = maakItem(titel: "Vers", pubDate: urenGeleden(2), fetchedAt: urenGeleden(2))
        let binnen = TopicClusteringService.withinSummaryWindow([item], now: nu)
        XCTAssertEqual(binnen.map(\.id), [item.id])
    }

    func testArtikelBuitenHetVensterValtAf() {
        let item = maakItem(titel: "Oud", pubDate: urenGeleden(72), fetchedAt: urenGeleden(72))
        let binnen = TopicClusteringService.withinSummaryWindow([item], now: nu)
        XCTAssertTrue(binnen.isEmpty)
    }

    /// Het venster staat op 48 uur: 47 uur oud telt mee, 49 uur oud niet.
    func testDeGrensLigtOp48Uur() {
        let net = maakItem(titel: "47 uur", pubDate: urenGeleden(47), fetchedAt: nil)
        let netNiet = maakItem(titel: "49 uur", pubDate: urenGeleden(49), fetchedAt: nil)

        let binnen = TopicClusteringService.withinSummaryWindow([net, netNiet], now: nu)

        XCTAssertEqual(binnen.map(\.id), [net.id])
        XCTAssertEqual(AppConfiguration.summaryWindow, 48 * 3600)
    }

    // MARK: - Terugval op fetchedAt

    func testZonderPubDateTeltHetOphaalmomentMee() {
        let item = maakItem(titel: "Geen datum", pubDate: nil, fetchedAt: urenGeleden(1))
        let binnen = TopicClusteringService.withinSummaryWindow([item], now: nu)
        XCTAssertEqual(binnen.map(\.id), [item.id], "Net opgehaald hoort binnen het venster te vallen")
    }

    /// Het gevaar uit #89: zonder eigen klok zou een datumloos artikel in élke
    /// samenvatting blijven terugkomen. Met `fetchedAt` veroudert het gewoon.
    func testEenDatumloosArtikelVeroudertOok() {
        let item = maakItem(titel: "Geen datum, oud", pubDate: nil, fetchedAt: urenGeleden(60))
        let binnen = TopicClusteringService.withinSummaryWindow([item], now: nu)
        XCTAssertTrue(binnen.isEmpty, "Een datumloos artikel hoort na het venster af te vallen")
    }

    func testPubDateWintVanFetchedAt() {
        // Oud artikel dat vandaag pas is opgehaald: de publicatiedatum telt.
        let item = maakItem(titel: "Oud bericht", pubDate: urenGeleden(100), fetchedAt: urenGeleden(1))
        let binnen = TopicClusteringService.withinSummaryWindow([item], now: nu)
        XCTAssertTrue(binnen.isEmpty)
    }

    /// Rijen van vóór deze wijziging hebben geen van beide. Die blijven buiten het
    /// venster, zoals ze zich feitelijk nu al gedragen.
    func testBestaandeRijZonderBeideValtBuitenHetVenster() {
        let item = maakItem(titel: "Oude rij", pubDate: nil, fetchedAt: nil)
        let binnen = TopicClusteringService.withinSummaryWindow([item], now: nu)
        XCTAssertTrue(binnen.isEmpty)
    }

    func testEffectiveDateKiestPubDateDanFetchedAt() {
        let metBeide = maakItem(titel: "Beide", pubDate: urenGeleden(5), fetchedAt: urenGeleden(1))
        let alleenFetched = maakItem(titel: "Alleen fetched", pubDate: nil, fetchedAt: urenGeleden(3))
        let geenVanBeide = maakItem(titel: "Geen", pubDate: nil, fetchedAt: nil)

        XCTAssertEqual(metBeide.effectiveDate, urenGeleden(5))
        XCTAssertEqual(alleenFetched.effectiveDate, urenGeleden(3))
        XCTAssertNil(geenVanBeide.effectiveDate)
    }

    func testNieuwArtikelKrijgtStandaardEenOphaalmoment() {
        let voor = Date()
        let item = FeedItem(title: "Vers opgehaald")
        let na = Date()

        guard let stempel = item.fetchedAt else {
            return XCTFail("Een nieuw artikel hoort standaard een ophaalmoment te krijgen")
        }
        XCTAssertTrue(
            stempel >= voor && stempel <= na,
            "fetchedAt hoort het moment van aanmaken te zijn")
    }

    // MARK: - Opruimen

    /// De losstaande bug uit #89: een datumloos artikel werd door `pubDate ?? .distantFuture`
    /// nooit opgeruimd. Met `effectiveDate` kan dat wel.
    func testDatumloosArtikelIsNuOpruimbaar() {
        let context = container.mainContext
        let feed = Feed(url: "https://example.com/rss", title: "Testfeed")
        context.insert(feed)

        let oud = FeedItem(title: "Oud zonder datum", pubDate: nil, fetchedAt: urenGeleden(24 * 40))
        let vers = FeedItem(title: "Vers", pubDate: nil, fetchedAt: urenGeleden(1))
        let bestaandeRij = FeedItem(title: "Rij van vóór #89", pubDate: nil, fetchedAt: nil)

        for item in [oud, vers, bestaandeRij] {
            item.feed = feed
            feed.items.append(item)
            context.insert(item)
        }

        FeedRefreshService.pruneOldItems(feed: feed, context: context)

        let overgebleven = feed.items.map(\.title)
        XCTAssertFalse(
            overgebleven.contains("Oud zonder datum"),
            "Een datumloos artikel ouder dan de bewaarperiode hoort te worden opgeruimd")
        XCTAssertTrue(overgebleven.contains("Vers"))
        XCTAssertTrue(
            overgebleven.contains("Rij van vóór #89"),
            "Zonder pubDate én zonder fetchedAt blijft een rij staan; er verdwijnt niets onverwachts")
    }

    func testBewaardArtikelBlijftStaan() {
        let context = container.mainContext
        let feed = Feed(url: "https://example.com/rss", title: "Testfeed")
        context.insert(feed)

        let bewaard = FeedItem(title: "Bewaard", pubDate: nil, fetchedAt: urenGeleden(24 * 40))
        bewaard.isSaved = true
        bewaard.feed = feed
        feed.items.append(bewaard)
        context.insert(bewaard)

        FeedRefreshService.pruneOldItems(feed: feed, context: context)

        XCTAssertEqual(feed.items.map(\.title), ["Bewaard"])
    }
}
