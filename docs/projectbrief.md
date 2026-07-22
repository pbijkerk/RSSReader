# Projectbrief — RSSReader

**Datum:** 2026-07-22
**Status:** opgesteld op 2026-07-22

## Doel
Een native iOS RSS-lezer die nieuws per onderwerp samenvat met AI (Claude API), gebouwd voor eigen gebruik. Reden om zelf te bouwen: geen bestaande RSS-lezer maakte samenvattingen per onderwerp naar wens. De app wordt dagelijks gebruikt (ochtend en late middag) voor zowel de Mastodon social feed als losse RSS-feeds.

Het project draait nu om één koersverschuiving: **de AI-samenvatting moet de hoofdpagina van de app worden**, in plaats van een bijzaak. De huidige samenvatting is "te mager" en moet uitgebreider én betrouwbaarder.

## Gewenste uitkomst
Een samenvatting die het startpunt van de app is en waarin je kunt navigeren:

- De samenvatting is de **hoofdpagina** — het eerste wat je ziet.
- Uitgebreider en betrouwbaarder dan nu.
- **Inline bronverwijzingen**: vanuit de samenvatting naar de onderliggende feed/het artikel springen, en weer terug.
- Bronanalyse en fact-check (bestaan al in de app) spelen een rol in de betrouwbaarheid van de samenvatting.

"Klaar" is bereikt wanneer de samenvatting een betrouwbaar overzicht geeft van de belangrijkste ontwikkelingen op het onderwerp van die samenvatting.

## Scope
**Wel:**
- Native iOS-app voor eigen gebruik.
- Mastodon social feed én losse RSS-feeds.
- AI-samenvatting per onderwerp als hoofdpagina, met inline bronverwijzingen.
- Bronanalyse en fact-check als onderdeel van de betrouwbaarheid.

**Niet:**
- Geen iPad-versie.
- Geen App Store-distributie.
- Geen ondersteuning voor andere gebruikers dan de maker zelf.

Er zijn verder geen features die nu bewust worden weggelaten.

## Doelgroep / belanghebbenden
Uitsluitend de maker, als enige gebruiker en beslisser. Een persoonlijk project zonder externe belanghebbenden.

## Succescriteria
- De samenvatting geeft een overzicht van de belangrijkste ontwikkelingen op het onderwerp van de samenvatting.
- De samenvatting is uitgebreider en betrouwbaarder dan de huidige, "te magere" versie.
- Vanuit de samenvatting is de bron (feed/artikel) direct te bereiken en terug te navigeren.
- Bij dagelijks gebruik (ochtend + late middag) is de app een bruikbaar startpunt voor het nieuws.

## Randvoorwaarden & aannames
- **Techniek:** native iOS (iOS 17+, Xcode 15+, Swift 5.9+), SwiftData, uitsluitend Apple-frameworks. AI via de Anthropic REST API (`claude-haiku-4-5`); API-sleutel in de Keychain.
- **API-kostprijs speelt een rol:** de kosten van de Claude API wegen mee in hoe ver uitgebreidere en vaker ververste samenvattingen mogen gaan. Uitgebreider mag niet onbeperkt duurder worden.
- **Offline/AI-uitval is een harde eis:** als de AI niet beschikbaar is (geen sleutel, API onbereikbaar, fout), moeten de feeds nog steeds gewoon leesbaar zijn. De AI-samenvatting is de hoofdpagina, maar mag geen blokkade vormen voor het basisgebruik.
- **Aanname:** de bestaande bronanalyse- en fact-check-functionaliteit is een geschikte basis om op voort te bouwen (zie ook het openstaande punt over hun precieze rol).
- **Risico:** een uitgebreidere samenvatting verhoogt zowel API-kosten als de kans op onbetrouwbaarheid; betrouwbaarheid en kosten moeten tegen elkaar worden afgewogen.

## Genomen besluiten
- De AI-samenvatting wordt de hoofdpagina van de app — reden: dit is de belangrijkste behoefte en de aanleiding om zelf te bouwen; de huidige samenvatting is te mager.
- De samenvatting krijgt inline bronverwijzingen (heen en terug navigeren naar feed/artikel) — reden: betrouwbaarheid en verifieerbaarheid; vanuit het overzicht direct naar de bron kunnen.
- Scope blijft puur iOS voor eigen gebruik: geen iPad, geen App Store, geen andere gebruikers — reden: persoonlijk project, geen distributiebehoefte.
- Feeds moeten leesbaar blijven zonder werkende AI — reden: de app mag niet onbruikbaar worden als de API wegvalt.
- De API-kostprijs weegt mee in de mate van uitbreiding/verversing — reden: kosten beheersbaar houden bij een uitgebreidere samenvatting.

## Openstaande punten
> Vast te leggen als issue.

1. Precieze rol van bronanalyse en fact-check in de samenvatting — het staat vast dát ze meespelen in de betrouwbaarheid, maar niet hóé. Dit bepaalt mede het ontwerp van de samenvatting-hoofdpagina en de weergave van bronnen.
2. Hoe "uitgebreider en betrouwbaarder" concreet wordt begrensd tegen de API-kostprijs — bepaalt de omvang, frequentie en het aantal API-calls per samenvatting.

## Richting, nog geen besluit
- Inline bronlink als vorm van zelfverificatie (lezer controleert de bron zelf) — als richting genoemd, nog niet definitief vastgesteld.
- Betrouwbaarheid van bronnen laten meewegen bij het samenvatten zelf — voorstel uit het gesprek, niet bevestigd.
- Tegenspraak tussen bronnen expliciet tonen in de samenvatting — voorstel uit het gesprek, niet bevestigd.

## Voorgestelde vervolgstappen
1. Beslissen hoe bronanalyse en fact-check in de samenvatting-hoofdpagina landen (openstaand punt 1) — kies uit de drie geopperde richtingen of een combinatie.
2. De samenvatting-hoofdpagina ontwerpen: uitgebreidere inhoud met inline bronverwijzingen (heen/terug-navigatie).
3. Een kostenkader bepalen voor de samenvatting (omvang, verversingsfrequentie, aantal API-calls) dat de kostprijs beheersbaar houdt (openstaand punt 2).
4. De offline/AI-uitval-eis borgen: feeds blijven leesbaar zonder werkende AI — controleren dat de huidige app dit al doet, anders inregelen.
5. De bestaande fact-check-fout onderzoeken (zie `error.txt`: ontbrekend veld `claims` in de API-response) voordat fact-check een grotere rol in de samenvatting krijgt.
