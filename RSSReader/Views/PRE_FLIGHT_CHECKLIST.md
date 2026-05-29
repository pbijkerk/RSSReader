# ✅ Pre-Flight Checklist - Tests Runnen

## Stap 1: Verifieer dat alle bestanden in Xcode zijn toegevoegd

### Nieuwe Bestanden (moeten in project zitten):
1. ✅ `AppConfiguration.swift` → App target
2. ✅ `RSSReaderTests.swift` → Test target
3. ✅ `CODE_IMPROVEMENTS.md` → Optioneel (documentatie)
4. ✅ `TEST_INSTRUCTIONS.md` → Optioneel (documentatie)

### Check dit in Xcode:
1. Open Project Navigator (Cmd+1)
2. Zoek naar `AppConfiguration.swift`
   - **Als NIET gevonden**: Ga naar stap 2
   - **Als WEL gevonden**: Klik erop en check File Inspector (Cmd+Opt+1)
     - Target Membership moet RSSReader bevatten (checked)
3. Zoek naar `RSSReaderTests.swift`
   - **Als NIET gevonden**: Ga naar stap 2
   - **Als WEL gevonden**: Klik erop en check File Inspector
     - Target Membership moet RSSReaderTests bevatten (checked)

---

## Stap 2: Voeg Ontbrekende Bestanden Toe

### AppConfiguration.swift Toevoegen (als ontbreekt):
1. File → Add Files to "RSSReader"...
2. Navigeer naar project directory
3. Selecteer `AppConfiguration.swift`
4. Zorg dat "Copy items if needed" is UNCHECKED
5. Zorg dat "RSSReader" target is CHECKED
6. Klik "Add"

### RSSReaderTests.swift Toevoegen (als ontbreekt):
1. File → New → Target...
2. Selecteer "Unit Testing Bundle"
3. Klik "Next"
4. Product Name: "RSSReaderTests"
5. Klik "Finish"
6. Verwijder de default test file
7. File → Add Files to "RSSReader"...
8. Selecteer `RSSReaderTests.swift`
9. Zorg dat "RSSReaderTests" target is CHECKED
10. Klik "Add"

---

## Stap 3: Verifieer Test Target Setup

1. Klik op project in Navigator (bovenaan)
2. Selecteer "RSSReaderTests" target (in de lijst links)
3. Ga naar "Build Phases" tab
4. Expand "Dependencies"
   - Moet "RSSReader" bevatten
   - **Als niet**: Klik "+" en voeg RSSReader toe
5. Expand "Link Binary With Libraries"
   - Moet "Testing.framework" of geen frameworks bevatten (Swift Testing is automatisch)

---

## Stap 4: Quick Build Test

Voordat je de tests runt, probeer eerst te builden:

```bash
# In Xcode: Cmd+B
# Of command line:
xcodebuild -scheme RSSReader -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Verwachte Output:
```
BUILD SUCCEEDED
```

### Als Build Faalt:

#### Error: "Cannot find 'AppConfiguration' in scope"
**Waar:** FeedRefreshService, TopicClusteringService, etc.

**Oplossing:**
1. Check dat `AppConfiguration.swift` in de RSSReader target zit
2. Clean build folder: Shift+Cmd+K
3. Build again: Cmd+B

#### Error: "No such module 'Testing'"
**Waar:** RSSReaderTests.swift

**Oplossing:**
- Check Xcode versie: moet 15.0+ zijn
- Update Xcode via App Store als nodig

#### Error: "Use of undeclared type 'FeedItem'"
**Waar:** RSSReaderTests.swift

**Oplossing:**
1. Bovenaan test file staat: `@testable import RSSReader`
2. Dit moet de app module importeren
3. Check dat test target RSSReader als dependency heeft

---

## Stap 5: Run de Tests

### Methode 1: Alle Tests (Aanbevolen eerste keer)
```
Cmd+U in Xcode
```

### Methode 2: Eén Test Suite
1. Open `RSSReaderTests.swift`
2. Klik op de diamant-icon naast `@Suite("Feed Item Tests")`
3. Wacht op resultaat

### Methode 3: Eén Individuele Test
1. Open `RSSReaderTests.swift`
2. Klik op de diamant-icon naast een specifieke `@Test`
3. Wacht op resultaat

---

## Stap 6: Interpreteer Resultaten

### ✅ Alle Tests Slagen
```
Test Suite 'RSSReaderTests' passed at [tijd]
    Executed 25 tests, with 0 failures in X.XXX seconds
