# Architectuurbeoordeling RSSReader

| Versie | Datum | Auteur | Wijziging | Status |
|---|---|---|---|---|
| 0.1 | 20-09-2026 | Codex | Eerste beoordeling van de huidige apparchitectuur | Concept |

## Doel en reikwijdte

Deze beoordeling beschrijft de huidige architectuur van RSSReader en vergelijkt
die met Apple-richtlijnen voor SwiftUI, SwiftData, concurrency en veilige
opslag. De beoordeling is gebaseerd op de broncode op 20-09-2026. Er zijn geen
wijzigingen aan de app aangebracht.

## Samenvattend oordeel

RSSReader heeft een goede, pragmatische basis voor een persoonlijke native
iOS-app: SwiftUI, SwiftData, Observation, structured concurrency en Keychain
zijn passend gekozen. De app is doelgericht en bevat bewuste maatregelen voor
performance, annulering en AI-uitval.

De voornaamste ontwikkelrichting is een scherpere scheiding tussen presentatie,
applicatielogica en infrastructuur. Views en services sturen nu geregeld
rechtstreeks SwiftData, netwerkverkeer en foutafhandeling aan. Dat werkt op de
huidige schaal, maar maakt uitbreiding en geautomatiseerd testen geleidelijk
kostbaarder.

## Huidige opbouw

```mermaid
flowchart LR
  V[SwiftUI Views] -->|@Query / ModelContext| D[SwiftData-modellen]
  V -->|start acties| S[Services]
  S --> D
  S --> N[RSS, Mastodon, AI en fact-check APIs]
  S --> K[Keychain en UserDefaults]
```

- **Presentatie:** SwiftUI-views, waaronder `ContentView`, schermen voor
  artikelen, feeds, instellingen en samenvattingen.
- **Domein en opslag:** SwiftData-modellen voor feeds, artikelen, onderwerpen,
  fact-checks, mappen en Mastodon-accounts.
- **Services:** feed-refresh, RSS/OPML-parsing, clustering, AI-samenvatting,
  fact-check, bronwaardering, OAuth en Mastodon.
- **Infrastructuur:** `URLSession`, Keychain, `UserDefaults` en externe APIs.

## Wat goed aansluit op Apple-richtlijnen

### Moderne SwiftUI-dataflow

`@Observable`-services worden met `@State` beheerd en `@Query` verzorgt de
reactieve SwiftData-weergave. Dit past bij Apples aanbeveling voor iOS 17+:
houd een duidelijke source of truth aan en laat SwiftUI alleen de delen van de
interface bijwerken die van die data afhankelijk zijn.

Bron: [Apple — Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app/).

### Concurrency en performance

De app is zorgvuldig in de scheiding tussen UI-gebonden SwiftData-werk en
CPU-intensief werk. `FeedRefreshService` begrenst parallelle feed-refreshes.
`TopicClusteringService` maakt snapshots van modeldata en verplaatst parsing,
tokenisatie en matching naar een detached taak, met expliciete annulering.
Dat beperkt blokkering van de main actor en voorkomt dat SwiftData-objecten
over actorgrenzen gaan.

