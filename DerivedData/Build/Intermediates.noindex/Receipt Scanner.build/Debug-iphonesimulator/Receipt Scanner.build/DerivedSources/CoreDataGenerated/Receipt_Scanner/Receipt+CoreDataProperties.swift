//
//  Receipt+CoreDataProperties.swift
//  
//
//  Created by Daryna Kalnichenko on 11/12/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ReceiptCoreDataPropertiesSet = NSSet

extension Receipt {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Receipt> {
        return NSFetchRequest<Receipt>(entityName: "Receipt")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var merchantName: String?
    @NSManaged public var amount: Double
    @NSManaged public var currency: String?
    @NSManaged public var date: Date?
    @NSManaged public var category: String?
    @NSManaged public var categoryEmoji: String?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var paymentEmoji: String?
    @NSManaged public var isTaxDeductible: Bool
    @NSManaged public var tags: String?
    @NSManaged public var notes: String?
    @NSManaged public var imageURL: URL?
    @NSManaged public var thumbnailURL: URL?
    @NSManaged public var recognizedText: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var isManualEntry: Bool
    @NSManaged public var compressionType: String?
    @NSManaged public var originalFileSize: Int64
    @NSManaged public var compressedFileSize: Int64
    @NSManaged public var compressionRatio: Double

}

extension Receipt : Identifiable {

}
