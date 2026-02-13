//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Contacts
import UIKit

/// Contact synchronization manager for discovering Signal users
final class ContactSynchronizationManager {
    
    // MARK: - Properties
    
    static let shared = ContactSynchronizationManager()
    
    private let contactStore = CNContactStore()
    private let syncQueue = DispatchQueue(label: "ContactSynchronization", qos: .userInitiated)
    private let securityManager = SecurityManager.shared
    
    private var lastSyncDate: Date?
    private var isCurrentlySyncing = false
    private var syncProgress: SyncProgress = SyncProgress()
    
    // MARK: - Sync Configuration
    
    private struct SyncConfiguration {
        let batchSize: Int = 500
        let maxRetryAttempts: Int = 3
        let syncInterval: TimeInterval = 24 * 60 * 60 // 24 hours
        let hashSaltRotationInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    }
    
    private let config = SyncConfiguration()
    
    // MARK: - Sync Progress
    
    struct SyncProgress {
        var totalContacts: Int = 0
        var processedContacts: Int = 0
        var discoveredSignalUsers: Int = 0
        var errors: Int = 0
        
        var progressPercentage: Double {
            guard totalContacts > 0 else { return 0 }
            return Double(processedContacts) / Double(totalContacts) * 100
        }
    }
    
    // MARK: - Delegate
    
    weak var delegate: ContactSyncDelegate?
    
    // MARK: - Permission Management
    
