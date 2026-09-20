# Tegenbeoordeling architectuurbeoordeling RSSReader

| Versie | Datum | Auteur | Wijziging | Status |
|---|---|---|---|---|
| 0.1 | 20-09-2026 | Claude | Tegenbeoordeling van `architectuurbeoordeling_v0.1_concept.md` (Codex) | Concept |
| 0.2 | 20-09-2026 | Claude | Aanscherping Codex op `persistClaudeKey()` verwerkt en uitgebreid; volgorde geconvergeerd | Concept |

## Doel en reikwijdte

Deze notitie weegt de zeven verbeterpunten uit de architectuurbeoordeling van
20-09-2026 tegen de projectbrief (herijkt 22-07-2026) en de feitelijke
broncode. Per punt volgt één oordeel: **overnemen**, **aanpassen** of
**afwijzen**. Er zijn geen wijzigingen aan de app aangebracht.

**Weegkader.** De projectbrief legt drie dingen vast die voor architectuurwerk
bepalend zijn:

- Eén gebruiker, geen App Store, geen andere belanghebbenden.
- De actieve koers is één feature: de samenvatting als hoofdpagina (R1–R3, R11).
- AI-uitval is een harde eis (R8), kosten zijn begrensd (R9).

Architectuurwerk concurreert dus rechtstreeks met featurewerk. Een voorstel
moet ofwel een reëel risico wegnemen, ofwel de hoofdpagina-feature goedkoper
maken. Structuur "omdat het netter is" valt buiten dat kader.

## Samenvattend oordeel

De beoordeling is feitelijk accuraat — elke concrete claim is in de code
teruggevonden. De zwakte zit niet in de waarnemingen maar in de weging: de
aanbevelingen zijn geordend naar architectuurzuiverheid, niet naar risico of
naar de koers van dit project. Twee punten met echt risico (opslagfouten,
legacy sleutel) staan naast twee punten die op deze schaal vooral bestanden
toevoegen (use cases, injecteerbare afhankelijkheden).

Eén punt bevat een aanname die niet klopt: de beoordeling gaat ervan uit dat
een Keychain-migratie al heeft plaatsgevonden. Die bestaat niet. Het advies
letterlijk opvolgen kost de gebruiker zijn API-sleutel.

| # | Punt uit de beoordeling | Oordeel | Reden in één regel |
|---|---|---|---|
| 5 | Centraliseer opslagfouten | **Overnemen** | Enig punt met risico op stil dataverlies; 28 vindplaatsen |
| 6 | Verwijder legacy API-key-terugval | **Aanpassen** | Migratie ontbreekt — éérst bouwen, dán verwijderen |
| 4 | Samenvattingen opslaan of `TopicSummary` verwijderen | **Aanpassen** | Beslissing uitstellen tot #14 het model vastlegt |
| 2 | Splits `TopicClusteringService` | **Overnemen (beperkt)** | 737 regels; splits op de naad die #14 tóch raakt |
| 7 | Bereid Swift 6-concurrency voor | **Aanpassen** | Waardevol, maar ná de hoofdpagina-feature |
| 3 | Maak afhankelijkheden vervangbaar in tests | **Afwijzen (nu)** | Abstractie zonder afnemer; 5 vindplaatsen |
| 1 | Voeg een applicatielaag toe (use cases) | **Afwijzen** | Hoogste kosten, laagste opbrengst bij één gebruiker |

## Correctie op de beoordeling

**Punt 6 rust op een onjuiste aanname.** De beoordeling schrijft: "Verwijder
die migratieroute nadat bestaande waarden eenmalig veilig naar de Keychain zijn
gemigreerd." Er ís geen eenmalige migratie. Wat er staat is een *luie* migratie
die alleen afgaat als de gebruiker Instellingen opent en het sleutelveld
wijzigt:

- `SettingsView.swift:159-160` — schrijft naar de Keychain en verwijdert daarna
  pas de UserDefaults-waarde.
- `ContentView.swift:69-70` en `SettingsView.swift:136-137` — lezen beide met
  de UserDefaults-terugval.

