import SwiftUI
import SwiftData

private let retentionOptions: [(label: String, days: Int)] = [
    ("1 dag",       1),
    ("2 dagen",     2),
    ("7 dagen",     7),
    ("14 dagen",   14),
    ("30 dagen",   30),
    ("60 dagen",   60),
    ("90 dagen",   90),
    ("180 dagen", 180),
    ("1 jaar",    365),
    ("Nooit",       0),
]

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var mastodonAccounts: [MastodonAccount]

    /// API-sleutel uit Keychain — geladen via .onAppear, opgeslagen via .onChange
    @State private var claudeAPIKey = ""
    
    @AppStorage(AppConfiguration.UserDefaultsKeys.retentionDays) 
    private var defaultRetentionDays = AppConfiguration.defaultRetentionDays
    
    @AppStorage(AppConfiguration.UserDefaultsKeys.hideReadArticles) private var hideReadArticles = false
    @AppStorage(AppConfiguration.UserDefaultsKeys.feedCountMode) private var feedCountMode = "total"
    @AppStorage(AppConfiguration.UserDefaultsKeys.previewLineCount) private var previewLineCount = 2
    @AppStorage(AppConfiguration.UserDefaultsKeys.showArticleThumbnails) private var showArticleThumbnails = true

    @AppStorage(AppConfiguration.UserDefaultsKeys.feedListScale)
    private var feedListScale = AppConfiguration.defaultFeedListScale

    @AppStorage(AppConfiguration.UserDefaultsKeys.articleFontSize)
    private var articleFontSize = AppConfiguration.defaultArticleFontSize

    @AppStorage(AppConfiguration.UserDefaultsKeys.articleFontFamily)
    private var articleFontFamily = AppConfiguration.defaultArticleFontFamily

    @AppStorage(AppConfiguration.UserDefaultsKeys.summaryLanguage)
    private var summaryLanguage = "nl"

    @AppStorage(AppConfiguration.UserDefaultsKeys.summaryLength)
    private var summaryLength = AppConfiguration.defaultSummaryLength
    
    @State private var showAPIKey = false
    @State private var savedConfirmation = false
    @State private var showMastodonSetup = false
    @State private var showingClaudeConsole = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showAPIKey {
                            TextField("sk-ant-…", text: $claudeAPIKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("sk-ant-…", text: $claudeAPIKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Claude API Key (Optional)")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adding an API key enables AI-powered article summaries using Claude. Without it, summaries are generated locally.")
                        if !claudeAPIKey.isEmpty {
                            Label("AI summaries enabled", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                                .padding(.top, 2)
                        }
                    }
                }

                Section("Weergave") {
                    Toggle("Verberg gelezen artikelen", isOn: $hideReadArticles)
                    Picker("Teller per feed", selection: $feedCountMode) {
                        Text("Totaal aantal artikelen").tag("total")
                        Text("Ongelezen artikelen").tag("unread")
                    }
                    Stepper("Regels voorvertoning: \(previewLineCount)", value: $previewLineCount, in: 1...5)
                    Toggle("Toon miniatuurafbeeldingen", isOn: $showArticleThumbnails)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tekstgrootte Feeds-lijst")
                            Spacer()
                            Text("\(Int(feedListScale * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundStyle(.secondary)
                            Slider(value: $feedListScale, in: 0.8...1.5, step: 0.05)
                            Image(systemName: "textformat.size.larger")
                                .foregroundStyle(.secondary)
                        }
                        Button("Herstel standaard") {
                            feedListScale = AppConfiguration.defaultFeedListScale
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lettergrootte artikelen: \(articleFontSize)pt")
                        Slider(
                            value: Binding(
                                get: { Double(articleFontSize) },
                                set: { articleFontSize = Int($0) }
                            ),
                            in: 13...23,
                            step: 1
                        )
                    }
                    .padding(.vertical, 4)
                    Picker("Lettertype", selection: $articleFontFamily) {
                        Text("Charter").tag("charter")
                        Text("SF Pro").tag("system")
                        Text("New York").tag("newyork")
                        Text("Georgia").tag("georgia")
                    }
                }

                Section("Samenvattingen") {
                    Picker("Taal", selection: $summaryLanguage) {
                        Text("Nederlands").tag("nl")
                        Text("English").tag("en")
                    }
                    Picker("Lengte", selection: $summaryLength) {
                        ForEach(AppConfiguration.SummaryLength.allCases, id: \.rawValue) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                }

                Section {
                    Picker("Standaard bewaarperiode", selection: $defaultRetentionDays) {
                        ForEach(retentionOptions, id: \.days) { opt in
                            Text(opt.label).tag(opt.days)
                        }
                    }
                } header: {
                    Text("Bewaarperiode artikelen")
                } footer: {
                    Text("Feeds zonder eigen instelling gebruiken deze periode. De instelling gaat in bij de volgende verversing.")
                        .font(.caption)
                }

                Section("Mastodon") {
                    ForEach(mastodonAccounts) { account in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: account.avatarURL)) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default:
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(account.displayName)
                                        .font(.body)
                                    if account.needsReauth {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                    }
                                }
                                Text("@\(account.username)@\(URL(string: account.instanceURL)?.host ?? account.instanceURL)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let last = account.lastRefreshed {
                                Text(last, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let account = mastodonAccounts[index]
                            if let feed = account.feed { modelContext.delete(feed) }
                            modelContext.delete(account)
                        }
                        try? modelContext.save()
                    }

                    Button {
                        showMastodonSetup = true
                    } label: {
                        Label("Mastodon account toevoegen", systemImage: "plus")
                    }
                }
                .sheet(isPresented: $showMastodonSetup) {
                    MastodonSetupView()
                }

                Section("About") {
                    LabeledContent("App", value: "RSS Reader")
                    LabeledContent("Version", value: "1.0.0")
                }

                Section {
                    Button("Get a Claude API Key") {
                        showingClaudeConsole = true
                    }
                } footer: {
                    Text("API keys are stored securely in your device's local storage and never shared.")
                }
                .sheet(isPresented: $showingClaudeConsole) {
                    SafariVideoPlayer(url: URL(string: "https://console.anthropic.com")!)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            // Lees uit Keychain; fall-back op UserDefaults voor bestaande installaties
            claudeAPIKey = KeychainService.load(forKey: AppConfiguration.KeychainKeys.claudeAPIKey)
                ?? UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKeys.claudeAPIKey)
                ?? ""
        }
        .onChange(of: claudeAPIKey) { _, newValue in
            KeychainService.save(newValue, forKey: AppConfiguration.KeychainKeys.claudeAPIKey)
            // Verwijder legacy UserDefaults-waarde na migratie
            UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKeys.claudeAPIKey)
        }
    }
}
