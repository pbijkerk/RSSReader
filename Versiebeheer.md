# Projectinstructies voor Claude Code

## Versiebeheer (iOS)

Pas bij alle ontwikkelwerkzaamheden de volgende best practices toe:

### Versienummering

- Gebruik **Semantic Versioning** (`MAJOR.MINOR.PATCH`) voor de marketing version (`CFBundleShortVersionString`).
  - MAJOR: breaking changes of grote redesigns
  - MINOR: nieuwe features
  - PATCH: bugfixes
- Verhoog het **build number** (`CFBundleVersion`) bij elke build die naar App Store Connect gaat. Wijzig dit nooit handmatig in de broncode; gebruik Fastlane of CI/CD.

### Git-workflow

- Maak voor elke release een tag in het formaat `vMAJOR.MINOR.PATCH` (bijv. `v2.4.1`).
- Gebruik release branches (`release/2.4`) voor stabilisatie en hotfixes; nieuwe features gaan via feature branches naar `main`.
- Schrijf duidelijke commit messages volgens Conventional Commits (`feat:`, `fix:`, `chore:`, etc.).
- Werk `CHANGELOG.md` bij bij elke versiewijziging.

### Automatisering (Fastlane)

- Gebruik `increment_build_number(build_number: latest_testflight_build_number + 1)` voor build numbers.
- Gebruik `increment_version_number(bump_type: ...)` voor de marketing version; vraag bij twijfel aan de gebruiker of het een patch, minor of major release is.
- Zet na een release automatisch een Git-tag met `add_git_tag` en `push_git_tags`.
- Gebruik `match` voor certificaten en provisioning profiles.

### Algemene regels

- Voer nooit een release-lane uit zonder expliciete bevestiging van de gebruiker.
- Controleer voor elke release of `CHANGELOG.md` en de release notes actueel zijn.
- Houd versie-informatie op één plek (Xcode project settings / `.xcconfig`), niet verspreid door de code.
### Installatie op het toestel

- Elke release wordt na het taggen op de iPhone geïnstalleerd; dit project gaat niet via de
  App Store, dus dit is de enige distributie. Zie stap 9 van `Workflow-feature.md` voor de
  commando's. Dit gebeurt alleen bij een release, niet na gewoon featurewerk.
- Draai `xcodegen generate` vóór de device-build: de versie staat in `project.yml` en komt pas
  in het `.xcodeproj` na regeneratie.
- Bouw device-builds naar een `-derivedDataPath` buiten de projectmap. Die staat in iCloud
  Drive, dat extended attributes op de buildoutput zet (waargenomen: `com.apple.provenance`;
  ook `com.apple.FinderInfo` komt voor), waarna `codesign` faalt met *"resource fork, Finder
  information, or similar detritus not allowed"*. `xattr -rc` lost dit niet op — die
  attributen komen terug of zijn niet te verwijderen.
