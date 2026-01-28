//
//  KeychainHelper.swift
//  SAEMusicLyrics
//
//  Secure storage utility for Keychain access
//

import Foundation
import Security

/// Helper class for secure Keychain storage
final class KeychainHelper {
    
    static let shared = KeychainHelper()
    
    private init() {}
    
    // MARK: - Save
    
    /// Save string to Keychain
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }
    
    /// Save data to Keychain
    func save(_ data: Data, forKey key: String) -> Bool {
        // Delete existing item first
        delete(key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Read
    
    /// Read string from Keychain
    func read(_ key: String) -> String? {
        guard let data = readData(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Read data from Keychain
    func readData(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    // MARK: - Delete
    
    /// Delete item from Keychain
    @discardableResult
    func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Convenience
    
    /// Save date to Keychain
    func save(date: Date, forKey key: String) -> Bool {
        let timestamp = String(date.timeIntervalSince1970)
        return save(timestamp, forKey: key)
    }
    
    /// Read date from Keychain
    func readDate(_ key: String) -> Date? {
        guard let timestampString = read(key),
              let timestamp = TimeInterval(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}
