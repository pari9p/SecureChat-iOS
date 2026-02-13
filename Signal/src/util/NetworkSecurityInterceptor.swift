//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Network
import Security

/// Network security interceptor for enhanced connection monitoring and validation
final class NetworkSecurityInterceptor: NSObject {
    
    // MARK: - Properties
    
    private let securityManager = SecurityManager.shared
    private var secureConnections: Set<UUID> = []
    private let queue = DispatchQueue(label: "NetworkSecurityInterceptor", qos: .userInitiated)
    
    // MARK: - Certificate Validation
    
    func validateConnection(_ connection: URLSessionTask, host: String) -> Bool {
        guard let urlRequest = connection.originalRequest,
              let url = urlRequest.url else {
            return false
        }
        
        // Validate ATS compliance
        if !securityManager.validateATSCompliance(for: url) {
            Logger.warn("ATS validation failed for: \(url)")
            return false
        }
        
        return true
    }
    
    func validateServerTrust(_ serverTrust: SecTrust, forHost host: String) -> Bool {
        // Perform certificate pinning validation
        let pinningValid = securityManager.validateCertificatePinning(
            serverTrust: serverTrust,
            host: host
        )
        
        if !pinningValid {
            Logger.warn("Certificate pinning validation failed for host: \(host)")
            return false
        }
        
        // Additional trust evaluation
        var result: SecTrustResultType = .invalid
        let status = SecTrustEvaluate(serverTrust, &result)
        
        guard status == errSecSuccess else {
            Logger.error("SecTrustEvaluate failed with status: \(status)")
            return false
        }
        
        switch result {
        case .unspecified, .proceed:
            return true
        case .recoverableTrustFailure:
            // Could implement additional recovery logic here
            Logger.warn("Recoverable trust failure for host: \(host)")
            return false
        default:
            Logger.error("Trust evaluation failed with result: \(result)")
            return false
        }
    }
    
    // MARK: - Connection Monitoring
    
    func monitorConnection(taskIdentifier: Int) {
        queue.async {
            let connectionId = UUID()
            self.secureConnections.insert(connectionId)
            
            Logger.info("Monitoring secure connection: \(connectionId)")
        }
    }
    
    func connectionCompleted(taskIdentifier: Int, withError error: Error?) {
        queue.async {
            if let error = error {
                Logger.warn("Secure connection failed: \(error.localizedDescription)")
                self.handleConnectionFailure(error: error)
            } else {
                Logger.info("Secure connection completed successfully")
            }
        }
    }
    
