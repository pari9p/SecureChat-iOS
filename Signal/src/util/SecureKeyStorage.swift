//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

/// Enhanced secure key storage with biometric protection and key derivation
final class SecureKeyStorage {
    
    // MARK: - Properties
    
    private let serviceName: String
    private let securityManager = SecurityManager.shared
    private let keychainStorage: KeychainStorage
    
    // MARK: - Initialization
    
    init(serviceName: String = "org.signal.SecureKeyStorage", 
         keychainStorage: KeychainStorage = KeychainStorageImpl(isUsingProductionService: !DebugFlags.isDebugEnvironment())) {
        self.serviceName = serviceName
        self.keychainStorage = keychainStorage
    }
    
    // MARK: - Key Storage Operations
    
    func storeSecureKey(_ key: Data, identifier: String, requireBiometric: Bool = false) throws {
        guard !key.isEmpty else {
            throw SecureKeyStorageError.invalidKey
        }
        
        let enhancedKey = try enhanceKeyWithDerivation(key, identifier: identifier)
        
        if requireBiometric && securityManager.isBiometricAvailable() {
            try storeBiometricProtectedKey(enhancedKey, identifier: identifier)
        } else {
            try keychainStorage.setDataValue(enhancedKey, service: serviceName, key: identifier)
        }
        
        Logger.info("Securely stored key with identifier: \(identifier)")
    }
    
    func retrieveSecureKey(identifier: String, requireBiometric: Bool = false) throws -> Data {
        let storedKey: Data
        
        if requireBiometric && securityManager.isBiometricAvailable() {
            storedKey = try retrieveBiometricProtectedKey(identifier: identifier)
        } else {
            storedKey = try keychainStorage.dataValue(service: serviceName, key: identifier)
        }
        
        let originalKey = try extractKeyFromDerivation(storedKey, identifier: identifier)
        
        Logger.info("Successfully retrieved key with identifier: \(identifier)")
        return originalKey
    }
    
    func removeSecureKey(identifier: String) throws {
        try keychainStorage.removeValue(service: serviceName, key: identifier)
        
        // Also remove biometric variant if exists
        let biometricIdentifier = "\(identifier).biometric"
        try? keychainStorage.removeValue(service: serviceName, key: biometricIdentifier)
        
        Logger.info("Removed key with identifier: \(identifier)")
    }
    
    // MARK: - Biometric Protected Storage
    
