import SwiftData
import Foundation

@Model
class FeedItem {
    var id: UUID
    var title: String
    var link: String?
    var itemDescription: String?
    var pubDate: Date?
    var isRead: Bool
    var isSaved: Bool = false
    var guid: String?
    var enclosureURL: String?
    var enclosureMIMEType: String?
    var imageURL: String?
    var feed: Feed?

    init(
        title: String,
        link: String? = nil,
        itemDescription: String? = nil,
        pubDate: Date? = nil,
        guid: String? = nil,
        enclosureURL: String? = nil,
        enclosureMIMEType: String? = nil,
        imageURL: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.link = link
        self.itemDescription = itemDescription
        self.pubDate = pubDate
        self.isRead = false
        self.guid = guid
        self.enclosureURL = enclosureURL
        self.enclosureMIMEType = enclosureMIMEType
        self.imageURL = imageURL
    }

    var plainDescription: String {
        guard let desc = itemDescription else { return "" }
        return desc
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .htmlEntityDecoded
    }

    // MARK: - Cached regexes voor performance
    
    private static let scriptRegex = try! NSRegularExpression(
        pattern: "(?i)<script[^>]*>[\\s\\S]*?</script>", options: []
    )
    private static let styleRegex = try! NSRegularExpression(
        pattern: "(?i)<style[^>]*>[\\s\\S]*?</style>", options: []
    )
    private static let noscriptRegex = try! NSRegularExpression(
        pattern: "(?i)<noscript[^>]*>[\\s\\S]*?</noscript>", options: []
    )
    private static let iframeRegex = try! NSRegularExpression(
        pattern: "(?i)<iframe[^>]*>[\\s\\S]*?</iframe>", options: []
    )
    
    /// RSS-content gestript van <script> en <style> blokken, maar met overige HTML intact.
    var sanitisedHTML: String {
        guard let html = itemDescription, !html.isEmpty else { return "" }
        var result = html
        
        // Gebruik cached regexes voor betere performance
        let regexes = [
            Self.scriptRegex,
            Self.styleRegex,
            Self.noscriptRegex,
            Self.iframeRegex
        ]
        
        for regex in regexes {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: ""
            )
        }
        
        return result
    }

    /// Voldoende RSS-content voor reader mode
    var hasSubstantialContent: Bool {
        plainDescription.count > AppConfiguration.minimumContentLength
    }

    var fullText: String {
        "\(title) \(plainDescription)"
    }

    // MARK: - Video detectie

    /// YouTube video-ID extraheren uit het artikel-link.
    var youtubeVideoID: String? {
        guard let link, link.contains("youtube.com") || link.contains("youtu.be") else { return nil }
        guard let url = URL(string: link) else { return nil }
        // youtube.com/watch?v=ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return v
        }
        // youtu.be/ID
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.dropFirst().first
        }
        return nil
    }

    /// Vimeo video-ID (numeriek) extraheren uit het artikel-link.
    var vimeoVideoID: String? {
        guard let link, link.contains("vimeo.com") else { return nil }
        guard let url = URL(string: link) else { return nil }
        // Zoek het eerste numerieke path-component (van achter naar voren)
        return url.pathComponents.reversed().first { Int($0) != nil }
    }

    /// Directe video-URL vanuit enclosure (MP4, WebM, etc.).
    var directVideoURL: URL? {
        guard let mime = enclosureMIMEType, mime.hasPrefix("video/"),
              let urlStr = enclosureURL else { return nil }
        return URL(string: urlStr)
    }

    /// `true` als dit item een afspeelbare video bevat.
    var isVideoItem: Bool {
        youtubeVideoID != nil || vimeoVideoID != nil || directVideoURL != nil
    }

    // MARK: - Audio detectie

    /// Directe audio-URL vanuit enclosure (MP3, AAC, etc.).
    var directAudioURL: URL? {
        guard let mime = enclosureMIMEType, mime.hasPrefix("audio/"),
              let urlStr = enclosureURL else { return nil }
        return URL(string: urlStr)
    }

    /// `true` als dit item een afspeelbare audio-enclosure bevat.
    var isAudioItem: Bool { directAudioURL != nil }

    /// Watch-URL voor YouTube / Vimeo (voor SFSafariViewController — geen embed).
    var videoPlayerURL: URL? {
        if let id = youtubeVideoID {
            return URL(string: "https://youtu.be/\(id)")
        }
        if let id = vimeoVideoID {
            return URL(string: "https://vimeo.com/\(id)")
        }
        return nil
    }
}

// MARK: - HTML-entiteiten decoderen

private extension String {
    /// Decodeert HTML-entiteiten: named (bv. &amp;, &mdash;) én numeriek (bv. &#8271;, &#x203F;).
    var htmlEntityDecoded: String {
        guard self.contains("&") else { return self }
        var s = self
        // Veelvoorkomende named entities
        let named: [(String, String)] = [
            ("&amp;",    "&"),  ("&lt;",    "<"),  ("&gt;",    ">"),
            ("&quot;",   "\""), ("&apos;",  "'"),  ("&nbsp;",  " "),
            ("&mdash;",  "—"),  ("&ndash;", "–"),  ("&lsquo;", "\u{2018}"),
            ("&rsquo;",  "\u{2019}"), ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
            ("&hellip;", "…"),  ("&bull;",  "•"),  ("&copy;",  "©"),
            ("&reg;",    "®"),  ("&trade;", "™"),  ("&euro;",  "€"),
        ]
        for (entity, char) in named {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        // Numerieke entiteiten: decimaal &#NNN; en hex &#xHHH;
        guard s.contains("&#"),
              let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);")
        else { return s }
        let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: s),
                  let numRange = Range(match.range(at: 2), in: s) else { continue }
            let isHex = match.range(at: 1).length > 0
            let numStr = String(s[numRange])
            if let code = isHex ? UInt32(numStr, radix: 16) : UInt32(numStr),
               let scalar = Unicode.Scalar(code) {
                s.replaceSubrange(range, with: String(scalar))
            }
        }
        return s
    }
}