    private func handleConnectionFailure(error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid:
                Logger.error("Certificate validation error: \(urlError.localizedDescription)")
                notifySecurityThreat(type: .certificateFailure, description: urlError.localizedDescription)
                
            case .secureConnectionFailed:
                Logger.error("Secure connection failed: \(urlError.localizedDescription)")
                notifySecurityThreat(type: .connectionFailure, description: urlError.localizedDescription)
                
            default:
                Logger.warn("Network error: \(urlError.localizedDescription)")
            }
        }
    }
    
    // MARK: - Request Validation
    
    func validateRequest(_ request: URLRequest) -> ValidationResult {
        guard let url = request.url else {
            return .invalid(reason: "Missing URL")
        }
        
        // Check for suspicious headers
        if let suspiciousHeader = detectSuspiciousHeaders(in: request) {
            return .suspicious(reason: "Suspicious header detected: \(suspiciousHeader)")
        }
        
        // Validate URL scheme
        guard url.scheme == "https" || isLocalDevelopment(url) else {
            return .invalid(reason: "Non-HTTPS connection attempted")
        }
        
        // Check against known malicious patterns
        if containsMaliciousPattern(url: url) {
            return .malicious(reason: "Malicious URL pattern detected")
        }
        
        return .valid
    }
    
    private func detectSuspiciousHeaders(in request: URLRequest) -> String? {
        let suspiciousHeaders = [
            "X-Forwarded-For",
            "X-Real-IP",
            "X-Original-URL",
            "X-Override-URL"
        ]
        
        for header in suspiciousHeaders {
            if request.allHTTPHeaderFields?[header] != nil {
                return header
            }
        }
        
        return nil
    }
    
    private func isLocalDevelopment(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("localhost") || host.contains("127.0.0.1") || host.contains("0.0.0.0")
    }
    
    private func containsMaliciousPattern(url: URL) -> Bool {
        let maliciousPatterns = [
            "javascript:",
            "data:",
            "vbscript:",
            "file://",
            "../",
            "<script",
            "eval(",
            "alert("
        ]
        
        let urlString = url.absoluteString.lowercased()
        
        for pattern in maliciousPatterns {
            if urlString.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Response Validation
    
    func validateResponse(_ response: HTTPURLResponse, data: Data?) -> Bool {
        // Check security headers
        let securityHeaders = extractSecurityHeaders(from: response)
        
        if !validateSecurityHeaders(securityHeaders) {
            Logger.warn("Security headers validation failed")
            return false
        }
        
        // Validate content type
        if let contentType = response.allHeaderFields["Content-Type"] as? String {
            if !isValidContentType(contentType) {
                Logger.warn("Invalid content type: \(contentType)")
                return false
            }
        }
        
        // Check for potential XSS in response data
        if let data = data, containsPotentialXSS(in: data) {
            Logger.error("Potential XSS content detected in response")
            return false
        }
        
        return true
    }
    
    private func extractSecurityHeaders(from response: HTTPURLResponse) -> [String: String] {
        let securityHeaderKeys = [
            "Strict-Transport-Security",
            "Content-Security-Policy",
            "X-Frame-Options",
            "X-Content-Type-Options",
            "Referrer-Policy"
        ]
        
        var securityHeaders: [String: String] = [:]
        
        for key in securityHeaderKeys {
            if let value = response.allHeaderFields[key] as? String {
                securityHeaders[key] = value
            }
        }
        
        return securityHeaders
    }
    
    private func validateSecurityHeaders(_ headers: [String: String]) -> Bool {
        // Check for required security headers
        if headers["Strict-Transport-Security"] == nil {
            Logger.info("Missing HSTS header")
        }
        
        if headers["X-Frame-Options"] == nil {
            Logger.info("Missing X-Frame-Options header")
        }
        
        return true // Non-blocking validation for now
    }
    
    private func isValidContentType(_ contentType: String) -> Bool {
        let validTypes = [
            "application/json",
            "application/protobuf",
            "application/x-protobuf",
            "text/plain",
            "application/octet-stream"
        ]
        
        for validType in validTypes {
            if contentType.lowercased().contains(validType) {
                return true
            }
        }
        
        return false
    }
    
    private func containsPotentialXSS(in data: Data) -> Bool {
        guard let string = String(data: data, encoding: .utf8) else { return false }
        
        let xssPatterns = [
            "<script",
            "javascript:",
            "onload=",
            "onerror=",
            "onclick=",
            "alert(",
            "document.cookie"
        ]
        
        let lowercaseString = string.lowercased()
        
        for pattern in xssPatterns {
            if lowercaseString.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Notification
    
    private func notifySecurityThreat(type: SecurityThreatType, description: String) {
        DispatchQueue.main.async {
            let userInfo = [
                "threatType": type.rawValue,
                "description": description
            ]
            
            NotificationCenter.default.post(
                name: .securityThreatDetected,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

// MARK: - Supporting Types

extension NetworkSecurityInterceptor {
    
    enum ValidationResult {
        case valid
        case invalid(reason: String)
        case suspicious(reason: String)
        case malicious(reason: String)
        
        var isSecure: Bool {
            switch self {
            case .valid:
                return true
            case .invalid, .suspicious, .malicious:
                return false
            }
        }
    }
    
    enum SecurityThreatType: String {
        case certificateFailure = "certificateFailure"
        case connectionFailure = "connectionFailure"
        case maliciousContent = "maliciousContent"
        case suspiciousActivity = "suspiciousActivity"
    }
}