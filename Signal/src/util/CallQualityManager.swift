//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import AVFoundation
import Network
import CallKit

/// Call quality monitoring and optimization for Signal voice/video calls
final class CallQualityManager: NSObject {
    
    // MARK: - Properties
    
    static let shared = CallQualityManager()
    
    private let networkMonitor = NWPathMonitor()
    private let monitoringQueue = DispatchQueue(label: "CallQualityManager", qos: .userInitiated)
    
    private var currentCall: ActiveCall?
    private var qualityMetrics: CallQualityMetrics = CallQualityMetrics()
    private var networkQuality: NetworkQuality = .unknown
    
    private var qualityTimer: Timer?
    private var adaptiveQualityEnabled = true
    
    // MARK: - Call Quality Configuration
    
    private struct QualityThresholds {
        static let excellentLatency: TimeInterval = 0.05 // 50ms
        static let goodLatency: TimeInterval = 0.15 // 150ms
        static let fairLatency: TimeInterval = 0.30 // 300ms
        
        static let excellentLossRate: Double = 0.01 // 1%
        static let goodLossRate: Double = 0.05 // 5%
        static let fairLossRate: Double = 0.15 // 15%
        
        static let excellentJitter: TimeInterval = 0.02 // 20ms
        static let goodJitter: TimeInterval = 0.05 // 50ms
        static let fairJitter: TimeInterval = 0.10 // 100ms
    }
    
    // MARK: - Delegate
    
