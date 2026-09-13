# Workflow: Feature afronden (versiebeheer)

Voer deze stappen in volgorde uit zodra een feature af is. Sla geen stappen over; meld het expliciet als een stap niet kan.

## 1. Controleer de werkstatus
- `git status` — welke bestanden horen bij deze feature?
- Werk op een feature branch (`feat/<korte-naam>` of `fix/<korte-naam>`). Zit je op `main`, maak dan eerst een branch.
- Stage alleen bestanden die bij de feature horen. Nooit: build-output, `.DS_Store`, losse notities of niet-gerelateerde wijzigingen (benoem die wel).

## 2. Build-check
- Draai `xcodebuild` voor de iOS Simulator. De build moet slagen vóór er gecommit wordt.
- Faalt de build: eerst herstellen, daarna verder.
- Gebruik een destination zonder toestelnaam; die hoeft voor een build-check niet:
  ```bash
  xcodebuild -project RSSReader.xcodeproj -scheme RSSReader \
    -destination 'generic/platform=iOS Simulator' build
  ```
- Noem je toch een toestel, geef dan ook `OS=` mee. Zonder die sleutel kiest `xcodebuild`
  `OS:latest`, en dan faalt de build met *"Unable to find a device matching the provided
  destination specifier"* zodra dat toestel niet in de nieuwste iOS-versie bestaat — een
  iPhone 16 kan lokaal alleen als iOS 18.0 bestaan terwijl de nieuwste runtime 26.x is.
  Welke combinaties er zijn: `xcrun simctl list devices available`. Pin geen vaste
  toestel/OS-combinatie vast in documentatie: die verschilt per werkplek en per
  Xcode-installatie.

## 3. CHANGELOG.md bijwerken
- Voeg onder de sectie `## [Unreleased]` één bondige regel toe (Nederlands) onder de juiste kop (`### Toegevoegd`, `### Gewijzigd` of `### Opgelost`).
- Neem dit bestand mee in dezelfde commit.

## 4. Commit
- Conventional Commits: `feat:`, `fix:`, `chore:`, etc.
- Onderwerpregel bondig in het Nederlands; daarna een korte toelichting met opsomming.
- Afsluiten met: `Co-Authored-By: Claude <noreply@anthropic.com>`

## 5. Push en pull request
- `git push -u origin <branch>`
- `gh pr create --base main` met secties **Doel**, **Wijzigingen** en **Verificatie**.

## 6. Review
- Voer `/code-review` uit op de PR.
- Correctheidsbevindingen: eerst oplossen, opnieuw committen en pushen.
- Cleanup-bevindingen: melden aan de gebruiker; alleen uitvoeren op verzoek.

## 7. Merge (alleen na akkoord van de gebruiker)
- Vraag expliciet akkoord voordat je merget.
- `gh pr merge <nr> --merge --delete-branch` (merge-commit, conform de repo-historie).
- Daarna: `git checkout main && git pull`.

## 8. Release (alleen op expliciet verzoek)
- Versie bumpen volgens SemVer: MINOR bij een feature, PATCH bij een fix.
- `## [Unreleased]` in CHANGELOG.md omzetten naar `## [X.Y.Z] - JJJJ-MM-DD`.
- Git-tag `vX.Y.Z` aanmaken en pushen.
- Voer nooit een release uit zonder expliciete bevestiging (zie Versiebeheer.md).

## 9. Installeren op de iPhone (alleen na een release, stap 8)
- Hoort bij stap 8 en deelt dus dezelfde gate: alleen uitvoeren als er daadwerkelijk een release
  is uitgebracht. Na gewoon featurewerk (stap 1–7) niets installeren.
- Zonder App Store-distributie is een release pas af als de nieuwe versie op het toestel staat.
- Regenereer eerst het project: stap 8 bumpt `MARKETING_VERSION` in `project.yml`, en zonder
  `xcodegen generate` bouw je een `.xcodeproj` met het oude versienummer.
- Zoek het toestel op in plaats van een identifier over te typen; die verandert bij herkoppelen,
  een ander toestel of een andere Mac. De regel moet `available (paired)` tonen.
