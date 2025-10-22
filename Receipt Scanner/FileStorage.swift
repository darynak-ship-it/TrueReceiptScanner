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
    
    // MARK: - Receipt Management
    
    func saveReceipt(
        merchantName: String,
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
        
        // Validate required fields
        guard !merchantName.isEmpty else {
            print("Error: Merchant name cannot be empty")
            return nil
        }
        
        guard amount >= 0 else {
            print("Error: Amount cannot be negative")
            return nil
        }
        
        let receipt = Receipt(context: context)
        receipt.id = UUID()
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
        receipt.imageURL = imageURL
        receipt.thumbnailURL = thumbnailURL
        receipt.recognizedText = recognizedText
        receipt.isManualEntry = isManualEntry
        receipt.createdAt = Date()
        receipt.updatedAt = Date()
        
        do {
            try context.save()
            refreshReceipts()
            print("Successfully saved receipt: \(merchantName) - $\(amount)")
            return receipt
        } catch {
            print("Failed to save receipt: \(error)")
            // Rollback the context to prevent corruption
            context.rollback()
            return nil
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