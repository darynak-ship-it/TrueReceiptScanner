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
    @FocusState private var isTagFieldFocused: Bool

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
            ScrollView {
            VStack(spacing: 16) {
                // Small preview at the very top (tap to view full receipt)
                Group {
                    if let previewImage = loadImageFromURL(imageURL) {
                        Button(action: { showReceiptViewer = true }) {
                            HStack(spacing: 12) {
                                Image(uiImage: previewImage)
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
                    } else {
                        // Fallback: Show placeholder if image can't be loaded
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.image")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Receipt image unavailable")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Image URL: \(imageURL.lastPathComponent)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }

                // Single gray pad with all editable fields
                VStack(alignment: .leading, spacing: 16) {
                    // Field 1 - Merchant Name (white rounded field with example)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant Name")
                            .font(.headline)
                        TextField("Item 1: Sample Item", text: $merchantName)
                            .textFieldStyle(.plain)
                            .foregroundColor(.primary)
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
                                .textFieldStyle(.plain)
                                .foregroundColor(.primary)
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

                    // Field 4 - Category (Menu-based selection)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Menu {
                            ForEach(categories, id: \.id) { category in
                                Button(action: { selectedCategory = category }) {
                                    Label(category.name, systemImage: selectedCategory == category ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        } label: {
                            FilterMenuLabel(
                                title: "\(selectedCategory.emoji) \(selectedCategory.name)",
                                count: 0
                            )
                        }
                    }

                    // Field 5 - Payment Method (Menu-based selection)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payment Method")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Menu {
                            ForEach(methods, id: \.id) { method in
                                Button(action: { selectedPayment = method }) {
                                    Label(method.name, systemImage: selectedPayment == method ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        } label: {
                            FilterMenuLabel(
                                title: "\(selectedPayment.emoji) \(selectedPayment.name)",
                                count: 0
                            )
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
                                .textFieldStyle(.plain)
                                .foregroundColor(.primary)
                                .padding(12)
                                .focused($isTagFieldFocused)
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
                                .foregroundColor(.primary)
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
            
            ToolbarItemGroup(placement: .keyboard) {
                if isTagFieldFocused {
                    Button("#") {
                        // Insert # at the end of the text
                        // Add space before # if text doesn't end with space or comma
                        if tagsText.isEmpty || tagsText.last == " " || tagsText.last == "," {
                            tagsText += "#"
                        } else {
                            tagsText += " #"
                        }
                    }
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 8)
                    
                    Spacer()
                    
                    Button("Done") {
                        isTagFieldFocused = false
                    }
                    .foregroundColor(.accentColor)
                }
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
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Save Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showReceiptViewer) {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let img = loadImageFromURL(imageURL) {
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
        
        // Validate that the image file exists before saving
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            errorMessage = "Failed to save receipt: Image file not found. Please try scanning again."
            showErrorAlert = true
            print("ERROR: Image file does not exist at path: \(imageURL.path)")
            return
        }
        
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
            if let image = UIImage(contentsOfFile: imageURL.path) {
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
        receipt.date = date // Ensure date is set (required field)
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
        
        // Validate required fields before saving
        guard receipt.id != nil else {
            errorMessage = "Failed to save receipt: Missing receipt ID"
            showErrorAlert = true
            viewContext.rollback()
            return
        }
        
        guard receipt.date != nil else {
            errorMessage = "Failed to save receipt: Missing date"
            showErrorAlert = true
            viewContext.rollback()
            return
        }
        
        // Set compression metadata
        if finalImageURL.pathExtension.lowercased() == "zip" {
            receipt.compressionType = "zip"
            // Get file sizes for compression metadata
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: finalImageURL.path)
                receipt.compressedFileSize = attributes[.size] as? Int64 ?? 0
                // Estimate original size (ZIP typically compresses to 60-70% of original)
                if receipt.compressedFileSize > 0 {
                receipt.originalFileSize = Int64(Double(receipt.compressedFileSize) / 0.65)
                receipt.compressionRatio = Double(receipt.compressedFileSize) / Double(receipt.originalFileSize)
                } else {
                    receipt.originalFileSize = 0
                    receipt.compressionRatio = 0.0
                }
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
            // Handle save error - show user-friendly error with details
            let nsError = error as NSError
            var errorDetails = "Failed to save receipt."
            
            // Provide more specific error messages
            if let validationErrors = nsError.userInfo[NSValidationKeyErrorKey] as? [String] {
                errorDetails += " Validation errors: \(validationErrors.joined(separator: ", "))"
            } else if let detailedError = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                let errorMessages = detailedError.compactMap { $0.localizedDescription }
                if !errorMessages.isEmpty {
                    errorDetails += " \(errorMessages.joined(separator: "; "))"
                }
            } else {
                errorDetails += " \(nsError.localizedDescription)"
            }
            
            errorMessage = errorDetails
            showErrorAlert = true
            print("Failed to save receipt to Core Data: \(error)")
            print("Error details: \(nsError.userInfo)")
            // Rollback the context to prevent corruption
            viewContext.rollback()
        }
    }

    // Enhanced OCR text parsing and prefill logic
    private func prefillFromOCR() {
        let text = recognizedText
        print("=== OCR TEXT DEBUG ===")
        print("Full OCR text:\n\(text)")
        print("Number of lines: \(text.components(separatedBy: .newlines).count)")
        
        // Extract merchant name
        extractMerchantName(from: text)
        
        // Extract date
        extractDate(from: text)
        
        // Extract amount and currency
        extractAmountAndCurrency(from: text)
        
        // Extract category based on merchant name or keywords
        extractCategory(from: text)
        
        print("=== EXTRACTION RESULTS ===")
        print("Merchant: '\(merchantName)'")
        print("Amount: '\(totalAmountText)'")
        print("Currency: '\(selectedCurrency.code)'")
        print("Date: \(date)")
        print("========================")
    }
    
    private func extractMerchantName(from text: String) {
        if !merchantName.isEmpty { return }
        
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Try various patterns for merchant name (case insensitive where helpful)
        let merchantPatterns = [
            // Explicit merchant/store labels (case insensitive, more flexible)
            "(?i)(?:Store|Merchant|Company|Business|Restaurant|Hotel|Shop|Vendor|Retailer)[:\\s]+(.+)",
            // Common receipt headers
            "^([A-Za-z][A-Za-z0-9\\s&'.-]{2,}(?:Hotel|Restaurant|Cafe|Store|Shop|Market|Center|Mall|Plaza|Inc|LLC|Ltd))",
            // First substantial line (not receipt, total, date, etc.)
            "^([A-Za-z][A-Za-z0-9\\s&'.-]{3,})$"
        ]
        
        for pattern in merchantPatterns {
            if let merchant = firstMatch(in: text, pattern: pattern) {
                // Filter out common non-merchant words
                let filteredMerchant = merchant.trimmingCharacters(in: .whitespaces)
                let lowercased = filteredMerchant.lowercased()
                
                if !lowercased.contains("receipt") &&
                   !lowercased.contains("total") &&
                   !lowercased.contains("date") &&
                   !lowercased.contains("time") &&
                   !lowercased.contains("amount") &&
                   !lowercased.contains("subtotal") &&
                   !lowercased.contains("tax") &&
                   !lowercased.contains("change") &&
                   !lowercased.contains("thank") &&
                   filteredMerchant.count > 2 {
                    merchantName = filteredMerchant
                    print("✅ Extracted merchant: \(filteredMerchant)")
                    return
                }
            }
        }
        
        // Fallback: use first non-empty line that looks like a business name
        for line in lines {
            if line.count > 2 {
                let lowercased = line.lowercased()
                if !lowercased.contains("receipt") &&
                   !lowercased.contains("total") &&
                   !lowercased.contains("date") &&
                   !lowercased.contains("time") &&
                   !lowercased.contains("amount") &&
                   !line.contains("$") &&
                   !line.contains("€") &&
                   !line.contains("£") &&
                   !matchesPattern(line, pattern: "\\d{1,2}[-/]\\d{1,2}[-/]\\d{2,4}") && // dates
                   !matchesPattern(line, pattern: "\\d{1,2}:\\d{2}") && // times
                   !matchesPattern(line, pattern: "^\\s*\\d+[.,]?\\d*\\s*$") { // just numbers
                    merchantName = line
                    print("✅ Extracted merchant (fallback): \(line)")
                    return
                }
            }
        }
        print("❌ No merchant name extracted")
    }
    
    private func extractDate(from text: String) {
        // More comprehensive date patterns with proper capture groups
        let datePatterns: [(pattern: String, formatters: [String])] = [
            // ISO format: 2024-10-16 or 2024/10/16
            ("(\\d{4}[-/]\\d{1,2}[-/]\\d{1,2})", ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy-M-d", "yyyy/M/d"]),
            // US format: 10/16/2024 or 10-16-2024
            ("(\\d{1,2}[-/]\\d{1,2}[-/]\\d{4})", ["MM/dd/yyyy", "MM-dd-yyyy", "M/d/yyyy", "M-dd-yyyy", "MM-d-yyyy", "M-d-yyyy"]),
            // European format: 16/10/2024 or 16-10-2024
            ("(\\d{1,2}[-/]\\d{1,2}[-/]\\d{4})", ["dd/MM/yyyy", "dd-MM-yyyy", "d/M/yyyy", "d-MM-yyyy", "dd-M-yyyy", "d-M-yyyy"]),
            // 2-digit year formats: 10/16/24
            ("(\\d{1,2}[-/]\\d{1,2}[-/]\\d{2})", ["MM/dd/yy", "MM-dd-yy", "M/d/yy", "dd/MM/yy", "dd-MM-yy"]),
            // Month name format: Oct 16, 2024 or October 16, 2024
            ("((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4})", ["MMM d, yyyy", "MMMM d, yyyy", "MMM d yyyy", "MMMM d yyyy"]),
            // Date with labels: Date: 10/16/2024
            ("(?i)(?:Date|Dated?|On)[:\\s]+(\\d{1,2}[-/]\\d{1,2}[-/]\\d{2,4})", ["MM/dd/yyyy", "MM-dd-yyyy", "dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yy", "dd/MM/yy"]),
            // Date with labels: Date: Oct 16, 2024
            ("(?i)(?:Date|Dated?|On)[:\\s]+((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4})", ["MMM d, yyyy", "MMMM d, yyyy"])
        ]
        
        for (pattern, formatters) in datePatterns {
            if let dateStr = firstMatch(in: text, pattern: pattern) {
                for format in formatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    // Handle 2-digit years
                    if format.contains("yy") && !format.contains("yyyy") {
                        formatter.twoDigitStartDate = Calendar.current.date(byAdding: .year, value: -80, to: Date())
                    }
                    
                    if let parsedDate = formatter.date(from: dateStr) {
                        // Validate date is reasonable (not too far in past/future)
                        let calendar = Calendar.current
                        let yearsAgo = calendar.dateComponents([.year], from: parsedDate, to: Date()).year ?? 0
                        if yearsAgo >= 0 && yearsAgo <= 10 {
                            date = parsedDate
                            print("✅ Extracted date: \(dateStr) -> \(parsedDate)")
                            return
                        }
                    }
                }
            }
        }
        print("❌ No date extracted from text")
    }
    
    private func extractAmountAndCurrency(from text: String) {
        if !totalAmountText.isEmpty { return }
        
        // Expanded currency symbols and codes
        let currencyMap: [String: String] = [
            "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", 
            "C$": "CAD", "A$": "AUD", "CHF": "CHF", "kr": "SEK",
            "₹": "INR", "₽": "RUB", "₩": "KRW", "₪": "ILS",
            "R$": "BRL", "NZ$": "NZD", "S$": "SGD", "HK$": "HKD"
        ]
        
        // First, try to detect currency separately
        var detectedCurrency: String? = nil
        
        // Look for currency codes in text (case insensitive)
        let currencyCodePattern = "(?i)\\b(USD|EUR|GBP|JPY|CAD|AUD|CHF|SEK|INR|RUB|KRW|ILS|BRL|NZD|SGD|HKD)\\b"
        if let currencyCode = firstMatch(in: text, pattern: currencyCodePattern) {
            detectedCurrency = currencyCode.uppercased()
            print("✅ Found currency code: \(detectedCurrency!)")
        }
        
        // Look for currency symbols in text
        if detectedCurrency == nil {
            for (symbol, code) in currencyMap {
                if text.contains(symbol) {
                    detectedCurrency = code
                    print("✅ Found currency symbol: \(symbol) -> \(code)")
                    break
                }
            }
        }
        
        // Enhanced amount patterns - handle commas, spaces, various formats
        let amountPatterns = [
            // Total with currency symbol before: $12.34, $1,234.56, $ 12.34
            "(?:[$€£¥₹₽₩₪]|C\\$|A\\$|R\\$|NZ\\$|S\\$|HK\\$)\\s*([0-9]{1,3}(?:[,\\s][0-9]{3})*(?:\\.[0-9]{1,2})?)",
            // Total with currency symbol after: 12.34 USD, 1,234.56 EUR
            "([0-9]{1,3}(?:[,\\s][0-9]{3})*(?:\\.[0-9]{1,2})?)\\s*(?:USD|EUR|GBP|JPY|CAD|AUD|CHF|SEK|INR|RUB|KRW|ILS|BRL|NZD|SGD|HKD)",
            // Total with label: Total: $12.34, Amount: 45.67, Sum: 123.45
            "(?i)(?:Total|Amount|Sum|Subtotal|Grand Total|Balance|Due|Paid|Charge)[:\\s]*(?:[$€£¥₹₽₩₪]|C\\$|A\\$|R\\$|NZ\\$|S\\$|HK\\$)?\\s*([0-9]{1,3}(?:[,\\s][0-9]{3})*(?:\\.[0-9]{1,2})?)",
            // Just amounts that look like totals (larger numbers, often at end of receipt)
            "([0-9]{1,3}(?:[,\\s][0-9]{3})*(?:\\.[0-9]{1,2})?)\\s*(?:USD|EUR|GBP|JPY|CAD|AUD|CHF|SEK|INR|RUB|KRW|ILS|BRL|NZD|SGD|HKD)?"
        ]
        
        var foundAmount: String?
        var foundAmountValue: Double = 0
        
        // Try patterns in order of specificity
        for pattern in amountPatterns {
            if let match = firstMatch(in: text, pattern: pattern) {
                // Clean the amount string
                var cleanAmount = match.trimmingCharacters(in: .whitespaces)
                // Remove commas and spaces from number
                cleanAmount = cleanAmount.replacingOccurrences(of: "[,\\s]", with: "", options: .regularExpression)
                
                if let value = Double(cleanAmount), value > 0 {
                    // Prefer larger amounts (likely totals) and amounts near currency symbols/labels
                    if value > foundAmountValue || foundAmount == nil {
                        foundAmount = cleanAmount
                        foundAmountValue = value
                        print("✅ Found amount candidate: \(cleanAmount) (value: \(value))")
                        
                        // If this pattern had a currency indicator, use it
                        if pattern.contains("USD|EUR") || pattern.contains("[$€£") {
                            break // Found amount with currency, use it
                        }
                    }
                }
            }
        }
        
        // If we found an amount, set it
        if let amount = foundAmount {
            totalAmountText = amount
            
            // Set currency if detected
            if let currency = detectedCurrency {
                if let currencyObj = currencies.first(where: { $0.code == currency }) {
                    selectedCurrency = currencyObj
                    print("✅ Set currency to: \(currency)")
                }
            } else {
                // Default to USD if no currency found
                if let usdCurrency = currencies.first(where: { $0.code == "USD" }) {
                    selectedCurrency = usdCurrency
                    print("⚠️ No currency found, defaulting to USD")
                }
            }
        } else {
            print("❌ No amount extracted from text")
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
        print("Loading image from URL: \(url.path)")
        print("File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        // Check if it's a ZIP file
        if url.pathExtension.lowercased() == "zip" {
            print("Attempting to load from ZIP file...")
            if let zipImage = StorageManager.shared.loadImageFromZip(zipURL: url) {
                print("Successfully loaded image from ZIP: \(zipImage.size)")
                return zipImage
            } else {
                print("Failed to load from ZIP, trying direct file access...")
                // Fallback: try to load as regular image file
                if let directImage = UIImage(contentsOfFile: url.path) {
                    print("Successfully loaded image directly: \(directImage.size)")
                    return directImage
                }
            }
        } else {
            // Regular file
            print("Loading regular image file...")
            if let image = UIImage(contentsOfFile: url.path) {
                print("Successfully loaded regular image: \(image.size)")
                return image
            } else {
                print("Failed to load regular image file")
            }
        }
        
        print("ERROR: Could not load image from URL: \(url.path)")
        return nil
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


