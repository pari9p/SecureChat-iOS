//
// AnalyticsManager.swift
// SecureChat
//
// Created by SecureChat Team on 2/12/2026.
// Copyright 2025 SecureChat Development Team
//

import Foundation
import UIKit
import Combine

// MARK: - Analytics Event Types

public enum AnalyticsEvent {
    case appLaunched(launchTime: TimeInterval)
    case appBackgrounded
    case appForegrounded
    case messagesSent(count: Int, type: MessageType)
    case messagesReceived(count: Int)
    case searchPerformed(query: String, resultsCount: Int, duration: TimeInterval)
    case themeChanged(from: String, to: String)
    case offlineMessageQueued(count: Int)
    case featureUsed(feature: String, duration: TimeInterval?)
    case errorOccurred(error: String, context: String)
    case performanceMetric(metric: PerformanceMetric)
    
    public enum MessageType: String {
        case text, image, video, audio, document
    }
    
    public enum PerformanceMetric {
        case appStartup(duration: TimeInterval)
        case messageLoad(duration: TimeInterval, count: Int)
        case searchLatency(duration: TimeInterval)
        case memoryUsage(bytes: Int64)
        case networkRequest(duration: TimeInterval, success: Bool)
    }
}

// MARK: - Analytics Data Structures

public struct AnalyticsEventData: Codable {
    let id: String
    let eventType: String
    let timestamp: Date
    let sessionId: String
    let userId: String // Anonymized user ID
    let properties: [String: AnalyticsValue]
    let deviceInfo: DeviceInfo
}

