# Changelog

Alle noemenswaardige wijzigingen aan dit project worden in dit bestand bijgehouden.

Het formaat is gebaseerd op [Keep a Changelog](https://keepachangelog.com/nl/1.1.0/)
en dit project volgt [Semantic Versioning](https://semver.org/lang/nl/).

## [Unreleased]

### Gewijzigd
- Vandaag toont nu de samenvatting zelf als kaartenscherm per onderwerp — beweringen met klikbare bronchips, bronduiding en fact-checkwaarschuwing direct zichtbaar — in plaats van een inhoudsopgave die eerst naar de samenvatting doorlinkt; bij meer dan drie beweringen verschijnt een "Toon meer"-knop, en alle teksten zijn nu Nederlands
- Tabbalk teruggebracht van vijf naar drie tabbladen (Vandaag, Artikelen, Bewaard) met leesbaardere labels van 11pt: Onderwerpen staat nu in Instellingen en Instellingen opent via een tandwielknop in de toolbar van Vandaag, als sheet met een Gereed-knop om te sluiten
- Releaseworkflow beschrijft nu het installeren van de nieuwe versie op de iPhone als vaste stap, inclusief de eis om device-builds buiten de iCloud-map te bouwen (anders faalt `codesign`)

## [1.4.2] - 2026-08-09

### Opgelost
- `RSSReaderTests` staat nu als testtarget in `project.yml` en het gedeelde `RSSReader`-scheme voert de tests uit, zodat `xcodebuild test` en `⌘U` de bestaande unit-tests daadwerkelijk draaien en dit een `xcodegen generate` overleeft

## [1.4.1] - 2026-08-09

### Opgelost
- Clustering draait al het CPU-werk (HTML-strippen van artikelteksten, tokenisatie en trefwoord-matching) nu off-main via `Task.detached` in plaats van op de MainActor, zodat refresh en samenvatting de UI niet langer seconden blokkeren; resultaten blijven identiek. Het HTML-strippen is bovendien geëxtraheerd naar `FeedItem.plainText(from:)` met gecachte regexes (geen per-aanroep regex-compilatie)
- Artikellijst in de samenvattingsdetailpagina wordt lazy opgebouwd (`LazyVStack`), zodat het openen van een groot onderwerp (honderden artikelen) niet langer alle rijen en hun navigatiedoelen in één main-thread-pass bouwt en de UI blokkeert
- Clustering hergebruikt en vult nu de platte-tekst-cache van artikelen, zodat dezelfde HTML niet elke ronde opnieuw gestript wordt en de lijstweergaven het strippen niet alsnog op de MainActor doen; daarnaast stopt het off-main CPU-werk nu daadwerkelijk zodra de aanroeper wordt geannuleerd

## [1.4.0] - 2026-07-29

### Toegevoegd
- Unit-tests voor de clustering-toewijzing (woordgrens, meerwoord-frase, case-insensitiviteit, minimumdrempel en tie-break) door de matching-logica testbaar te isoleren zonder productiegedrag te wijzigen
- Bron-duidingsstrip in het artikeldetail: boven alle layouts (audio/video/reader) tonen de politieke positie (`BiasBarView`) en betrouwbaarheid (`ReliabilityBadgeView`) zodra de feed een beoordeling heeft; tik op de bias-balk opent de bestaande transparantie-sheet, en zonder beoordeling verschijnt er niets

### Gewijzigd
- Clustering hergebruikt nu één `NLTokenizer`-instantie in `wordBoundaryText` in plaats van er per aanroep een aan te maken; identieke uitvoer, minder allocaties in de hotloop

## [1.3.0] - 2026-07-29

### Toegevoegd
- Subtiele betrouwbaarheidsmarkering per bron in de samenvatting: de artikelrijen en bron-chips tonen nu een compacte betrouwbaarheidsbadge (hergebruik `ReliabilityBadgeView`), zodat low/mixed bronnen zichtbaar geduid worden; onbekende betrouwbaarheid toont niets en er wordt niets uit de samenvatting weggelaten
- Fact-check-waarschuwing per onderwerp op de samenvattingspagina (lijst en detail): toont een compacte, neutrale melding zodra minstens één artikel in het cluster een betwijfeld verdict heeft, met inklapbare details per bewering en beoordelaar; classificatie is deterministisch (geen AI-call)

### Gewijzigd
- Samenvattingsprompt stuurt bij een onderwerp met meerdere bronnen nu expliciet op synthese: de belangrijkste beweringen leiden met door twee of meer bronnen bevestigde ontwikkelingen, terwijl enkelvoudige-bron-items behouden blijven (R11-garantie ongewijzigd)

## [1.2.1] - 2026-07-29

### Gewijzigd
- App opent nu standaard op de samenvatting-tab in plaats van de feedlijst

## [1.2.0] - 2026-07-29

### Toegevoegd
- Per-onderwerp bronduiding op de samenvattingspagina (lijst en detail): een geaggregeerd politieke-kleurspectrum met "overwegend"-label plus een afgeleid betrouwbaarheidslabel over de distinct bronnen; onbekende ratings tellen niet mee en worden nooit geraden

### Gewijzigd
- Claude API-sleutel wordt in Settings nu echt gevalideerd (lichte `GET /v1/models`): de statusindicator toont pas groen "actief" na een geslaagde controle, met aparte standen voor valideren, ongeldige sleutel (401/403) en "kon niet valideren" bij netwerkfouten — in plaats van groen zodra het veld niet leeg is
- Topic-clustering matcht trefwoorden nu op woordgrens (hele woorden/frasen) in plaats van deelstring, met een instelbare minimumdrempel, zodat toevalstreffers als "ai" in "email" geen artikelen meer in het verkeerde onderwerp trekken
- Samenvattingsprompt stuurt nu op hybride bron-synthese: beweringen citeren alle onderbouwende artikelen bij overlappende berichtgeving, één bron bij een enkele bron (R11-garantie behouden)
- Bron-chip onder een bewering toont nu de artikeltitel (met feednaam als secundair label), zodat meerdere bronnen uit dezelfde feed onderscheidbaar zijn

## [1.1.0] - 2026-07-24

### Gewijzigd
- Instellingenpagina heringedeeld in zeven logische secties, volledig Nederlandstalig
- Alle drie de tekstgrootte-instellingen gebruiken nu dezelfde slider in procenten (80–150%), met één herstel-knop

### Toegevoegd
- Borging bron-attributie (R11): beweringen zonder bron-id zijn onconstrueerbaar en een validatiegate faalt zichtbaar bij een regressie
- Inline bronverwijzingen in samenvattingen: beweringen met stabiele bron-ids, aantikbaar naar het bronartikel in de detailweergave
- Versiebeheer-workflow (Workflow-feature.md) en dit changelog-bestand
- Instelbare tekstgrootte voor bronanalyse en fact-check (10–18pt) in Settings
- Bronanalyse op artikelkaarten: bias-balk, betrouwbaarheidsbadge en fact-check-chip
- Gebeurtenisgroepering in de mapweergave
- Retro Future UI-herontwerp: warme kleuren, magazine-cards, zwevende tab bar, leesvoortgangsbalk

## [1.0.0] - 2026-06-01

### Toegevoegd
- Eerste versie: RSS/Atom-feeds, mappen, OPML-import, Mastodon-integratie,
  AI-samenvattingen (Claude API), podcast- en videoweergave, bewaarde artikelen