Bronnen: [Apple — Sendable](https://developer.apple.com/documentation/swift/sendable/), [Apple — TaskGroup](https://developer.apple.com/documentation/swift/taskgroup).

### Model en veerkracht

De SwiftData-relaties en cascade-regels passen bij de gegevensstructuur van de
app. De lokale samenvattingsfallback houdt de feedlezer bruikbaar bij een
ontbrekende sleutel of een falende AI-aanroep; dit ondersteunt de harde
projecteis dat nieuws ook zonder AI leesbaar blijft.

### Geheimen

Nieuwe Claude- en Mastodon-credentials gaan via de Keychain. Dat is de juiste
Apple-voorziening voor kleine geheime waarden, omdat deze versleutelde opslag
biedt.

Bron: [Apple — Keychain services](https://developer.apple.com/documentation/security/keychain-services).

## Verbeterpunten, geprioriteerd

### 1. Voeg een kleine applicatielaag toe

Maak use cases zoals `RefreshFeeds`, `GenerateSummaries` en
`ManageMastodonAccount`. Views geven dan een gebruikersintentie door; de use
case coördineert netwerk, opslag en fouten. Hierdoor hoeven views niet zelf
services en `ModelContext` te combineren.

Dit sluit aan op Apples uitgangspunt dat data en views gescheiden blijven om
modulariteit, testbaarheid en begrijpelijkheid te behouden.

Bron: [Apple — Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app/).

### 2. Splits `TopicClusteringService`

Deze service bevat nu drie verantwoordelijkheden: onderwerpclustering,
samenvattingsbeleid en Anthropic-HTTP/JSON-afhandeling. Splits die bijvoorbeeld
in een `TopicClusterer`, `SummaryGenerator` en `AnthropicClient`. Daarmee
worden tests kleiner en kan de AI-provider later veranderen zonder de
clusteringlogica aan te raken.

### 3. Maak afhankelijkheden vervangbaar in tests

`URLSession.shared`, `UserDefaults.standard`, Keychain en enkele shared
services worden rechtstreeks aangeroepen. Introduceer kleine protocollen en
injecteer implementaties in services. Testcode kan dan zonder echt netwerk,
Keychain of opgeslagen voorkeuren werken.

### 4. Sla samenvattingen bewust op, of verwijder het ongebruikte model

`TopicSummary` staat in het SwiftData-schema, maar de actuele samenvattingen
zijn alleen tijdelijke `TopicCluster`-waarden in `ContentView`. Daardoor
verdwijnen ze bij een nieuwe appstart. Een persistente cache met bron-ids,
generatietijd en invoer-hash voorkomt onnodige AI-calls en geeft sneller een
laatst bekende samenvatting weer. Als dit niet gewenst is, verwijder dan
`TopicSummary` uit het schema om dode architectuur te voorkomen.

### 5. Centraliseer opslagfouten

Veel schermen gebruiken `try? modelContext.save()`. Daardoor kan een
gebruikerswijziging ongemerkt verloren gaan. Maak één opslagfunctie die fouten
logt en, wanneer de gebruiker een expliciete actie uitvoert, een begrijpelijke
melding kan tonen.

### 6. Verwijder de legacy API-key-terugval

De app leest de Claude-sleutel nog als terugval uit `UserDefaults`. Verwijder
die migratieroute nadat bestaande waarden eenmalig veilig naar de Keychain zijn
gemigreerd. Secrets horen niet in gewone voorkeurenopslag.

Bron: [Apple — Using the keychain to manage user secrets](https://developer.apple.com/documentation/security/using-the-keychain-to-manage-user-secrets).

### 7. Bereid Swift 6-concurrency voor

Zet Strict Concurrency Checking eerst op `Complete` en los de meldingen
stapsgewijs op. De huidige bewuste actorgrenzen geven hiervoor een goede basis;
de compiler helpt dan mogelijke dataraces te vinden voordat de app naar Swift
6 overstapt.

Bron: [Apple — Adopting strict concurrency in Swift 6 apps](https://developer.apple.com/documentation/swift/adoptingswift6).

## Schaalbaarheid van SwiftData

De huidige paginering in de artikelenlijst is een goede stap. Bij groei van het
aantal feeds en opgeslagen artikelen is het verstandig verdere verwerking niet
via volledige relatiecollecties zoals `feed.items` te doen, maar via
`FetchDescriptor` met predicate, sortering en een limiet. Dat laat de opslaglaag
alleen de benodigde modellen teruggeven.

Bron: [Apple — FetchDescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor).

## Voorgestelde volgorde

1. De legacy sleutel uit `UserDefaults` verwijderen en opslagfouten
   centraliseren.
2. `TopicClusteringService` opsplitsen en externe afhankelijkheden injecteerbaar
   maken.
3. Beslissen of samenvattingen persistent gecachet worden.
4. Use cases invoeren voor refresh, samenvatting en Mastodon.
5. Strict Concurrency Checking op `Complete` zetten en de resterende meldingen
   oplossen.

## Verificatie

De broncode is onderzocht. Het uitvoeren van de tests was in deze omgeving niet
mogelijk, omdat geen concrete iOS-simulator beschikbaar was.