public enum AnalyticsValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else {
            throw DecodingError.typeMismatch(AnalyticsValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown value type"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

public struct DeviceInfo: Codable {
    let platform: String = "iOS"
    let osVersion: String
    let appVersion: String
    let deviceModel: String
    let locale: String
    let timezone: String
}

// MARK: - Analytics Manager

@objc
public class AnalyticsManager: NSObject {
    
    public static let shared = AnalyticsManager()
    
    @Published public private(set) var isEnabled = true
    @Published public private(set) var eventsCount = 0
    
    private let analyticsQueue = DispatchQueue(label: "com.securechat.analytics", qos: .utility)
    private let sessionId = UUID().uuidString
    private let anonymizedUserId = UUID().uuidString // Generate unique anonymous ID
    
    private var eventBuffer: [AnalyticsEventData] = []
    private let maxBufferSize = 100
    private let flushInterval: TimeInterval = 30.0 // 30 seconds
    
    private var flushTimer: Timer?
    private var sessionStartTime = Date()
    
    // User preferences
    private let enabledKey = "SecureChat.Analytics.Enabled"
    private let userDefaults = UserDefaults.standard
    
    public override init() {
        super.init()
        loadSettings()
        setupDeviceInfo()
        startFlushTimer()
        setupAppLifecycleObservers()
    }
    
    // MARK: - Public Interface
    
    public func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        analyticsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let eventData = self.createEventData(from: event)
            self.eventBuffer.append(eventData)
            
            DispatchQueue.main.async {
                self.eventsCount += 1
            }
            
            // Flush if buffer is full
            if self.eventBuffer.count >= self.maxBufferSize {
                self.flushEvents()
            }
        }
    }
    
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: enabledKey)
        
        if !enabled {
            clearBuffer()
        }
    }
    
    public func flush() {
        analyticsQueue.async { [weak self] in
            self?.flushEvents()
        }
    }
    
    public func getSessionInfo() -> (id: String, duration: TimeInterval, eventsCount: Int) {
        let duration = Date().timeIntervalSince(sessionStartTime)
        return (sessionId, duration, eventsCount)
    }
    
    // MARK: - Event Creation
    
    private func createEventData(from event: AnalyticsEvent) -> AnalyticsEventData {
        let eventType: String
        var properties: [String: AnalyticsValue] = [:]
        
        switch event {
        case .appLaunched(let launchTime):
            eventType = "app_launched"
            properties["launch_time"] = .double(launchTime)
            
        case .appBackgrounded:
            eventType = "app_backgrounded"
            let sessionDuration = Date().timeIntervalSince(sessionStartTime)
            properties["session_duration"] = .double(sessionDuration)
            
        case .appForegrounded:
            eventType = "app_foregrounded"
            
        case .messagesSent(let count, let type):
            eventType = "messages_sent"
            properties["count"] = .int(count)
            properties["message_type"] = .string(type.rawValue)
            
        case .messagesReceived(let count):
            eventType = "messages_received"
            properties["count"] = .int(count)
            
        case .searchPerformed(let query, let resultsCount, let duration):
            eventType = "search_performed"
            properties["query_length"] = .int(query.count)
            properties["results_count"] = .int(resultsCount)
            properties["duration"] = .double(duration)
            
        case .themeChanged(let from, let to):
            eventType = "theme_changed"
            properties["from_theme"] = .string(from)
            properties["to_theme"] = .string(to)
            
        case .offlineMessageQueued(let count):
            eventType = "offline_message_queued"
            properties["queue_count"] = .int(count)
            
        case .featureUsed(let feature, let duration):
            eventType = "feature_used"
            properties["feature"] = .string(feature)
            if let duration = duration {
                properties["duration"] = .double(duration)
            }
            
        case .errorOccurred(let error, let context):
            eventType = "error_occurred"
            properties["error"] = .string(error)
            properties["context"] = .string(context)
            
        case .performanceMetric(let metric):
            eventType = "performance_metric"
            addPerformanceProperties(metric, to: &properties)
        }
        
        return AnalyticsEventData(
            id: UUID().uuidString,
            eventType: eventType,
            timestamp: Date(),
            sessionId: sessionId,
            userId: anonymizedUserId,
            properties: properties,
            deviceInfo: currentDeviceInfo
        )
    }
    
    private func addPerformanceProperties(_ metric: AnalyticsEvent.PerformanceMetric, to properties: inout [String: AnalyticsValue]) {
        switch metric {
        case .appStartup(let duration):
            properties["metric_type"] = .string("app_startup")
            properties["duration"] = .double(duration)
            
        case .messageLoad(let duration, let count):
            properties["metric_type"] = .string("message_load")
            properties["duration"] = .double(duration)
            properties["message_count"] = .int(count)
            
        case .searchLatency(let duration):
            properties["metric_type"] = .string("search_latency")
            properties["duration"] = .double(duration)
            
        case .memoryUsage(let bytes):
            properties["metric_type"] = .string("memory_usage")
            properties["bytes"] = .int(Int(bytes))
            
        case .networkRequest(let duration, let success):
            properties["metric_type"] = .string("network_request")
            properties["duration"] = .double(duration)
            properties["success"] = .bool(success)
        }
    }
    
    // MARK: - Device Info
    
    private var currentDeviceInfo: DeviceInfo!
    
    private func setupDeviceInfo() {
        let device = UIDevice.current
        currentDeviceInfo = DeviceInfo(
            osVersion: device.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            deviceModel: device.model,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }
    
    // MARK: - Data Management
    
    private func flushEvents() {
        guard !eventBuffer.isEmpty else { return }
        
        let eventsToSend = eventBuffer
        eventBuffer.removeAll()
        
        // In a real app, this would send to your analytics service
        sendEvents(eventsToSend)
    }
    
    private func sendEvents(_ events: [AnalyticsEventData]) {
        // Simulate sending to analytics service
        print("📊 Analytics: Sending \(events.count) events")
        
        for event in events {
            print("  • \(event.eventType) at \(event.timestamp)")
        }
        
        // In production, implement actual network request
        // Example: POST to your analytics endpoint
        /*
        let data = try JSONEncoder().encode(events)
        let request = URLRequest(url: analyticsEndpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        URLSession.shared.dataTask(with: request).resume()
        */
    }
    
    private func clearBuffer() {
        analyticsQueue.async { [weak self] in
            self?.eventBuffer.removeAll()
            DispatchQueue.main.async {
                self?.eventsCount = 0
            }
        }
    }
    
    // MARK: - Settings & Lifecycle
    
    private func loadSettings() {
        if userDefaults.object(forKey: enabledKey) != nil {
            isEnabled = userDefaults.bool(forKey: enabledKey)
        } else {
            isEnabled = true // Default enabled
            userDefaults.set(true, forKey: enabledKey)
        }
    }
    
    private func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        track(.appBackgrounded)
        flush()
    }
    
    @objc private func appWillEnterForeground() {
        track(.appForegrounded)
        sessionStartTime = Date()
    }
    
    deinit {
        flushTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Convenience Extensions

extension AnalyticsManager {
    
    public func trackFeatureUsage(_ feature: String) {
        track(.featureUsed(feature: feature, duration: nil))
    }
    
    public func trackError(_ error: Error, context: String = "") {
        track(.errorOccurred(error: error.localizedDescription, context: context))
    }
    
    public func trackPerformance<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        track(.featureUsed(feature: operation, duration: duration))
        return result
    }
}