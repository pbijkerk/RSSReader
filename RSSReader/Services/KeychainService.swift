import Foundation
import Security
import OSLog

/// Eenvoudige Keychain-wrapper voor het veilig opslaan van gevoelige strings.
enum KeychainService {

    private static let service = "com.rssreader.app"

    private static let logger = Logger(
        subsystem: AppConfiguration.LogSubsystem.main,
        category: "keychain"
    )

    // MARK: - Opslaan

    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)

        if status != errSecSuccess {
            logger.error("Keychain save failed for key '\(key)': OSStatus \(status)")
        }
        return status == errSecSuccess
    }

    // MARK: - Ophalen

    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
                logger.error("Keychain load succeeded but data is unreadable for key '\(key)'")
                return nil
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Keychain load failed for key '\(key)': OSStatus \(status)")
            return nil
        }
    }

    // MARK: - Verwijderen

    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain delete failed for key '\(key)': OSStatus \(status)")
        }
        return status == errSecSuccess
    }
}
