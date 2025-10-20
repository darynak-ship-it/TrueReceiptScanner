//
//  SampleReceiptGenerator.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

enum SampleReceiptGenerator {
    static func generate() -> UIImage? {
        // Realistic thermal receipt dimensions: 80mm width (typical thermal paper)
        // At 203 DPI (thermal printer resolution): 80mm ≈ 640 pixels
        // Height proportional to a typical receipt (3-4x the width)
        let size = CGSize(width: 640, height: 2000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Light grayish background to mimic thermal paper
            UIColor(white: 0.98, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let inset: CGFloat = 40
            var yPosition: CGFloat = inset
            
            // Header - Store name
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor.black
            ]
            let storeName = "SAMPLE STORE"
            let headerSize = (storeName as NSString).size(withAttributes: headerAttrs)
            (storeName as NSString).draw(at: CGPoint(x: (size.width - headerSize.width) / 2, y: yPosition), withAttributes: headerAttrs)
            yPosition += headerSize.height + 10
            
            // Store details
            let detailsFont = UIFont.systemFont(ofSize: 20, weight: .regular)
            let detailsAttrs: [NSAttributedString.Key: Any] = [
                .font: detailsFont,
                .foregroundColor: UIColor.darkGray
            ]
            
            let storeDetails = [
                "123 Main Street",
                "Sample City, Country",
                "Tel: +1 555 123 456",
                "VAT: 123456789"
            ]
            
            for detail in storeDetails {
                let detailSize = (detail as NSString).size(withAttributes: detailsAttrs)
                (detail as NSString).draw(at: CGPoint(x: (size.width - detailSize.width) / 2, y: yPosition), withAttributes: detailsAttrs)
                yPosition += detailSize.height + 5
            }
            
            yPosition += 20
            drawDottedLine(in: ctx.cgContext, y: yPosition, width: size.width, inset: inset)
            yPosition += 20
            
            // Date and time
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            let dateStr = "Date: 10/08/2025  14:23"
            (dateStr as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: dateAttrs)
            yPosition += 35
            
            let receiptNum = "Receipt #: 2025-001"
            (receiptNum as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: dateAttrs)
            yPosition += 35
            
            drawDottedLine(in: ctx.cgContext, y: yPosition, width: size.width, inset: inset)
            yPosition += 25
            
            // Items header
            let itemsHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            ("ITEM                     QTY   PRICE" as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: itemsHeaderAttrs)
            yPosition += 35
            
            // Items
            let itemAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            
            let items = [
                "Item 1                    1    5.50",
                "Item 2                    2    3.25",
                "Item 3                    1    2.75",
                "Item 4                    1    4.50"
            ]
            
            for item in items {
                (item as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: itemAttrs)
                yPosition += 30
            }
            
            yPosition += 15
            drawDottedLine(in: ctx.cgContext, y: yPosition, width: size.width, inset: inset)
            yPosition += 25
            
            // Subtotal and totals
            let totalAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            
            ("Subtotal:               16.00" as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: totalAttrs)
            yPosition += 30
            
            ("Tax (10%):               1.60" as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: totalAttrs)
            yPosition += 35
            
            drawDottedLine(in: ctx.cgContext, y: yPosition, width: size.width, inset: inset)
            yPosition += 25
            
            // Grand total
            let grandTotalAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            ("TOTAL:                  17.60" as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: grandTotalAttrs)
            yPosition += 40
            
            drawDottedLine(in: ctx.cgContext, y: yPosition, width: size.width, inset: inset)
            yPosition += 25
            
            // Payment method
            ("Payment: Credit Card" as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: itemAttrs)
            yPosition += 30
            ("Card: **** **** **** 4532" as NSString).draw(at: CGPoint(x: inset, y: yPosition), withAttributes: itemAttrs)
            yPosition += 50
            
            // Footer message
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            
            let footerMessages = [
                "Thank you for your visit!",
                "",
                "Please visit us again",
                "www.samplestore.com"
            ]
            
            for message in footerMessages {
                let msgSize = (message as NSString).size(withAttributes: footerAttrs)
                (message as NSString).draw(at: CGPoint(x: (size.width - msgSize.width) / 2, y: yPosition), withAttributes: footerAttrs)
                yPosition += msgSize.height + 8
            }
            
            yPosition += 40
            
            // Generate and draw QR code
            if let qrImage = generateQRCode(from: "https://samplestore.com/receipt/2025-001") {
                let qrSize: CGFloat = 200
                let qrX = (size.width - qrSize) / 2
                qrImage.draw(in: CGRect(x: qrX, y: yPosition, width: qrSize, height: qrSize))
            }
        }
        return image
    }
    
    private static func drawDottedLine(in context: CGContext, y: CGFloat, width: CGFloat, inset: CGFloat) {
        context.saveGState()
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.move(to: CGPoint(x: inset, y: y))
        context.addLine(to: CGPoint(x: width - inset, y: y))
        context.strokePath()
        context.restoreGState()
    }
    
    private static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}


