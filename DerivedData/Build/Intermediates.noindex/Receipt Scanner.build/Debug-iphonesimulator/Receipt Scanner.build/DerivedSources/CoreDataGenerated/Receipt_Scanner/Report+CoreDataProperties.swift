//
//  Report+CoreDataProperties.swift
//  
//
//  Created by Daryna Kalnichenko on 11/12/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ReportCoreDataPropertiesSet = NSSet

extension Report {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Report> {
        return NSFetchRequest<Report>(entityName: "Report")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var type: String?
    @NSManaged public var fileURL: URL?
    @NSManaged public var createdAt: Date?
    @NSManaged public var fileSize: Int64
    @NSManaged public var receiptCount: Int32

}

extension Report : Identifiable {

}
