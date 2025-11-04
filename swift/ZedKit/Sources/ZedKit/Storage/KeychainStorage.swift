import Foundation
import Security

/// Secure storage for credentials using iOS Keychain
public actor KeychainStorage {
    private let service: String

    public init(service: String = "dev.zed.ZedKit") {
        self.service = service
    }

    // MARK: - Credentials Storage

    /// Save credentials to keychain
    public func saveCredentials(_ credentials: ZedCredentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "credentials",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status: status)
        }
    }

    /// Load credentials from keychain
    public func loadCredentials() throws -> ZedCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unableToLoad(status: status)
        }

        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }

        return try JSONDecoder().decode(ZedCredentials.self, from: data)
    }

    /// Delete credentials from keychain
    public func deleteCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "credentials"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status: status)
        }
    }
}

/// Errors that can occur during keychain operations
public enum KeychainError: Error, LocalizedError {
    case unableToSave(status: OSStatus)
    case unableToLoad(status: OSStatus)
    case unableToDelete(status: OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .unableToSave(let status):
            return "Unable to save to keychain (status: \(status))"
        case .unableToLoad(let status):
            return "Unable to load from keychain (status: \(status))"
        case .unableToDelete(let status):
            return "Unable to delete from keychain (status: \(status))"
        case .invalidData:
            return "Invalid data in keychain"
        }
    }
}
