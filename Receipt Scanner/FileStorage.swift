//
//  FileStorage.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import Foundation
import UIKit
import CoreData
import Combine
import Compression

// MARK: - Storage Manager

class StorageManager: ObservableObject {
    @Published var receipts: [Receipt] = []
    @Published var reports: [Report] = []
    
    private var cancellables = Set<AnyCancellable>()
    static let shared = StorageManager()
    
    private let persistenceController = PersistenceController.shared
    private let fileManager = FileManager.default
    
    private init() {
        refreshReceipts()
        refreshReports()
    }
    
    // MARK: - Image Storage
    
    func saveReceiptImage(_ image: UIImage, compressionQuality: CGFloat = 0.6) -> (imageURL: URL?, thumbnailURL: URL?) {
        guard let documentsDirectory = documentsDirectory() else { 
            print("Error: Could not access documents directory")
            return (nil, nil) 
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        
        // Save full image
        let imageFilename = "receipt_\(timestamp)_\(uuid).jpg"
        let imageURL = documentsDirectory.appendingPathComponent(imageFilename)
        
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else { 
            print("Error: Could not convert image to JPEG data")
            return (nil, nil) 
        }
        
        do {
            try imageData.write(to: imageURL, options: [.atomic])
            print("Successfully saved image to: \(imageURL.path)")
        } catch {
            print("Failed to save receipt image: \(error)")
            return (nil, nil)
        }
        
        // Create and save thumbnail
        let thumbnailFilename = "thumb_\(timestamp)_\(uuid).jpg"
        let thumbnailURL = documentsDirectory.appendingPathComponent(thumbnailFilename)
        
        if let thumbnailData = createThumbnail(from: image, maxSize: CGSize(width: 200, height: 200))?.jpegData(compressionQuality: 0.8) {
            do {
                try thumbnailData.write(to: thumbnailURL, options: [.atomic])
                print("Successfully saved thumbnail to: \(thumbnailURL.path)")
                return (imageURL, thumbnailURL)
            } catch {
                print("Failed to save thumbnail: \(error)")
                // If thumbnail fails, still return the main image
                return (imageURL, nil)
            }
        }
        
        return (imageURL, nil)
    }
    
    private func createThumbnail(from image: UIImage, maxSize: CGSize) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        var thumbnailSize = maxSize
        
        if aspectRatio > 1 {
            thumbnailSize.height = maxSize.width / aspectRatio
        } else {
            thumbnailSize.width = maxSize.height * aspectRatio
        }
        
        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail
    }
    
    // MARK: - ZIP Compression System
    
    /// Saves receipt image and thumbnail as a compressed ZIP archive
    func saveReceiptImageAsZip(_ image: UIImage, compressionQuality: CGFloat = 0.6) -> (zipURL: URL?, originalSize: Int64, compressedSize: Int64) {
        guard let documentsDirectory = documentsDirectory() else { 
            print("Error: Could not access documents directory")
            return (nil, 0, 0) 
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        
        // Create JPEG data for full image
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else { 
            print("Error: Could not convert image to JPEG data")
            return (nil, 0, 0) 
        }
        
        // Create thumbnail
        guard let thumbnail = createThumbnail(from: image, maxSize: CGSize(width: 200, height: 200)),
              let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) else {
            print("Error: Could not create thumbnail")
            return (nil, 0, 0)
        }
        
        // Create ZIP archive
        let zipFilename = "receipt_\(timestamp)_\(uuid).zip"
        let zipURL = documentsDirectory.appendingPathComponent(zipFilename)
        
        do {
            let zipData = try createZipArchive(imageData: imageData, thumbnailData: thumbnailData)
            try zipData.write(to: zipURL, options: [.atomic])
            
            let originalSize = Int64(imageData.count + thumbnailData.count)
            let compressedSize = Int64(zipData.count)
            let compressionRatio = Double(compressedSize) / Double(originalSize) * 100
            
            print("Successfully saved ZIP archive: \(zipURL.path)")
            print("Original size: \(originalSize) bytes, Compressed size: \(compressedSize) bytes")
            print("Compression ratio: \(String(format: "%.1f", compressionRatio))%")
            
            return (zipURL, originalSize, compressedSize)
        } catch {
            print("Failed to create ZIP archive: \(error)")
            return (nil, 0, 0)
        }
    }
    
