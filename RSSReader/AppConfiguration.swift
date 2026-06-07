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
    }

    // MARK: - Keychain Keys

    enum KeychainKeys {
        static let claudeAPIKey = "claudeAPIKey"
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
