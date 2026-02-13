//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

/// Centralized security manager for enhanced app security features
final class SecurityManager {
    
    // MARK: - Singleton
    
    static let shared = SecurityManager()
    
    private init() {
        setupSecurityConfiguration()
    }
    
    // MARK: - Security Configuration
    
    private func setupSecurityConfiguration() {
        // Configure app security settings
        configureSecureDefaults()
        configureMemoryProtection()
    }
    
    private func configureSecureDefaults() {
        // Clear pasteboard after app backgrounding
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.securePasteboard()
        }
    }
    
    private func configureMemoryProtection() {
        // Enable memory protection flags
        #if !DEBUG
        let pageSize = getpagesize()
        let protectionFlags = PROT_READ | PROT_WRITE
        mprotect(UnsafeMutableRawPointer(bitPattern: pageSize), Int(pageSize), protectionFlags)
        #endif
    }
    
    // MARK: - Pasteboard Security
    
    func securePasteboard() {
        UIPasteboard.general.items = []
        UIPasteboard.general.string = nil
    }
    
    func copyToSecurePasteboard(_ text: String, expirationTime: TimeInterval = 30.0) {
        UIPasteboard.general.string = text
        
        // Auto-clear pasteboard after specified time
        DispatchQueue.main.asyncAfter(deadline: .now() + expirationTime) {
            if UIPasteboard.general.string == text {
                self.securePasteboard()
            }
        }
    }
    
    // MARK: - Biometric Authentication
    
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func getBiometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    // MARK: - Key Generation
    
    func generateSecureRandomData(length: Int) -> Data {
        return Randomness.generateRandomBytes(UInt(length))
    }
    
    func generateSecureHMAC(data: Data, key: Data) -> Data {
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(hmac)
    }
    
    // MARK: - Certificate Pinning Validation
    
    func validateCertificatePinning(serverTrust: SecTrust, host: String) -> Bool {
        // Get certificate chain
        guard let certificateChain = extractCertificateChain(from: serverTrust) else {
            return false
        }
        
        // Validate against known good certificate hashes
        return validateCertificateHashes(certificateChain, forHost: host)
    }
    
    private func extractCertificateChain(from serverTrust: SecTrust) -> [Data]? {
        var certificates: [Data] = []
        
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
                let data = SecCertificateCopyData(certificate)
                certificates.append(data as Data)
            }
        }
        
        return certificates.isEmpty ? nil : certificates
    }
    
    private func validateCertificateHashes(_ certificates: [Data], forHost host: String) -> Bool {
        // In a real implementation, you would have pinned certificate hashes
        // for different Signal endpoints
        let knownGoodHashes = getKnownCertificateHashes(forHost: host)
        
        for certificate in certificates {
            let hash = SHA256.hash(data: certificate)
            let hashData = Data(hash)
            
            if knownGoodHashes.contains(hashData) {
                return true
            }
        }
        
        return false
    }
    
    private func getKnownCertificateHashes(forHost host: String) -> Set<Data> {
        // Placeholder for actual certificate hashes
        // In production, these would be the SHA-256 hashes of Signal's certificates
        return Set<Data>()
    }
    
    // MARK: - Screen Recording Protection
    
    var isScreenRecordingDetected: Bool {
        if #available(iOS 11.0, *) {
            return UIScreen.main.isCaptured
        }
        return false
    }
    
    func startScreenRecordingMonitoring() {
        if #available(iOS 11.0, *) {
            NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                self.handleScreenRecordingChange()
            }
        }
    }
    
    private func handleScreenRecordingChange() {
        if isScreenRecordingDetected {
            NotificationCenter.default.post(
                name: .screenRecordingDetected,
                object: nil
            )
        }
    }
    
    // MARK: - Memory Security
    
    func secureMemoryWipe<T>(_ data: inout T) {
        withUnsafeMutableBytes(of: &data) { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
    }
    
    func secureDataWipe(_ data: inout Data) {
        data.withUnsafeMutableBytes { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
        data.removeAll()
    }
    
    // MARK: - App Transport Security
    
    func validateATSCompliance(for url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        
        // Ensure HTTPS for all external connections
        if scheme != "https" && !isLocalhost(url) {
            return false
        }
        
        return true
    }
    
    private func isLocalhost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
    
    // MARK: - Debug Detection
    
    func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        
        if result != 0 {
            return false
        }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    // MARK: - Jailbreak Detection
    
    func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for common jailbreak files and directories
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/var/cache/apt",
            "/var/lib/apt",
            "/var/lib/cydia"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Try to write in a restricted location
        let testPath = "/private/test_write"
        do {
            try "test".write(toFile: testPath, atomically: false, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let screenRecordingDetected = Notification.Name("screenRecordingDetected")
    static let securityThreatDetected = Notification.Name("securityThreatDetected")
}

// MARK: - Security Extensions

extension LABiometryType {
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Unknown"
        }
    }
}