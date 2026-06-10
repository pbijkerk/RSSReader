import Foundation

/// Centrale configuratie voor de hele app — voorkomt magic numbers en duplicatie.
enum AppConfiguration {
    
    // MARK: - Content thresholds
    
    /// Minimum aantal tekens voor "substantial content" in reader mode
    static let minimumContentLength = 200
    
    /// Maximum aantal feeds dat parallel ververst kan worden
    static let maxParallelRefreshes = 10
    
    // MARK: - Retention
    
    /// Standaard aantal dagen dat artikelen bewaard blijven (als feed geen eigen instelling heeft)
    static let defaultRetentionDays = 30
    
    // MARK: - API & Network
    
    /// Timeout voor artikel-extractie (in seconden)
    static let articleExtractionTimeout: TimeInterval = 30
    
    /// Timeout voor netwerk-requests (in seconden)
    static let networkTimeout: TimeInterval = 30
    
    /// Maximum aantal artikelen per Claude summary request
    static let maxArticlesPerSummary = 10
    
    /// Maximum aantal tokens voor Claude responses
    static let claudeMaxTokens = 600
    
    // MARK: - UI

    /// Standaard fontsize voor artikel-weergave
    static let defaultArticleFontSize = 17

    /// Standaard lettertypefamilie voor artikel-weergave
    static let defaultArticleFontFamily = "charter"

    /// Standaard schaalfactor voor de Feeds-lijst (tekst + iconen)
    static let defaultFeedListScale: Double = 1.0

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let retentionDays       = "defaultRetentionDays"
        static let claudeAPIKey        = "claudeAPIKey"          // legacy – gebruik Keychain
        static let articleFontSize     = "articleFontSize"
        static let articleFontFamily   = "articleFontFamily"
        static let hideReadArticles    = "hideReadArticles"
        static let feedCountMode       = "feedCountMode"
        static let previewLineCount    = "previewLineCount"
        static let showArticleThumbnails = "showArticleThumbnails"
        static let summaryLanguage     = "summaryLanguage"
        static let feedListScale       = "feedListScale"
        static let summaryLength       = "summaryLength"
        static let showBiasIndicators  = "showBiasIndicators"
    }

    // MARK: - Summary length

    enum SummaryLength: String, CaseIterable {
        case kort      = "kort"
        case normaal   = "normaal"
        case uitgebreid = "uitgebreid"

        var label: String {
            switch self {
            case .kort:       return "Kort (2–3 zinnen)"
            case .normaal:    return "Normaal (4–6 zinnen)"
            case .uitgebreid: return "Uitgebreid (8–10 zinnen)"
            }
        }

        var sentenceInstruction: (nl: String, en: String) {
            switch self {
            case .kort:
                return (
                    "Schrijf een samenvatting van 2 tot 3 zinnen in het Nederlands die de kern beschrijft. Wees feitelijk en objectief.",
                    "Write a summary of 2 to 3 sentences in English describing the core theme. Be factual and objective."
                )
            case .normaal:
                return (
                    "Schrijf een samenvatting van 4 tot 6 zinnen in het Nederlands die de belangrijkste thema's en ontwikkelingen beschrijft. Wees feitelijk en objectief.",
                    "Write a summary of 4 to 6 sentences in English describing the main themes and developments. Be factual and objective."
                )
            case .uitgebreid:
                return (
                    "Schrijf een samenvatting van 8 tot 10 zinnen in het Nederlands die de belangrijkste thema's, ontwikkelingen en achtergronden uitgebreid beschrijft. Wees feitelijk en objectief.",
                    "Write a summary of 8 to 10 sentences in English describing the main themes, developments and context in detail. Be factual and objective."
                )
            }
        }

        var maxTokens: Int {
            switch self {
            case .kort:       return 300
            case .normaal:    return 600
            case .uitgebreid: return 1000
            }
        }

        var localSnippetCount: Int {
            switch self {
            case .kort:       return 2
            case .normaal:    return 5
            case .uitgebreid: return 8
            }
        }
    }

    static let defaultSummaryLength = SummaryLength.normaal.rawValue

    // MARK: - Keychain Keys

    /// Aantal dagen dat een fact-check resultaat geldig blijft vóór hercontrole
    static let factCheckCacheDays: Double = 7

    enum KeychainKeys {
        static let claudeAPIKey           = "claudeAPIKey"
        static let googleFactCheckAPIKey  = "googleFactCheckAPIKey"
        static func mastodonToken(instanceURL: String, accountID: String) -> String {
            "mastodon.token.\(instanceURL).\(accountID)"
        }
    }
    
    // MARK: - Logging
    
    enum LogSubsystem {
        static let main = "com.rssreader.app"
        
        enum Category {
            static let networking = "networking"
            static let clustering = "clustering"
            static let mastodon = "mastodon"
            static let feed = "feed"
            static let extraction = "extraction"
        }
    }
}
