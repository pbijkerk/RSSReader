# Workflow: Feature afronden (versiebeheer)

Voer deze stappen in volgorde uit zodra een feature af is. Sla geen stappen over; meld het expliciet als een stap niet kan.

## 1. Controleer de werkstatus
- `git status` — welke bestanden horen bij deze feature?
- Werk op een feature branch (`feat/<korte-naam>` of `fix/<korte-naam>`). Zit je op `main`, maak dan eerst een branch.
- Stage alleen bestanden die bij de feature horen. Nooit: build-output, `.DS_Store`, losse notities of niet-gerelateerde wijzigingen (benoem die wel).

## 2. Build-check
- Draai `xcodebuild` voor de iOS Simulator. De build moet slagen vóór er gecommit wordt.
- Faalt de build: eerst herstellen, daarna verder.

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

## 9. Installeren op de iPhone (hoort bij elke release)
- Direct na stap 8: de nieuwe versie op het toestel zetten. Zonder App Store-distributie is een
  release pas af als hij op de iPhone staat.
- Controleer eerst `xcrun devicectl list devices` — het toestel moet `available (paired)` zijn.
- Bouw en installeer:
  ```bash
  DEVICE=A500BDFC-5A4E-5B21-9E09-5A1ABF32D5B3   # iPhone van Peter
  DERIVED=~/Library/Developer/Xcode/DerivedData/RSSReader-device
  xcodebuild -project RSSReader.xcodeproj -scheme RSSReader -configuration Release \
    -destination "id=$DEVICE" -derivedDataPath "$DERIVED" -allowProvisioningUpdates build
  xcrun devicectl device install app --device "$DEVICE" \
    "$DERIVED/Build/Products/Release-iphoneos/RSSReader.app"
  ```
- **Bouw niet binnen de projectmap.** Die staat in iCloud Drive; iCloud zet dan
  `com.apple.FinderInfo` op de `.app` en `codesign` faalt met *"resource fork, Finder
  information, or similar detritus not allowed"*. Simulatorbuilds hebben hier geen last van
  omdat die niet worden ondertekend.
