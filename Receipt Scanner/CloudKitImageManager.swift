//
//  CloudKitImageManager.swift
//  Receipt Scanner
//
//  Created by AI Assistant
//

import Foundation
import CloudKit
import UIKit

class CloudKitImageManager {
    static let shared = CloudKitImageManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
    }
    
    /// Uploads an image to CloudKit and returns the record ID
    func uploadImage(_ image: UIImage, receiptID: UUID, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(CloudKitError.imageConversionFailed))
            return
        }
        
        let recordID = CKRecord.ID(recordName: "ReceiptImage_\(receiptID.uuidString)")
        let record = CKRecord(recordType: "ReceiptImage", recordID: recordID)
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        
        do {
            try imageData.write(to: fileURL)
            let asset = CKAsset(fileURL: fileURL)
            record["image"] = asset
            record["receiptID"] = receiptID.uuidString
            record["uploadedAt"] = Date()
            
            privateDatabase.save(record) { savedRecord, error in
                // Clean up temp file
                try? FileManager.default.removeItem(at: fileURL)
                
                if let error = error {
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    completion(.success(savedRecord.recordID))
                } else {
                    completion(.failure(CloudKitError.unknownError))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Downloads an image from CloudKit
    func downloadImage(recordID: CKRecord.ID, completion: @escaping (Result<UIImage, Error>) -> Void) {
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = record,
                  let asset = record["image"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let imageData = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: imageData) else {
                completion(.failure(CloudKitError.imageNotFound))
                return
            }
            
            completion(.success(image))
        }
    }
    
    /// Deletes an image from CloudKit
    func deleteImage(recordID: CKRecord.ID, completion: @escaping (Result<Void, Error>) -> Void) {
        privateDatabase.delete(withRecordID: recordID) { recordID, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Uploads a ZIP archive to CloudKit
    func uploadZipArchive(zipURL: URL, receiptID: UUID, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: "ReceiptArchive_\(receiptID.uuidString)")
        let record = CKRecord(recordType: "ReceiptArchive", recordID: recordID)
        
        let asset = CKAsset(fileURL: zipURL)
        record["archive"] = asset
        record["receiptID"] = receiptID.uuidString
        record["uploadedAt"] = Date()
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                completion(.success(savedRecord.recordID))
            } else {
                completion(.failure(CloudKitError.unknownError))
            }
        }
    }
    
    /// Downloads a ZIP archive from CloudKit
    func downloadZipArchive(recordID: CKRecord.ID, completion: @escaping (Result<URL, Error>) -> Void) {
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = record,
                  let asset = record["archive"] as? CKAsset,
                  let fileURL = asset.fileURL else {
                completion(.failure(CloudKitError.archiveNotFound))
                return
            }
            
            // Copy to documents directory
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDir.appendingPathComponent(fileURL.lastPathComponent)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                completion(.success(destinationURL))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

enum CloudKitError: LocalizedError {
    case imageConversionFailed
    case imageNotFound
    case archiveNotFound
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to data"
        case .imageNotFound:
            return "Image not found in CloudKit"
        case .archiveNotFound:
            return "Archive not found in CloudKit"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}