```

**Actie:** Gefeliciteerd! Ga naar stap 7.

---

### ❌ Tests Falen

#### Voorbeeld Failure:
```
FeedItemTests.youtubeWatchURL failed at RSSReaderTests.swift:20
#expect(item.youtubeVideoID == "dQw4w9WgXcQ") failed
```

**Debug Stappen:**
1. Klik op de gefaalde test in de lijst
2. Bekijk de failure message
3. Klik op de regel in code
4. Voeg breakpoint toe (Cmd+\)
5. Run test opnieuw met breakpoint (Ctrl+Opt+Cmd+U)
6. Inspect de variabelen in debug area

#### Common Test Failures:

**1. YouTube ID extraction faalt**
```swift
// Check of de regex in FeedItem.swift correct is
var youtubeVideoID: String? {
    guard let link, link.contains("youtube.com") || link.contains("youtu.be") else { return nil }
    // ... check deze logica
}
```

**2. HTML sanitization faalt**
```swift
// Check of de regexes gecompileerd zijn
private static let scriptRegex = try! NSRegularExpression(...)
// Error hier betekent regex pattern is invalid
```

**3. HTML entity decoding faalt**
```swift
// Check de htmlEntityDecoded extension in FeedItem.swift
// Deze moet alle entities correct decoderen
```

---

## Stap 7: Handmatige Verificatie

Tests zijn geslaagd? Nu handmatig testen:

### 7.1 App Starten
1. Run app: Cmd+R
2. Wacht tot app volledig geladen is
3. Check console op errors/warnings

### 7.2 Voeg Test Feed Toe
```
https://www.nu.nl/rss/Algemeen
```
1. Tap "+" om feed toe te voegen
2. Plak URL
3. Tap "Add Feed"
4. Wacht op refresh

### 7.3 Check Logging
1. Open Console.app
2. Filter op subsystem: `com.rssreader.app`
3. Je zou moeten zien:
   ```
   [feed] Starting refresh of 1 feeds
   [feed] Fetching feed: NU.nl - Algemeen
   [feed] Successfully refreshed feed: NU.nl - Algemeen
   [feed] Refresh completed
   ```

### 7.4 Open Artikel
1. Tap op een artikel in de lijst
2. Artikel moet laden
3. Scroll door content
4. Tap "Open in browser" icon
5. Safari view moet openen

### 7.5 Test Video/Audio
Als je een YouTube/podcast feed hebt:
1. Tap op video/audio item
2. Player moet verschijnen
3. Tap play
4. Media moet afspelen

---

## Stap 8: Performance Check (Optioneel)

### Memory Leaks
1. Product → Profile (Cmd+I)
2. Selecteer "Leaks"
3. Run app
4. Gebruik app normaal (refresh, open articles, etc.)
5. Check dat er geen leaks zijn (rood = bad, groen = good)

### Time Profiler
1. Product → Profile (Cmd+I)
2. Selecteer "Time Profiler"
3. Run app
4. Refresh feeds
5. Check welke functies de meeste tijd kosten
6. Verwachting: refreshAll moet < 5s voor 10 feeds

---

## ✅ Alles Werkt Checklist

- [ ] Build succeeds (Cmd+B)
- [ ] All tests pass (Cmd+U) - 25+ tests
- [ ] App launches without crash (Cmd+R)
- [ ] Feed refresh works
- [ ] Parallel refresh zichtbaar in logs
- [ ] Article detail opens
- [ ] HTML is gesanitized (geen scripts)
- [ ] Dark mode works
- [ ] No memory leaks (Instruments)
- [ ] Console logs zijn informatief
- [ ] Settings kunnen worden aangepast

---

## 🚨 Emergency Troubleshooting

### Nuclear Option: Clean Everything
```bash
# Stop app
# Sluit Xcode
# Delete DerivedData:
rm -rf ~/Library/Developer/Xcode/DerivedData/RSSReader-*
# Open Xcode weer
# Product → Clean Build Folder (Shift+Cmd+K)
# Build (Cmd+B)
```

### Reset Simulator
```bash
# Als app crasht op simulator:
xcrun simctl shutdown all
xcrun simctl erase all
# Heropen Xcode en run opnieuw
```

---

## 📞 Hulp Nodig?

Als je ergens vastloopt:

1. **Check de error message nauwkeurig**
   - Compiler errors: meestal duidelijk
   - Runtime errors: check stack trace

2. **Verifieer file structure**
   ```
   RSSReader/
   ├── AppConfiguration.swift ← NIEUW
   ├── FeedItem.swift
   ├── FeedRefreshService.swift
   ├── TopicClusteringService.swift
   └── ... andere files
   
   RSSReaderTests/
   └── RSSReaderTests.swift ← NIEUW
   ```

3. **Check git status**
   ```bash
   git status
   # Alle nieuwe files moeten zichtbaar zijn
   ```

---

**Succes met testen! 🚀**