Wordt alleen de terugval verwijderd, dan verliest een installatie waar de
sleutel nog in UserDefaults staat zijn sleutel zonder melding. Gevolg: de
samenvatting valt terug op `localSummary` (R8 vangt dat netjes op), maar de
hoofdfunctie is stil weg. De volgorde moet dus omgekeerd: eerst een migratie
bij het opstarten, daarna beide leesterugvallen weg.

## Oordeel per punt

### Punt 5 — Centraliseer opslagfouten → **overnemen**, als eerste

Geverifieerd: `try? modelContext.save()` staat **28×** verspreid over **13**
view-bestanden. De beoordeling noemt dit punt wel, maar zet het op plaats 1 van
de volgorde *samen met* punt 6 en kwantificeert het niet.

Dit is het enige voorstel waarbij de huidige code stil gebruikerswerk kan
weggooien: bewaren, mappen indelen, onderwerpen bewerken. Bij één gebruiker
zonder synchronisatie is er geen tweede kans om het te ontdekken.

Voorstel: één `save(_ context:)`-helper die logt en bij expliciete
gebruikersacties een melding kan tonen — geen bredere herstructurering.

### Punt 6 — Legacy API-key-terugval → **aanpassen** (volgorde omdraaien)

Inhoudelijk correct: geheimen horen niet in UserDefaults. Zie de correctie
hierboven voor de volgorde.

**Aanvulling 0.2 — `persistClaudeKey()` verwijdert de legacywaarde ook bij een
mislukte Keychain-write.** Aangedragen door Codex, geverifieerd en bevestigd:

```swift
// SettingsView.swift:158-161
private func persistClaudeKey() {
    KeychainService.save(claudeAPIKey, forKey: AppConfiguration.KeychainKeys.claudeAPIKey)
    UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKeys.claudeAPIKey)
}
```

`KeychainService.save` geeft een `Bool` terug (`KeychainService.swift:17-36`,
`@discardableResult`); die wordt hier genegeerd. Mislukt de write, dan
verdwijnt de legacywaarde alsnog.

Twee bevindingen die Codex niet noemt en die de ernst vergroten:

- **De Keychain-write is zelf niet atomair.** `save` doet eerst
  `SecItemDelete` en daarna `SecItemAdd` (`KeychainService.swift:27-30`).
  Faalt de `SecItemAdd`, dan is de *bestaande* Keychain-waarde al weg. In
  combinatie met de onvoorwaardelijke `removeObject` hierboven zijn bij één
  mislukte schrijfactie **beide** kopieën verdwenen.
- **`persistClaudeKey()` draait bij elke wijziging van het veld**
  (`SettingsView.swift:125-128`), inclusief de wijziging die `loadStoredValues`
  zelf veroorzaakt bij `onAppear`. Het openen van het instellingenscherm is
  daarmee de feitelijke migratie — de gebruiker hoeft niets te typen. Dat
  verklaart waarom de legacy-terugval in de praktijk zelden aanslaat, en het
  betekent tegelijk dat bovengenoemde faalroute bij élk bezoek aan
  Instellingen wordt afgelopen, en bij elke toetsaanslag opnieuw.

Praktische kans op schade is klein — het scherm staat op de voorgrond, dus het
toestel is ontgrendeld en de standaard-toegankelijkheid is voldoende. Maar het
patroon is verkeerd om, en de migratie uit stap 2 erft het als die op `save`
wordt gebouwd.

**Veilige volgorde (overgenomen van Codex, met twee toevoegingen):**

1. Maak de write atomair: `SecItemCopyMatching` → `SecItemUpdate` bij een
   bestaand item, `SecItemAdd` alleen bij een nieuw item. Verwijder nooit
   vóór een geslaagde write. *(toevoeging)*
2. Schrijf naar de Keychain en **controleer de returnwaarde**.
3. Verwijder de legacywaarde pas na een bevestigde write — zowel in
   `persistClaudeKey()` als in de migratie.
4. Laat de opstartmigratie idempotent zijn: geen Keychain-waarde aanwezig én
   wél een UserDefaults-waarde → migreren; in alle andere gevallen niets doen.
   *(toevoeging)*
