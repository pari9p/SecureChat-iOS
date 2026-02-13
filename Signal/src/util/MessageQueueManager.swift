//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Network
import UIKit

/// Message queue manager for handling offline and poor network conditions
final class MessageQueueManager {
    
    // MARK: - Properties
    
    static let shared = MessageQueueManager()
    
    private let messageQueue: DispatchQueue = DispatchQueue(label: "MessageQueueManager", qos: .utility)
    private let fileManager = FileManager.default
    private let networkMonitor = NWPathMonitor()
    
    private var pendingMessages: [QueuedMessage] = []
    private var isOnline = false
    private var retryTimer: Timer?
    
    private let maxRetryAttempts = 5
    private let maxQueueSize = 1000
    private let retryIntervals: [TimeInterval] = [1, 5, 15, 60, 300] // Progressive backoff
    
    // MARK: - Storage
    
    private var queueStorageURL: URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: documentsPath).appendingPathComponent("message_queue.json")
    }
    
    // MARK: - Delegate
    
    weak var delegate: MessageQueueDelegate?
    
    // MARK: - Initialization
    
    init() {
        setupNetworkMonitoring()
        loadPersistedQueue()
        
        // Monitor app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let wasOnline = self?.isOnline ?? false
            self?.isOnline = path.status == .satisfied
            
            if !wasOnline && self?.isOnline == true {
                Logger.info("Network connection restored, processing queued messages")
                self?.processQueuedMessages()
            } else if wasOnline && self?.isOnline == false {
                Logger.info("Network connection lost")
                self?.stopRetryTimer()
            }
        }
        
        networkMonitor.start(queue: messageQueue)
    }
    
    // MARK: - Message Queuing
    
    func queueMessage(
        _ messageData: Data,
        messageType: MessageType,
        recipientId: String,
        priority: MessagePriority = .normal,
        metadata: [String: Any] = [:]
    ) -> String {
        
        let messageId = UUID().uuidString
        let timestamp = Date()
        
        let queuedMessage = QueuedMessage(
            id: messageId,
            data: messageData,
            type: messageType,
            recipientId: recipientId,
            priority: priority,
            timestamp: timestamp,
            metadata: metadata,
            retryAttempts: 0,
            nextRetryTime: timestamp
        )
        
        messageQueue.async {
            self.addToQueue(queuedMessage)
        }
        
        Logger.info("Queued message: \(messageId) for recipient: \(recipientId)")
        
        return messageId
    }
    
    private func addToQueue(_ message: QueuedMessage) {
        // Check queue size limit
        if pendingMessages.count >= maxQueueSize {
            // Remove oldest low-priority messages
            removeOldestLowPriorityMessages()
        }
        
        // Insert based on priority
        insertMessageByPriority(message)
        
        // Persist queue
        persistQueue()
        
        // Try to send immediately if online
        if isOnline {
            processSingleMessage(message)
        } else {
            delegate?.messageWasQueued(messageId: message.id, reason: .networkUnavailable)
        }
    }
    
    private func insertMessageByPriority(_ message: QueuedMessage) {
        let insertIndex = pendingMessages.firstIndex { $0.priority.rawValue < message.priority.rawValue } ?? pendingMessages.count
        pendingMessages.insert(message, at: insertIndex)
    }
    
    private func removeOldestLowPriorityMessages() {
        // Remove oldest messages with normal or low priority
        pendingMessages = pendingMessages.filter { message in
            return message.priority == .high || message.priority == .critical
        }
        
        // If still over limit, remove oldest normal priority messages
        while pendingMessages.count >= maxQueueSize && pendingMessages.contains(where: { $0.priority == .normal }) {
            if let index = pendingMessages.firstIndex(where: { $0.priority == .normal }) {
                let removedMessage = pendingMessages.remove(at: index)
                delegate?.messageWasDropped(messageId: removedMessage.id, reason: .queueFull)
            }
        }
    }
    
    // MARK: - Message Processing
    
    func processQueuedMessages() {
        messageQueue.async {
            guard self.isOnline else { return }
            
            Logger.info("Processing \(self.pendingMessages.count) queued messages")
            
            let currentTime = Date()
            let messagesToProcess = self.pendingMessages.filter { $0.nextRetryTime <= currentTime }
            
            for message in messagesToProcess {
                self.processSingleMessage(message)
            }
            
            if !self.pendingMessages.isEmpty {
                self.scheduleRetryTimer()
            }
        }
    }
    
    private func processSingleMessage(_ message: QueuedMessage) {
        Task {
            let result = await sendMessage(message)
            
            await MainActor.run {
                self.handleMessageResult(message, result: result)
            }
        }
    }
    
    private func sendMessage(_ message: QueuedMessage) async -> MessageSendResult {
        do {
            // Simulate message sending with different outcomes based on conditions
            let success = await simulateMessageSending(message)
            
            if success {
                return .success
            } else {
                return .failure(.temporaryError)
            }
            
        } catch {
            return .failure(.permanentError)
        }
    }
    
    private func simulateMessageSending(_ message: QueuedMessage) async -> Bool {
        // Simulate network delay
        let delay = UInt64(Double.random(in: 0.5...3.0) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
        
        // Simulate success rate based on network conditions
        let successRate: Double = isOnline ? 0.85 : 0.1
        
        return Double.random(in: 0...1) < successRate
    }
    
    private func handleMessageResult(_ message: QueuedMessage, result: MessageSendResult) {
        messageQueue.async {
            switch result {
            case .success:
                self.removeMessageFromQueue(message.id)
                self.delegate?.messageWasSent(messageId: message.id)
                Logger.info("Message sent successfully: \(message.id)")
                
            case .failure(let error):
                self.handleMessageFailure(message, error: error)
            }
            
            self.persistQueue()
        }
    }
    
    private func handleMessageFailure(_ message: QueuedMessage, error: MessageSendError) {
        guard var updatedMessage = pendingMessages.first(where: { $0.id == message.id }) else {
            return
        }
        
        updatedMessage.retryAttempts += 1
        
        switch error {
        case .temporaryError:
            if updatedMessage.retryAttempts < maxRetryAttempts {
                // Schedule retry with exponential backoff
                let retryInterval = retryIntervals[min(updatedMessage.retryAttempts - 1, retryIntervals.count - 1)]
                updatedMessage.nextRetryTime = Date().addingTimeInterval(retryInterval)
                
                // Update message in queue
                if let index = pendingMessages.firstIndex(where: { $0.id == message.id }) {
                    pendingMessages[index] = updatedMessage
                }
                
                Logger.info("Message retry scheduled: \(message.id), attempt: \(updatedMessage.retryAttempts)")
                delegate?.messageRetryScheduled(messageId: message.id, attempt: updatedMessage.retryAttempts)
                
                scheduleRetryTimer()
                
            } else {
                removeMessageFromQueue(message.id)
                delegate?.messageFailed(messageId: message.id, error: .maxRetriesExceeded)
                Logger.error("Message failed after max retries: \(message.id)")
            }
            
        case .permanentError:
            removeMessageFromQueue(message.id)
            delegate?.messageFailed(messageId: message.id, error: .permanentFailure)
            Logger.error("Message failed permanently: \(message.id)")
        }
    }
    
    // MARK: - Queue Management
    
    private func removeMessageFromQueue(_ messageId: String) {
        pendingMessages.removeAll { $0.id == messageId }
    }
    
    func cancelMessage(_ messageId: String) -> Bool {
        messageQueue.sync {
            let wasRemoved = pendingMessages.removeAll { $0.id == messageId }.count > 0
            
            if wasRemoved {
                persistQueue()
                delegate?.messageWasCancelled(messageId: messageId)
                Logger.info("Message cancelled: \(messageId)")
            }
            
            return wasRemoved
        }
    }
    
    func clearQueue() {
        messageQueue.async {
            let cancelledCount = self.pendingMessages.count
            self.pendingMessages.removeAll()
            self.persistQueue()
            self.stopRetryTimer()
            
            Logger.info("Cleared \(cancelledCount) messages from queue")
            self.delegate?.queueWasCleared(messageCount: cancelledCount)
        }
    }
    
    func getQueueStatus() -> QueueStatus {
        return messageQueue.sync {
            let statusByPriority = Dictionary(grouping: pendingMessages) { $0.priority }
            
            return QueueStatus(
                totalMessages: pendingMessages.count,
                highPriorityCount: statusByPriority[.high]?.count ?? 0,
                normalPriorityCount: statusByPriority[.normal]?.count ?? 0,
                lowPriorityCount: statusByPriority[.low]?.count ?? 0,
                criticalPriorityCount: statusByPriority[.critical]?.count ?? 0,
                oldestMessageTimestamp: pendingMessages.first?.timestamp,
                isOnline: isOnline
            )
        }
    }
    
    // MARK: - Retry Management
    
    private func scheduleRetryTimer() {
        stopRetryTimer()
        
        let nextRetryTime = pendingMessages.compactMap { $0.nextRetryTime }.min()
        
        guard let nextRetry = nextRetryTime else { return }
        
        let timeUntilRetry = max(1.0, nextRetry.timeIntervalSinceNow)
        
        DispatchQueue.main.async {
            self.retryTimer = Timer.scheduledTimer(withTimeInterval: timeUntilRetry, repeats: false) { _ in
                self.processQueuedMessages()
            }
        }
    }
    
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    // MARK: - Persistence
    
    private func persistQueue() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(pendingMessages)
            try data.write(to: queueStorageURL)
        } catch {
            Logger.error("Failed to persist message queue: \(error)")
        }
    }
    
    private func loadPersistedQueue() {
        do {
            let data = try Data(contentsOf: queueStorageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            pendingMessages = try decoder.decode([QueuedMessage].self, from: data)
            
            Logger.info("Loaded \(pendingMessages.count) messages from persistent queue")
            
            // Clean up expired messages
            cleanupExpiredMessages()
            
        } catch {
            Logger.info("No persisted queue found or failed to load: \(error)")
            pendingMessages = []
        }
    }
    
    private func cleanupExpiredMessages() {
        let expirationTime = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours
        let initialCount = pendingMessages.count
        
        pendingMessages = pendingMessages.filter { message in
            if message.timestamp < expirationTime {
                delegate?.messageFailed(messageId: message.id, error: .expired)
                return false
            }
            return true
        }
        
        let removedCount = initialCount - pendingMessages.count
        if removedCount > 0 {
            Logger.info("Removed \(removedCount) expired messages from queue")
            persistQueue()
        }
    }
    
    // MARK: - App Lifecycle
    
    @objc private func appWillResignActive() {
        persistQueue()
    }
    
    @objc private func appDidBecomeActive() {
        if isOnline && !pendingMessages.isEmpty {
            processQueuedMessages()
        }
    }
    
    // MARK: - Debug Support
    
    func exportQueueForDebug() -> [String: Any] {
        return messageQueue.sync {
            return [
                "totalMessages": pendingMessages.count,
                "isOnline": isOnline,
                "messages": pendingMessages.map { message in
                    [
                        "id": message.id,
                        "type": message.type.rawValue,
                        "recipientId": message.recipientId,
                        "priority": message.priority.rawValue,
                        "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
                        "retryAttempts": message.retryAttempts,
                        "nextRetryTime": ISO8601DateFormatter().string(from: message.nextRetryTime)
                    ]
                }
            ]
        }
    }
}