    weak var delegate: CallQualityDelegate?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkPathUpdate(path)
        }
        
        networkMonitor.start(queue: monitoringQueue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let previousQuality = networkQuality
        networkQuality = assessNetworkQuality(from: path)
        
        Logger.info("Network quality changed: \(networkQuality)")
        
        if networkQuality != previousQuality {
            DispatchQueue.main.async {
                self.delegate?.networkQualityDidChange(self.networkQuality)
            }
            
            // Adapt call quality if needed
            if adaptiveQualityEnabled, let call = currentCall {
                adjustCallQuality(for: call, networkQuality: networkQuality)
            }
        }
    }
    
    private func assessNetworkQuality(from path: NWPath) -> NetworkQuality {
        guard path.status == .satisfied else {
            return .poor
        }
        
        if path.isExpensive {
            return .fair // Cellular connection
        }
        
        if path.usesInterfaceType(.wifi) {
            return .excellent
        } else if path.usesInterfaceType(.cellular) {
            // Could check cellular type (5G, 4G, 3G) for more granular assessment
            return .good
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .excellent
        }
        
        return .good
    }
    
    // MARK: - Call Management
    
    func startMonitoringCall(_ callId: String, type: CallType) {
        currentCall = ActiveCall(
            id: callId,
            type: type,
            startTime: Date(),
            isVideoEnabled: type == .video
        )
        
        qualityMetrics = CallQualityMetrics()
        
        startQualityMonitoring()
        
        Logger.info("Started monitoring call: \(callId), type: \(type)")
        delegate?.callMonitoringDidStart(callId: callId)
    }
    
    func stopMonitoringCall() {
        guard let call = currentCall else { return }
        
        stopQualityMonitoring()
        
        // Generate final call report
        let callDuration = Date().timeIntervalSince(call.startTime)
        let finalReport = generateCallReport(duration: callDuration)
        
        delegate?.callMonitoringDidEnd(report: finalReport)
        Logger.info("Stopped monitoring call: \(call.id)")
        
        currentCall = nil
    }
    
    func toggleVideo(_ enabled: Bool) {
        currentCall?.isVideoEnabled = enabled
        
        // Video toggling affects quality requirements
        if adaptiveQualityEnabled {
            adjustVideoQuality(enabled: enabled)
        }
    }
    
    // MARK: - Quality Monitoring
    
    private func startQualityMonitoring() {
        qualityTimer?.invalidate()
        
        qualityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateQualityMetrics()
        }
    }
    
    private func stopQualityMonitoring() {
        qualityTimer?.invalidate()
        qualityTimer = nil
    }
    
    private func updateQualityMetrics() {
        guard let call = currentCall else { return }
        
        // Simulate collecting real-time metrics
        // In production, these would come from WebRTC stats or AVAudioSession
        let latency = simulateLatencyMeasurement()
        let packetLoss = simulatePacketLossMeasurement()
        let jitter = simulateJitterMeasurement()
        let bandwidth = simulateBandwidthMeasurement()
        
        // Update metrics
        qualityMetrics.addLatencySample(latency)
        qualityMetrics.addPacketLossSample(packetLoss)
        qualityMetrics.addJitterSample(jitter)
        qualityMetrics.currentBandwidth = bandwidth
        
        // Update audio/video specific metrics
        if call.type == .video || call.isVideoEnabled {
            let frameRate = simulateFrameRateMeasurement()
            let resolution = simulateResolutionMeasurement()
            qualityMetrics.videoMetrics.frameRate = frameRate
            qualityMetrics.videoMetrics.resolution = resolution
        }
        
        let audioLevel = simulateAudioLevelMeasurement()
        qualityMetrics.audioMetrics.inputLevel = audioLevel.input
        qualityMetrics.audioMetrics.outputLevel = audioLevel.output
        
        // Assess overall quality
        let overallQuality = assessCallQuality()
        qualityMetrics.overallQuality = overallQuality
        
        // Notify delegate
        DispatchQueue.main.async {
            self.delegate?.callQualityDidUpdate(self.qualityMetrics)
        }
        
        // Auto-adjust if quality is poor
        if adaptiveQualityEnabled && overallQuality == .poor {
            autoAdjustCallQuality()
        }
    }
    
    // MARK: - Quality Assessment
    
    private func assessCallQuality() -> CallQuality {
        let latencyScore = scoreLatency(qualityMetrics.averageLatency)
        let lossScore = scorePacketLoss(qualityMetrics.averagePacketLoss)
        let jitterScore = scoreJitter(qualityMetrics.averageJitter)
        
        let overallScore = (latencyScore + lossScore + jitterScore) / 3.0
        
        switch overallScore {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        default:
            return .poor
        }
    }
    
    private func scoreLatency(_ latency: TimeInterval) -> Double {
        if latency <= QualityThresholds.excellentLatency {
            return 1.0
        } else if latency <= QualityThresholds.goodLatency {
            return 0.8
        } else if latency <= QualityThresholds.fairLatency {
            return 0.6
        } else {
            return 0.0
        }
    }
    
    private func scorePacketLoss(_ lossRate: Double) -> Double {
        if lossRate <= QualityThresholds.excellentLossRate {
            return 1.0
        } else if lossRate <= QualityThresholds.goodLossRate {
            return 0.8
        } else if lossRate <= QualityThresholds.fairLossRate {
            return 0.6
        } else {
            return 0.0
        }
    }
    
    private func scoreJitter(_ jitter: TimeInterval) -> Double {
        if jitter <= QualityThresholds.excellentJitter {
            return 1.0
        } else if jitter <= QualityThresholds.goodJitter {
            return 0.8
        } else if jitter <= QualityThresholds.fairJitter {
            return 0.6
        } else {
            return 0.0
        }
    }
    
    // MARK: - Adaptive Quality Control
    
    private func adjustCallQuality(for call: ActiveCall, networkQuality: NetworkQuality) {
        Logger.info("Adjusting call quality for network: \(networkQuality)")
        
        switch networkQuality {
        case .excellent:
            setHighQualityMode()
        case .good:
            setMediumQualityMode()
        case .fair:
            setLowQualityMode()
        case .poor:
            setMinimalQualityMode()
        case .unknown:
            break
        }
    }
    
    private func autoAdjustCallQuality() {
        guard let call = currentCall else { return }
        
        Logger.info("Auto-adjusting call quality due to poor performance")
        
        // Progressive quality reduction
        if call.isVideoEnabled && call.type != .audioOnly {
            // First, try reducing video quality
            reduceVideoQuality()
        } else {
            // Reduce audio quality if video is already off
            reduceAudioQuality()
        }
        
        delegate?.callQualityAutoAdjusted(reason: "Poor network performance")
    }
    
    private func setHighQualityMode() {
        // Configure for highest quality settings
        configureAudioQuality(.high)
        configureVideoQuality(.high)
    }
    
    private func setMediumQualityMode() {
        configureAudioQuality(.medium)
        configureVideoQuality(.medium)
    }
    
    private func setLowQualityMode() {
        configureAudioQuality(.low)
        configureVideoQuality(.low)
    }
    
    private func setMinimalQualityMode() {
        configureAudioQuality(.minimal)
        configureVideoQuality(.minimal)
    }
    
    private func reduceVideoQuality() {
        // Step down video quality
        guard let call = currentCall else { return }
        
        if call.isVideoEnabled {
            configureVideoQuality(.low)
            delegate?.videoQualityReduced()
        }
    }
    
    private func reduceAudioQuality() {
        configureAudioQuality(.low)
        delegate?.audioQualityReduced()
    }
    
    private func adjustVideoQuality(enabled: Bool) {
        if enabled {
            // Enable video with appropriate quality based on network
            let videoQuality: QualityLevel
            
            switch networkQuality {
            case .excellent, .good:
                videoQuality = .high
            case .fair:
                videoQuality = .medium
            case .poor, .unknown:
                videoQuality = .low
            }
            
            configureVideoQuality(videoQuality)
        }
    }
    
    // MARK: - Quality Configuration
    
    private func configureAudioQuality(_ level: QualityLevel) {
        // Configure audio codec settings based on quality level
        let codec: AudioCodec
        let bitrate: Int
        
        switch level {
        case .high:
            codec = .opus
            bitrate = 64000
        case .medium:
            codec = .opus
            bitrate = 32000
        case .low:
            codec = .opus
            bitrate = 16000
        case .minimal:
            codec = .opus
            bitrate = 8000
        }
        
        Logger.info("Configured audio: codec=\(codec), bitrate=\(bitrate)")
    }
    
    private func configureVideoQuality(_ level: QualityLevel) {
        guard let call = currentCall,
              call.type == .video || call.isVideoEnabled else { return }
        
        let resolution: VideoResolution
        let frameRate: Int
        let bitrate: Int
        
        switch level {
        case .high:
            resolution = .hd720
            frameRate = 30
            bitrate = 1500000
        case .medium:
            resolution = .vga
            frameRate = 24
            bitrate = 800000
        case .low:
            resolution = .cif
            frameRate = 15
            bitrate = 300000
        case .minimal:
            resolution = .qcif
            frameRate = 10
            bitrate = 100000
        }
        
        Logger.info("Configured video: resolution=\(resolution), fps=\(frameRate), bitrate=\(bitrate)")
    }
    
    // MARK: - Diagnostics
    
    func runNetworkDiagnostics() async -> NetworkDiagnosticsResult {
        Logger.info("Running network diagnostics")
        
        // Simulate network tests
        let latency = await measureActualLatency()
        let bandwidth = await measureActualBandwidth()
        let packetLoss = await measureActualPacketLoss()
        
        let result = NetworkDiagnosticsResult(
            latency: latency,
            bandwidth: bandwidth,
            packetLoss: packetLoss,
            networkType: getCurrentNetworkType(),
            timestamp: Date()
        )
        
        Logger.info("Network diagnostics completed: \(result)")
        return result
    }
    
    private func measureActualLatency() async -> TimeInterval {
        // Simulate latency measurement to Signal servers
        return Double.random(in: 0.02...0.3)
    }
    
    private func measureActualBandwidth() async -> Double {
        // Simulate bandwidth test
        return Double.random(in: 1000000...100000000) // 1Mbps to 100Mbps
    }
    
    private func measureActualPacketLoss() async -> Double {
        // Simulate packet loss measurement
        return Double.random(in: 0...0.1) // 0-10%
    }
    
    private func getCurrentNetworkType() -> String {
        guard let path = networkMonitor.currentPath else { return "Unknown" }
        
        if path.usesInterfaceType(.wifi) {
            return "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        }
        
        return "Unknown"
    }
    
    // MARK: - Reporting
    
    private func generateCallReport(duration: TimeInterval) -> CallQualityReport {
        return CallQualityReport(
            callId: currentCall?.id ?? "",
            duration: duration,
            averageLatency: qualityMetrics.averageLatency,
            averagePacketLoss: qualityMetrics.averagePacketLoss,
            averageJitter: qualityMetrics.averageJitter,
            overallQuality: qualityMetrics.overallQuality,
            networkQuality: networkQuality,
            videoWasEnabled: currentCall?.isVideoEnabled ?? false,
            qualityAdjustments: qualityMetrics.qualityAdjustmentCount
        )
    }
    
    func getCallStatistics() -> CallStatistics? {
        guard let call = currentCall else { return nil }
        
        let duration = Date().timeIntervalSince(call.startTime)
        
        return CallStatistics(
            callId: call.id,
            duration: duration,
            currentQuality: qualityMetrics.overallQuality,
            networkQuality: networkQuality,
            audioMetrics: qualityMetrics.audioMetrics,
            videoMetrics: qualityMetrics.videoMetrics
        )
    }
    
    // MARK: - Mock Data Generation
    
    private func simulateLatencyMeasurement() -> TimeInterval {
        let baseLatency = Double.random(in: 0.02...0.05)
        let networkMultiplier = networkQualityMultiplier()
        return baseLatency * networkMultiplier
    }
    
    private func simulatePacketLossMeasurement() -> Double {
        let baseLoss = Double.random(in: 0...0.02)
        let networkMultiplier = networkQualityMultiplier()
        return min(baseLoss * networkMultiplier, 0.5)
    }
    
    private func simulateJitterMeasurement() -> TimeInterval {
        let baseJitter = Double.random(in: 0.01...0.03)
        let networkMultiplier = networkQualityMultiplier()
        return baseJitter * networkMultiplier
    }
    
    private func simulateBandwidthMeasurement() -> Double {
        let baseBandwidth = 10_000_000.0 // 10 Mbps
        let networkMultiplier = 1.0 / networkQualityMultiplier()
        return baseBandwidth * networkMultiplier
    }
    
    private func simulateFrameRateMeasurement() -> Double {
        return Double.random(in: 15...30)
    }
    
    private func simulateResolutionMeasurement() -> CGSize {
        return CGSize(width: 640, height: 480)
    }
    
    private func simulateAudioLevelMeasurement() -> (input: Double, output: Double) {
        return (
            input: Double.random(in: 0.1...0.8),
            output: Double.random(in: 0.2...0.9)
        )
    }
    
    private func networkQualityMultiplier() -> Double {
        switch networkQuality {
        case .excellent:
            return 1.0
        case .good:
            return 2.0
        case .fair:
            return 4.0
        case .poor:
            return 8.0
        case .unknown:
            return 3.0
        }
    }
}

