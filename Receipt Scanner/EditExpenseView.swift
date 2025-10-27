//
//  EditExpenseView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import UIKit
import CoreData

// MARK: - Models

private struct Currency: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let flag: String
}

private struct Category: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var emoji: String
}

private struct PaymentMethod: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let emoji: String
}

// MARK: - EditExpenseView

struct EditExpenseView: View {
    let imageURL: URL
    @State var recognizedText: String
    let onScanAnother: () -> Void
    let onSaved: () -> Void
    @State private var showReceiptViewer: Bool = false
    @Environment(\.managedObjectContext) private var viewContext
    
    @AppStorage("defaultCurrency") private var defaultCurrency: String = "USD"
    @AppStorage("defaultCategory") private var defaultCategory: String = "Other"
    @StateObject private var themeManager = ThemeManager.shared

    // Editable fields
    @State private var merchantName: String = ""
    @State private var date: Date = Date()
    @State private var totalAmountText: String = ""
    @State private var selectedCurrency: Currency = Currency(code: "USD", flag: "🇺🇸")
    @State private var selectedCategory: Category = Category(name: "Other", emoji: "🗂️")
    @State private var selectedPayment: PaymentMethod = PaymentMethod(name: "Other", emoji: "❓")
    @State private var taxDeductible: Bool = false
    @State private var tagsText: String = ""
    @State private var notes: String = ""

    // Sheet toggles
    @State private var showCurrencySheet: Bool = false
    @State private var showCategorySheet: Bool = false
    @State private var showPaymentSheet: Bool = false
    @State private var showSavedAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // Currency and category options
    private let currencies: [Currency] = [
        Currency(code: "CAD", flag: "🇨🇦"),
        Currency(code: "CHF", flag: "🇨🇭"),
        Currency(code: "CZK", flag: "🇨🇿"),
        Currency(code: "DKK", flag: "🇩🇰"),
        Currency(code: "EUR", flag: "🇪🇺"),
        Currency(code: "GBP", flag: "🇬🇧"),
        Currency(code: "HUF", flag: "🇭🇺"),
        Currency(code: "INR", flag: "🇮🇳"),
        Currency(code: "JPY", flag: "🇯🇵"),
        Currency(code: "KRW", flag: "🇰🇷"),
        Currency(code: "MXN", flag: "🇲🇽"),
        Currency(code: "NOK", flag: "🇳🇴"),
        Currency(code: "PLN", flag: "🇵🇱"),
        Currency(code: "RON", flag: "🇷🇴"),
        Currency(code: "SEK", flag: "🇸🇪"),
        Currency(code: "USD", flag: "🇺🇸")
    ]
    
    private let categories: [Category] = [
        Category(name: "Travel expenses", emoji: "🧳"),
        Category(name: "Food & Dining", emoji: "🍽️"),
        Category(name: "Accommodation", emoji: "🏨"),
        Category(name: "Office supplies", emoji: "📎"),
        Category(name: "Technology and equipment", emoji: "🖥️"),
        Category(name: "Software and subscriptions", emoji: "🛠️"),
        Category(name: "Education", emoji: "📚"),
        Category(name: "Professional memberships", emoji: "🪪"),
        Category(name: "Home office expenses", emoji: "🏡"),
        Category(name: "Uniform", emoji: "🥋"),
        Category(name: "Sports", emoji: "💪"),
        Category(name: "Health", emoji: "❤️‍🩹"),
        Category(name: "Communication expenses", emoji: "☎️"),
        Category(name: "Relocation expenses", emoji: "📦"),
        Category(name: "Client-related expenses", emoji: "🤝"),
        Category(name: "Other", emoji: "🗂️")
    ]