// MARK: - Supporting Types

struct QueuedMessage: Codable {
    let id: String
    let data: Data
    let type: MessageType
    let recipientId: String
    let priority: MessagePriority
    let timestamp: Date
    let metadata: [String: String] // Simplified for Codable
    var retryAttempts: Int
    var nextRetryTime: Date
    
    init(id: String, data: Data, type: MessageType, recipientId: String, priority: MessagePriority, timestamp: Date, metadata: [String: Any], retryAttempts: Int, nextRetryTime: Date) {
        self.id = id
        self.data = data
        self.type = type
        self.recipientId = recipientId
        self.priority = priority
        self.timestamp = timestamp
        self.retryAttempts = retryAttempts
        self.nextRetryTime = nextRetryTime
        
        // Convert Any to String for Codable compliance
        self.metadata = metadata.compactMapValues { "\($0)" }
    }
}

enum MessageType: String, Codable {
    case text = "text"
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    case location = "location"
    case reaction = "reaction"
    case readReceipt = "readReceipt"
    case typing = "typing"
}

enum MessagePriority: Int, Codable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
}

enum MessageSendResult {
    case success
    case failure(MessageSendError)
}

enum MessageSendError {
    case temporaryError
    case permanentError
}

enum QueueFailureReason {
    case networkUnavailable
    case queueFull
    case maxRetriesExceeded
    case permanentFailure
    case expired
}

struct QueueStatus {
    let totalMessages: Int
    let highPriorityCount: Int
    let normalPriorityCount: Int
    let lowPriorityCount: Int
    let criticalPriorityCount: Int
    let oldestMessageTimestamp: Date?
    let isOnline: Bool
    
    var formattedOldestMessage: String? {
        guard let timestamp = oldestMessageTimestamp else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Delegate Protocol

protocol MessageQueueDelegate: AnyObject {
    func messageWasQueued(messageId: String, reason: QueueFailureReason)
    func messageWasSent(messageId: String)
    func messageWasCancelled(messageId: String)
    func messageWasDropped(messageId: String, reason: QueueFailureReason)
    func messageFailed(messageId: String, error: QueueFailureReason)
    func messageRetryScheduled(messageId: String, attempt: Int)
    func queueWasCleared(messageCount: Int)
}