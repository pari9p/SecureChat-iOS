//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit

/// Utility class for optimizing app performance and cleaning temporary files
public class AppOptimizer {
    
    public static let shared = AppOptimizer()
    
    private init() {}
    
    /// Performs routine cleanup of temporary files and caches
    public func performCleanup() {
        cleanTemporaryFiles()
        optimizeImageCache()
        Logger.info("App optimization cleanup completed")
    }
    
    private func cleanTemporaryFiles() {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, 
                                                                       includingPropertiesForKeys: [.fileSizeKey],
                                                                       options: .skipsHiddenFiles)
            
            for tempFile in tempFiles {
                // Remove files older than 24 hours
                let attributes = try FileManager.default.attributesOfItem(atPath: tempFile.path)
                if let modificationDate = attributes[.modificationDate] as? Date,
                   Date().timeIntervalSince(modificationDate) > 86400 {
                    try FileManager.default.removeItem(at: tempFile)
                    Logger.debug("Removed temporary file: \(tempFile.lastPathComponent)")
                }
            }
        } catch {
            Logger.warn("Failed to clean temporary files: \(error)")
        }
    }
    
    private func optimizeImageCache() {
        // Clean up expired image cache entries
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        
        guard let cacheDir = cacheDirectory else { return }
        
        do {
            let cacheContents = try FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                           includingPropertiesForKeys: [.contentModificationDateKey],
                                                                           options: .skipsHiddenFiles)
            
            for cacheFile in cacheContents where cacheFile.pathExtension.lowercased() == "tmp" {
                try FileManager.default.removeItem(at: cacheFile)
                Logger.debug("Removed cache file: \(cacheFile.lastPathComponent)")
            }
        } catch {
            Logger.warn("Failed to optimize image cache: \(error)")
        }
    }
}