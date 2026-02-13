//
// OfflineMessageQueue.swift
// SecureChat
//
// Created by SecureChat Team on 2/12/2026.
// Copyright 2025 SecureChat Development Team
//

import Foundation
import Network
import Combine

public struct QueuedMessage: Codable {
    let id: String
    let recipientId: String
    let content: String
    let timestamp: Date
    let messageType: MessageType
    let priority: Priority
    
    enum MessageType: String, Codable {
        case text
        case media
        case document
        case voice
    }
    
    enum Priority: Int, Codable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
    }
}

@objc
public class OfflineMessageQueue: NSObject {
    
    public static let shared = OfflineMessageQueue()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.securechat.offline-queue")
    
    @Published public private(set) var isOnline = false
    @Published public private(set) var queuedMessageCount = 0
    @Published public private(set) var isSyncing = false
    
    private var messageQueue: [QueuedMessage] = []
    private let maxQueueSize = 1000
    private let storageKey = "SecureChat.OfflineMessageQueue"
    
    public override init() {
        super.init()
        setupNetworkMonitoring()
        loadQueuedMessages()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                // If we just came online, process the queue
                if !wasOnline && self?.isOnline == true {
                    self?.processQueuedMessages()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - Queue Management
    
    public func queueMessage(
        recipientId: String,
        content: String,
        type: QueuedMessage.MessageType,
        priority: QueuedMessage.Priority = .normal
    ) {
        let message = QueuedMessage(
            id: UUID().uuidString,
            recipientId: recipientId,
            content: content,
            timestamp: Date(),
            messageType: type,
            priority: priority
        )
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check queue size limit
            if self.messageQueue.count >= self.maxQueueSize {
                // Remove oldest low-priority message
                if let oldestIndex = self.messageQueue.firstIndex(where: { $0.priority == .low }) {
                    self.messageQueue.remove(at: oldestIndex)
                } else {
                    self.messageQueue.removeFirst()
                }
            }
            
            // Insert message in priority order
            let insertIndex = self.messageQueue.firstIndex { $0.priority.rawValue < message.priority.rawValue } ?? self.messageQueue.count
            self.messageQueue.insert(message, at: insertIndex)
            
            self.saveQueuedMessages()
            
            DispatchQueue.main.async {
                self.queuedMessageCount = self.messageQueue.count
                
                // If online, immediately try to send
                if self.isOnline {
                    self.processQueuedMessages()
                }
            }
        }
    }
    
    // MARK: - Message Processing
    
    private func processQueuedMessages() {
        guard isOnline && !isSyncing else { return }
        
        isSyncing = true
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let messagesToProcess = Array(self.messageQueue.prefix(10)) // Process in batches
            
            for message in messagesToProcess {
                self.sendMessage(message) { [weak self] success in
                    if success {
                        self?.removeMessageFromQueue(message.id)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
    }
    
    private func sendMessage(_ message: QueuedMessage, completion: @escaping (Bool) -> Void) {
        // Simulate network request - replace with actual implementation
        let delay = Double.random(in: 0.5...2.0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            // Simulate 90% success rate
            let success = Double.random(in: 0...1) < 0.9
            completion(success)
        }
    }
    
    private func removeMessageFromQueue(_ messageId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.messageQueue.removeAll { $0.id == messageId }
            self.saveQueuedMessages()
            
            DispatchQueue.main.async {
                self.queuedMessageCount = self.messageQueue.count
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveQueuedMessages() {
        do {
            let data = try JSONEncoder().encode(messageQueue)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save queued messages: \(error)")
        }
    }
    
    private func loadQueuedMessages() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        do {
            messageQueue = try JSONDecoder().decode([QueuedMessage].self, from: data)
            queuedMessageCount = messageQueue.count
        } catch {
            print("Failed to load queued messages: \(error)")
            messageQueue = []
        }
    }
    
    // MARK: - Public Interface
    
    public func retryFailedMessages() {
        guard isOnline else { return }
        processQueuedMessages()
    }
    
    public func clearQueue() {
        queue.async { [weak self] in
            self?.messageQueue.removeAll()
            self?.saveQueuedMessages()
            
            DispatchQueue.main.async {
                self?.queuedMessageCount = 0
            }
        }
    }
    
    public func getQueueStatus() -> (count: Int, oldestMessage: Date?) {
        return (messageQueue.count, messageQueue.first?.timestamp)
    }
}