//
//  ReportPreviewView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import UIKit
import CoreData

struct ReportPreviewView: View {
    let receipts: [Receipt]
    let reportNumber: String
    let onBack: () -> Void
    let onGenerate: () -> Void
    
    @State private var selectedReceiptIndex: Int? = nil
    @State private var showReceiptDetail = false
    @State private var detailReceipt: Receipt? = nil
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Report \(reportNumber)")
                                    .font(.title2.bold())
                                
                                Text(formatDate(Date()))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatAmount(totalAmount))
                                .font(.title2.bold())
                                .foregroundColor(.accentColor)
                        }
                        
                        Divider()
                        
                        // Summary Info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Date range:")
                                    .foregroundColor(.secondary)
                                Text(dateRangeText)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Receipts attached:")
                                    .foregroundColor(.secondary)
                                Text("\(receipts.count)")
                                    .fontWeight(.medium)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Expense Table
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Expenses")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        expenseTable
                    }
                    
                    // Category Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        categorySummaryTable
                    }
                    
                    // Receipt Images
                    if !receipts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Receipts")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(Array(receipts.enumerated()), id: \.element.id) { index, receipt in
                                receiptImageView(receipt: receipt, index: index)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back", action: onBack)
                        .foregroundColor(.accentColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate", action: onGenerate)
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var expenseTable: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    tableHeaderCell("#", width: 50)
                    tableHeaderCell("DATE", width: 120)
                    tableHeaderCell("MERCHANT", width: 160)
                    tableHeaderCell("CATEGORY", width: 140)
                    tableHeaderCell("DESCRIPTION", width: 200)
                    tableHeaderCell("TOTAL", width: 110, alignment: .trailing)
                }
                .background(Color(UIColor.systemGray6))
                
                // Data Rows
                ForEach(Array(receipts.enumerated()), id: \.element.id) { index, receipt in
                    HStack(spacing: 0) {
                        tableDataCell("\(index + 1)", width: 50)
                        tableDataCell(formatShortDate(receipt.date ?? Date()), width: 120)
                        tableDataCell(receipt.merchantName ?? "Unknown", width: 160)
                        tableDataCell(receipt.category ?? "Other", width: 140)
                        tableDataCell(receipt.notes ?? "", width: 200)
                        tableDataCell(formatAmount(receipt.amount, currency: receipt.currency ?? "USD"), width: 110, alignment: .trailing)
                    }
                    .background(index % 2 == 0 ? Color.white : Color(UIColor.systemGray6).opacity(0.2))
                }
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var categorySummaryTable: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 0) {
                tableHeaderCell("CATEGORY", width: .infinity)
                tableHeaderCell("TOTAL", width: 120, alignment: .trailing)
            }
            .background(Color(UIColor.systemGray6))
            
            // Category Rows
            ForEach(categoryTotals.sorted(by: { $0.key < $1.key }), id: \.key) { category, total in
                HStack(spacing: 0) {
                    tableDataCell(category, width: .infinity)
                    tableDataCell(formatAmount(total, currency: getCurrencyForCategory(category)), width: 120, alignment: .trailing)
                }
                .background(Color.white)
            }
            
            // Total Row
            HStack(spacing: 0) {
                tableDataCell("TOTAL", width: .infinity, fontWeight: .bold)
                tableDataCell(formatAmount(totalAmount), width: 120, alignment: .trailing, fontWeight: .bold)
            }
            .background(Color.accentColor.opacity(0.15))
        }
        .background(Color.white)
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func receiptImageView(receipt: Receipt, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Receipt \(index + 1)")
                .font(.subheadline.bold())
                .padding(.horizontal)
            
            Button(action: {
                detailReceipt = receipt
                selectedReceiptIndex = index
                showReceiptDetail = true
            }) {
                Group {
                    if let imageURL = receipt.imageURL {
                        loadReceiptImage(from: imageURL)?
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("No receipt image")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
        .sheet(isPresented: $showReceiptDetail) {
            if let receipt = detailReceipt, let index = selectedReceiptIndex {
                ReceiptDetailView(receipt: receipt, index: index)
            }
        }
    }
    
    private func tableHeaderCell(_ text: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(width: width == .infinity ? nil : width, alignment: alignment)
            .fixedSize(horizontal: width == .infinity, vertical: false)
    }
    
    private func tableDataCell(_ text: String, width: CGFloat, alignment: Alignment = .leading, fontWeight: Font.Weight = .regular) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(.system(size: 12, weight: fontWeight))
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: width == .infinity ? nil : width, alignment: alignment)
            .fixedSize(horizontal: width == .infinity, vertical: false)
    }
    
    private var totalAmount: Double {
        receipts.reduce(0) { $0 + $1.amount }
    }
    
    private var dateRangeText: String {
        guard !receipts.isEmpty else { return "—" }
        
        let dates = receipts.compactMap { $0.date }.sorted()
        guard let firstDate = dates.first, let lastDate = dates.last else {
            return "—"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if firstDate == lastDate {
            return formatter.string(from: firstDate)
        } else {
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        }
    }
    
    private var categoryTotals: [String: Double] {
        var totals: [String: Double] = [:]
        
        for receipt in receipts {
            let category = receipt.category ?? "Other"
            totals[category, default: 0] += receipt.amount
        }
        
        return totals
    }
    
    private func getCurrencyForCategory(_ category: String) -> String {
        // Get currency from the first receipt with this category
        if let receipt = receipts.first(where: { ($0.category ?? "Other") == category }) {
            return receipt.currency ?? "USD"
        }
        return "USD"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatAmount(_ amount: Double, currency: String = "USD") -> String {
        // Use appropriate currency symbol
        let currencySymbol: String
        switch currency.uppercased() {
        case "EUR": currencySymbol = "€"
        case "GBP": currencySymbol = "£"
        case "USD": currencySymbol = "$"
        case "JPY": currencySymbol = "¥"
        case "CAD": currencySymbol = "C$"
        default: currencySymbol = currency
        }
        
        return String(format: "%.2f %@", amount, currencySymbol)
    }
    
    private func loadReceiptImage(from url: URL) -> Image? {
        if url.pathExtension.lowercased() == "zip" {
            if let uiImage = StorageManager.shared.loadImageFromZip(zipURL: url) {
                return Image(uiImage: uiImage)
            }
        } else {
            if let uiImage = UIImage(contentsOfFile: url.path) {
                return Image(uiImage: uiImage)
            }
        }
        return nil
    }
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    let index: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView([.vertical, .horizontal], showsIndicators: true) {
                        if let imageURL = receipt.imageURL {
                            loadReceiptImage(from: imageURL)?
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width)
                        } else {
                            VStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.5))
                                Text("No receipt image available")
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.top)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Receipt \(index + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    private func loadReceiptImage(from url: URL) -> Image? {
        if url.pathExtension.lowercased() == "zip" {
            if let uiImage = StorageManager.shared.loadImageFromZip(zipURL: url) {
                return Image(uiImage: uiImage)
            }
        } else {
            if let uiImage = UIImage(contentsOfFile: url.path) {
                return Image(uiImage: uiImage)
            }
        }
        return nil
    }
}


#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Create sample receipts
    let receipt1 = Receipt(context: context)
    receipt1.id = UUID()
    receipt1.merchantName = "Phive Porto"
    receipt1.amount = 16.00
    receipt1.currency = "EUR"
    receipt1.date = Date()
    receipt1.category = "Services"
    receipt1.categoryEmoji = "🛠️"
    receipt1.paymentMethod = "Credit Card"
    receipt1.paymentEmoji = "💳"
    receipt1.isTaxDeductible = false
    receipt1.notes = ""
    receipt1.isManualEntry = false
    
    return ReportPreviewView(
        receipts: [receipt1],
        reportNumber: "№001",
        onBack: {},
        onGenerate: {}
    )
}

