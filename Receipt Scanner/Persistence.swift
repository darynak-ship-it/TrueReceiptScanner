//
//  Persistence.swift
//  Receipt Scanner
//
//  Created by Daryna Kalnichenko on 10/15/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample receipts for preview
        let sampleReceipts = [
            ("Coffee Shop", 4.50, "Food & Dining", "🍽️", "Credit Card", "💳", false),
            ("Office Supplies Store", 25.99, "Office supplies", "📎", "Debit Card", "🤑", true),
            ("Gas Station", 45.20, "Travel expenses", "🧳", "Credit Card", "💳", true)
        ]
        
        for (index, receiptData) in sampleReceipts.enumerated() {
            let receipt = Receipt(context: viewContext)
            receipt.id = UUID()
            receipt.merchantName = receiptData.0
            receipt.amount = receiptData.1
            receipt.currency = "USD"
            receipt.date = Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            receipt.category = receiptData.2
            receipt.categoryEmoji = receiptData.3
            receipt.paymentMethod = receiptData.4
            receipt.paymentEmoji = receiptData.5
            receipt.isTaxDeductible = receiptData.6
            receipt.tags = index == 0 ? "coffee,morning" : index == 1 ? "office,supplies" : "gas,travel"
            receipt.notes = ""
            receipt.isManualEntry = false
            receipt.createdAt = Date()
            receipt.updatedAt = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Receipt_Scanner")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for better performance and data protection
            let storeDescription = container.persistentStoreDescriptions.first
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // Configure for better performance
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Enable background context for heavy operations
        container.viewContext.undoManager = nil
    }
    
    // MARK: - Background Context for Heavy Operations
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Save Context
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}