import Foundation

/// Singleton die de OAuth-callback opvangt en doorstuurt naar de wachtende async-aanroep.
class OAuthCallbackHandler {
    static let shared = OAuthCallbackHandler()
    private init() {}

    var pendingContinuation: CheckedContinuation<String, Error>?

    /// Verwerkt een inkomende URL (aangeroepen vanuit ContentView.onOpenURL).
    func handle(url: URL) {
        guard url.scheme == "rssreader" else { return }

        // Geef SafariBrowserView het signaal om te sluiten
        NotificationCenter.default.post(name: .oauthCallbackReceived, object: nil)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            pendingContinuation?.resume(throwing: MastodonError.oauthFailed("Geen autorisatiecode ontvangen"))
            pendingContinuation = nil
            return
        }

        pendingContinuation?.resume(returning: code)
        pendingContinuation = nil
    }

    /// Annuleert de wachtende OAuth-aanvraag (gebruiker sluit browser handmatig).
    func cancel() {
        pendingContinuation?.resume(throwing: MastodonError.oauthCancelled)
        pendingContinuation = nil
    }
}

extension Notification.Name {
    static let oauthCallbackReceived = Notification.Name("nl.rssreader.oauthCallbackReceived")
}
