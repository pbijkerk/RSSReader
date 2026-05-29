# RSSReader - Test Instructies

## 🧪 Hoe de Tests te Runnen

### Optie 1: Via Xcode (Aanbevolen)
1. Open het project in Xcode
2. Druk op `Cmd+U` of klik op Product → Test
3. Wacht tot alle tests klaar zijn
4. Bekijk de resultaten in de Test Navigator (Cmd+6)

### Optie 2: Via Command Line
```bash
# Vanaf de project root directory
xcodebuild test -scheme RSSReader -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Optie 3: Specifieke Test Suites Runnen
```bash
# Alleen Feed Item tests
xcodebuild test -scheme RSSReader -only-testing:RSSReaderTests/FeedItemTests

# Alleen Configuration tests
xcodebuild test -scheme RSSReader -only-testing:RSSReaderTests/AppConfigurationTests

# Alleen HTML Entity tests
xcodebuild test -scheme RSSReader -only-testing:RSSReaderTests/HTMLEntityTests
```

---

## 📋 Test Checklist

### Unit Tests
- [ ] FeedItemTests - YouTube video ID extraction
- [ ] FeedItemTests - Vimeo video ID extraction
- [ ] FeedItemTests - Direct video/audio detection
- [ ] FeedItemTests - HTML sanitization (scripts, styles, iframes)
- [ ] FeedItemTests - Plain description (HTML stripping)
- [ ] FeedItemTests - Substantial content detection
- [ ] HTMLEntityTests - Named entities (amp, lt, gt, etc.)
- [ ] HTMLEntityTests - Numeric decimal entities
- [ ] HTMLEntityTests - Numeric hexadecimal entities
- [ ] AppConfigurationTests - Default values

### Handmatige Tests (na unit tests)
- [ ] Build succesvol (Cmd+B)
- [ ] App start zonder crashes
- [ ] Feed refresh werkt
- [ ] Article detail view opent
- [ ] Video playback werkt
- [ ] Audio playback werkt
- [ ] Dark mode werkt
- [ ] Settings kunnen worden aangepast
- [ ] Mastodon OAuth flow werkt

---

## 🔍 Verwachte Resultaten

### Alle Tests Slagen
Je zou moeten zien:
```
Test Suite 'All tests' passed at [timestamp]
    Executed 25 tests, with 0 failures (0 unexpected) in X.XXX seconds
```

### Als Tests Falen

#### Mogelijke Oorzaken:
1. **Module niet gevonden**: Test target mist dependencies
2. **Type niet gevonden**: Import statement mist of verkeerd
3. **Test data incorrect**: Check de test assertions

#### Debug Stappen:
1. Check de console output voor details
2. Klik op de gefaalde test in Test Navigator
3. Bekijk de failure message
4. Run de test opnieuw met breakpoint

---

## 🐛 Mogelijke Compiler Issues & Oplossingen

### Issue 1: "Cannot find 'AppConfiguration' in scope"
**Oplossing:** Zorg dat `AppConfiguration.swift` in de app target zit:
1. Selecteer het bestand in Project Navigator
2. Check File Inspector (rechterpanel)
3. Zorg dat Target Membership klopt

### Issue 2: "No such module 'Testing'"
**Oplossing:** Swift Testing is alleen beschikbaar in Xcode 15+
- Check je Xcode versie: `xcodebuild -version`
- Update naar Xcode 15.0 of hoger

### Issue 3: Tests compilen niet
**Oplossing:** Check test target dependencies:
1. Selecteer project in Navigator
2. Ga naar test target
3. Build Phases → Link Binary with Libraries
4. Voeg app target toe als dependency

---

## 📊 Performance Benchmarks

Na het draaien van de tests, check ook de performance:

### Feed Refresh Performance
```swift
// Open Console.app en filter op:
subsystem:com.rssreader.app category:feed

// Je zou moeten zien:
"Starting refresh of X feeds"
"Successfully refreshed feed: [name]" (voor elke feed)
"Refresh completed" 
```

### Tijd Verwachtingen
- 1 feed refresh: < 2 seconden
- 10 feeds parallel: < 5 seconden
- HTML sanitization: < 0.01 seconden per item
- Article extraction: < 5 seconden (of timeout na 30s)

---

## 🔧 Test Coverage Uitbreiden (Toekomst)

Voeg later toe:

### Integration Tests
```swift
@Test("Full feed refresh flow")
func feedRefreshIntegration() async throws {
    // Test complete flow van URL fetch tot SwiftData opslag
}

@Test("RSS Parser with real feed")
func parseRealFeed() async throws {
    // Test met een echte RSS feed URL
}
```

### UI Tests
```swift
@Test("Navigate to article detail")
func navigateToDetail() throws {
    // Test UI flow met XCUITest
}
```

### Performance Tests
```swift
@Test("HTML sanitization performance")
func sanitizationPerformance() {
    // Measure time voor 1000 items
}
```

---

## 📝 Logging Bekijken Tijdens Tests

### Console.app Setup
1. Open Console.app (in /Applications/Utilities/)
2. Selecteer je simulator/device in de sidebar
3. Filter op subsystem: `com.rssreader.app`
4. Run de app/tests
5. Bekijk de structured logs

### Log Levels Betekenis
- **Debug** 🔵: Gedetailleerde info voor development
- **Info** 🟢: Normale operaties (feed refresh success, etc.)
- **Warning** 🟡: Potentiële problemen (API key empty, timeout, etc.)
- **Error** 🔴: Echte fouten (network failures, parsing errors)

### Handige Filters
```
# Alleen errors
level:error

# Alleen clustering
category:clustering

# Alleen Mastodon
category:mastodon

# Laatste 5 minuten
last:5m
```

---

## ✅ Success Criteria

De code is production-ready als:
- ✅ Alle 25+ unit tests slagen
- ✅ Build succeeds zonder warnings
- ✅ App start zonder crashes
- ✅ Memory leaks test (Instruments → Leaks)
- ✅ Performance is acceptabel (zie benchmarks)
- ✅ Dark mode werkt correct
- ✅ Accessibility labels aanwezig
- ✅ Logs zijn informatief maar niet te verbose

---

## 🚨 Known Issues

### Normale Test Warnings (Kunnen Genegeerd)
- Purple warnings over constraints in SwiftUI previews
- "Publishing changes from background threads" (als correct met @MainActor)
- Simulator locale warnings

### Echte Issues (Moeten Gefixt)
- ❌ Crashes tijdens tests
- ❌ Memory leaks (check met Instruments)
- ❌ Force unwrap crashes
- ❌ Network calls zonder timeout
- ❌ SwiftData threading violations

---

**Laatste Update:** 29 mei 2026
**Status:** Klaar om te testen
