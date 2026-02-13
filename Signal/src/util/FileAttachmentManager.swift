//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import UIKit
import UniformTypeIdentifiers
import Photos
import MobileCoreServices

/// Comprehensive file attachment manager for Signal iOS
final class FileAttachmentManager: NSObject {
    
    // MARK: - Properties
    
    static let shared = FileAttachmentManager()
    
    private let fileManager = FileManager.default
    private let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxImageDimension: CGFloat = 4096
    private let imageCompressionQuality: CGFloat = 0.8
    
    private let attachmentsDirectory: URL
    private let tempDirectory: URL
    private let thumbnailDirectory: URL
    
    // MARK: - Initialization
    
    override init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        self.attachmentsDirectory = documentsURL.appendingPathComponent("Attachments")
        self.tempDirectory = documentsURL.appendingPathComponent("Temp")
        self.thumbnailDirectory = documentsURL.appendingPathComponent("Thumbnails")
        
        super.init()
        
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        for directory in [attachmentsDirectory, tempDirectory, thumbnailDirectory] {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Attachment Processing
    
    func processAttachment(_ attachment: AttachmentInput) async -> AttachmentProcessingResult {
        do {
            // Validate file size
            let fileSize = try getFileSize(for: attachment)
            guard fileSize <= maxFileSize else {
                return .failure(.fileTooLarge(size: fileSize, maxSize: maxFileSize))
            }
            
            // Determine attachment type
            let attachmentType = determineAttachmentType(for: attachment)
            
            // Process based on type
            switch attachmentType {
            case .image:
                return await processImageAttachment(attachment)
            case .video:
                return await processVideoAttachment(attachment)
            case .audio:
                return await processAudioAttachment(attachment)
            case .document:
                return await processDocumentAttachment(attachment)
            case .unknown:
                return .failure(.unsupportedFileType)
            }
            
        } catch {
            return .failure(.processingFailed(error))
        }
    }
    
    // MARK: - Image Processing
    
    private func processImageAttachment(_ input: AttachmentInput) async -> AttachmentProcessingResult {
        do {
            let originalImage: UIImage
            
            switch input {
            case .data(let data, let filename, _):
                guard let image = UIImage(data: data) else {
                    return .failure(.invalidImageData)
                }
                originalImage = image
                
            case .url(let url):
                let data = try Data(contentsOf: url)
                guard let image = UIImage(data: data) else {
                    return .failure(.invalidImageData)
                }
                originalImage = image
                
            case .asset(let asset):
                guard let image = await loadImageFromAsset(asset) else {
                    return .failure(.assetLoadingFailed)
                }
                originalImage = image
            }
            
            // Resize and compress if needed
            let processedImage = await processImage(originalImage)
            
            // Convert to JPEG
            guard let imageData = processedImage.jpegData(compressionQuality: imageCompressionQuality) else {
                return .failure(.imageCompressionFailed)
            }
            
            // Save to attachments directory
            let filename = generateUniqueFilename(extension: "jpg")
            let fileURL = attachmentsDirectory.appendingPathComponent(filename)
            
            try imageData.write(to: fileURL)
            
            // Generate thumbnail
            let thumbnailURL = try await generateThumbnail(for: fileURL, type: .image)
            
            let processedAttachment = ProcessedAttachment(
                id: UUID().uuidString,
                type: .image,
                originalURL: fileURL,
                thumbnailURL: thumbnailURL,
                fileSize: Int64(imageData.count),
                mimeType: "image/jpeg",
                filename: filename,
                dimensions: CGSize(width: processedImage.size.width, height: processedImage.size.height),
                duration: nil
            )
            
            return .success(processedAttachment)
            
        } catch {
            return .failure(.processingFailed(error))
        }
    }
    
    private func processImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let processedImage = self.resizeImageIfNeeded(image)
                continuation.resume(returning: processedImage)
            }
        }
    }
    
    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        let maxDimension = max(image.size.width, image.size.height)
        
        guard maxDimension > maxImageDimension else {
            return image
        }
        
        let scale = maxImageDimension / maxDimension
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    // MARK: - Video Processing
    
    private func processVideoAttachment(_ input: AttachmentInput) async -> AttachmentProcessingResult {
        do {
            let sourceURL: URL
            
            switch input {
            case .data(let data, let filename, _):
                // Write data to temp file first
                let tempURL = tempDirectory.appendingPathComponent(filename ?? "video.mp4")
                try data.write(to: tempURL)
                sourceURL = tempURL
                
            case .url(let url):
                sourceURL = url
                
            case .asset(let asset):
                guard let url = await exportVideoFromAsset(asset) else {
                    return .failure(.assetLoadingFailed)
                }
                sourceURL = url
            }
            
            // Move/copy to attachments directory
            let filename = generateUniqueFilename(extension: "mp4")
            let finalURL = attachmentsDirectory.appendingPathComponent(filename)
            
            if sourceURL.path.hasPrefix(tempDirectory.path) {
                try fileManager.moveItem(at: sourceURL, to: finalURL)
            } else {
                try fileManager.copyItem(at: sourceURL, to: finalURL)
            }
            
            // Get video metadata
            let metadata = try await getVideoMetadata(from: finalURL)
            
            // Generate thumbnail
            let thumbnailURL = try await generateVideoThumbnail(from: finalURL)
            
            let processedAttachment = ProcessedAttachment(
                id: UUID().uuidString,
                type: .video,
                originalURL: finalURL,
                thumbnailURL: thumbnailURL,
                fileSize: try getFileSize(at: finalURL),
                mimeType: "video/mp4",
                filename: filename,
                dimensions: metadata.dimensions,
                duration: metadata.duration
            )
            
            return .success(processedAttachment)
            
        } catch {
            return .failure(.processingFailed(error))
        }
    }
    
    // MARK: - Audio Processing
    
    private func processAudioAttachment(_ input: AttachmentInput) async -> AttachmentProcessingResult {
        do {
            let sourceURL: URL
            
            switch input {
            case .data(let data, let filename, _):
                let tempURL = tempDirectory.appendingPathComponent(filename ?? "audio.m4a")
                try data.write(to: tempURL)
                sourceURL = tempURL
                
            case .url(let url):
                sourceURL = url
                
            case .asset(let asset):
                guard let url = await exportAudioFromAsset(asset) else {
                    return .failure(.assetLoadingFailed)
                }
                sourceURL = url
            }
            
            // Move to attachments directory
            let filename = generateUniqueFilename(extension: sourceURL.pathExtension)
            let finalURL = attachmentsDirectory.appendingPathComponent(filename)
            
            if sourceURL.path.hasPrefix(tempDirectory.path) {
                try fileManager.moveItem(at: sourceURL, to: finalURL)
            } else {
                try fileManager.copyItem(at: sourceURL, to: finalURL)
            }
            
            // Get audio metadata
            let duration = try await getAudioDuration(from: finalURL)
            
            let processedAttachment = ProcessedAttachment(
                id: UUID().uuidString,
                type: .audio,
                originalURL: finalURL,
                thumbnailURL: nil,
                fileSize: try getFileSize(at: finalURL),
                mimeType: getMimeType(for: finalURL),
                filename: filename,
                dimensions: nil,
                duration: duration
            )
            
            return .success(processedAttachment)
            
        } catch {
            return .failure(.processingFailed(error))
        }
    }
    
    // MARK: - Document Processing
    
    private func processDocumentAttachment(_ input: AttachmentInput) async -> AttachmentProcessingResult {
        do {
            let sourceURL: URL
            let originalFilename: String
            
            switch input {
            case .data(let data, let filename, _):
                originalFilename = filename ?? "document"
                let tempURL = tempDirectory.appendingPathComponent(originalFilename)
                try data.write(to: tempURL)
                sourceURL = tempURL
                
            case .url(let url):
                sourceURL = url
                originalFilename = url.lastPathComponent
                
            case .asset:
                return .failure(.unsupportedAssetType)
            }
            
            // Copy to attachments directory with unique name
            let filename = generateUniqueFilename(baseName: originalFilename)
            let finalURL = attachmentsDirectory.appendingPathComponent(filename)
            
            if sourceURL.path.hasPrefix(tempDirectory.path) {
                try fileManager.moveItem(at: sourceURL, to: finalURL)
            } else {
                try fileManager.copyItem(at: sourceURL, to: finalURL)
            }
            
            // Try to generate thumbnail for documents
            let thumbnailURL = try? await generateDocumentThumbnail(from: finalURL)
            
            let processedAttachment = ProcessedAttachment(
                id: UUID().uuidString,
                type: .document,
                originalURL: finalURL,
                thumbnailURL: thumbnailURL,
                fileSize: try getFileSize(at: finalURL),
                mimeType: getMimeType(for: finalURL),
                filename: filename,
                dimensions: nil,
                duration: nil
            )
            
            return .success(processedAttachment)
            
        } catch {
            return .failure(.processingFailed(error))
        }
    }
    
    // MARK: - Asset Loading
    
    private func loadImageFromAsset(_ asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func exportVideoFromAsset(_ asset: PHAsset) async -> URL? {
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestExportSession(
                forVideo: asset,
                options: options,
                exportPreset: AVAssetExportPresetMediumQuality
            ) { exportSession, _ in
                guard let exportSession = exportSession else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let filename = self.generateUniqueFilename(extension: "mp4")
                let outputURL = self.tempDirectory.appendingPathComponent(filename)
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                
                exportSession.exportAsynchronously {
                    if exportSession.status == .completed {
                        continuation.resume(returning: outputURL)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    private func exportAudioFromAsset(_ asset: PHAsset) async -> URL? {
        // Similar implementation for audio assets
        return nil // Placeholder
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateThumbnail(for fileURL: URL, type: AttachmentType) async throws -> URL? {
        switch type {
        case .image:
            return try await generateImageThumbnail(from: fileURL)
        case .video:
            return try await generateVideoThumbnail(from: fileURL)
        case .document:
            return try await generateDocumentThumbnail(from: fileURL)
        case .audio:
            return nil
        case .unknown:
            return nil
        }
    }
    
    private func generateImageThumbnail(from fileURL: URL) async throws -> URL {
        let data = try Data(contentsOf: fileURL)
        guard let originalImage = UIImage(data: data) else {
            throw AttachmentError.thumbnailGenerationFailed
        }
        
        let thumbnailSize = CGSize(width: 150, height: 150)
        let thumbnailImage = await resizeImage(originalImage, to: thumbnailSize)
        
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) else {
            throw AttachmentError.thumbnailGenerationFailed
        }
        
        let thumbnailFilename = "thumb_\(generateUniqueFilename(extension: "jpg"))"
        let thumbnailURL = thumbnailDirectory.appendingPathComponent(thumbnailFilename)
        
        try thumbnailData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    private func generateVideoThumbnail(from fileURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let asset = AVAsset(url: fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            
            generator.generateCGImageAsynchronously(for: time) { _, cgImage, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: AttachmentError.thumbnailGenerationFailed)
                    return
                }
                
                let image = UIImage(cgImage: cgImage)
                
                Task {
                    let thumbnailImage = await self.resizeImage(image, to: CGSize(width: 150, height: 150))
                    
                    guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) else {
                        continuation.resume(throwing: AttachmentError.thumbnailGenerationFailed)
                        return
                    }
                    
                    let thumbnailFilename = "thumb_\(self.generateUniqueFilename(extension: "jpg"))"
                    let thumbnailURL = self.thumbnailDirectory.appendingPathComponent(thumbnailFilename)
                    
                    do {
                        try thumbnailData.write(to: thumbnailURL)
                        continuation.resume(returning: thumbnailURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func generateDocumentThumbnail(from fileURL: URL) async throws -> URL? {
        // For PDF documents, we could generate a thumbnail of the first page
        // This is a simplified implementation
        return nil
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: size))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
                
                continuation.resume(returning: resizedImage)
            }
        }
    }
    
    // MARK: - Metadata Extraction
    
    private func getVideoMetadata(from url: URL) async throws -> (dimensions: CGSize, duration: TimeInterval) {
        let asset = AVAsset(url: url)
        
        async let duration = try await asset.load(.duration).seconds
        async let tracks = try await asset.loadTracks(withMediaType: .video)
        
        let durationValue = try await duration
        let videoTracks = try await tracks
        
        guard let videoTrack = videoTracks.first else {
            return (CGSize.zero, durationValue)
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        return (naturalSize, durationValue)
    }
    
    private func getAudioDuration(from url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
    
    // MARK: - File Utilities
    
    private func getFileSize(for attachment: AttachmentInput) throws -> Int64 {
        switch attachment {
        case .data(let data, _, _):
            return Int64(data.count)
        case .url(let url):
            return try getFileSize(at: url)
        case .asset(let asset):
            // For assets, we'll get the size after processing
            return 0
        }
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func determineAttachmentType(for attachment: AttachmentInput) -> AttachmentType {
        switch attachment {
        case .data(_, let filename, let mimeType):
            if let mimeType = mimeType {
                return attachmentType(from: mimeType)
            } else if let filename = filename {
                return attachmentType(from: filename)
            }
            return .unknown
            
        case .url(let url):
            return attachmentType(from: url.pathExtension)
            
        case .asset(let asset):
            switch asset.mediaType {
            case .image:
                return .image
            case .video:
                return .video
            case .audio:
                return .audio
            default:
                return .unknown
            }
        }
    }
    
    private func attachmentType(from mimeType: String) -> AttachmentType {
        if mimeType.hasPrefix("image/") {
            return .image
        } else if mimeType.hasPrefix("video/") {
            return .video
        } else if mimeType.hasPrefix("audio/") {
            return .audio
        } else {
            return .document
        }
    }
    
    private func attachmentType(from filename: String) -> AttachmentType {
        let pathExtension = URL(fileURLWithPath: filename).pathExtension.lowercased()
        
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif"]
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "webm"]
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg"]
        
        if imageExtensions.contains(pathExtension) {
            return .image
        } else if videoExtensions.contains(pathExtension) {
            return .video
        } else if audioExtensions.contains(pathExtension) {
            return .audio
        } else {
            return .document
        }
    }
    
    private func getMimeType(for url: URL) -> String {
        if #available(iOS 14.0, *) {
            if let utType = UTType(filenameExtension: url.pathExtension) {
                return utType.preferredMIMEType ?? "application/octet-stream"
            }
        }
        return "application/octet-stream"
    }
    
    private func generateUniqueFilename(extension fileExtension: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        return "\(timestamp)_\(uuid).\(fileExtension)"
    }
    
    private func generateUniqueFilename(baseName: String) -> String {
        let url = URL(fileURLWithPath: baseName)
        let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        
        if fileExtension.isEmpty {
            return "\(nameWithoutExtension)_\(timestamp)_\(uuid)"
        } else {
            return "\(nameWithoutExtension)_\(timestamp)_\(uuid).\(fileExtension)"
        }
    }
    
    // MARK: - Cleanup
    
    func deleteAttachment(_ attachment: ProcessedAttachment) {
        do {
            try fileManager.removeItem(at: attachment.originalURL)
            
            if let thumbnailURL = attachment.thumbnailURL {
                try fileManager.removeItem(at: thumbnailURL)
            }
            
            Logger.info("Deleted attachment: \(attachment.id)")
            
        } catch {
            Logger.error("Failed to delete attachment: \(error)")
        }
    }
    
    func cleanupTempFiles() {
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in tempFiles {
                try fileManager.removeItem(at: fileURL)
            }
            
            Logger.info("Cleaned up \(tempFiles.count) temp files")
            
        } catch {
            Logger.error("Failed to cleanup temp files: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum AttachmentInput {
    case data(Data, filename: String?, mimeType: String?)
    case url(URL)
    case asset(PHAsset)
}

enum AttachmentType {
    case image
    case video
    case audio
    case document
    case unknown
}

struct ProcessedAttachment {
    let id: String
    let type: AttachmentType
    let originalURL: URL
    let thumbnailURL: URL?
    let fileSize: Int64
    let mimeType: String
    let filename: String
    let dimensions: CGSize?
    let duration: TimeInterval?
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum AttachmentProcessingResult {
    case success(ProcessedAttachment)
    case failure(AttachmentError)
}

enum AttachmentError: LocalizedError {
    case fileTooLarge(size: Int64, maxSize: Int64)
    case unsupportedFileType
    case invalidImageData
    case imageCompressionFailed
    case thumbnailGenerationFailed
    case assetLoadingFailed
    case processingFailed(Error)
    case unsupportedAssetType
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let size, let maxSize):
            let formatter = ByteCountFormatter()
            return "File size (\(formatter.string(fromByteCount: size))) exceeds maximum allowed size (\(formatter.string(fromByteCount: maxSize)))"
        case .unsupportedFileType:
            return "Unsupported file type"
        case .invalidImageData:
            return "Invalid image data"
        case .imageCompressionFailed:
            return "Image compression failed"
        case .thumbnailGenerationFailed:
            return "Thumbnail generation failed"
        case .assetLoadingFailed:
            return "Failed to load asset"
        case .processingFailed(let error):
            return "Processing failed: \(error.localizedDescription)"
        case .unsupportedAssetType:
            return "Unsupported asset type"
        }
    }
}