    /// Creates a ZIP archive containing image and thumbnail data
    private func createZipArchive(imageData: Data, thumbnailData: Data) throws -> Data {
        // Create a temporary directory for ZIP contents
        let tempDir = FileManager.default.temporaryDirectory
        let tempFolder = tempDir.appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        
        // Write image files to temp directory
        let imageFile = tempFolder.appendingPathComponent("image.jpg")
        let thumbnailFile = tempFolder.appendingPathComponent("thumbnail.jpg")
        
        try imageData.write(to: imageFile)
        try thumbnailData.write(to: thumbnailFile)
        
        // Create ZIP archive
        let zipData = try createZipFromDirectory(tempFolder)
        
        // Clean up temp directory
        try FileManager.default.removeItem(at: tempFolder)
        
        return zipData
    }
    
    /// Creates ZIP data from a directory
    private func createZipFromDirectory(_ directory: URL) throws -> Data {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        
        var zipData = Data()
        
        // Simple ZIP header
        let zipHeader = "PK" + String(Character(UnicodeScalar(0x03)!)) + String(Character(UnicodeScalar(0x04)!)) // ZIP file signature
        zipData.append(zipHeader.data(using: .ascii)!)
        
        // Add each file to ZIP
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            let fileData = try Data(contentsOf: fileURL)
            
            // Compress file data using iOS Compression framework
            let compressedData = try compressData(fileData)
            
            // Add file entry to ZIP
            let fileEntry = createZipFileEntry(fileName: fileName, data: compressedData, originalSize: fileData.count)
            zipData.append(fileEntry)
        }
        
        // Add ZIP central directory
        let centralDir = createZipCentralDirectory(entries: contents)
        zipData.append(centralDir)
        