5. Verwijder de leesterugvallen (`ContentView.swift:70`,
   `SettingsView.swift:137`) en de legacy-key
   (`AppConfiguration.swift:97`) pas nadat die migratie op het toestel is
   uitgerold en geverifieerd.

Nuancering van het risico blijft staan: dit is een persoonlijk toestel zonder
distributie. De urgentie is "hygiëne plus één reële faalroute", niet "lek".

### Punt 4 — `TopicSummary` → **aanpassen**: beslissing uitstellen, niet nu forceren

Geverifieerd: `TopicSummary` zit in het schema (`RSSReaderApp.swift:11`) en in
de cascade-relatie op `Topic` (`Models/Topic.swift:12`), maar wordt nergens
weggeschreven. De actuele samenvattingen leven als `clusters` in `ContentView`.
De waarneming klopt dus.

De beoordeling stelt de keuze echter nú, terwijl issue #14 (gestructureerde
generatie: beweringen met bron-ids, bronduiding per onderwerp, fact-check per
bewering) het datamodel van een samenvatting juist gaat vastleggen. Nu een
persistente cache ontwerpen op het huidige, nog te vervangen model is werk dat
#14 weer weggooit — en `TopicSummary` weghalen om het straks opnieuw in te
voeren evenmin.

Wel relevant, en in de beoordeling onderbelicht: een persistente cache raakt
R9 (kostenkader) en geeft bij het opstarten direct een laatst bekende
samenvatting in plaats van een leeg scherm — precies de hoofdpagina uit R1.
Beleg dit als eis binnen #14, niet als losse opruimactie.

### Punt 2 — `TopicClusteringService` splitsen → **overnemen, maar beperkt**

Geverifieerd: 737 regels, het grootste bestand in `Services/`, en de drie
genoemde verantwoordelijkheden zijn in de structuur zichtbaar (clustering rond
`performCluster`, samenvattingsbeleid rond `currentSummaryLength` /
`localSummary`, Anthropic-HTTP/JSON rond `generateSummaryWithClaude` /
`parseStatements`).

De voorgestelde driedeling is verdedigbaar, maar de winst zit niet in "de
AI-provider kan later veranderen" — die wisselt in dit project niet. De winst
is dat #14 zich volledig in de prompt-, parse- en validatielaag afspeelt
(`generateSummaryWithClaude`, `parseStatements`, `validated`). Die eruit tillen
maakt de komende feature overzichtelijker.

Voorstel: splits alleen `AnthropicClient` (HTTP + JSON + parsing) af. Laat
clustering en samenvattingsbeleid voorlopig samen — die naad is minder scherp
dan de beoordeling suggereert, en een derde bestand levert nu niets op.

### Punt 7 — Strict Concurrency op `Complete` → **aanpassen**: wel doen, later

Geverifieerd: `project.yml` staat op `SWIFT_VERSION: "5.9"`, zonder
`SWIFT_STRICT_CONCURRENCY`. De beoordeling prijst de bestaande actorgrenzen
terecht; dat maakt de overstap juist haalbaar.

Bezwaar tegen de plaatsing: `Complete` aanzetten levert een onvoorspelbare
hoeveelheid meldingen op, verspreid over de hele app, precies in de code die
#14 gaat herschrijven. Doe dit ná de hoofdpagina-feature, of hooguit alvast op
`Targeted` om de omvang te peilen zonder het werk te blokkeren.

### Punt 3 — Afhankelijkheden injecteerbaar maken → **afwijzen voor nu**

Geverifieerd: `URLSession.shared` komt **5×** voor; Keychain en UserDefaults
worden rechtstreeks aangeroepen. Er zijn **7** testbestanden (~1.250 regels),
en die testen juist de pure logica: parsers, filters, datumsanity,
clustervolgorde, samenvattingsvenster.

Dat is het patroon dat bij dit project past: testen wat rekent, niet wat praat.
Protocollen en injectie toevoegen levert pas iets op als er daadwerkelijk
netwerk- of Keychain-tests komen. Zolang die niet gepland zijn, is het
abstractie zonder afnemer — en elke laag extra maakt #14 duurder, niet
goedkoper.

