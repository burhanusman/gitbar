import Foundation
import Security
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "KeychainService")

/// Errors that can occur during Keychain operations
enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidItemFormat
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in Keychain"
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .invalidItemFormat:
            return "Invalid item format in Keychain"
        case .encodingFailed:
            return "Failed to encode data for Keychain"
        }
    }
}

/// Service for securely storing API keys in macOS Keychain
final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.gitbar.app"

    // Keychain account identifiers
    private let openAIAPIKeyAccount = "openai-api-key"

    private init() {}

    // MARK: - OpenAI API Key

    /// Saves the OpenAI API key to Keychain
    func saveOpenAIAPIKey(_ key: String) throws {
        try saveString(key, account: openAIAPIKeyAccount)
    }

    /// Retrieves the OpenAI API key from Keychain
    func getOpenAIAPIKey() -> String? {
        return getString(account: openAIAPIKeyAccount)
    }

    /// Deletes the OpenAI API key from Keychain
    func deleteOpenAIAPIKey() throws {
        try deleteItem(account: openAIAPIKeyAccount)
    }

    /// Checks if an OpenAI API key exists
    var hasOpenAIAPIKey: Bool {
        return getOpenAIAPIKey() != nil
    }

    // MARK: - Generic Keychain Operations

    private func saveString(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // First try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, create it
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]

            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            logger.error("Failed to save to Keychain: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        logger.debug("Saved item to Keychain: \(account)")
    }

    private func getString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                logger.warning("Failed to retrieve from Keychain: \(status)")
            }
            return nil
        }

        return string
    }

    private func deleteItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete from Keychain: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        logger.debug("Deleted item from Keychain: \(account)")
    }
}