        return zipData
    }
    
    /// Compresses data using iOS Compression framework
    private func compressData(_ data: Data) throws -> Data {
        let bufferSize = data.count
        let compressedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { compressedBuffer.deallocate() }
        
        let compressedSize = compression_encode_buffer(
            compressedBuffer, bufferSize,
            data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, data.count,
            nil, COMPRESSION_ZLIB
        )
        
        guard compressedSize > 0 else {
            throw CompressionError.compressionFailed
        }
        
        return Data(bytes: compressedBuffer, count: compressedSize)
    }
    
    /// Decompresses data using iOS Compression framework
    private func decompressData(_ data: Data, originalSize: Int) throws -> Data {
        let bufferSize = originalSize
        let decompressedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { decompressedBuffer.deallocate() }
        
        let decompressedSize = compression_decode_buffer(
            decompressedBuffer, bufferSize,
            data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, data.count,
            nil, COMPRESSION_ZLIB
        )
        
        guard decompressedSize > 0 else {
            throw CompressionError.decompressionFailed
        }
        
        return Data(bytes: decompressedBuffer, count: decompressedSize)
    }
    
    /// Creates a ZIP file entry
    private func createZipFileEntry(fileName: String, data: Data, originalSize: Int) -> Data {
        var entry = Data()
        
        // Local file header signature
        let headerSig = "PK" + String(Character(UnicodeScalar(0x03)!)) + String(Character(UnicodeScalar(0x04)!))
        entry.append(headerSig.data(using: .ascii)!)
        
        // Version needed to extract (2.0)
        entry.append(Data([0x14, 0x00]))
        
        // General purpose bit flag
        entry.append(Data([0x00, 0x00]))
        
        // Compression method (deflate)
        entry.append(Data([0x08, 0x00]))
        
        // Last mod file time
        entry.append(Data([0x00, 0x00]))
        
        // Last mod file date
        entry.append(Data([0x00, 0x00]))
        
        // CRC-32 (simplified - would need proper calculation in production)
        entry.append(Data([0x00, 0x00, 0x00, 0x00]))
        
        // Compressed size
        let compressedSize = UInt32(data.count)
        entry.append(Data([
            UInt8(compressedSize & 0xFF),
            UInt8((compressedSize >> 8) & 0xFF),
            UInt8((compressedSize >> 16) & 0xFF),
            UInt8((compressedSize >> 24) & 0xFF)
        ]))
        
        // Uncompressed size
        let uncompressedSize = UInt32(originalSize)
        entry.append(Data([
            UInt8(uncompressedSize & 0xFF),
            UInt8((uncompressedSize >> 8) & 0xFF),
            UInt8((uncompressedSize >> 16) & 0xFF),
            UInt8((uncompressedSize >> 24) & 0xFF)
        ]))
        
        // File name length
        let fileNameLength = UInt16(fileName.utf8.count)
        entry.append(Data([
            UInt8(fileNameLength & 0xFF),
            UInt8((fileNameLength >> 8) & 0xFF)
        ]))
        
        // Extra field length
        entry.append(Data([0x00, 0x00]))
        
        // File name
        entry.append(fileName.data(using: .utf8)!)
        
        // File data
        entry.append(data)
        
        return entry
    }
    
    /// Creates ZIP central directory
    private func createZipCentralDirectory(entries: [URL]) -> Data {
        var centralDir = Data()
        
        for entry in entries {
            // Central directory file header signature
            let centralSig = "PK" + String(Character(UnicodeScalar(0x01)!)) + String(Character(UnicodeScalar(0x02)!))
            centralDir.append(centralSig.data(using: .ascii)!)
            
            // Version made by
            centralDir.append(Data([0x14, 0x00]))
            
            // Version needed to extract
            centralDir.append(Data([0x14, 0x00]))
            
            // General purpose bit flag
            centralDir.append(Data([0x00, 0x00]))
            
            // Compression method
            centralDir.append(Data([0x08, 0x00]))
            
            // Last mod file time
            centralDir.append(Data([0x00, 0x00]))
            
            // Last mod file date
            centralDir.append(Data([0x00, 0x00]))
            
            // CRC-32
            centralDir.append(Data([0x00, 0x00, 0x00, 0x00]))
            
            // Compressed size
            centralDir.append(Data([0x00, 0x00, 0x00, 0x00]))
            
            // Uncompressed size
            centralDir.append(Data([0x00, 0x00,  0x00, 0x00]))
            
            // File name length
            let fileNameLength = UInt16(entry.lastPathComponent.utf8.count)
            centralDir.append(Data([
                UInt8(fileNameLength & 0xFF),
                UInt8((fileNameLength >> 8) & 0xFF)
            ]))
            
            // Extra field length
            centralDir.append(Data([0x00, 0x00]))
            
            // Comment length
            centralDir.append(Data([0x00, 0x00]))
            
            // Disk number start
            centralDir.append(Data([0x00, 0x00]))
            
            // Internal file attributes
            centralDir.append(Data([0x00, 0x00]))
            
            // External file attributes
            centralDir.append(Data([0x00, 0x00, 0x00, 0x00]))
            
            // Relative offset of local header
            centralDir.append(Data([0x00, 0x00, 0x00, 0x00]))
            
            // File name
            centralDir.append(entry.lastPathComponent.data(using: .utf8)!)
        }
        
        // End of central directory record
        let endSig = "PK" + String(Character(UnicodeScalar(0x05)!)) + String(Character(UnicodeScalar(0x06)!))
        centralDir.append(endSig.data(using: .ascii)!)
        
        // Number of this disk
        centralDir.append(Data([0x00, 0x00]))
        
        // Number of the disk with the start of the central directory
        centralDir.append(Data([0x00, 0x00]))
        
        // Total number of entries in the central directory on this disk
        let entryCount = UInt16(entries.count)
        centralDir.append(Data([
            UInt8(entryCount & 0xFF),
            UInt8((entryCount >> 8) & 0xFF)
        ]))
        
        // Total number of entries in the central directory
        centralDir.append(Data([
            UInt8(entryCount & 0xFF),
            UInt8((entryCount >> 8) & 0xFF)
        ]))
        
        // Size of the central directory
        centralDir.append(Data([0x00, 0x00, 0x00, 0x00]))
        
        // Offset of start of central directory with respect to the starting disk number
        centralDir.append(Data([0x00, 0x00, 0x00, 0x00]))
        
        // ZIP file comment length
        centralDir.append(Data([0x00, 0x00]))
        
        return centralDir
    }
    
    /// Loads image from ZIP archive
    func loadImageFromZip(zipURL: URL) -> UIImage? {
        do {
            print("Loading ZIP file from: \(zipURL.path)")
            let zipData = try Data(contentsOf: zipURL)
            print("ZIP data loaded, size: \(zipData.count) bytes")
            
            // Try to extract image
            let imageData = try extractImageFromZip(zipData: zipData)
            print("Image data extracted, size: \(imageData.count) bytes")
            
            guard let image = UIImage(data: imageData) else {
                print("Failed to create UIImage from extracted data")
                return nil
            }
            
            print("Successfully created UIImage from ZIP: \(image.size)")
            return image
        } catch {
            print("Failed to load image from ZIP: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Loads thumbnail from ZIP archive
    func loadThumbnailFromZip(zipURL: URL) -> UIImage? {
        do {
            let zipData = try Data(contentsOf: zipURL)
            let thumbnailData = try extractThumbnailFromZip(zipData: zipData)
            return UIImage(data: thumbnailData)
        } catch {
            print("Failed to load thumbnail from ZIP: \(error)")
            return nil
        }
    }
    
    /// Extracts image data from ZIP archive
    private func extractImageFromZip(zipData: Data) throws -> Data {
        // Parse ZIP structure to find and extract image.jpg
        let imageSignature = "image.jpg"
        guard let imageStartRange = zipData.range(of: imageSignature.data(using: .utf8)!) else {
            print("Could not find 'image.jpg' signature in ZIP data")
            throw CompressionError.fileNotFound
        }
        
        // Find the start of the local file header for this entry
        // Look backwards for the ZIP local file header signature (PK\x03\x04)
        let zipHeader: [UInt8] = [0x50, 0x4B, 0x03, 0x04] // "PK.."
        let zipHeaderData = Data(zipHeader)
        
        // Search backwards from filename to find the header
        let filenameStartOffset = zipData.distance(from: zipData.startIndex, to: imageStartRange.lowerBound)
        let maxSearchBack = min(300, filenameStartOffset) // Local file header is typically within 300 bytes
        
        var headerOffset = 0
        
        if maxSearchBack > 0 {
            let searchStart = filenameStartOffset - maxSearchBack
            let searchRange = zipData.subdata(in: searchStart..<filenameStartOffset)
            if let headerRange = searchRange.range(of: zipHeaderData, options: .backwards) {
                let relativeOffset = searchRange.distance(from: searchRange.startIndex, to: headerRange.lowerBound)
                headerOffset = searchStart + relativeOffset
            } else {
                // If we can't find header, assume it's right before filename (simplified ZIP format)
                headerOffset = max(0, filenameStartOffset - 100)
            }
        }
        
        // Local file header structure (offset from header start):
        // 0-3: Signature (already found)
        // 4-5: Version (2 bytes)
        // 6-7: General purpose bit flag (2 bytes)
        // 8-9: Compression method (2 bytes)
        // 10-11: Last mod time (2 bytes)
        // 12-13: Last mod date (2 bytes)
        // 14-17: CRC-32 (4 bytes)
        // 18-21: Compressed size (4 bytes, little-endian)
        // 22-25: Uncompressed size (4 bytes, little-endian)
        // 26-27: File name length (2 bytes, little-endian)
        // 28-29: Extra field length (2 bytes, little-endian)
        // 30+: File name + Extra field + Compressed data
        
        // Read values from ZIP header using byte array access
        guard headerOffset + 30 <= zipData.count else {
            throw CompressionError.invalidZipFormat
        }
        
        let headerBytes = zipData.subdata(in: headerOffset..<min(headerOffset + 100, zipData.count))
        let bytes = [UInt8](headerBytes)
        
        guard bytes.count >= 30 else {
            throw CompressionError.invalidZipFormat
        }
        
        // Read compressed size (offset 18-21, little-endian)
        let compressedSize = UInt32(bytes[18]) |
                             (UInt32(bytes[19]) << 8) |
                             (UInt32(bytes[20]) << 16) |
                             (UInt32(bytes[21]) << 24)
        
        // Read uncompressed size (offset 22-25, little-endian)
        let uncompressedSize = UInt32(bytes[22]) |
                               (UInt32(bytes[23]) << 8) |
                               (UInt32(bytes[24]) << 16) |
                               (UInt32(bytes[25]) << 24)
        
        // Read filename length (offset 26-27, little-endian)
        let filenameLength = UInt16(bytes[26]) | (UInt16(bytes[27]) << 8)
        
        // Read extra field length (offset 28-29, little-endian)
        let extraFieldLength = UInt16(bytes[28]) | (UInt16(bytes[29]) << 8)
        
        // Calculate where compressed data starts (after header + filename + extra field)
        let dataStartOffset = headerOffset + 30 + Int(filenameLength) + Int(extraFieldLength)
        let dataEndOffset = dataStartOffset + Int(compressedSize)
        
        guard dataEndOffset <= zipData.count else {
            throw CompressionError.invalidZipFormat
        }
        
        // Extract compressed data
        let compressedData = zipData.subdata(in: dataStartOffset..<dataEndOffset)
        print("Found compressed image data: \(compressedData.count) bytes (uncompressed: \(uncompressedSize) bytes)")
        
        // Decompress the data
        let decompressedData = try decompressData(compressedData, originalSize: Int(uncompressedSize))
        print("Decompressed image data: \(decompressedData.count) bytes")
        
        // Verify it's a valid JPEG
        let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]
        if !decompressedData.prefix(3).elementsEqual(jpegMagic) {
            print("Warning: Decompressed data doesn't start with JPEG magic bytes")
            // Still return it, as it might be valid
        }
        
        return decompressedData
    }
    
    /// Extracts thumbnail data from ZIP archive
    private func extractThumbnailFromZip(zipData: Data) throws -> Data {
        let thumbnailSignature = "thumbnail.jpg"
        guard let thumbnailStart = zipData.range(of: thumbnailSignature.data(using: .utf8)!) else {
            throw CompressionError.fileNotFound
        }
        
        let dataStart = thumbnailStart.upperBound
        let thumbnailData = zipData.subdata(in: dataStart..<zipData.count)
        
        return thumbnailData
    }
    
    // MARK: - Receipt Management
    
    func saveReceipt(
        merchantName: String?,
        amount: Double,
        currency: String,
        date: Date,
        category: String,
        categoryEmoji: String,
        paymentMethod: String,
        paymentEmoji: String,
        isTaxDeductible: Bool,
        tags: [String],
        notes: String,
        imageURL: URL?,
        thumbnailURL: URL?,
        recognizedText: String?,
        isManualEntry: Bool
    ) -> Receipt? {
        let context = persistenceController.container.viewContext
        
        // Validate amount is not negative
        guard amount >= 0 else {
            print("Error: Amount cannot be negative")
            return nil
        }
        
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.merchantName = merchantName
        receipt.amount = amount
        receipt.currency = currency.isEmpty ? "USD" : currency
        receipt.date = date // Ensure date is set (required field)
        receipt.category = category.isEmpty ? "Other" : category
        receipt.categoryEmoji = categoryEmoji.isEmpty ? "🗂️" : categoryEmoji
        receipt.paymentMethod = paymentMethod.isEmpty ? "Other" : paymentMethod
        receipt.paymentEmoji = paymentEmoji.isEmpty ? "❓" : paymentEmoji
        receipt.isTaxDeductible = isTaxDeductible
        receipt.tags = tags.joined(separator: ",")
        receipt.notes = notes
        receipt.imageURL = imageURL
        receipt.thumbnailURL = thumbnailURL
        receipt.recognizedText = recognizedText
        receipt.isManualEntry = isManualEntry
        receipt.createdAt = Date()
        receipt.updatedAt = Date()
        
        // Validate required fields before saving
        guard receipt.id != nil else {
            print("Error: Receipt ID is nil")
            context.rollback()
            return nil
        }
        
        guard receipt.date != nil else {
            print("Error: Receipt date is nil")
            context.rollback()
            return nil
        }
        
        // Set compression metadata
        if let imageURL = imageURL {
            if imageURL.pathExtension.lowercased() == "zip" {
                receipt.compressionType = "zip"
                // Get file sizes for compression metadata
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: imageURL.path)
                    receipt.compressedFileSize = attributes[.size] as? Int64 ?? 0
                    // Estimate original size (ZIP typically compresses to 60-70% of original)
                    if receipt.compressedFileSize > 0 {
                        receipt.originalFileSize = Int64(Double(receipt.compressedFileSize) / 0.65)
                        receipt.compressionRatio = Double(receipt.compressedFileSize) / Double(receipt.originalFileSize)
                    } else {
                        receipt.originalFileSize = 0
                        receipt.compressionRatio = 0.0
                    }
                } catch {
                    receipt.compressionType = "zip"
                    receipt.originalFileSize = 0
                    receipt.compressedFileSize = 0
                    receipt.compressionRatio = 0.0
                }
            } else {
                receipt.compressionType = "none"
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: imageURL.path)
                    receipt.originalFileSize = attributes[.size] as? Int64 ?? 0
                    receipt.compressedFileSize = receipt.originalFileSize
                    receipt.compressionRatio = 1.0
                } catch {
                    receipt.originalFileSize = 0
                    receipt.compressedFileSize = 0
                    receipt.compressionRatio = 1.0
                }
            }
        } else {
            receipt.compressionType = "none"
            receipt.originalFileSize = 0
            receipt.compressedFileSize = 0
            receipt.compressionRatio = 1.0
        }
        
        do {
            try context.save()
            refreshReceipts()
            print("Successfully saved receipt: \(merchantName) - $\(amount)")
            return receipt
        } catch {
            let nsError = error as NSError
            print("Failed to save receipt: \(error)")
            print("Error details: \(nsError.userInfo)")
            
            // Log more specific error information
            if let validationErrors = nsError.userInfo[NSValidationKeyErrorKey] as? [String] {
                print("Validation errors: \(validationErrors)")
            }
            if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    print("Detailed error: \(detailedError.localizedDescription)")
                }
            }
            
            // Rollback the context to prevent corruption
            context.rollback()
            return nil
        }
    }
    
    func updateReceipt(
        receipt: Receipt,
        merchantName: String?,
        amount: Double,
        currency: String,
        date: Date,
        category: String,
        categoryEmoji: String,
        paymentMethod: String,
        paymentEmoji: String,
        isTaxDeductible: Bool,
        tags: [String],
        notes: String,
        imageURL: URL?,
        thumbnailURL: URL?
    ) -> Bool {
        let context = persistenceController.container.viewContext
        
        // Validate amount is not negative
        guard amount >= 0 else {
            print("Error: Amount cannot be negative")
            return false
        }
        
        // Update receipt properties
        receipt.merchantName = merchantName
        receipt.amount = amount
        receipt.currency = currency.isEmpty ? "USD" : currency
        receipt.date = date
        receipt.category = category.isEmpty ? "Other" : category
        receipt.categoryEmoji = categoryEmoji.isEmpty ? "🗂️" : categoryEmoji
        receipt.paymentMethod = paymentMethod.isEmpty ? "Other" : paymentMethod
        receipt.paymentEmoji = paymentEmoji.isEmpty ? "❓" : paymentEmoji
        receipt.isTaxDeductible = isTaxDeductible
        receipt.tags = tags.joined(separator: ",")
        receipt.notes = notes
        receipt.updatedAt = Date()
        
        // Only update image URLs if new ones are provided
        if let imageURL = imageURL {
            receipt.imageURL = imageURL
        }
        if let thumbnailURL = thumbnailURL {
            receipt.thumbnailURL = thumbnailURL
        }
        
        // Update compression metadata if image URL changed
        if let imageURL = imageURL {
            if imageURL.pathExtension.lowercased() == "zip" {
                receipt.compressionType = "zip"
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: imageURL.path)
                    receipt.compressedFileSize = attributes[.size] as? Int64 ?? 0
                    receipt.originalFileSize = Int64(Double(receipt.compressedFileSize) / 0.65)
                    receipt.compressionRatio = Double(receipt.compressedFileSize) / Double(receipt.originalFileSize)
                } catch {
                    receipt.compressionType = "zip"
                    receipt.originalFileSize = 0
                    receipt.compressedFileSize = 0
                    receipt.compressionRatio = 0.0
                }
            } else {
                receipt.compressionType = "none"
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: imageURL.path)
                    receipt.originalFileSize = attributes[.size] as? Int64 ?? 0
                    receipt.compressedFileSize = receipt.originalFileSize
                    receipt.compressionRatio = 1.0
                } catch {
                    receipt.originalFileSize = 0
                    receipt.compressedFileSize = 0
                    receipt.compressionRatio = 1.0
                }
            }
        }
        
        do {
            try context.save()
            refreshReceipts()
            print("Successfully updated receipt: \(merchantName ?? "Unknown") - $\(amount)")
            return true
        } catch {
            print("Failed to update receipt: \(error)")
            context.rollback()
            return false
        }
    }
    
    func fetchReceipts() -> [Receipt] {
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)]
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch receipts: \(error)")
            return []
        }
    }
    
    func fetchReceipts(filter: ReceiptFilter, searchText: String = "") -> [Receipt] {
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Apply search filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "merchantName CONTAINS[cd] %@ OR category CONTAINS[cd] %@ OR tags CONTAINS[cd] %@", searchText, searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        // Apply date filter
        switch filter {
        case .all:
            break
        case .thisMonth:
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            let datePredicate = NSPredicate(format: "date >= %@ AND date < %@", startOfMonth as NSDate, endOfMonth as NSDate)
            predicates.append(datePredicate)
        case .lastMonth:
            let calendar = Calendar.current
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            let startOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? lastMonth
            let endOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? lastMonth
            let datePredicate = NSPredicate(format: "date >= %@ AND date < %@", startOfMonth as NSDate, endOfMonth as NSDate)
            predicates.append(datePredicate)
        case .taxDeductible:
            predicates.append(NSPredicate(format: "isTaxDeductible == YES"))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)]
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch filtered receipts: \(error)")
            return []
        }
    }
    
    func deleteReceipt(_ receipt: Receipt) {
        let context = persistenceController.container.viewContext
        
        // Delete associated image files
        if let imageURL = receipt.imageURL {
            try? fileManager.removeItem(at: imageURL)
        }
        if let thumbnailURL = receipt.thumbnailURL {
            try? fileManager.removeItem(at: thumbnailURL)
        }
        
        context.delete(receipt)
        
        do {
            try context.save()
            refreshReceipts()
        } catch {
            print("Failed to delete receipt: \(error)")
        }
    }
    
    // MARK: - Report Management
    
    func saveReport(title: String, type: String, fileURL: URL, receiptCount: Int) -> Report? {
        let context = persistenceController.container.viewContext
        
        let report = Report(context: context)
        report.id = UUID()
        report.title = title
        report.type = type
        report.fileURL = fileURL
        report.createdAt = Date()
        report.receiptCount = Int32(receiptCount)
        
        // Get file size
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            report.fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            report.fileSize = 0
        }
        
        do {
            try context.save()
            refreshReports()
            return report
        } catch {
            print("Failed to save report: \(error)")
            return nil
        }
    }
    
    func fetchReports() -> [Report] {
        let request: NSFetchRequest<Report> = Report.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Report.createdAt, ascending: false)]
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch reports: \(error)")
            return []
        }
    }
    
    func deleteReport(_ report: Report) {
        let context = persistenceController.container.viewContext
        
        // Delete associated file
        try? fileManager.removeItem(at: report.fileURL!)
        
        context.delete(report)
        
        do {
            try context.save()
            refreshReports()
        } catch {
            print("Failed to delete report: \(error)")
        }
    }
    
    // MARK: - Recent Activity Methods
    
    func fetchRecentActivities(limit: Int = 5) -> [RecentActivityItem] {
        var activities: [RecentActivityItem] = []
        
        // Fetch recent receipts
        let receipts = fetchReceipts()
        for receipt in receipts.prefix(limit) {
            let activity = RecentActivityItem(
                type: .receipt,
                title: receipt.merchantName ?? "Unknown Merchant",
                subtitle: receipt.category ?? "Other",
                amount: receipt.amount,
                currency: receipt.currency,
                date: receipt.date ?? Date(),
                thumbnailURL: receipt.thumbnailURL,
                isManualEntry: receipt.isManualEntry
            )
            activities.append(activity)
        }
        
        // Fetch recent reports
        let reports = fetchReports()
        for report in reports.prefix(limit) {
            let activity = RecentActivityItem(
                type: .report,
                title: report.title ?? "Untitled Report",
                subtitle: "\(report.receiptCount) receipts",
                amount: nil,
                currency: nil,
                date: report.createdAt ?? Date(),
                thumbnailURL: nil,
                isManualEntry: false
            )
            activities.append(activity)
        }
        
        // Sort by date (most recent first) and limit results
        return activities
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }
    
    func getMonthlyStatistics() -> (totalAmount: Double, receiptCount: Int) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfMonth as NSDate, endOfMonth as NSDate)
        
        do {
            let receipts = try persistenceController.container.viewContext.fetch(request)
            let totalAmount = receipts.reduce(0) { $0 + $1.amount }
            return (totalAmount, receipts.count)
        } catch {
            print("Failed to fetch monthly statistics: \(error)")
            return (0, 0)
        }
    }
    
    func getTotalReceiptCount() -> Int {
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        
        do {
            let receipts = try persistenceController.container.viewContext.fetch(request)
            return receipts.count
        } catch {
            print("Failed to fetch total receipt count: \(error)")
            return 0
        }
    }
    
    // MARK: - Refresh Methods
    
    func refreshReceipts() {
        DispatchQueue.main.async {
            self.receipts = self.fetchReceipts()
        }
    }
    
    func refreshReports() {
        DispatchQueue.main.async {
            self.reports = self.fetchReports()
        }
    }
    
    // MARK: - Utility
    
    private func documentsDirectory() -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    func getStorageSize() -> Int64 {
        guard let documentsDirectory = documentsDirectory() else { return 0 }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            return contents.reduce(0) { total, url in
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    return total + (attributes[.size] as? Int64 ?? 0)
                } catch {
                    return total
                }
            }
        } catch {
            return 0
        }
    }
    
    // MARK: - Compression Testing
    
    /// Tests the ZIP compression system with a sample image
    func testCompressionSystem() {
        print("🧪 Testing ZIP compression system...")
        
        // Create a test image
        let testImage = createTestImage()
        
        // Test regular JPEG saving
        let regularResult = saveReceiptImage(testImage, compressionQuality: 0.7)
        let regularSize = regularResult.imageURL != nil ? getFileSize(url: regularResult.imageURL!) : 0
        
        // Test ZIP compression
        let zipResult = saveReceiptImageAsZip(testImage, compressionQuality: 0.7)
        let zipSize = zipResult.zipURL != nil ? getFileSize(url: zipResult.zipURL!) : 0
        
        // Calculate compression ratio
        if regularSize > 0 && zipSize > 0 {
            let compressionRatio = Double(zipSize) / Double(regularSize) * 100
            let savings = 100 - compressionRatio
            
            print("📊 Compression Test Results:")
            print("   Regular JPEG: \(regularSize) bytes")
            print("   ZIP Compressed: \(zipSize) bytes")
            print("   Compression Ratio: \(String(format: "%.1f", compressionRatio))%")
            print("   Storage Savings: \(String(format: "%.1f", savings))%")
            
            if savings > 0 {
                print("✅ ZIP compression is working! Saving \(String(format: "%.1f", savings))% storage")
            } else {
                print("⚠️ ZIP compression not providing savings - may need optimization")
            }
        } else {
            print("❌ Compression test failed")
        }
        
        // Clean up test files
        if let regularURL = regularResult.imageURL {
            try? fileManager.removeItem(at: regularURL)
        }
        if let thumbnailURL = regularResult.thumbnailURL {
            try? fileManager.removeItem(at: thumbnailURL)
        }
        if let zipURL = zipResult.zipURL {
            try? fileManager.removeItem(at: zipURL)
        }
    }
    
    /// Creates a test image for compression testing
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create a receipt-like image with text
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text to make it more realistic
            let text = "Sample Receipt\nStore: Test Store\nDate: 2024-10-16\nTotal: $12.34\nThank you for your purchase!"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            text.draw(in: CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40), withAttributes: attributes)
        }
    }
    
    /// Gets file size for a given URL
    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Recent Activity Model

