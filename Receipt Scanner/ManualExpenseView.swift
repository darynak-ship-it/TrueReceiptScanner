//
//  ManualExpenseView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import UIKit

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

// MARK: - ManualExpenseView

struct ManualExpenseView: View {
    let onSaved: () -> Void
    let onCancel: () -> Void
    
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
    
    // Image attachment
    @State private var attachedImage: UIImage? = nil
    @State private var attachedImageURL: URL? = nil
    @State private var showReceiptViewer: Bool = false
    
    // Sheet toggles
    @State private var showCurrencySheet: Bool = false
    @State private var showCategorySheet: Bool = false
    @State private var showPaymentSheet: Bool = false
    @State private var showSavedAlert: Bool = false
    @State private var showImagePicker: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Image attachment section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Receipt Image (Optional)")
                        .font(.headline)
                    
                    if let image = attachedImage {
                        Button(action: { showReceiptViewer = true }) {
                            HStack(spacing: 12) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .cornerRadius(12)
                                
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .foregroundColor(.secondary)
                                    Text("Tap to view full size")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        
                        HStack {
                            Button("Remove Image") {
                                attachedImage = nil
                                attachedImageURL = nil
                            }
                            .foregroundColor(.red)
                            
                            Spacer()
                            
                            Button("Replace Image") {
                                showImagePicker = true
                            }
                            .foregroundColor(.accentColor)
                        }
                        .font(.subheadline)
                    } else {
                        Button(action: { showImagePicker = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title)
                                    .foregroundColor(.accentColor)
                                
                                Text("Attach Receipt Image")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                
                                Text("Optional - helps with record keeping")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                
                // Single gray pad with all editable fields
                VStack(alignment: .leading, spacing: 16) {
                    // Field 1 - Merchant Name (white rounded field with example)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant Name")
                            .font(.headline)
                        TextField("Enter merchant name", text: $merchantName)
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
                            TextField("0.00", text: $totalAmountText)
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
        .navigationTitle("Manual Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel", action: onCancel)
                    .foregroundColor(.accentColor)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $attachedImage)
        }
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
        .fullScreenCover(isPresented: $showReceiptViewer) {
            if let image = attachedImage {
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        GeometryReader { geometry in
                            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width)
                            }
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
        .onChange(of: attachedImage) { _, newImage in
            if let image = newImage {
                // Save the image and perform OCR
                if let url = FileStorage.save(image: image) {
                    attachedImageURL = url
                    // Perform OCR on the attached image
                    OCRTextRecognizer.recognizeText(from: image) { recognizedText in
                        DispatchQueue.main.async {
                            prefillFromOCR(recognizedText ?? "")
                        }
                    }
                }
            }
        }
    }
    
    private func saveExpense() {
        // Save the expense with optional image
        // For now, just show success and call onSaved
        showSavedAlert = true
        onSaved()
    }
    
    private func prefillFromOCR(_ recognizedText: String) {
        let text = recognizedText
        
        // Only prefill if fields are empty
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
            if let dt = formatter.date(from: dateStr.replacingOccurrences(of: "/", with: "-")) { 
                date = dt 
            }
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
        ManualExpenseView(
            onSaved: {},
            onCancel: {}
        )
    }
}
