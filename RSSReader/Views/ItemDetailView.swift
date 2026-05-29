import SwiftUI
import WebKit
import AVKit
import SafariServices

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let item: FeedItem

    @AppStorage(AppConfiguration.UserDefaultsKeys.articleFontSize) private var articleFontSize = AppConfiguration.defaultArticleFontSize

    @State private var displayHTML: String = ""
    @State private var isExtracting = false
    @State private var extractionFailed = false
    @State private var showingVideoPlayer = false
    @State private var safariItem: IdentifiableURL? = nil
    @StateObject private var extractor = ArticleExtractorService()

    private var articleURL: URL? {
        guard let link = item.link else { return nil }
        return URL(string: link)
    }

    private var canExtract: Bool {
        !item.isVideoItem && !item.isAudioItem
            && item.feed?.isMastodonFeed != true
            && articleURL != nil
    }

    var body: some View {
        Group {
            if item.isAudioItem {
                audioLayout
            } else if item.isVideoItem {
                videoLayout
            } else {
                readerLayout
            }
        }
        .navigationTitle(item.feed?.title ?? "Artikel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(item: $safariItem) { item in
            SafariVideoPlayer(url: item.url).ignoresSafeArea()
        }
        .task { await loadContent() }
        .onAppear {
            if !item.isRead {
                item.isRead = true
                try? modelContext.save()
            }
        }
    }

    // MARK: - Audio layout

    @ViewBuilder
    private var audioLayout: some View {
        if let audioURL = item.directAudioURL {
            VStack(spacing: 0) {
                AudioPlayerView(url: audioURL)
                ReaderWebView(
                    html: displayHTML,
                    baseURL: articleURL,
                    onLoadFullArticle: articleURL != nil ? { Task { await extractFromWeb() } } : nil,
                    onOpenURL: openInAppBrowser
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Video layout

    @ViewBuilder
    private var videoLayout: some View {
        if let videoURL = item.directVideoURL {
            // Directe MP4/WebM: native AVPlayer inline
            nativePlayerLayout(videoURL: videoURL)
        } else if let playerURL = item.videoPlayerURL {
            // YouTube / Vimeo: afspeelknop → SFSafariViewController
            safariPlayerLayout(playerURL: playerURL)
        }
    }

    /// YouTube / Vimeo: afspeelkaart + beschrijving; video opent in SFSafariViewController
    private func safariPlayerLayout(playerURL: URL) -> some View {
        VStack(spacing: 0) {
            // Afspeelkaart
            Button {
                showingVideoPlayer = true
            } label: {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16 / 9, contentMode: .fit)
                    VStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 8)
                        Text("Tik om af te spelen")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showingVideoPlayer) {
                SafariVideoPlayer(url: playerURL)
                    .ignoresSafeArea()
            }

            // Beschrijving
            ReaderWebView(html: descriptionHTML, baseURL: articleURL, onOpenURL: openInAppBrowser)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Directe MP4: native AVPlayer bovenaan, beschrijving eronder
    private func nativePlayerLayout(videoURL: URL) -> some View {
        VStack(spacing: 0) {
            NativeVideoPlayer(url: videoURL)
                .frame(height: UIScreen.main.bounds.width * 9 / 16)
            if !displayHTML.isEmpty {
                ReaderWebView(html: displayHTML, baseURL: articleURL, onOpenURL: openInAppBrowser)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Reader layout (bestaand)

    private var readerLayout: some View {
        ZStack {
            ReaderWebView(
                html: displayHTML,
                baseURL: articleURL,
                onLoadFullArticle: articleURL != nil ? { Task { await extractFromWeb() } } : nil,
                onOpenURL: openInAppBrowser
            )
            .ignoresSafeArea(edges: .bottom)

            if isExtracting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Artikel laden…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func openInAppBrowser(_ url: URL) {
        safariItem = IdentifiableURL(url: url)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let url = articleURL {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Opnieuw laden bij extractiefout
                if extractionFailed {
                    Button {
                        Task { await extractFromWeb() }
                    } label: {
                        Label("Opnieuw laden", systemImage: "arrow.clockwise")
                    }
                    .disabled(isExtracting)
                }

                // Bewaar artikel
                Button {
                    item.isSaved.toggle()
                    try? modelContext.save()
                } label: {
                    Image(systemName: item.isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(item.isSaved ? "Verwijder uit bewaard" : "Bewaar artikel")

                // Open in browser (in-app)
                Button {
                    safariItem = IdentifiableURL(url: url)
                } label: {
                    Label("Open in browser", systemImage: "safari")
                }

                // Delen
                ShareLink(item: url) {
                    Label("Delen", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - HTML helpers

    private var descriptionHTML: String {
        Self.readerHTML(
            content: item.sanitisedHTML.isEmpty
                ? "<p><em>Geen beschrijving beschikbaar.</em></p>"
                : item.sanitisedHTML,
            title: item.title,
            feedName: item.feed?.title,
            date: item.pubDate,
            fontSize: articleFontSize
        )
    }

    // MARK: - Content laden

    private func loadContent() async {
        guard !item.isVideoItem else { return }
        // Mastodon-posts hebben geen apart "volledig artikel" — link niet klikbaar maken
        let articleLink = item.feed?.isMastodonFeed == true ? nil : item.link
        var rssHTML = item.sanitisedHTML
        // Mastodon: afbeelding toevoegen als die nog niet in de HTML staat
        // (items opgehaald vóór de img-fix hebben enclosureURL maar geen <img> in itemDescription)
        if item.feed?.isMastodonFeed == true,
           let imgURL = item.enclosureURL,
           !rssHTML.contains(imgURL) {
            rssHTML += "\n<img src=\"\(imgURL)\" alt=\"\" style=\"max-width:100%;border-radius:8px;margin:8px 0;display:block;\">"
        }
        if !rssHTML.isEmpty {
            // Toon RSS-samenvatting; titel is tappable voor volledig artikel (niet bij Mastodon)
            displayHTML = Self.readerHTML(
                content: rssHTML,
                title: item.title,
                feedName: item.feed?.title,
                date: item.pubDate,
                articleLink: articleLink,
                fontSize: articleFontSize
            )
        } else {
            // Geen RSS-content — hint dat de gebruiker op de titel kan tikken
            displayHTML = Self.readerHTML(
                content: "<p><em>Geen samenvatting beschikbaar. Tik op de titel om het volledige artikel te lezen.</em></p>",
                title: item.title,
                feedName: item.feed?.title,
                date: item.pubDate,
                articleLink: articleLink,
                fontSize: articleFontSize
            )
        }
    }

    private func extractFromWeb(url: URL? = nil) async {
        guard let url = url ?? articleURL else { return }
        isExtracting = true
        extractionFailed = false
        do {
            let html = try await extractor.extract(from: url)
            displayHTML = Self.readerHTML(
                content: html.isEmpty ? "<p><em>Geen inhoud gevonden.</em></p>" : html,
                title: item.title,
                feedName: item.feed?.title,
                date: item.pubDate,
                fontSize: articleFontSize
            )
        } catch {
            extractionFailed = true
        }
        isExtracting = false
    }

    // MARK: - HTML-template

    static func readerHTML(content: String, title: String, feedName: String?, date: Date?,
                           articleLink: String? = nil, fontSize: Int = 17) -> String {
        let dateStr: String
        if let date {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.timeStyle = .none
            fmt.locale = Locale.current
            dateStr = fmt.string(from: date)
        } else {
            dateStr = ""
        }

        let meta = [feedName, dateStr].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5">
        <style>
        :root {
            --text:      #1a1a1a;
            --bg:        #ffffff;
            --secondary: #6b6b6b;
            --link:      #007aff;
            --code-bg:   rgba(0,0,0,0.06);
            --border:    rgba(0,0,0,0.12);
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --text:      #f0f0f0;
                --bg:        #1c1c1e;
                --secondary: #ababab;
                --link:      #0a84ff;
                --code-bg:   rgba(255,255,255,0.08);
                --border:    rgba(255,255,255,0.12);
            }
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        html { background: var(--bg); }
        body {
            font-family: -apple-system, 'SF Pro Text', Georgia, 'Times New Roman', serif;
            font-size: \(fontSize)px;
            line-height: 1.75;
            color: var(--text);
            background: var(--bg);
            padding: 20px 20px 48px;
            max-width: 680px;
            margin: 0 auto;
            word-break: break-word;
            -webkit-text-size-adjust: 100%;
        }
        .article-title {
            font-size: 1.55em;
            font-weight: 700;
            line-height: 1.25;
            margin-bottom: 0.3em;
            letter-spacing: -0.02em;
        }
        .article-meta {
            font-size: 0.82em;
            color: var(--secondary);
            margin-bottom: 1.6em;
            padding-bottom: 1.2em;
            border-bottom: 1px solid var(--border);
        }
        h1, h2, h3, h4, h5, h6 {
            font-weight: 700;
            line-height: 1.3;
            margin: 1.4em 0 0.4em;
            letter-spacing: -0.01em;
        }
        h1 { font-size: 1.4em; }
        h2 { font-size: 1.2em; }
        h3 { font-size: 1.05em; }
        p { margin: 0.85em 0; }
        a { color: var(--link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        img, video {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 0.6em 0;
            display: block;
        }
        figure { margin: 1.2em 0; }
        figcaption, .wp-caption-text, .caption {
            font-size: 0.82em;
            color: var(--secondary);
            text-align: center;
            margin-top: 0.4em;
        }
        blockquote {
            border-left: 3px solid var(--secondary);
            padding: 0.2em 0 0.2em 1em;
            color: var(--secondary);
            margin: 1em 0;
            font-style: italic;
        }
        pre {
            background: var(--code-bg);
            padding: 14px;
            border-radius: 8px;
            overflow-x: auto;
            font-size: 0.85em;
            line-height: 1.5;
            margin: 1em 0;
        }
        code {
            font-family: 'SF Mono', Menlo, monospace;
            font-size: 0.875em;
            background: var(--code-bg);
            padding: 2px 5px;
            border-radius: 4px;
        }
        pre code { background: none; padding: 0; border-radius: 0; }
        ul, ol { padding-left: 1.4em; margin: 0.8em 0; }
        li { margin: 0.3em 0; }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9em;
            margin: 1em 0;
            overflow-x: auto;
            display: block;
        }
        th, td { border: 1px solid var(--border); padding: 8px 12px; text-align: left; }
        th { background: var(--code-bg); font-weight: 600; }
        hr { border: none; border-top: 1px solid var(--border); margin: 1.5em 0; }
        .article-title-link { text-decoration: none; color: inherit; display: block; }
        .article-title-link:active h1 { opacity: 0.6; }
        .read-full-hint { font-size: 13px; color: var(--link); margin-top: 4px; margin-bottom: 16px; }
        </style>
        </head>
        <body>
        \(articleLink != nil ? "<a href=\"rssreader://load-full-article\" class=\"article-title-link\">" : "")
        <h1 class="article-title">\(escapeHTML(title))</h1>
        \(articleLink != nil ? "<p class=\"read-full-hint\">Tik voor het volledige artikel ›</p></a>" : "")
        \(meta.isEmpty ? "" : "<p class=\"article-meta\">\(escapeHTML(meta))</p>")
        \(content)
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - IdentifiableURL (voor .sheet(item:) zonder race condition)

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - SafariVideoPlayer (YouTube / Vimeo — volwaardige Safari binnen de app)

struct SafariVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - ReaderWebView

struct ReaderWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    var onLoadFullArticle: (() -> Void)? = nil
    var onOpenURL: ((URL) -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false      // geen scripts in RSS-HTML

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.scrollView.contentInsetAdjustmentBehavior = .automatic
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        // Herlaad alleen als de HTML veranderd is
        guard html != context.coordinator.lastHTML else { return }
        context.coordinator.lastHTML = html
        context.coordinator.initialLoadDone = false   // reset vóór nieuwe lading
        wv.loadHTMLString(html, baseURL: baseURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFullArticle: onLoadFullArticle, onOpenURL: onOpenURL)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String = ""
        var initialLoadDone = false
        let onLoadFullArticle: (() -> Void)?
        let onOpenURL: ((URL) -> Void)?

        init(onLoadFullArticle: (() -> Void)?, onOpenURL: ((URL) -> Void)?) {
            self.onLoadFullArticle = onLoadFullArticle
            self.onOpenURL = onOpenURL
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            initialLoadDone = true
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            initialLoadDone = true
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if url.scheme == "rssreader" {
                // Tik op artikel-titel → volledig artikel laden
                onLoadFullArticle?()
                decisionHandler(.cancel)
            } else if (url.scheme == "https" || url.scheme == "http") && initialLoadDone {
                // Alle http(s)-navigaties ná de initiële lading openen in in-app browser
                // (onderschept zowel .linkActivated als .other, bijv. Mastodon-redirects)
                if let onOpenURL {
                    onOpenURL(url)
                } else {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