struct RecentActivityItem: Identifiable {
    let id = UUID()
    let type: ActivityType
    let title: String
    let subtitle: String
    let amount: Double?
    let currency: String?
    let date: Date
    let thumbnailURL: URL?
    let isManualEntry: Bool
    
    enum ActivityType {
        case receipt
        case report
    }
}

// MARK: - Enums

enum ReceiptFilter: String, CaseIterable {
    case all = "All"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case taxDeductible = "Tax Deductible"
}

enum ReceiptSortOption: String, CaseIterable {
    case dateDesc = "Date (Newest)"
    case dateAsc = "Date (Oldest)"
    case amountDesc = "Amount (Highest)"
    case amountAsc = "Amount (Lowest)"
    case merchant = "Merchant (A-Z)"
}

// MARK: - Legacy FileStorage (for backward compatibility)

enum FileStorage {
    static func documentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static func save(image: UIImage, compressionQuality: CGFloat = 0.7) -> URL? {
        let result = StorageManager.shared.saveReceiptImage(image, compressionQuality: compressionQuality)
        
        // Verify the image was actually saved
        if let url = result.imageURL, FileManager.default.fileExists(atPath: url.path) {
            return url
        } else {
            print("Warning: Image file not found after saving")
            return nil
        }
    }
}

// MARK: - Compression Errors

enum CompressionError: Error {
    case compressionFailed
    case decompressionFailed
    case fileNotFound
    case invalidZipFormat
    case insufficientMemory
    
    var localizedDescription: String {
        switch self {
        case .compressionFailed:
            return "Failed to compress data"
        case .decompressionFailed:
            return "Failed to decompress data"
        case .fileNotFound:
            return "File not found in archive"
        case .invalidZipFormat:
            return "Invalid ZIP format"
        case .insufficientMemory:
            return "Insufficient memory for operation"
        }
    }
}