//
//  ReportGenerator.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import UIKit

struct ReportGenerator {
    static func generatePDFReport(
        receipts: [Receipt],
        reportNumber: String? = nil,
        generatedAt: Date = Date()
    ) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let filename = "receipt_report_\(Int(Date().timeIntervalSince1970)).pdf"
        let pdfURL = documentsDirectory.appendingPathComponent(filename)
        
        let title = reportNumber ?? "Receipt Report"
        var renderedImage: UIImage?

        let renderBlock = {
            let exportView = ReportLayoutView(
                receipts: receipts,
                reportNumber: title,
                generatedAt: generatedAt,
                onTapReceipt: nil
            )
            .padding(.vertical, 24)
            .padding(.horizontal, 32)
            .frame(width: 612, alignment: .center)
            .background(Color.white)
            .environment(\.colorScheme, .light)

            let renderer = ImageRenderer(content: exportView)
            renderer.proposedSize = ProposedViewSize(width: 612, height: nil)
            renderer.scale = UIScreen.main.scale
            renderedImage = renderer.uiImage
        }

        if Thread.isMainThread {
            renderBlock()
        } else {
            DispatchQueue.main.sync(execute: renderBlock)
        }

        guard let image = renderedImage else { return nil }

        let bounds = CGRect(origin: .zero, size: image.size)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: bounds)

        do {
            let pdfData = pdfRenderer.pdfData { context in
                context.beginPage()
                image.draw(in: bounds)
            }
            try pdfData.write(to: pdfURL)
            return pdfURL
        } catch {
            print("Failed to render PDF report: \(error)")
            return nil
        }
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
        guard let pdfURL = generatePDFReport(receipts: receipts, reportNumber: title, generatedAt: Date()) else { return nil }
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