// MARK: - Supporting Types

enum CallType {
    case audioOnly
    case video
}

enum CallQuality {
    case excellent
    case good
    case fair
    case poor
}

enum NetworkQuality {
    case excellent
    case good
    case fair
    case poor
    case unknown
}

enum QualityLevel {
    case high
    case medium
    case low
    case minimal
}

enum AudioCodec {
    case opus
    case aac
    case pcm
}

enum VideoResolution {
    case hd720
    case vga
    case cif
    case qcif
    
    var size: CGSize {
        switch self {
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .vga:
            return CGSize(width: 640, height: 480)
        case .cif:
            return CGSize(width: 352, height: 288)
        case .qcif:
            return CGSize(width: 176, height: 144)
        }
    }
}

struct ActiveCall {
    let id: String
    let type: CallType
    let startTime: Date
    var isVideoEnabled: Bool
}

struct CallQualityMetrics {
    private var latencySamples: [TimeInterval] = []
    private var packetLossSamples: [Double] = []
    private var jitterSamples: [TimeInterval] = []
    
    var currentBandwidth: Double = 0
    var overallQuality: CallQuality = .good
    var qualityAdjustmentCount: Int = 0
    
    struct AudioMetrics {
        var inputLevel: Double = 0
        var outputLevel: Double = 0
    }
    
