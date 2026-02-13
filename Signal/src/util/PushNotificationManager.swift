//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import UserNotifications
import UIKit

/// Centralized push notification manager for Signal iOS
final class PushNotificationManager: NSObject {
    
    // MARK: - Properties
    
    static let shared = PushNotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var pendingActions: [String: NotificationAction] = [:]
    private let queue = DispatchQueue(label: "PushNotificationManager", qos: .userInitiated)
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotificationCenter()
    }
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
        registerNotificationCategories()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge, .provisional, .criticalAlert]
            )
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                Logger.info("Push notification permission granted")
            } else {
                Logger.warn("Push notification permission denied")
            }
            
            return granted
        } catch {
            Logger.error("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func checkNotificationSettings() async -> UNNotificationSettings {
        return await notificationCenter.getNotificationSettings()
    }
    
    // MARK: - Notification Categories
    
    private func registerNotificationCategories() {
        let messageCategory = createMessageCategory()
        let callCategory = createCallCategory()
        let groupCategory = createGroupMessageCategory()
        
        notificationCenter.setNotificationCategories([
            messageCategory,
            callCategory,
            groupCategory
        ])
    }
    
    private func createMessageCategory() -> UNNotificationCategory {
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [.authenticationRequired],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )
        
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Mark as Read",
            options: [.authenticationRequired]
        )
        
        return UNNotificationCategory(
            identifier: "MESSAGE_CATEGORY",
            actions: [replyAction, markReadAction],
            intentIdentifiers: ["INSendMessageIntent"],
            options: [.customDismissAction]
        )
    }
    
    private func createCallCategory() -> UNNotificationCategory {
        let answerAction = UNNotificationAction(
            identifier: "ANSWER_CALL_ACTION",
            title: "Answer",
            options: [.foreground, .authenticationRequired]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_CALL_ACTION",
            title: "Decline",
            options: [.destructive]
        )
        
        return UNNotificationCategory(
            identifier: "CALL_CATEGORY",
            actions: [answerAction, declineAction],
            intentIdentifiers: ["INStartCallIntent"],
            options: [.customDismissAction]
        )
    }
    
    private func createGroupMessageCategory() -> UNNotificationCategory {
        let replyAction = UNTextInputNotificationAction(
            identifier: "GROUP_REPLY_ACTION",
            title: "Reply",
            options: [.authenticationRequired],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Reply to group..."
        )
        
        let muteAction = UNNotificationAction(
            identifier: "MUTE_GROUP_ACTION",
            title: "Mute",
            options: []
        )
        
        return UNNotificationCategory(
            identifier: "GROUP_MESSAGE_CATEGORY",
            actions: [replyAction, muteAction],
            intentIdentifiers: ["INSendMessageIntent"],
            options: [.customDismissAction]
        )
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        userInfo: [String: Any] = [:],
        categoryIdentifier: String? = nil,
        sound: UNNotificationSound? = .default
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        content.sound = sound
        
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                Logger.error("Failed to schedule notification: \(error)")
            } else {
                Logger.info("Scheduled local notification: \(identifier)")
            }
        }
    }
    
    // MARK: - Message Notifications
    
    func showMessageNotification(
        from senderName: String,
        messagePreview: String,
        threadId: String,
        isGroup: Bool = false
    ) {
        let content = UNMutableNotificationContent()
        
        if isGroup {
            content.title = "New Group Message"
            content.body = "\(senderName): \(messagePreview)"
            content.categoryIdentifier = "GROUP_MESSAGE_CATEGORY"
        } else {
            content.title = senderName
            content.body = messagePreview
            content.categoryIdentifier = "MESSAGE_CATEGORY"
        }
        
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        content.userInfo = [
            "threadId": threadId,
            "type": "message",
            "isGroup": isGroup
        ]
        
        let identifier = "message-\(threadId)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                Logger.error("Failed to show message notification: \(error)")
            }
        }
    }
    
    // MARK: - Call Notifications
    
    func showCallNotification(from callerName: String, callId: String, isVideo: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = isVideo ? "Incoming Video Call" : "Incoming Call"
        content.body = "from \(callerName)"
        content.categoryIdentifier = "CALL_CATEGORY"
        content.sound = .default
        
        content.userInfo = [
            "callId": callId,
            "type": "call",
            "callerName": callerName,
            "isVideo": isVideo
        ]
        
        let identifier = "call-\(callId)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                Logger.error("Failed to show call notification: \(error)")
            }
        }
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Notification Cleanup
    
    func removeNotifications(with identifiers: [String]) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func removeNotificationsForThread(_ threadId: String) {
        queue.async {
            self.notificationCenter.getDeliveredNotifications { notifications in
                let identifiersToRemove = notifications
                    .filter { notification in
                        if let threadIdFromNotification = notification.request.content.userInfo["threadId"] as? String {
                            return threadIdFromNotification == threadId
                        }
                        return false
                    }
                    .map(\.request.identifier)
                
                if !identifiersToRemove.isEmpty {
                    self.removeNotifications(with: identifiersToRemove)
                }
            }
        }
    }
    
    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
        clearBadge()
    }
    
    // MARK: - Privacy Protection
    
    func shouldShowNotificationPreview() -> Bool {
        // Check user's privacy settings
        // This would normally check against stored user preferences
        return true // Placeholder
    }
    
    func createPrivacyProtectedNotification(senderName: String) -> (title: String, body: String) {
        if shouldShowNotificationPreview() {
            return (senderName, "New Message")
        } else {
            return ("Signal", "New Message")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground for messages
        let userInfo = notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String {
            switch type {
            case "message":
                completionHandler([.banner, .sound, .badge])
            case "call":
                completionHandler([.banner, .sound])
            default:
                completionHandler([.banner, .sound])
            }
        } else {
            completionHandler([.banner, .sound])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "REPLY_ACTION", "GROUP_REPLY_ACTION":
            handleReplyAction(response: response, userInfo: userInfo)
            
        case "MARK_READ_ACTION":
            handleMarkReadAction(userInfo: userInfo)
            
        case "ANSWER_CALL_ACTION":
            handleAnswerCallAction(userInfo: userInfo)
            
        case "DECLINE_CALL_ACTION":
            handleDeclineCallAction(userInfo: userInfo)
            
        case "MUTE_GROUP_ACTION":
            handleMuteGroupAction(userInfo: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(userInfo: userInfo)
            
        default:
            Logger.info("Unhandled notification action: \(actionIdentifier)")
        }
        
        completionHandler()
    }
    
    // MARK: - Action Handlers
    
    private func handleReplyAction(response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        guard let textResponse = response as? UNTextInputNotificationResponse,
              let threadId = userInfo["threadId"] as? String else {
            return
        }
        
        let messageText = textResponse.userText
        Logger.info("Quick reply in thread \(threadId): \(messageText)")
        
        // Here you would send the message through your message sending pipeline
        NotificationCenter.default.post(
            name: .quickReplyMessage,
            object: nil,
            userInfo: [
                "threadId": threadId,
                "messageText": messageText
            ]
        )
    }
    
    private func handleMarkReadAction(userInfo: [AnyHashable: Any]) {
        guard let threadId = userInfo["threadId"] as? String else { return }
        
        Logger.info("Marking thread as read: \(threadId)")
        
        NotificationCenter.default.post(
            name: .markThreadAsRead,
            object: nil,
            userInfo: ["threadId": threadId]
        )
        
        removeNotificationsForThread(threadId)
    }
    
    private func handleAnswerCallAction(userInfo: [AnyHashable: Any]) {
        guard let callId = userInfo["callId"] as? String else { return }
        
        Logger.info("Answering call: \(callId)")
        
        NotificationCenter.default.post(
            name: .answerCall,
            object: nil,
            userInfo: ["callId": callId]
        )
    }
    
    private func handleDeclineCallAction(userInfo: [AnyHashable: Any]) {
        guard let callId = userInfo["callId"] as? String else { return }
        
        Logger.info("Declining call: \(callId)")
        
        NotificationCenter.default.post(
            name: .declineCall,
            object: nil,
            userInfo: ["callId": callId]
        )
    }
    
    private func handleMuteGroupAction(userInfo: [AnyHashable: Any]) {
        guard let threadId = userInfo["threadId"] as? String else { return }
        
        Logger.info("Muting group: \(threadId)")
        
        NotificationCenter.default.post(
            name: .muteThread,
            object: nil,
            userInfo: ["threadId": threadId]
        )
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        // Open the app to the relevant conversation or screen
        
        if let threadId = userInfo["threadId"] as? String {
            NotificationCenter.default.post(
                name: .openThread,
                object: nil,
                userInfo: ["threadId": threadId]
            )
        } else if let callId = userInfo["callId"] as? String {
            NotificationCenter.default.post(
                name: .openCall,
                object: nil,
                userInfo: ["callId": callId]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let quickReplyMessage = Notification.Name("quickReplyMessage")
    static let markThreadAsRead = Notification.Name("markThreadAsRead")
    static let answerCall = Notification.Name("answerCall")
    static let declineCall = Notification.Name("declineCall")
    static let muteThread = Notification.Name("muteThread")
    static let openThread = Notification.Name("openThread")
    static let openCall = Notification.Name("openCall")
}

// MARK: - Supporting Types

enum NotificationAction {
    case reply(threadId: String, message: String)
    case markRead(threadId: String)
    case answerCall(callId: String)
    case declineCall(callId: String)
    case muteGroup(threadId: String)
}