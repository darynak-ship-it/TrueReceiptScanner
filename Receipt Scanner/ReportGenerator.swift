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
    static func generatePDFReport(receipts: [MockReceipt]) -> URL? {
        let pdfDocument = PDFDocument()
        
        // Create a new page
        let page = PDFPage()
        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Standard letter size
        
        // Create PDF context
        let pdfContext = CGContext(consumer: CGDataConsumer(data: NSMutableData())!, mediaBox: &pageRect, nil)
        pdfContext?.beginPage(mediaBox: &pageRect)
        
        // Add title
        let title = "Receipt Report - \(Date().formatted(date: .abbreviated, time: .omitted))"
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(x: 50, y: pageRect.height - 50, width: titleSize.width, height: titleSize.height)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Add receipts table
        var yPosition = pageRect.height - 100
        let rowHeight: CGFloat = 30
        let columnWidths: [CGFloat] = [150, 100, 80, 100, 80]
        
        // Table headers
        let headers = ["Merchant", "Date", "Amount", "Category", "Tax Deductible"]
        let headerFont = UIFont.boldSystemFont(ofSize: 12)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        
        var xPosition: CGFloat = 50
        for (index, header) in headers.enumerated() {
            let headerRect = CGRect(x: xPosition, y: yPosition, width: columnWidths[index], height: rowHeight)
            header.draw(in: headerRect, withAttributes: headerAttributes)
            xPosition += columnWidths[index]
        }
        
        yPosition -= rowHeight
        
        // Add receipt data
        let dataFont = UIFont.systemFont(ofSize: 10)
        let dataAttributes: [NSAttributedString.Key: Any] = [
            .font: dataFont,
            .foregroundColor: UIColor.black
        ]
        
        for receipt in receipts {
            xPosition = 50
            let data = [
                receipt.merchantName,
                receipt.date.formatted(date: .abbreviated, time: .omitted),
                String(format: "$%.2f", receipt.amount),
                receipt.category,
                receipt.isTaxDeductible ? "Yes" : "No"
            ]
            
            for (index, value) in data.enumerated() {
                let dataRect = CGRect(x: xPosition, y: yPosition, width: columnWidths[index], height: rowHeight)
                value.draw(in: dataRect, withAttributes: dataAttributes)
                xPosition += columnWidths[index]
            }
            
            yPosition -= rowHeight
            
            if yPosition < 100 { // Start new page if needed
                pdfContext?.endPage()
                pdfContext?.beginPage(mediaBox: &pageRect)
                yPosition = pageRect.height - 50
            }
        }
        
        pdfContext?.endPage()
        
        // Save PDF to temporary file
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let filename = "receipt_report_\(Int(Date().timeIntervalSince1970)).pdf"
        let pdfURL = documentsDirectory.appendingPathComponent(filename)
        
        // For simplicity, create a basic PDF using PDFKit
        let finalPDF = PDFDocument()
        let finalPage = PDFPage()
        finalPDF.insert(finalPage, at: 0)
        
        do {
            finalPDF.write(to: pdfURL)
            return pdfURL
        } catch {
            return nil
        }
    }
    
    static func generateCSVReport(receipts: [MockReceipt]) -> URL? {
        var csvContent = "Merchant,Date,Amount,Category,Payment Method,Tax Deductible,Tags,Notes\n"
        
        for receipt in receipts {
            let tags = receipt.tags.joined(separator: ";")
            let notes = "" // MockReceipt doesn't have notes field
            let line = "\"\(receipt.merchantName)\",\"\(receipt.date.formatted(date: .abbreviated, time: .omitted))\",\"\(String(format: "%.2f", receipt.amount))\",\"\(receipt.category)\",\"\(receipt.paymentMethod)\",\"\(receipt.isTaxDeductible ? "Yes" : "No")\",\"\(tags)\",\"\(notes)\"\n"
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
    
    static func generateExcelReport(receipts: [MockReceipt]) -> URL? {
        // For Excel, we'll create a CSV file with .xlsx extension
        // In a real implementation, you'd use a library like SwiftExcel
        return generateCSVReport(receipts: receipts)?.appendingPathExtension("xlsx")
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
