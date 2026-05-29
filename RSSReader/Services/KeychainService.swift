import Foundation
import Security

/// Eenvoudige Keychain-wrapper voor het veilig opslaan van gevoelige strings.
enum KeychainService {

    private static let service = "com.rssreader.app"

    // MARK: - Opslaan

    /// Slaat een string-waarde op onder de opgegeven sleutel.
    /// Overschrijft een bestaand item als dat aanwezig is.
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        // Verwijder eventueel bestaand item
        SecItemDelete(query as CFDictionary)

        // Voeg nieuw item toe
        var attributes = query
        attributes[kSecValueData] = data
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Ophalen

    /// Laadt een eerder opgeslagen string-waarde, of `nil` als die niet bestaat.
    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  kCFBooleanTrue as Any,
            kSecMatchLimit:  kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data   = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    // MARK: - Verwijderen

    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
