# RSSReader

Native iOS RSS-lezer met AI-samenvattingen via de Claude API.

**Vereisten:** iOS 17+, Xcode 15+, Swift 5.9+

**Bouwen:** SweetPad in VS Code (zie *Toolchain*), of open `RSSReader.xcodeproj` in Xcode → `⌘R`

## Toolchain
**BELANGRIJK:** dit project gebruikt **SweetPad**, niet XcodeBuildMCP. Deze sectie vervangt de
`## XcodeBuildMCP Integration`-sectie uit de bovenliggende `CLAUDE.md`; gebruik in dit project
geen `mcp__xcodebuildmcp__*`-tools.

- **Build/run/debug:** SweetPad (VS Code) of `xcodebuild` via de terminal.
- **Scheme:** `RSSReader` — het Xcode-project wordt gegenereerd uit `project.yml` (XcodeGen).
- **Code-intelligence:** SourceKit-LSP heeft een `buildServer.json` nodig (niet in Git):
  ```bash
  brew install xcode-build-server xcbeautify
  xcode-build-server config -project RSSReader.xcodeproj -scheme RSSReader
  ```
- **Aanbevolen VS Code-extensies:** zie `.vscode/extensions.json`.

## Architectuur
- `RSSReader/Models/` — SwiftData-modellen (Feed, FeedItem, MastodonAccount, Topic)
- `RSSReader/Views/` — SwiftUI-views per scherm
- `RSSReader/Services/` — businesslogica (parsing, refresh, clustering, Keychain)
- `AppConfiguration.swift` — centrale constanten en configuratiesleutels

Geen externe Swift-packages; uitsluitend Apple-frameworks en de Anthropic REST API (`claude-haiku-4-5`). API-sleutel wordt opgeslagen in de Keychain via `KeychainService`.

## Swift best practices en richtlijnen
@IOS_Swift.md

## Versiebeheer
@Versiebeheer.md

## Workflow feature afronden
@Workflow-feature.md
- Voer deze workflow automatisch en volledig uit zodra de gebruiker aangeeft dat een feature af, klaar of gereed is — of vraagt om te committen na afgerond featurewerk.