    func requestContactsPermission() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                contactStore.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }
    
    func checkContactsPermission() -> Bool {
        return CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    // MARK: - Main Sync Methods
    
    func performContactSync() async -> ContactSyncResult {
        // Check if sync is needed
        guard shouldPerformSync() else {
            return .success(cached: true)
        }
        
        // Check permission
        guard await requestContactsPermission() else {
            return .failure(.permissionDenied)
        }
        
        // Prevent concurrent syncs
        guard !isCurrentlySyncing else {
            return .failure(.syncInProgress)
        }
        
        isCurrentlySyncing = true
        defer { isCurrentlySyncing = false }
        
        do {
            Logger.info("Starting contact synchronization")
            delegate?.contactSyncDidStart()
            
            let result = await performFullSync()
            
            if case .success = result {
                lastSyncDate = Date()
                saveLastSyncDate()
            }
            
            return result
            
        } catch {
            Logger.error("Contact sync failed: \(error)")
            return .failure(.syncFailed(error))
        }
    }
    
    private func performFullSync() async -> ContactSyncResult {
        do {
            // Fetch all contacts
            let allContacts = try fetchAllContacts()
            
            syncProgress = SyncProgress()
            syncProgress.totalContacts = allContacts.count
            
            delegate?.contactSyncDidUpdateProgress(syncProgress)
            
            // Process contacts in batches
            var discoveredUsers: [SignalUser] = []
            
            for batch in allContacts.chunked(into: config.batchSize) {
                let batchResult = await processBatch(batch)
                
                switch batchResult {
                case .success(let users):
                    discoveredUsers.append(contentsOf: users)
                    syncProgress.processedContacts += batch.count
                    syncProgress.discoveredSignalUsers = discoveredUsers.count
                    
                case .failure:
                    syncProgress.errors += 1
                }
                
                delegate?.contactSyncDidUpdateProgress(syncProgress)
            }
            
            // Save discovered users
            try await saveDiscoveredUsers(discoveredUsers)
            
            Logger.info("Contact sync completed. Discovered \(discoveredUsers.count) Signal users")
            delegate?.contactSyncDidComplete(discoveredUserCount: discoveredUsers.count)
            
            return .success(cached: false)
            
        } catch {
            delegate?.contactSyncDidFail(error: error)
            return .failure(.syncFailed(error))
        }
    }
    
    // MARK: - Contact Fetching
    
    private func fetchAllContacts() throws -> [CNContact] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [CNContact] = []
        
        try contactStore.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        
        return contacts
    }
    
    // MARK: - Batch Processing
    
    private func processBatch(_ contacts: [CNContact]) async -> BatchProcessingResult {
        do {
            // Extract identifiers from contacts
            let identifiers = extractContactIdentifiers(from: contacts)
            
            // Hash identifiers for privacy
            let hashedIdentifiers = await hashIdentifiers(identifiers)
            
            // Check with server
            let signalUsers = try await checkIdentifiersWithServer(hashedIdentifiers, originalIdentifiers: identifiers)
            
            return .success(signalUsers)
            
        } catch {
            Logger.error("Batch processing failed: \(error)")
            return .failure(error)
        }
    }
    
    private func extractContactIdentifiers(from contacts: [CNContact]) -> [ContactIdentifier] {
        var identifiers: [ContactIdentifier] = []
        
        for contact in contacts {
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            
            // Extract phone numbers
            for phoneNumber in contact.phoneNumbers {
                let normalizedNumber = normalizePhoneNumber(phoneNumber.value.stringValue)
                if !normalizedNumber.isEmpty {
                    identifiers.append(ContactIdentifier(
                        type: .phoneNumber,
                        value: normalizedNumber,
                        contactId: contact.identifier,
                        displayName: fullName
                    ))
                }
            }
            
            // Extract email addresses
            for email in contact.emailAddresses {
                let normalizedEmail = email.value.lowercased
                identifiers.append(ContactIdentifier(
                    type: .email,
                    value: normalizedEmail,
                    contactId: contact.identifier,
                    displayName: fullName
                ))
            }
        }
        
        return identifiers
    }
    
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-numeric characters
        let numericOnly = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Add country code if missing (assuming US +1 for demo)
        if numericOnly.hasPrefix("1") && numericOnly.count == 11 {
            return "+\(numericOnly)"
        } else if numericOnly.count == 10 {
            return "+1\(numericOnly)"
        }
        
        return "+\(numericOnly)"
    }
    
    // MARK: - Privacy-Preserving Hashing
    
    private func hashIdentifiers(_ identifiers: [ContactIdentifier]) async -> [HashedIdentifier] {
        return await withTaskGroup(of: HashedIdentifier?.self) { group in
            for identifier in identifiers {
                group.addTask {
                    return await self.hashSingleIdentifier(identifier)
                }
            }
            
            var hashedIdentifiers: [HashedIdentifier] = []
            for await hashedIdentifier in group {
                if let hashed = hashedIdentifier {
                    hashedIdentifiers.append(hashed)
                }
            }
            
            return hashedIdentifiers
        }
    }
    
    private func hashSingleIdentifier(_ identifier: ContactIdentifier) async -> HashedIdentifier? {
        do {
            // Get current salt (rotated periodically for privacy)
            let salt = getCurrentHashSalt()
            
            // Combine identifier with salt
            let saltedIdentifier = "\(identifier.value):\(salt)"
            let data = saltedIdentifier.data(using: .utf8)!
            
            // Generate secure hash
            let hash = securityManager.generateSecureHMAC(data: data, key: getHashingKey())
            
            return HashedIdentifier(
                hash: hash.base64EncodedString(),
                type: identifier.type,
                originalIdentifier: identifier
            )
            
        } catch {
            Logger.error("Failed to hash identifier: \(error)")
            return nil
        }
    }
    
    private func getCurrentHashSalt() -> String {
        let currentTime = Date().timeIntervalSince1970
        let saltPeriod = floor(currentTime / config.hashSaltRotationInterval)
        return "signal_salt_\(Int(saltPeriod))"
    }
    
    private func getHashingKey() -> Data {
        // In production, this would be a securely derived key
        return "signal_contact_hashing_key".data(using: .utf8)!
    }
    
    // MARK: - Server Communication
    
    private func checkIdentifiersWithServer(_ hashedIdentifiers: [HashedIdentifier], originalIdentifiers: [ContactIdentifier]) async throws -> [SignalUser] {
        // This would normally make an encrypted request to Signal's servers
        // For demo purposes, we simulate server response
        
        let mockSignalUsers = simulateServerResponse(for: hashedIdentifiers, originalIdentifiers: originalIdentifiers)
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return mockSignalUsers
    }
    
    private func simulateServerResponse(for hashedIdentifiers: [HashedIdentifier], originalIdentifiers: [ContactIdentifier]) -> [SignalUser] {
        // Simulate finding some Signal users (for demo)
        var signalUsers: [SignalUser] = []
        
        for (index, identifier) in originalIdentifiers.enumerated() {
            // Simulate 20% of contacts being Signal users
            if index % 5 == 0 {
                signalUsers.append(SignalUser(
                    signalId: UUID().uuidString,
                    phoneNumber: identifier.type == .phoneNumber ? identifier.value : nil,
                    email: identifier.type == .email ? identifier.value : nil,
                    displayName: identifier.displayName,
                    profilePicture: nil,
                    isRegistered: true,
                    lastSeen: Date().addingTimeInterval(-Double.random(in: 0...86400))
                ))
            }
        }
        
        return signalUsers
    }
    
    // MARK: - Data Persistence
    
    private func saveDiscoveredUsers(_ users: [SignalUser]) async throws {
        // Save to local database
        // This would normally integrate with your database layer
        
        let userData = try JSONEncoder().encode(users)
        UserDefaults.standard.set(userData, forKey: "DiscoveredSignalUsers")
        
        Logger.info("Saved \(users.count) discovered Signal users")
    }
    
    func loadDiscoveredUsers() -> [SignalUser] {
        guard let userData = UserDefaults.standard.data(forKey: "DiscoveredSignalUsers"),
              let users = try? JSONDecoder().decode([SignalUser].self, from: userData) else {
            return []
        }
        
        return users
    }
    
    // MARK: - Sync Management
    
    private func shouldPerformSync() -> Bool {
        guard let lastSync = lastSyncDate else {
            return true // Never synced before
        }
        
        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        return timeSinceLastSync >= config.syncInterval
    }
    
    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "LastContactSyncDate")
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "LastContactSyncDate") as? Date
    }
    
    // MARK: - Manual Operations
    
    func addContact(_ phoneNumber: String) async -> ContactAddResult {
        guard await requestContactsPermission() else {
            return .failure(.permissionDenied)
        }
        
        let normalizedNumber = normalizePhoneNumber(phoneNumber)
        
        // Check if user is on Signal
        let identifier = ContactIdentifier(
            type: .phoneNumber,
            value: normalizedNumber,
            contactId: "",
            displayName: ""
        )
        
        let hashedIdentifier = await hashSingleIdentifier(identifier)
        
        guard let hashed = hashedIdentifier else {
            return .failure(.processingFailed)
        }
        
        do {
            let signalUsers = try await checkIdentifiersWithServer([hashed], originalIdentifiers: [identifier])
            
            if let signalUser = signalUsers.first {
                return .success(signalUser)
            } else {
                return .failure(.userNotFound)
            }
            
        } catch {
            return .failure(.networkError(error))
        }
    }
    
    func inviteContact(_ phoneNumber: String) async -> InviteResult {
        // Send invitation SMS or email
        let normalizedNumber = normalizePhoneNumber(phoneNumber)
        
        // This would integrate with your invitation system
        Logger.info("Sending invitation to: \(normalizedNumber)")
        
        return .success
    }
    
    // MARK: - Privacy Management
    
    func clearContactData() {
        UserDefaults.standard.removeObject(forKey: "DiscoveredSignalUsers")
        UserDefaults.standard.removeObject(forKey: "LastContactSyncDate")
        
        lastSyncDate = nil
        
        Logger.info("Cleared all contact synchronization data")
    }
    
    func getPrivacyInfo() -> ContactPrivacyInfo {
        return ContactPrivacyInfo(
            lastSyncDate: lastSyncDate,
            contactCount: syncProgress.totalContacts,
            signalUserCount: syncProgress.discoveredSignalUsers,
            hashSaltRotationInterval: config.hashSaltRotationInterval
        )
    }
}