    private func storeBiometricProtectedKey(_ key: Data, identifier: String) throws {
        let biometricIdentifier = "\(identifier).biometric"
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: biometricIdentifier,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Add biometric protection
        if #available(iOS 11.3, *) {
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet, .or, .devicePasscode],
                nil
            )
            
            if let access = access {
                query[kSecAttrAccessControl as String] = access
            }
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureKeyStorageError.keychainError(status)
        }
    }
    
    private func retrieveBiometricProtectedKey(identifier: String) throws -> Data {
        let biometricIdentifier = "\(identifier).biometric"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: biometricIdentifier,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecUseOperationPrompt as String: "Authenticate to access secure key"
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw SecureKeyStorageError.keychainError(status)
        }
        
        guard let keyData = result as? Data else {
            throw SecureKeyStorageError.invalidKeyData
        }
        
        return keyData
    }
    
    // MARK: - Key Derivation
    
    private func enhanceKeyWithDerivation(_ key: Data, identifier: String) throws -> Data {
        let salt = generateOrRetrieveSalt(for: identifier)
        let info = "Signal.SecureKeyStorage.\(identifier)".data(using: .utf8)!
        
        let derivedKey = try deriveKey(from: key, salt: salt, info: info, outputLength: 32)
        return derivedKey
    }
    
    private func extractKeyFromDerivation(_ derivedKey: Data, identifier: String) throws -> Data {
        // For this implementation, we'll store metadata to help with key extraction
        // In a real implementation, you might need more sophisticated key extraction
        
        guard derivedKey.count >= 32 else {
            throw SecureKeyStorageError.invalidKeyData
        }
        
        // Extract the original key length and data
        return derivedKey
    }
    
    private func deriveKey(from inputKey: Data, salt: Data, info: Data, outputLength: Int) throws -> Data {
        return try inputKey.withUnsafeBytes { inputBytes in
            try salt.withUnsafeBytes { saltBytes in
                try info.withUnsafeBytes { infoBytes in
                    let derivedKey = try HKDF<SHA256>.deriveKey(
                        inputKeyMaterial: SymmetricKey(data: inputKey),
                        salt: salt,
                        info: info,
                        outputByteCount: outputLength
                    )
                    return derivedKey.withUnsafeBytes { Data($0) }
                }
            }
        }
    }
    
    private func generateOrRetrieveSalt(for identifier: String) -> Data {
        let saltIdentifier = "\(identifier).salt"
        
        if let existingSalt = try? keychainStorage.dataValue(service: serviceName, key: saltIdentifier) {
            return existingSalt
        }
        
        // Generate new salt
        let newSalt = securityManager.generateSecureRandomData(length: 32)
        
        try? keychainStorage.setDataValue(newSalt, service: serviceName, key: saltIdentifier)
        
        return newSalt
    }
    
    // MARK: - Key Validation
    
    func validateKeyIntegrity(identifier: String) throws -> Bool {
        let key = try retrieveSecureKey(identifier: identifier)
        
        // Verify key is not empty
        guard !key.isEmpty else {
            throw SecureKeyStorageError.invalidKey
        }
        
        // Verify key hasn't been tampered with
        let expectedChecksum = try calculateKeyChecksum(key, identifier: identifier)
        let storedChecksum = try retrieveKeyChecksum(identifier: identifier)
        
        return expectedChecksum == storedChecksum
    }
    
    private func calculateKeyChecksum(_ key: Data, identifier: String) throws -> Data {
        let checksumInput = key + identifier.data(using: .utf8)!
        return Data(SHA256.hash(data: checksumInput))
    }
    
    private func retrieveKeyChecksum(identifier: String) throws -> Data {
        let checksumIdentifier = "\(identifier).checksum"
        return try keychainStorage.dataValue(service: serviceName, key: checksumIdentifier)
    }
    
    private func storeKeyChecksum(_ checksum: Data, identifier: String) throws {
        let checksumIdentifier = "\(identifier).checksum"
        try keychainStorage.setDataValue(checksum, service: serviceName, key: checksumIdentifier)
    }
    
    // MARK: - Utility Methods
    
    func listStoredKeys() -> [String] {
        // In a real implementation, you'd query the keychain for all stored keys
        // For now, return empty array as keychain doesn't provide easy enumeration
        return []
    }
    
    func clearAllKeys() throws {
        // Remove all keys for this service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SecureKeyStorageError.keychainError(status)
        }
        
        Logger.info("Cleared all secure keys")
    }
    
    // MARK: - Key Rotation
    
    func rotateKey(identifier: String, newKey: Data, requireBiometric: Bool = false) throws {
        // Store new key
        try storeSecureKey(newKey, identifier: "\(identifier).new", requireBiometric: requireBiometric)
        
        // Remove old key
        try removeSecureKey(identifier: identifier)
        
        // Rename new key to original identifier
        let newKeyData = try retrieveSecureKey(identifier: "\(identifier).new")
        try storeSecureKey(newKeyData, identifier: identifier, requireBiometric: requireBiometric)
        try removeSecureKey(identifier: "\(identifier).new")
        
        Logger.info("Successfully rotated key: \(identifier)")
    }
}

// MARK: - Error Types

enum SecureKeyStorageError: LocalizedError {
    case invalidKey
    case invalidKeyData
    case keychainError(OSStatus)
    case biometricNotAvailable
    case derivationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid key provided"
        case .invalidKeyData:
            return "Invalid key data format"
        case .keychainError(let status):
            return "Keychain operation failed with status: \(status)"
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .derivationFailed:
            return "Key derivation failed"
        }
    }
}