    var body: some View {
            ScrollView {
            VStack(spacing: 16) {
                // Small preview at the very top (tap to view full receipt)
                let previewImage = loadImageFromURL(imageURL) ?? SampleReceiptGenerator.generate()
                if let thumb = previewImage {
                    Button(action: { showReceiptViewer = true }) {
                        HStack(spacing: 12) {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .cornerRadius(12)

                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Receipt preview. Tap to view full size.")
                }

                // Single gray pad with all editable fields
                VStack(alignment: .leading, spacing: 16) {
                    // Field 1 - Merchant Name (white rounded field with example)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant Name")
                            .font(.headline)
                        TextField("Item 1: Sample Item", text: $merchantName)
                            .padding(12)
                            .background(themeManager.textFieldBackgroundColor)
                            .cornerRadius(8)
                    }

                    // Field 2 - Date (label and date on one line)
                    HStack {
                        Text("Date")
                            .font(.headline)
                        Spacer()
                        DatePicker("Select date", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    // Field 3 - Total + Currency (white rounded field with example)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total")
                            .font(.headline)
                        HStack(spacing: 12) {
                            TextField("0.0", text: $totalAmountText)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(themeManager.textFieldBackgroundColor)
                                .cornerRadius(8)
                            Button(action: { showCurrencySheet = true }) {
                                HStack(spacing: 6) {
                                    Text(selectedCurrency.flag)
                                    Text(selectedCurrency.code)
                                        .foregroundColor(.accentColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // Field 4 - Category (single-line label + preview)
                    HStack {
                        Text("Category")
                            .font(.headline)
                        Spacer()
                        Button(action: { showCategorySheet = true }) {
                            HStack(spacing: 8) {
                                Text(selectedCategory.emoji)
                                Text(selectedCategory.name)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Field 5 - Payment Method
                    HStack {
                        Text("Payment Method")
                            .font(.headline)
                        Spacer()
                        Button(action: { showPaymentSheet = true }) {
                            HStack(spacing: 8) {
                                Text(selectedPayment.emoji)
                                Text(selectedPayment.name)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Field 6 - Tax Deductible toggle
                    HStack {
                        Text("Tax Deductible")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $taxDeductible)
                            .labelsHidden()
                    }

                    // Field 7 - Tag (white rounded field with example)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tag")
                            .font(.headline)
                        ZStack(alignment: .leading) {
                            if tagsText.isEmpty {
                                Text("#work, #meal, #projectX")
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 12)
                            }
                            TextField("", text: $tagsText)
                                .padding(12)
                        }
                        .background(themeManager.textFieldBackgroundColor)
                        .cornerRadius(8)
                    }

                    // Field 8 - Notes (white rounded field with example)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Add notes")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 12)
                            }
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(4)
                                .scrollContentBackground(.hidden)
                        }
                        .background(themeManager.textFieldBackgroundColor)
                        .cornerRadius(8)
                    }

                    // Save button
                    Button(action: { saveExpense() }) {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back", action: onScanAnother)
                    .foregroundColor(.accentColor)
            }
        }
        .onAppear {
            prefillFromOCR()
            // Set default currency and category from settings
            if let defaultCurrencyObj = currencies.first(where: { $0.code == defaultCurrency }) {
                selectedCurrency = defaultCurrencyObj
            }
            if let defaultCategoryObj = categories.first(where: { $0.name == defaultCategory }) {
                selectedCategory = defaultCategoryObj
            }
        }
        .sheet(isPresented: $showCurrencySheet) {
            CurrencyPickerView(selected: $selectedCurrency, isPresented: $showCurrencySheet, themeManager: themeManager)
        }
        .sheet(isPresented: $showCategorySheet) {
            CategoryPickerView(selected: $selectedCategory, isPresented: $showCategorySheet, themeManager: themeManager)
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentPickerView(selected: $selectedPayment, isPresented: $showPaymentSheet, themeManager: themeManager)
        }
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Save Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showReceiptViewer) {
            let fullImage = loadImageFromURL(imageURL) ?? SampleReceiptGenerator.generate()
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let img = fullImage {
                        GeometryReader { geometry in
                            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width)
                            }
                        }
                    } else {
                        Text("No receipt available")
                            .foregroundColor(.white)
                    }
                }
                .navigationTitle("Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showReceiptViewer = false }
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }

    private func saveExpense() {
        // Parse amount - allow 0 for empty entries
        let amount = Double(totalAmountText) ?? 0.0
        
        // Parse tags
        let tags = tagsText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Use the existing image URL from scanning - no need to save again
        // The image was already saved during the scanning process in ScannerContainer
        let finalImageURL = imageURL
        
        // For ZIP files, we don't need a separate thumbnail as it's included in the ZIP
        // For regular files, create thumbnail if needed
        let thumbnailURL: URL?
        if imageURL.pathExtension.lowercased() == "zip" {
            // ZIP files contain both image and thumbnail
            thumbnailURL = nil
        } else {
            // Regular files need separate thumbnail
            // Don't fail if thumbnail creation fails - just proceed without it
            if FileManager.default.fileExists(atPath: imageURL.path),
               let image = UIImage(contentsOfFile: imageURL.path) {
                let thumbnailResult = StorageManager.shared.saveReceiptImage(image, compressionQuality: 0.3)
                thumbnailURL = thumbnailResult.thumbnailURL
            } else {
                thumbnailURL = nil
            }
        }
        
        // Create receipt directly in Core Data
        let receipt = Receipt(context: viewContext)
        receipt.id = UUID()
        receipt.merchantName = merchantName.isEmpty ? nil : merchantName
        receipt.amount = amount
        receipt.currency = selectedCurrency.code.isEmpty ? "USD" : selectedCurrency.code
        receipt.date = date
        receipt.category = selectedCategory.name.isEmpty ? "Other" : selectedCategory.name
        receipt.categoryEmoji = selectedCategory.emoji.isEmpty ? "🗂️" : selectedCategory.emoji
        receipt.paymentMethod = selectedPayment.name.isEmpty ? "Other" : selectedPayment.name
        receipt.paymentEmoji = selectedPayment.emoji.isEmpty ? "❓" : selectedPayment.emoji
        receipt.isTaxDeductible = taxDeductible
        receipt.tags = tags.joined(separator: ",")
        receipt.notes = notes
        receipt.imageURL = finalImageURL
        receipt.thumbnailURL = thumbnailURL
        receipt.recognizedText = recognizedText
        receipt.isManualEntry = false
        receipt.createdAt = Date()
        receipt.updatedAt = Date()
        
        // Set compression metadata
        if finalImageURL.pathExtension.lowercased() == "zip" {
            receipt.compressionType = "zip"
            // Get file sizes for compression metadata
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: finalImageURL.path)
                receipt.compressedFileSize = attributes[.size] as? Int64 ?? 0
                // Estimate original size (ZIP typically compresses to 60-70% of original)
                receipt.originalFileSize = Int64(Double(receipt.compressedFileSize) / 0.65)
                receipt.compressionRatio = Double(receipt.compressedFileSize) / Double(receipt.originalFileSize)
            } catch {
                receipt.compressionType = "zip"
                receipt.originalFileSize = 0
                receipt.compressedFileSize = 0
                receipt.compressionRatio = 0.0
            }
        } else {
            receipt.compressionType = "none"
            if FileManager.default.fileExists(atPath: finalImageURL.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: finalImageURL.path)
                    receipt.originalFileSize = attributes[.size] as? Int64 ?? 0
                    receipt.compressedFileSize = receipt.originalFileSize
                    receipt.compressionRatio = 1.0
                } catch {
                    receipt.originalFileSize = 0
                    receipt.compressedFileSize = 0
                    receipt.compressionRatio = 1.0
                }
            } else {
                receipt.originalFileSize = 0
                receipt.compressedFileSize = 0
                receipt.compressionRatio = 1.0
            }
        }
        
        // Save to Core Data
        do {
            try viewContext.save()
            print("Successfully saved receipt: \(receipt.merchantName ?? "Unknown") - $\(receipt.amount)")
            showSavedAlert = true
            // Delay the onSaved callback to show the alert first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onSaved()
            }
        } catch {
            // Handle save error - show user-friendly error
            errorMessage = "Failed to save receipt. Please check your device storage and try again."
            showErrorAlert = true
            print("Failed to save receipt to Core Data: \(error)")
            // Rollback the context to prevent corruption
            viewContext.rollback()
        }
    }

    // Enhanced OCR text parsing and prefill logic
    private func prefillFromOCR() {
        let text = recognizedText
        print("Prefilling from OCR text: \(text)")
        
        // Extract merchant name
        extractMerchantName(from: text)
        
        // Extract date
        extractDate(from: text)
        
        // Extract amount and currency
        extractAmountAndCurrency(from: text)
        
        // Extract category based on merchant name or keywords
        extractCategory(from: text)
        
        print("Prefilled fields - Merchant: '\(merchantName)', Amount: '\(totalAmountText)', Currency: '\(selectedCurrency.code)', Date: \(date)")
    }
    
    private func extractMerchantName(from text: String) {
        if !merchantName.isEmpty { return }
        
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Try various patterns for merchant name
        let merchantPatterns = [
            // Explicit merchant/store labels
            "(?:Store|Merchant|Company|Business|Restaurant|Hotel|Shop)[:\\s]+(.+)",
            // Common receipt headers
            "^([A-Za-z][A-Za-z0-9\\s&.-]+(?:Hotel|Restaurant|Cafe|Store|Shop|Market|Center|Mall|Plaza))",
            // First substantial line (not receipt, total, date, etc.)
            "^([A-Za-z][A-Za-z0-9\\s&.-]{3,})$"
        ]
        
        for pattern in merchantPatterns {
            if let merchant = firstMatch(in: text, pattern: pattern) {
                // Filter out common non-merchant words
                let filteredMerchant = merchant.trimmingCharacters(in: .whitespaces)
                if !filteredMerchant.lowercased().contains("receipt") &&
                   !filteredMerchant.lowercased().contains("total") &&
                   !filteredMerchant.lowercased().contains("date") &&
                   !filteredMerchant.lowercased().contains("time") &&
                   filteredMerchant.count > 2 {
                    merchantName = filteredMerchant
                    return
                }
            }
        }
        
        // Fallback: use first non-empty line that looks like a business name
        for line in lines {
            if line.count > 3 && 
               !line.lowercased().contains("receipt") &&
               !line.lowercased().contains("total") &&
               !line.lowercased().contains("date") &&
               !line.lowercased().contains("time") &&
               !line.contains("$") &&
               !line.contains("€") &&
               !line.contains("£") &&
               !matchesPattern(line, pattern: "\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}") {
                merchantName = line
                return
            }
        }
    }
    
    private func extractDate(from text: String) {
        let datePatterns = [
            // ISO format: 2024-10-16 or 2024/10/16
            "(\\d{4}[-/](?:0?[1-9]|1[0-2])[-/](?:0?[1-9]|[12]\\d|3[01]))",
            // US format: 10/16/2024 or 10-16-2024
            "(?:0?[1-9]|1[0-2])[-/](?:0?[1-9]|[12]\\d|3[01])[-/](\\d{4})",
            // European format: 16/10/2024 or 16-10-2024
            "(?:0?[1-9]|[12]\\d|3[01])[-/](?:0?[1-9]|1[0-2])[-/](\\d{4})",
            // Month name format: Oct 16, 2024 or October 16, 2024
            "(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)\\s+(?:0?[1-9]|[12]\\d|3[01]),?\\s+(\\d{4})"
        ]
        
        for pattern in datePatterns {
            if let dateStr = firstMatch(in: text, pattern: pattern) {
                let formatters = [
                    "yyyy-MM-dd",
                    "yyyy/MM/dd", 
                    "MM/dd/yyyy",
                    "MM-dd-yyyy",
                    "dd/MM/yyyy",
                    "dd-MM-yyyy",
                    "MMM d, yyyy",
                    "MMMM d, yyyy"
                ]
                
                for format in formatters {
            let formatter = DateFormatter()
                    formatter.dateFormat = format
                    if let parsedDate = formatter.date(from: dateStr) {
                        date = parsedDate
                        return
                    }
                }
            }
        }
    }
    
    private func extractAmountAndCurrency(from text: String) {
        if !totalAmountText.isEmpty { return }
        
        // Currency symbols and their codes
        let currencyMap: [String: String] = [
            "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", 
            "C$": "CAD", "A$": "AUD", "CHF": "CHF", "kr": "SEK",
            "₹": "INR", "₽": "RUB", "₩": "KRW", "₪": "ILS"
        ]
        
        // Amount patterns - look for various formats
        let amountPatterns = [
            // Total with currency symbol: $12.34, €45.67
            "([$€£¥C$A$₹₽₩₪])\\s*([0-9]+(?:\\.[0-9]{1,2})?)",
            // Total without currency: Total: 12.34, Amount: 45.67
            "(?:Total|Amount|Sum|Subtotal|Grand Total)[:\\s]*([0-9]+(?:\\.[0-9]{1,2})?)",
            // Just numbers that look like amounts: 12.34, 123.45
            "\\b([0-9]+(?:\\.[0-9]{1,2})?)\\b"
        ]
        
        var foundAmount: String?
        var foundCurrency: String = "USD" // default
        
        for pattern in amountPatterns {
            if let match = firstMatch(in: text, pattern: pattern) {
                // Check if it contains currency symbol
                for (symbol, code) in currencyMap {
                    if match.contains(symbol) {
                        foundCurrency = code
                        // Extract just the number part
                        if let amount = firstMatch(in: match, pattern: "([0-9]+(?:\\.[0-9]{1,2})?)") {
                            foundAmount = amount
                            break
                        }
                    }
                }
                
                // If no currency symbol, check if it's a reasonable amount
                if foundAmount == nil {
                    let amount = match.trimmingCharacters(in: .whitespaces)
                    if let value = Double(amount), value > 0 && value < 10000 {
                        foundAmount = amount
                    }
                }
            }
            
            if foundAmount != nil { break }
        }
        
        if let amount = foundAmount {
            totalAmountText = amount
            // Update currency if we found one
            if let currencyCode = currencyMap.values.first(where: { $0 == foundCurrency }) {
                selectedCurrency = Currency(code: foundCurrency, flag: getFlagForCurrency(foundCurrency))
            }
        }
    }
    
    private func extractCategory(from text: String) {
        let merchantLower = merchantName.lowercased()
        let textLower = text.lowercased()
        
        // Category mapping based on keywords
        let categoryKeywords: [String: (String, String)] = [
            "hotel": ("Accommodation", "🏨"),
            "restaurant": ("Food & Dining", "🍽️"),
            "cafe": ("Food & Dining", "🍽️"),
            "coffee": ("Food & Dining", "🍽️"),
            "food": ("Food & Dining", "🍽️"),
            "dining": ("Food & Dining", "🍽️"),
            "gas": ("Travel expenses", "🧳"),
            "fuel": ("Travel expenses", "🧳"),
            "station": ("Travel expenses", "🧳"),
            "office": ("Office supplies", "📎"),
            "supplies": ("Office supplies", "📎"),
            "computer": ("Technology and equipment", "🖥️"),
            "software": ("Software and subscriptions", "🛠️"),
            "subscription": ("Software and subscriptions", "🛠️"),
            "education": ("Education", "📚"),
            "school": ("Education", "📚"),
            "university": ("Education", "📚"),
            "health": ("Health", "❤️‍🩹"),
            "medical": ("Health", "❤️‍🩹"),
            "pharmacy": ("Health", "❤️‍🩹"),
            "sport": ("Sports", "💪"),
            "gym": ("Sports", "💪"),
            "fitness": ("Sports", "💪"),
            "communication": ("Communication expenses", "☎️"),
            "phone": ("Communication expenses", "☎️"),
            "internet": ("Communication expenses", "☎️"),
            "uniform": ("Uniform", "🥋"),
            "clothing": ("Uniform", "🥋"),
            "travel": ("Travel expenses", "🧳"),
            "transport": ("Travel expenses", "🧳"),
            "taxi": ("Travel expenses", "🧳"),
            "uber": ("Travel expenses", "🧳"),
            "client": ("Client-related expenses", "🤝"),
            "business": ("Client-related expenses", "🤝"),
            "meeting": ("Client-related expenses", "🤝")
        ]
        
        // Check merchant name first
        for (keyword, (category, emoji)) in categoryKeywords {
            if merchantLower.contains(keyword) {
                selectedCategory = Category(name: category, emoji: emoji)
                return
            }
        }
        
        // Check full text for keywords
        for (keyword, (category, emoji)) in categoryKeywords {
            if textLower.contains(keyword) {
                selectedCategory = Category(name: category, emoji: emoji)
                return
            }
        }
    }
    
    private func getFlagForCurrency(_ code: String) -> String {
        let flagMap: [String: String] = [
            "USD": "🇺🇸", "EUR": "🇪🇺", "GBP": "🇬🇧", "JPY": "🇯🇵",
            "CAD": "🇨🇦", "AUD": "🇦🇺", "CHF": "🇨🇭", "SEK": "🇸🇪",
            "INR": "🇮🇳", "RUB": "🇷🇺", "KRW": "🇰🇷", "ILS": "🇮🇱"
        ]
        return flagMap[code] ?? "🇺🇸"
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)), match.numberOfRanges > 1 {
                if let range = Range(match.range(at: 1), in: text) {
                    return String(text[range]).trimmingCharacters(in: .whitespaces)
                }
            }
        } catch { }
        return nil
    }
    
    private func matchesPattern(_ text: String, pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    /// Loads image from URL, handling both regular files and ZIP archives
    private func loadImageFromURL(_ url: URL) -> UIImage? {
        // Check if it's a ZIP file
        if url.pathExtension.lowercased() == "zip" {
            return StorageManager.shared.loadImageFromZip(zipURL: url)
        } else {
            // Regular file
            return UIImage(contentsOfFile: url.path)
        }
    }
}