// MARK: - Supporting Types

enum ContactIdentifierType {
    case phoneNumber
    case email
}

struct ContactIdentifier {
    let type: ContactIdentifierType
    let value: String
    let contactId: String
    let displayName: String
}

struct HashedIdentifier {
    let hash: String
    let type: ContactIdentifierType
    let originalIdentifier: ContactIdentifier
}

struct SignalUser: Codable {
    let signalId: String
    let phoneNumber: String?
    let email: String?
    let displayName: String
    let profilePicture: String? // URL or base64
    let isRegistered: Bool
    let lastSeen: Date
    
    var formattedLastSeen: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSeen, relativeTo: Date())
    }
}

enum ContactSyncResult {
    case success(cached: Bool)
    case failure(ContactSyncError)
}

enum BatchProcessingResult {
    case success([SignalUser])
    case failure(Error)
}

enum ContactAddResult {
    case success(SignalUser)
    case failure(ContactAddError)
}

enum InviteResult {
    case success
    case failure(InviteError)
}

enum ContactSyncError: LocalizedError {
    case permissionDenied
    case syncInProgress
    case syncFailed(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Contacts permission denied"
        case .syncInProgress:
            return "Contact sync already in progress"
        case .syncFailed(let error):
            return "Contact sync failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

enum ContactAddError: LocalizedError {
    case permissionDenied
    case userNotFound
    case processingFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Contacts permission denied"
        case .userNotFound:
            return "User not found on Signal"
        case .processingFailed:
            return "Failed to process contact"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

enum InviteError: LocalizedError {
    case sendingFailed
    case invalidContact
    
    var errorDescription: String? {
        switch self {
        case .sendingFailed:
            return "Failed to send invitation"
        case .invalidContact:
            return "Invalid contact information"
        }
    }
}

struct ContactPrivacyInfo {
    let lastSyncDate: Date?
    let contactCount: Int
    let signalUserCount: Int
    let hashSaltRotationInterval: TimeInterval
    
    var formattedLastSync: String {
        guard let lastSyncDate = lastSyncDate else {
            return "Never"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastSyncDate)
    }
}

// MARK: - Delegate Protocol

protocol ContactSyncDelegate: AnyObject {
    func contactSyncDidStart()
    func contactSyncDidUpdateProgress(_ progress: ContactSynchronizationManager.SyncProgress)
    func contactSyncDidComplete(discoveredUserCount: Int)
    func contactSyncDidFail(error: Error)
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}