    struct VideoMetrics {
        var frameRate: Double = 0
        var resolution: CGSize = .zero
    }
    
    var audioMetrics = AudioMetrics()
    var videoMetrics = VideoMetrics()
    
    mutating func addLatencySample(_ latency: TimeInterval) {
        latencySamples.append(latency)
        if latencySamples.count > 60 { // Keep last 60 samples
            latencySamples.removeFirst()
        }
    }
    
    mutating func addPacketLossSample(_ loss: Double) {
        packetLossSamples.append(loss)
        if packetLossSamples.count > 60 {
            packetLossSamples.removeFirst()
        }
    }
    
    mutating func addJitterSample(_ jitter: TimeInterval) {
        jitterSamples.append(jitter)
        if jitterSamples.count > 60 {
            jitterSamples.removeFirst()
        }
    }
    
    var averageLatency: TimeInterval {
        return latencySamples.isEmpty ? 0 : latencySamples.reduce(0, +) / Double(latencySamples.count)
    }
    
    var averagePacketLoss: Double {
        return packetLossSamples.isEmpty ? 0 : packetLossSamples.reduce(0, +) / Double(packetLossSamples.count)
    }
    
    var averageJitter: TimeInterval {
        return jitterSamples.isEmpty ? 0 : jitterSamples.reduce(0, +) / Double(jitterSamples.count)
    }
}

struct CallQualityReport {
    let callId: String
    let duration: TimeInterval
    let averageLatency: TimeInterval
    let averagePacketLoss: Double
    let averageJitter: TimeInterval
    let overallQuality: CallQuality
    let networkQuality: NetworkQuality
    let videoWasEnabled: Bool
    let qualityAdjustments: Int
}

struct CallStatistics {
    let callId: String
    let duration: TimeInterval
    let currentQuality: CallQuality
    let networkQuality: NetworkQuality
    let audioMetrics: CallQualityMetrics.AudioMetrics
    let videoMetrics: CallQualityMetrics.VideoMetrics
}

struct NetworkDiagnosticsResult {
    let latency: TimeInterval
    let bandwidth: Double
    let packetLoss: Double
    let networkType: String
    let timestamp: Date
}

// MARK: - Delegate Protocol

protocol CallQualityDelegate: AnyObject {
    func callMonitoringDidStart(callId: String)
    func callMonitoringDidEnd(report: CallQualityReport)
    func callQualityDidUpdate(_ metrics: CallQualityMetrics)
    func networkQualityDidChange(_ quality: NetworkQuality)
    func callQualityAutoAdjusted(reason: String)
    func videoQualityReduced()
    func audioQualityReduced()
}