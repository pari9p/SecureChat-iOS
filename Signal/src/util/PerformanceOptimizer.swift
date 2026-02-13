//
// Copyright 2024 Signal Messenger, LLC  
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit

/// Enhanced memory management utilities for better app performance
public class PerformanceOptimizer {
    
    public static let shared = PerformanceOptimizer()
    
    private init() {}
    
    /// Optimizes memory usage by cleaning up expired cache entries
    public func optimizeMemoryUsage() {
        autoreleasepool {
            cleanExpiredCacheEntries()
            forceMemoryWarningIfNeeded()
        }
        Logger.info("Memory optimization completed")
    }
    
    /// Performs batch operations more efficiently with autoreleasepool
    public func performBatchOperation<T>(_ operation: () throws -> T) rethrows -> T {
        return try autoreleasepool {
            try operation()
        }
    }
    
    /// Creates a weak timer to avoid retain cycles
    public static func createWeakTimer(
        timeInterval: TimeInterval,
        target: AnyObject,
        selector: Selector,
        repeats: Bool = false
    ) -> Timer {
        return Timer.weakScheduledTimer(
            withTimeInterval: timeInterval,
            target: target,
            selector: selector,
            userInfo: nil,
            repeats: repeats
        )
    }
    
    private func cleanExpiredCacheEntries() {
        // Clean up any remaining tmp files that might affect memory
        let fileManager = FileManager.default
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
        
        do {
            let tmpContents = try fileManager.contentsOfDirectory(
                at: tmpURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            for tmpFile in tmpContents {
                let resourceValues = try tmpFile.resourceValues(forKeys: [.contentModificationDateKey])
                if let modDate = resourceValues.contentModificationDate,
                   Date().timeIntervalSince(modDate) > 3600 { // 1 hour
                    try fileManager.removeItem(at: tmpFile)
                }
            }
        } catch {
            Logger.warn("Unable to clean cache entries: \(error)")
        }
    }
    
    private func forceMemoryWarningIfNeeded() {
        let memoryStatus = LocalDevice.currentMemoryStatus()
        if let footprint = memoryStatus?.footprint, footprint > 500_000_000 { // 500MB
            Logger.warn("High memory usage detected: \(footprint) bytes")
            // Trigger memory pressure notification for cleanup
            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
        }
    }
}