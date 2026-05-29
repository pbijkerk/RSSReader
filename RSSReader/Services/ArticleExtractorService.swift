import Foundation
import WebKit
import OSLog

/// Haalt de hoofdcontent van een webpagina op via een verborgen WKWebView + JS-extractie.
@MainActor
class ArticleExtractorService: NSObject, ObservableObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?
    
    private let logger = Logger(
        subsystem: AppConfiguration.LogSubsystem.main,
        category: AppConfiguration.LogSubsystem.Category.extraction
    )

    private static let extractorJS = """
    (function() {
        // Verwijder ruis-elementen
        var remove = [
            'script', 'style', 'noscript', 'nav', 'header', 'footer',
            'aside', 'iframe', 'form', 'button',
            '[class*="ad-"]', '[class*="-ad"]', '[id*="ad-"]',
            '[class*="banner"]', '[class*="popup"]', '[class*="modal"]',
            '[class*="sidebar"]', '[class*="related"]', '[class*="comment"]',
            '[class*="share"]', '[class*="social"]', '[class*="newsletter"]',
            '[class*="subscribe"]', '[class*="cookie"]', '[role="complementary"]',
            '[role="navigation"]', '[role="banner"]'
        ];
        remove.forEach(function(sel) {
            try {
                document.querySelectorAll(sel).forEach(function(el) { el.remove(); });
            } catch(e) {}
        });

        // Zoek hoofd-content element (volgorde = prioriteit)
        var selectors = [
            'article',
            '[role="main"]',
            'main',
            '.entry-content',
            '.post-content',
            '.article-body',
            '.article-content',
            '.story-body',
            '.post-body',
            '.content-body',
            '.body-text',
            '#article-body',
            '#content',
            '.post',
            '.article'
        ];

        for (var i = 0; i < selectors.length; i++) {
            var el = document.querySelector(selectors[i]);
            if (el && el.innerText && el.innerText.length > 200) {
                return el.innerHTML;
            }
        }

        // Fallback: div/section met meeste tekst
        var best = document.body;
        var bestLen = 0;
        document.querySelectorAll('div, section').forEach(function(el) {
            var len = el.innerText ? el.innerText.length : 0;
            if (len > bestLen && len > 500) { bestLen = len; best = el; }
        });
        return best ? best.innerHTML : document.body.innerHTML;
    })()
    """

    func extract(from url: URL) async throws -> String {
        logger.debug("Starting extraction from: \(url.absoluteString)")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true

            let wv = WKWebView(frame: .zero, configuration: config)
            wv.navigationDelegate = self
            self.webView = wv

            wv.load(URLRequest(url: url))
            
            // Timeout protection — cleanup na configureerbare tijd
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(AppConfiguration.articleExtractionTimeout))
                
                guard let self, self.continuation != nil else { return }
                
                self.logger.warning("Article extraction timed out for: \(url.absoluteString)")
                self.cleanup(with: URLError(.timedOut))
            }
        }
    }
    
    private func cleanup(with error: Error? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil
        
        if let error {
            continuation?.resume(throwing: error)
        }
        
        continuation = nil
        webView?.stopLoading()
        webView = nil
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            do {
                let result = try await webView.evaluateJavaScript(Self.extractorJS)
                let html = result as? String ?? ""
                
                logger.info("Successfully extracted \(html.count) characters")
                self.continuation?.resume(returning: html)
                self.cleanup()
            } catch {
                logger.error("JavaScript evaluation failed: \(error.localizedDescription)")
                self.continuation?.resume(throwing: error)
                self.cleanup()
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            logger.error("Navigation failed: \(error.localizedDescription)")
            self.cleanup(with: error)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            logger.error("Provisional navigation failed: \(error.localizedDescription)")
            self.cleanup(with: error)
        }
    }
}
