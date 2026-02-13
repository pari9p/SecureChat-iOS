//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import AVFoundation
import UIKit

/// Voice message recording and playback manager with waveform generation
final class VoiceMessageManager: NSObject {
    
    // MARK: - Properties
    
    static let shared = VoiceMessageManager()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var currentRecordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    private let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    private let audioQueue = DispatchQueue(label: "VoiceMessageManager.audio", qos: .userInitiated)
    
    // MARK: - Audio Settings
    
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    // MARK: - Delegates
    
    weak var delegate: VoiceMessageManagerDelegate?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            try recordingSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try recordingSession.setActive(true)
        } catch {
            Logger.error("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Permission Management
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            recordingSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func checkMicrophonePermission() -> Bool {
        return recordingSession.recordPermission == .granted
    }
    
    // MARK: - Recording Management
    
    func startRecording() async -> VoiceRecordingResult {
        // Check permission
        guard await requestMicrophonePermission() else {
            return .failure(.permissionDenied)
        }
        
        // Setup recording file
        guard let recordingURL = createRecordingURL() else {
            return .failure(.fileCreationFailed)
        }
        
        do {
            // Configure audio session for recording
            try recordingSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try recordingSession.setActive(true)
            
            // Create recorder
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Start recording
            guard audioRecorder?.record() == true else {
                return .failure(.recordingFailed)
            }
            
            currentRecordingURL = recordingURL
            recordingStartTime = Date()
            
            // Start monitoring
            startRecordingTimer()
            
            Logger.info("Voice recording started")
            delegate?.voiceRecordingDidStart()
            
            return .success(recordingURL)
            
        } catch {
            Logger.error("Failed to start recording: \(error)")
            return .failure(.recordingFailed)
        }
    }
    
    func stopRecording() -> VoiceRecordingStopResult {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return .failure(.notRecording)
        }
        
        // Stop recording
        recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Calculate duration
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        guard let recordingURL = currentRecordingURL else {
            return .failure(.fileNotFound)
        }
        
        // Check minimum duration (1 second)
        if duration < 1.0 {
            cleanupRecording(at: recordingURL)
            return .failure(.tooShort)
        }
        
        Logger.info("Voice recording stopped, duration: \(duration)s")
        
        let voiceMessage = VoiceMessage(
            url: recordingURL,
            duration: duration,
            waveform: generateWaveform(from: recordingURL),
            fileSize: getFileSize(at: recordingURL)
        )
        
        delegate?.voiceRecordingDidStop(voiceMessage: voiceMessage)
        
        // Reset state
        resetRecordingState()
        
        return .success(voiceMessage)
    }
    
    func cancelRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Clean up file
        if let recordingURL = currentRecordingURL {
            cleanupRecording(at: recordingURL)
        }
        
        resetRecordingState()
        
        Logger.info("Voice recording cancelled")
        delegate?.voiceRecordingDidCancel()
    }
    
    private func resetRecordingState() {
        audioRecorder = nil
        currentRecordingURL = nil
        recordingStartTime = nil
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateRecordingMetrics()
        }
    }
    
    private func updateRecordingMetrics() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            recordingTimer?.invalidate()
            return
        }
        
        // Update metering
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Calculate duration
        let currentDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Check max duration
        if currentDuration >= maxRecordingDuration {
            DispatchQueue.main.async {
                _ = self.stopRecording()
            }
            return
        }
        
        // Notify delegate
        let metrics = RecordingMetrics(
            duration: currentDuration,
            averagePower: averagePower,
            peakPower: peakPower
        )
        
        DispatchQueue.main.async {
            self.delegate?.voiceRecordingDidUpdateMetrics(metrics)
        }
    }
    
    // MARK: - Playback Management
    
    func playVoiceMessage(_ voiceMessage: VoiceMessage) async -> PlaybackResult {
        // Stop any current playback
        stopPlayback()
        
        do {
            // Configure audio session for playback
            try recordingSession.setCategory(.playback)
            try recordingSession.setActive(true)
            
            // Create player
            audioPlayer = try AVAudioPlayer(contentsOf: voiceMessage.url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Start playback
            guard audioPlayer?.play() == true else {
                return .failure(.playbackFailed)
            }
            
            Logger.info("Voice message playback started")
            delegate?.voicePlaybackDidStart(voiceMessage: voiceMessage)
            
            return .success
            
        } catch {
            Logger.error("Failed to play voice message: \(error)")
            return .failure(.playbackFailed)
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        delegate?.voicePlaybackDidPause()
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        delegate?.voicePlaybackDidResume()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        delegate?.voicePlaybackDidStop()
    }
    
    func seekToTime(_ time: TimeInterval) {
        audioPlayer?.currentTime = time
    }
    
    // MARK: - File Management
    
    private func createRecordingURL() -> URL? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "voice_message_\(timestamp).m4a"
        let recordingURL = URL(fileURLWithPath: documentsPath).appendingPathComponent(filename)
        
        return recordingURL
    }
    
    private func cleanupRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Logger.warn("Failed to cleanup recording file: \(error)")
        }
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    // MARK: - Waveform Generation
    
    private func generateWaveform(from url: URL) -> [Float] {
        return audioQueue.sync {
            return generateWaveformData(from: url)
        }
    }
    
    private func generateWaveformData(from url: URL) -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url),
              let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                              sampleRate: audioFile.fileFormat.sampleRate,
                                              channels: 1,
                                              interleaved: false) else {
            return []
        }
        
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            return []
        }
        
        do {
            try audioFile.read(into: audioBuffer)
        } catch {
            Logger.error("Failed to read audio file for waveform: \(error)")
            return []
        }
        
        guard let floatChannelData = audioBuffer.floatChannelData?[0] else {
            return []
        }
        
        let sampleCount = Int(audioBuffer.frameLength)
        let samplesPerPixel = max(1, sampleCount / 100) // Generate 100 waveform points
        
        var waveformData: [Float] = []
        
        for i in stride(from: 0, to: sampleCount, by: samplesPerPixel) {
            let endIndex = min(i + samplesPerPixel, sampleCount)
            var maxAmplitude: Float = 0
            
            for j in i..<endIndex {
                maxAmplitude = max(maxAmplitude, abs(floatChannelData[j]))
            }
            
            waveformData.append(maxAmplitude)
        }
        
        return waveformData
    }
    
    // MARK: - Current State
    
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    var currentPlaybackTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    var recordingDuration: TimeInterval {
        return recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceMessageManager: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            Logger.info("Audio recording finished successfully")
        } else {
            Logger.error("Audio recording finished with error")
            delegate?.voiceRecordingDidFail(error: .recordingFailed)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Logger.error("Audio recorder encode error: \(error?.localizedDescription ?? "unknown")")
        delegate?.voiceRecordingDidFail(error: .encodingFailed)
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceMessageManager: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            Logger.info("Audio playback finished successfully")
        } else {
            Logger.error("Audio playback finished with error")
        }
        
        audioPlayer = nil
        delegate?.voicePlaybackDidFinish()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Logger.error("Audio player decode error: \(error?.localizedDescription ?? "unknown")")
        delegate?.voicePlaybackDidFail(error: .decodingFailed)
    }
}

