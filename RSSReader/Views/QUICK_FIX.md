# 🔧 QUICK FIX - Build Errors

## ❌ Huidige Problemen

1. **"Unable to resolve module dependency: 'Testing'"**
   - Swift Testing is alleen beschikbaar in Xcode 15+
   - Je hebt waarschijnlijk Xcode 14 of het test target bestaat niet

2. **String literal errors met unicode quotes**
   - Gefixed in de nieuwe test file

---

## ✅ Oplossing: Gebruik XCTest in plaats van Swift Testing

Ik heb een **XCTest** versie van de tests gemaakt die werkt met alle Xcode versies.

### Stappen om te Fixen:

#### Optie A: Verwijder Swift Testing Tests (Simpelst)

1. **Verwijder `RSSReaderTests.swift`** uit je project
   - Klik met rechts op het bestand
   - Kies "Delete" → "Move to Trash"

2. **Voeg `RSSReaderTestsXCTest.swift` toe**
   - File → Add Files to "RSSReader"...
   - Selecteer `RSSReaderTestsXCTest.swift`
   - Zorg dat "RSSReaderTests" target checked is
   - Klik "Add"

3. **Build opnieuw**
   ```
   Cmd+Shift+K  (Clean)
   Cmd+B        (Build)
   ```

---

#### Optie B: Test Target Aanmaken (Als het nog niet bestaat)

Als je GEEN "RSSReaderTests" target hebt:

1. **Maak Test Target aan**
   - File → New → Target...
   - Selecteer "Unit Testing Bundle"
   - Klik "Next"
   - Product Name: **RSSReaderTests**
   - Testing Framework: **XCTest** (NIET Swift Testing)
   - Klik "Finish"

2. **Verwijder default test file**
   - Delete `RSSReaderTests.swift` (de auto-generated met boilerplate)

3. **Voeg onze test file toe**
   - File → Add Files to "RSSReader"...
   - Selecteer `RSSReaderTestsXCTest.swift`
   - Target: Check "RSSReaderTests"
   - Klik "Add"

4. **Verifieer dependencies**
   - Selecteer project in Navigator
   - Selecteer "RSSReaderTests" target
   - Build Phases → Dependencies
   - Moet "RSSReader" bevatten
   - Zo niet: klik "+" en voeg toe

---

## 🏃 Direct aan de Slag

### Voor mensen met Xcode 14 (of als je XCTest wilt gebruiken):

```bash
# 1. Verwijder problematische file
rm RSSReaderTests.swift 2>/dev/null || true

# 2. Hernoem XCTest versie
mv RSSReaderTestsXCTest.swift RSSReaderTests.swift

# 3. Open Xcode en voeg toe aan test target
```

In Xcode:
```
1. Cmd+Shift+K (Clean)
2. Cmd+B (Build) → Should succeed now!
3. Cmd+U (Test) → Should run 25 tests
```

---

### Voor mensen met Xcode 15+ (Swift Testing beschikbaar):

Je kunt de originele `RSSReaderTests.swift` blijven gebruiken, maar de unicode string fix is nodig:

**De fix is al toegepast!** De problematische regels:
```swift
// VOOR (broken):
#expect(plain.contains("""))  // Syntax error!

// NA (fixed):
#expect(plain.contains("\u{201C}"))  // Works!
```

Build opnieuw:
```
Cmd+Shift+K
Cmd+B
```

---

## 🎯 Verwachte Output na Fix

### Build (Cmd+B):
```
✅ Build Succeeded
```

### Tests (Cmd+U):
```
Test Suite 'RSSReaderTests' started
Test Suite 'FeedItemTests' started
  ✓ testYouTubeWatchURL (0.001s)
  ✓ testYouTubeShortURL (0.001s)
  ✓ testVimeoVideoID (0.001s)
  ... (22 more tests)
  
Test Suite 'All tests' passed
  Executed 25 tests, with 0 failures (0 unexpected)
```

---

## 🔍 Verify Everything Works

Run deze commands in Xcode console:

```swift
// Test 1: AppConfiguration exists
print(AppConfiguration.defaultRetentionDays)  // Should print: 30

// Test 2: FeedItem compiles
let item = FeedItem(title: "Test")
print(item.title)  // Should print: Test

// Test 3: Logging works
import OSLog
let logger = Logger(subsystem: "test", category: "test")
logger.info("Hello from tests!")  // Check Console.app
```

---

## ❓ Nog Steeds Errors?

### Error: "Cannot find 'AppConfiguration' in scope"
**Waar:** Overal in de app code

**Fix:**
1. Check dat `AppConfiguration.swift` bestaat in Project Navigator
2. Click op het bestand → File Inspector → Target Membership
3. Moet "RSSReader" checked hebben
4. Als niet: check het vakje
5. Clean + Build

---

### Error: "No such module 'RSSReader'" (in tests)
**Waar:** Bovenaan test file bij `@testable import RSSReader`

**Fix:**
1. Project → RSSReaderTests target → Build Phases
2. Dependencies → Moet "RSSReader" bevatten
3. Zo niet: Klik "+" → Selecteer "RSSReader" → Add

---

### Error: Tests runnen niet
**Check:**
```
Product → Scheme → RSSReader
Product → Test (Cmd+U)
```

Als nog steeds niet:
```
Product → Scheme → Manage Schemes
Check dat "RSSReaderTests" visible is
```

---

## 🎉 Success!

Je bent klaar als:
- ✅ `Cmd+B` = Build Succeeded
- ✅ `Cmd+U` = 25 tests passed
- ✅ Geen rode errors in editor
- ✅ App runt zonder crashes (`Cmd+R`)

---

**Volgende stap:** Run de app en test handmatig!
