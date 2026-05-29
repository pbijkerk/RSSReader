# iOS Swift — Richtlijnen & Best Practices

## Architectuur

- **Gebruik MVVM of MV (voor SwiftUI)** — houd views dun; verplaats logica naar ViewModels of `@Observable` klassen
- **Scheid verantwoordelijkheden** — netwerken, persistentie en bedrijfslogica in aparte services/lagen
- **Geef de voorkeur aan value types** (`struct`) boven reference types (`class`), tenzij je gedeelde mutable state of identiteit nodig hebt

## Concurrency

- **Gebruik Swift Concurrency** (`async`/`await`, `Task`, `TaskGroup`) in plaats van GCD en callbacks
- **Isoleer UI- en modelmutaties naar `@MainActor`** — raak SwiftUI-state nooit aan vanuit een achtergrondthread
- **Voorkom data races** — gebruik `actor` voor gedeelde mutable state tussen threads
- **Gebruik `Task.detached` voor CPU-intensief werk** (parsen, beeldverwerking) om blokkering van de main actor te vermijden

## Geheugenbeheer

- **Gebruik `[weak self]` in closures** die het object overleven (timers, notificaties, delegates)
- **Doorbreek retain cycles** — vooral tussen parent/child-objecten of delegate-patronen
- **Geef de voorkeur aan `weak var delegate`** — delegates zijn bijna altijd `weak`

## SwiftData / CoreData

- **Voer modelmutaties uit op `@MainActor`** — SwiftData `ModelContext` is niet thread-safe
- **Fetch alleen wat je nodig hebt** — gebruik predicates en sort descriptors op queryniveau
- **Roep altijd `try? context.save()` aan** na mutaties die je wilt bewaren

## Foutafhandeling

- **Definieer getypeerde fouten** (`enum MyError: LocalizedError`) in plaats van generieke `Error`-strings
- **Slik fouten nooit stil** — log ze minimaal; presenteer bruikbare fouten aan de gebruiker
- **Controleer HTTP-statuscodes** vóór het decoderen van responses — ga niet uit van 2xx

## Beveiliging

- **Sla geheimen op in de Keychain**, nooit in `UserDefaults` of SwiftData
- **Valideer en escape gebruikers-/externe content** vóór injectie in HTML of SQL
- **Gebruik uitsluitend `https://`** en schakel App Transport Security in
- **Saneer HTML** die in `WKWebView` wordt getoond — schakel JavaScript uit tenzij vereist

## UI / SwiftUI

- **Houd views declaratief en vrij van neveneffecten** — neveneffecten horen in `.task`, `.onAppear` of expliciete gebruikersacties
- **Ondersteun Dynamic Type** — gebruik `@ScaledMetric` en relatieve lettertypegroottes
- **Ondersteun Dark Mode** — gebruik semantische kleuren (`Color.primary`, asset catalog-kleuren)
- **Test op echte apparaten** — simulators weerspiegelen geen geheugendruk, netwerkomstandigheden of echte prestaties

## Prestaties

- **Vermijd O(n²)-operaties in kritieke paden** — vooral binnen SwiftData relationship-loops
- **Cache dure berekeningen** — regex-patronen, formatters (`DateFormatter` is kostbaar om aan te maken)
- **Laad afbeeldingen lazy** — gebruik `AsyncImage` of een cache-laag; decodeer afbeeldingen nooit op de main thread
- **Profileer met Instruments** vóór optimalisatie — meet eerst

## Codekwaliteit

- **Gebruik `AppConfiguration` of vergelijkbaar** voor magic numbers en string-sleutels — geen literals verspreid door de code
- **Vermijd gedupliceerde logica** — extraheer gedeeld gedrag naar één plek
- **Schrijf zelfverklarende code** — benoem functies en variabelen duidelijk; reserveer comments voor de niet-voor-de-hand-liggende *waarom*
- **Gebruik `OSLog`** in plaats van `print()` voor gestructureerde, filterbare logging

## Testen

- **Unit-test services en bedrijfslogica** — houd ze onafhankelijk van SwiftUI en SwiftData waar mogelijk
- **Gebruik echte persistentie in integratietests** — gemockte databases missen vaak schema- en migratiebugs
- **Test randgevallen** — lege feeds, ongeldige URLs, netwerkfouten, grote datasets