Herzien zodra een concrete testbehoefte ontstaat (bijvoorbeeld het vastleggen
van Anthropic-antwoorden voor de gestructureerde generatie uit #14). Dan is de
natuurlijke plek de `AnthropicClient` uit punt 2 — één protocol, niet vijf.

### Punt 1 — Applicatielaag met use cases → **afwijzen**

Dit is het zwaarste voorstel uit de beoordeling en het enige dat de hele app
raakt. De onderbouwing ("modulariteit, testbaarheid, begrijpelijkheid") is
generiek Clean-Architecture-advies; de bron die wordt aangehaald pleit voor
scheiding van data en views, niet specifiek voor een use-case-laag.

Tegenargumenten uit dit project:

- De aangevoerde aanleiding is in de code beperkt zichtbaar: `ContentView` is
  85 regels en delegeert het werk al aan `TopicClusteringService` en
  `FeedRefreshService`. De services *zijn* de coördinatielaag.
- Baten (modulariteit, parallel werken, vervangbaarheid) veronderstellen een
  team of een tweede afnemer. De projectbrief sluit beide uit.
- `@Query` en `ModelContext` zijn door Apple bewust als view-gebonden
  voorzieningen ontworpen. Een use-case-laag ertussen schuiven werkt tegen de
  SwiftData-dataflow in die de beoordeling in dezelfde notitie prijst.

Wat wél overblijft van dit punt is het echte bezwaar, en dat is punt 5: views
doen zelf aan foutafhandeling bij opslaan. Dat is met één helper opgelost, niet
met een laag.

## Herziene volgorde

1. **Gecentraliseerde save** met logging en melding bij expliciete acties
   (punt 5) — wegnemen van stil dataverlies.
2. **Veilige Keychain-migratie met succescontrole** bij app-start: atomaire
   write, returnwaarde controleren, pas daarna de legacywaarde weg. De
   terugvallen verdwijnen pas ná uitrol (punt 6).
3. **`AnthropicClient` afsplitsen** van `TopicClusteringService` (punt 2,
   beperkt) — bereidt #14 voor.
4. **Verder met de hoofdpagina-feature** (#14: R1–R3, R11). Beleg de
   persistente samenvatting (punt 4) als eis binnen dat issue.
5. **Strict Concurrency** op `Complete` ná die feature (punt 7).
6. **Niet doen**, tot een concrete aanleiding: use-case-laag (punt 1) en brede
   protocol-injectie (punt 3).

Stap 1 t/m 3 zijn begrensd werk in bestaande bestanden. Geen daarvan
introduceert een nieuwe laag.

**Status 0.2:** deze volgorde is door beide beoordelaars onderschreven. De
resterende verschillen zijn tekstueel, niet inhoudelijk.

## Waar de beoordeling gelijk heeft zonder voorbehoud

- De schaalbaarheidsopmerking over `feed.items`. Geverifieerd: `.items` komt
  **27×** voor, waaronder `feeds.filter { $0.includedInSummary }.flatMap
  { $0.items }` in `ContentView.swift:66-68` — dat laadt alle artikelen van
  alle meetellende feeds in het geheugen vóór het venster wordt toegepast. Bij
  groei is `FetchDescriptor` met predicate en limiet hier de juiste stap. Dit
  is nu geen probleem en geen prioriteit, maar het is de juiste waarneming.
- De positieve bevindingen (concurrency-opzet, `localSummary` als R8-borging,
  Keychain voor nieuwe geheimen) zijn correct en goed onderbouwd.

## Verificatie

Gecontroleerd tegen de broncode op 20-09-2026, commit `a841788`:

- aantallen `try? modelContext.save()`, `URLSession.shared`, `.items`,
  `FetchDescriptor` en `@Query` via `grep`;
- alle vindplaatsen van `claudeAPIKey` (levert de correctie op punt 6);
- `TopicSummary` in schema, model en views;
- structuur en omvang van `TopicClusteringService`;
- `SWIFT_VERSION` en concurrency-instellingen in `project.yml`;
- omvang en onderwerp van de bestaande tests.

Niet gedaan: de tests zijn niet uitgevoerd en de app is niet gebouwd. De
oordelen berusten op codeanalyse en op de projectbrief, niet op runtime-gedrag.
