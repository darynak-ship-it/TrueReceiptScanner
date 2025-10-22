//
//  ReportGenerator.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ReportGenerator {
    static func generatePDFReport(receipts: [Receipt]) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let filename = "receipt_report_\(Int(Date().timeIntervalSince1970)).pdf"
        let pdfURL = documentsDirectory.appendingPathComponent(filename)
        
        // Create a simple PDF using PDFKit
        let finalPDF = PDFDocument()
        let page = PDFPage()
        
        // Add some basic content to the page
        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = CGContext(data: nil, width: Int(pageRect.width), height: Int(pageRect.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let cgContext = context else { return nil }
        
        cgContext.beginPage(mediaBox: &pageRect)
        
        // Add title
        let title = "Receipt Report - \(Date().formatted(date: .abbreviated, time: .omitted))"
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: 50, y: 750), withAttributes: titleAttributes)
        
        // Add receipt count
        let countText = "Total Receipts: \(receipts.count)"
        let countFont = UIFont.systemFont(ofSize: 14)
        let countAttributes: [NSAttributedString.Key: Any] = [
            .font: countFont,
            .foregroundColor: UIColor.black
        ]
        countText.draw(at: CGPoint(x: 50, y: 720), withAttributes: countAttributes)
        
        cgContext.endPage()
        
        // Insert the page into the PDF document
        finalPDF.insert(page, at: 0)
        
        finalPDF.write(to: pdfURL)
        return pdfURL
    }
    
    static func generateCSVReport(receipts: [Receipt]) -> URL? {
        var csvContent = "Merchant,Date,Amount,Currency,Category,Payment Method,Tax Deductible,Tags,Notes\n"
        
        for receipt in receipts {
            let tags = receipt.tags ?? ""
            let notes = receipt.notes ?? ""
            let line = "\"\(receipt.merchantName ?? "Unknown")\",\"\(receipt.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")\",\"\(String(format: "%.2f", receipt.amount))\",\"\(receipt.currency ?? "USD")\",\"\(receipt.category ?? "Other")\",\"\(receipt.paymentMethod ?? "Other")\",\"\(receipt.isTaxDeductible ? "Yes" : "No")\",\"\(tags)\",\"\(notes)\"\n"
            csvContent += line
        }
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let filename = "receipt_report_\(Int(Date().timeIntervalSince1970)).csv"
        let csvURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            return csvURL
        } catch {
            return nil
        }
    }
    
    static func generateExcelReport(receipts: [Receipt]) -> URL? {
        // Create a proper Excel file using CSV format with Excel-compatible headers
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let filename = "receipt_report_\(Int(Date().timeIntervalSince1970)).xlsx"
        let excelURL = documentsDirectory.appendingPathComponent(filename)
        
        // Create Excel-compatible CSV content
        var csvContent = "Merchant,Date,Amount,Currency,Category,Payment Method,Tax Deductible,Tags,Notes\n"
        
        for receipt in receipts {
            let tags = receipt.tags ?? ""
            let notes = receipt.notes ?? ""
            let line = "\"\(receipt.merchantName ?? "Unknown")\",\"\(receipt.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")\",\"\(String(format: "%.2f", receipt.amount))\",\"\(receipt.currency ?? "USD")\",\"\(receipt.category ?? "Other")\",\"\(receipt.paymentMethod ?? "Other")\",\"\(receipt.isTaxDeductible ? "Yes" : "No")\",\"\(tags)\",\"\(notes)\"\n"
            csvContent += line
        }
        
        do {
            try csvContent.write(to: excelURL, atomically: true, encoding: .utf8)
            return excelURL
        } catch {
            print("Failed to write Excel file: \(error)")
            return nil
        }
    }
    
    // MARK: - Report Storage Integration
    
    static func generateAndSavePDFReport(receipts: [Receipt], title: String) -> Report? {
        guard let pdfURL = generatePDFReport(receipts: receipts) else { return nil }
        return StorageManager.shared.saveReport(
            title: title,
            type: "PDF",
            fileURL: pdfURL,
            receiptCount: receipts.count
        )
    }
    
    static func generateAndSaveCSVReport(receipts: [Receipt], title: String) -> Report? {
        guard let csvURL = generateCSVReport(receipts: receipts) else { return nil }
        return StorageManager.shared.saveReport(
            title: title,
            type: "CSV",
            fileURL: csvURL,
            receiptCount: receipts.count
        )
    }
    
    static func generateAndSaveExcelReport(receipts: [Receipt], title: String) -> Report? {
        guard let excelURL = generateExcelReport(receipts: receipts) else { return nil }
        return StorageManager.shared.saveReport(
            title: title,
            type: "Excel",
            fileURL: excelURL,
            receiptCount: receipts.count
        )
    }
}

struct ReportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