// MARK: - Currency Picker

private struct CurrencyPickerView: View {
    @Binding var selected: Currency
    @Binding var isPresented: Bool
    @ObservedObject var themeManager: ThemeManager

    private let currencies: [Currency] = [
        Currency(code: "CAD", flag: "🇨🇦"),
        Currency(code: "CHF", flag: "🇨🇭"),
        Currency(code: "CZK", flag: "🇨🇿"),
        Currency(code: "DKK", flag: "🇩🇰"),
        Currency(code: "EUR", flag: "🇪🇺"),
        Currency(code: "GBP", flag: "🇬🇧"),
        Currency(code: "HUF", flag: "🇭🇺"),
        Currency(code: "INR", flag: "🇮🇳"),
        Currency(code: "JPY", flag: "🇯🇵"),
        Currency(code: "KRW", flag: "🇰🇷"),
        Currency(code: "MXN", flag: "🇲🇽"),
        Currency(code: "NOK", flag: "🇳🇴"),
        Currency(code: "PLN", flag: "🇵🇱"),
        Currency(code: "RON", flag: "🇷🇴"),
        Currency(code: "SEK", flag: "🇸🇪"),
        Currency(code: "USD", flag: "🇺🇸")
    ]

    var body: some View {
        NavigationStack {
            List(currencies) { curr in
                HStack {
                    Text(curr.flag)
                    Text(curr.code)
                    Spacer()
                    if curr == selected { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = curr }
                .listRowBackground(curr == selected ? themeManager.selectionColor : Color.clear)
            }
            .navigationTitle("Currency")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { isPresented = false }
                        .foregroundColor(.accentColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { isPresented = false }
                        .foregroundColor(.accentColor)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Category Picker

private struct CategoryPickerView: View {
    @Binding var selected: Category
    @Binding var isPresented: Bool
    @State private var showCreate: Bool = false
    @State private var draftCategory: Category = Category(name: "", emoji: "")
    @ObservedObject var themeManager: ThemeManager

    private var presets: [Category] {
        [
            Category(name: "Travel expenses", emoji: "🧳"),
            Category(name: "Food & Dining", emoji: "🍽️"),
            Category(name: "Accommodation", emoji: "🏨"),
            Category(name: "Office supplies", emoji: "📎"),
            Category(name: "Technology and equipment", emoji: "🖥️"),
            Category(name: "Software and subscriptions", emoji: "🛠️"),
            Category(name: "Education", emoji: "📚"),
            Category(name: "Professional memberships", emoji: "🪪"),
            Category(name: "Home office expenses", emoji: "🏡"),
            Category(name: "Uniform", emoji: "🥋"),
            Category(name: "Sports", emoji: "💪"),
            Category(name: "Health", emoji: "❤️‍🩹"),
            Category(name: "Communication expenses", emoji: "☎️"),
            Category(name: "Relocation expenses", emoji: "📦"),
            Category(name: "Client-related expenses", emoji: "🤝"),
            Category(name: "Other", emoji: "🗂️")
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section("SELECT CATEGORY") {
                    ForEach(presets) { cat in
                        HStack {
                            Text(cat.emoji)
                            Text(cat.name)
                            Spacer()
                            if cat == selected { Image(systemName: "checkmark") }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selected = cat }
                        .listRowBackground(cat == selected ? themeManager.selectionColor : Color.clear)
                    }
                }

                Section {
                    Button(action: { draftCategory = Category(name: "", emoji: ""); showCreate = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                            Text("Create new category")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { isPresented = false }
                        .foregroundColor(.accentColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { isPresented = false }
                        .foregroundColor(.accentColor)
                }
            }
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    Form {
                        Section(header: Text("Emoji")) {
                            TextField("Enter emoji", text: $draftCategory.emoji)
                        }
                        Section(header: Text("Name")) {
                            TextField("Category name", text: $draftCategory.name)
                        }
                    }
                    .navigationTitle("New Category")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back") { showCreate = false }
                                .foregroundColor(.accentColor)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                let newCat = Category(name: draftCategory.name.isEmpty ? "Custom" : draftCategory.name, emoji: draftCategory.emoji.isEmpty ? "🗂️" : draftCategory.emoji)
                                selected = newCat
                                showCreate = false
                                isPresented = false
                            }
                            .disabled(draftCategory.name.trimmingCharacters(in: .whitespaces).isEmpty && draftCategory.emoji.trimmingCharacters(in: .whitespaces).isEmpty)
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Payment Picker

private struct PaymentPickerView: View {
    @Binding var selected: PaymentMethod
    @Binding var isPresented: Bool
    @ObservedObject var themeManager: ThemeManager

    private let methods: [PaymentMethod] = [
        PaymentMethod(name: "Credit Card", emoji: "💳"),
        PaymentMethod(name: "Debit Card", emoji: "🤑"),
        PaymentMethod(name: "PayPal", emoji: "🔹"),
        PaymentMethod(name: "Apple Pay/Google Pay", emoji: "🤳"),
        PaymentMethod(name: "Bank Transfer", emoji: "⏩"),
        PaymentMethod(name: "Cash", emoji: "💸"),
        PaymentMethod(name: "Prepaid Cards", emoji: "🎁"),
        PaymentMethod(name: "Other", emoji: "❓")
    ]

    var body: some View {
        NavigationStack {
            List(methods) { method in
                HStack {
                    Text(method.emoji)
                    Text(method.name)
                    Spacer()
                    if method == selected { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = method }
                .listRowBackground(method == selected ? themeManager.selectionColor : Color.clear)
            }
            .navigationTitle("Payment Method")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { isPresented = false }
                        .foregroundColor(.accentColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { isPresented = false }
                        .foregroundColor(.accentColor)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        EditExpenseView(
            imageURL: URL(fileURLWithPath: "/dev/null"),
            recognizedText: "Sample Receipt\nStore: Demo Market\nDate: 2025-10-16\nTotal: $11.64",
            onScanAnother: {},
            onSaved: {}
        )
    }
}


