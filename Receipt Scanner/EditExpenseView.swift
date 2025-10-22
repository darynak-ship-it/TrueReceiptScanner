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

    var body: some View {
            ScrollView {
            VStack(spacing: 16) {
                // Small preview at the very top (tap to view full receipt)
                let previewImage = UIImage(contentsOfFile: imageURL.path) ?? SampleReceiptGenerator.generate()
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
                            .background(Color.white)
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
                                .background(Color.white)
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
                            }
                            TextField("", text: $tagsText)
                                .padding(12)
                                .background(Color.white.opacity(0.001))
                        }
                        .padding(12)
                        .background(Color.white)
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
                                    .padding(.leading, 6)
                            }
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                            .padding(8)
                                .background(Color.clear)
                        }
                        .padding(12)
                        .background(Color.white)
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
        .onAppear(perform: prefillFromOCR)
        .sheet(isPresented: $showCurrencySheet) {
            CurrencyPickerView(selected: $selectedCurrency, isPresented: $showCurrencySheet)
        }
        .sheet(isPresented: $showCategorySheet) {
            CategoryPickerView(selected: $selectedCategory, isPresented: $showCategorySheet)
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentPickerView(selected: $selectedPayment, isPresented: $showPaymentSheet)
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
            let fullImage = UIImage(contentsOfFile: imageURL.path) ?? SampleReceiptGenerator.generate()
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
        // Parse amount
        let amount = Double(totalAmountText) ?? 0.0
        
        // Parse tags
        let tags = tagsText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Use the existing image URL from scanning - no need to save again
        // The image was already saved during the scanning process in ScannerContainer
        let finalImageURL = imageURL
        
        // Create thumbnail if needed (for better performance in lists)
        let thumbnailURL: URL?
        if let image = UIImage(contentsOfFile: imageURL.path) {
            let thumbnailResult = StorageManager.shared.saveReceiptImage(image, compressionQuality: 0.3)
            thumbnailURL = thumbnailResult.thumbnailURL
        } else {
            thumbnailURL = nil
        }
        
        // Create receipt directly in Core Data
        let receipt = Receipt(context: viewContext)
        receipt.id = UUID()
        receipt.merchantName = merchantName.isEmpty ? "Unknown Merchant" : merchantName
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

    // Very lightweight heuristics based on recognizedText
    private func prefillFromOCR() {
        let text = recognizedText
        if merchantName.isEmpty {
            if let m = firstMatch(in: text, pattern: "(?:Store|Merchant)[:\\t ]+(.+)") {
                merchantName = m
            } else if let firstLine = text.split(separator: "\n").first, !firstLine.lowercased().contains("receipt") {
                merchantName = String(firstLine).trimmingCharacters(in: .whitespaces)
            }
        }

        if let dateStr = firstMatch(in: text, pattern: "(\\d{4}[-/](?:0?[1-9]|1[0-2])[-/](?:0?[1-9]|[12]\\d|3[01]))") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let dt = formatter.date(from: dateStr.replacingOccurrences(of: "/", with: "-")) { date = dt }
        }

        if totalAmountText.isEmpty {
            if let tot = firstMatch(in: text, pattern: "Total[^\\n]*?([0-9]+(?:\\.[0-9]{1,2})?)") {
                totalAmountText = tot
            }
        }
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
}

// MARK: - Currency Picker

private struct CurrencyPickerView: View {
    @Binding var selected: Currency
    @Binding var isPresented: Bool

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