- Bouw en installeer:
  ```bash
  xcodegen generate
  DEVICE=$(xcrun devicectl list devices | grep iPhone | grep 'available (paired)' \
    | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)
  DERIVED=~/Library/Developer/Xcode/DerivedData/RSSReader-device
  xcodebuild -project RSSReader.xcodeproj -scheme RSSReader -configuration Release \
    -destination "id=$DEVICE" -derivedDataPath "$DERIVED" -allowProvisioningUpdates build
  xcrun devicectl device install app --device "$DEVICE" \
    "$DERIVED/Build/Products/Release-iphoneos/RSSReader.app"
  ```
- Controleer na afloop dat de geïnstalleerde build het verwachte versienummer heeft:
  `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$DERIVED/Build/Products/Release-iphoneos/RSSReader.app/Info.plist"`
- **Bouw niet binnen de projectmap.** Die staat in iCloud Drive, dat extended attributes op
  de buildoutput zet (waargenomen: `com.apple.provenance`; ook `com.apple.FinderInfo` komt
  voor). `codesign` faalt dan met *"resource fork, Finder information, or similar detritus
  not allowed"*. `xattr -rc` lost dit niet op — die attributen komen terug of zijn niet te
  verwijderen; bouw naar een pad buiten de projectmap. Simulatorbuilds hebben hier geen last
  van omdat die niet worden ondertekend.

## 10. Continuous integration (GitHub Actions)

Naast de handmatige stappen hierboven draait er een CI-workflow op elke pull request naar
`main`. Die doet precies twee dingen:

- **Build-check** — dezelfde controle als stap 2, met `generic/platform=iOS Simulator`.
- **Tests** — de unit-tests in `RSSReaderTests` op een simulator die de workflow zelf opzoekt.

Dat is bewust smal gehouden: het valideert wat een agent of reviewer anders handmatig moet
draaien, en niets meer.

### Wanneer draait de CI?
- Automatisch bij elke pull request naar `main`.
- Handmatig via GitHub → Actions → *CI* → *Run workflow*.

Niet bij een push naar `main`: dat verdubbelt het verbruik zonder dat het iets toevoegt aan
wat de PR-run al heeft gecontroleerd.

### Verhouding tot deze workflow
CI **vervangt stap 2 niet**. Draai de build-check lokaal vóór het committen; CI is het
vangnet dat betrapt wat er op een andere machine misgaat, niet de eerste keer dat je hoort
dat de build faalt. Stap 6 (review) blijft mensenwerk — CI toetst geen correctheid.

### Wat er bewust níét in zit
- **Release-/device-builds.** Signing werkt niet op een runner: `DEVELOPMENT_TEAM` staat vast
  in `project.yml` en er is geen certificaat. Met signing uitgeschakeld valideer je niets
  extra's. De distributie loopt via stap 9, op het toestel zelf.
- **SwiftLint.** Dit project gebruikt swift-format en heeft geen `.swiftlint.yml`; een
  strict-run op de standaardregels zou permanent rood staan.
- **Code coverage / Codecov.** `xcodebuild` levert een `.xcresult`, geen `.lcov`, en er is
  geen Codecov-token. Toe te voegen zodra er iets met die cijfers gedaan wordt.

### Kosten
De repository is privé, dus macOS-minuten tellen **10×** tegen het inbegrepen quotum. Op het
Free-plan (2000 minuten/maand) is dat ruwweg 200 macOS-minuten, en een run kost al gauw 6–10
minuten — orde van grootte 20–30 runs per maand. Daarom: alleen op PR's, en
`cancel-in-progress` zodat een nieuwe push de vorige run afbreekt.

### Het workflow-bestand
- **Locatie:** `.github/workflows/ci.yml`
- **Job:** `build-test`
- De Xcode-versie is gepind op `latest-stable`. De runner-standaard verschuift; zonder pin
  wisselt de SDK waartegen gebouwd wordt stilzwijgend mee.
- Het toestel voor de testrun wordt opgezocht via `xcrun simctl`, niet vastgelegd. Zie de
  waarschuwing bij stap 2: een vaste toestel/OS-combinatie breekt zodra die combinatie niet
  bestaat.