// MARK: - Supporting Types

struct VoiceMessage {
    let url: URL
    let duration: TimeInterval
    let waveform: [Float]
    let fileSize: Int64
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

struct RecordingMetrics {
    let duration: TimeInterval
    let averagePower: Float
    let peakPower: Float
    
    var normalizedPower: Float {
        // Convert from dB to 0-1 range
        let minDb: Float = -80
        let maxDb: Float = 0
        return max(0, min(1, (averagePower - minDb) / (maxDb - minDb)))
    }
}

enum VoiceRecordingResult {
    case success(URL)
    case failure(VoiceRecordingError)
}

enum VoiceRecordingStopResult {
    case success(VoiceMessage)
    case failure(VoiceRecordingError)
}

enum PlaybackResult {
    case success
    case failure(PlaybackError)
}

enum VoiceRecordingError {
    case permissionDenied
    case fileCreationFailed
    case recordingFailed
    case encodingFailed
    case notRecording
    case fileNotFound
    case tooShort
}

enum PlaybackError {
    case playbackFailed
    case decodingFailed
}

// MARK: - Delegate Protocol

protocol VoiceMessageManagerDelegate: AnyObject {
    func voiceRecordingDidStart()
    func voiceRecordingDidStop(voiceMessage: VoiceMessage)
    func voiceRecordingDidCancel()
    func voiceRecordingDidFail(error: VoiceRecordingError)
    func voiceRecordingDidUpdateMetrics(_ metrics: RecordingMetrics)
    
    func voicePlaybackDidStart(voiceMessage: VoiceMessage)
    func voicePlaybackDidPause()
    func voicePlaybackDidResume()
    func voicePlaybackDidStop()
    func voicePlaybackDidFinish()
    func voicePlaybackDidFail(error: PlaybackError)
}