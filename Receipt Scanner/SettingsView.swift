//
//  SettingsView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("defaultCurrency") private var defaultCurrency: String = "USD"
    @AppStorage("defaultCategory") private var defaultCategory: String = "Other"
    @State private var showClearHistoryAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showSupport = false
    
    private let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "CNY", "INR", "BRL"]
    private let categories = ["Food & Dining", "Transportation", "Office supplies", "Travel expenses", "Entertainment", "Healthcare", "Shopping", "Utilities", "Other"]
    
    var body: some View {
        NavigationStack {
            List {
                // App Theme Section
                Section("Appearance") {
                    Picker("App Theme", selection: $themeManager.appTheme) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: themeManager.appTheme) { newTheme in
                        themeManager.setTheme(newTheme)
                    }
                }
                
                // Default Settings Section
                Section("Defaults") {
                    Picker("Default Currency", selection: $defaultCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    
                    Picker("Default Category", selection: $defaultCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                // Data Management Section
                Section("Data Management") {
                    Button(action: {
                        showClearHistoryAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Scan History")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Legal Section
                Section("Legal") {
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                        }
                    }
                    
                    Button(action: {
                        showTermsOfService = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
                        }
                    }
                }
                
                // Support Section
                Section("Support") {
                    Button(action: {
                        showSupport = true
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Support")
                        }
                    }
                }
                
                // App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Clear Scan History", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearScanHistory()
            }
        } message: {
            Text("This will permanently delete all scanned receipts and reports. This action cannot be undone.")
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showSupport) {
            SupportView()
        }
    }
    
    private func clearScanHistory() {
        // Clear all receipts and reports from Core Data
        let context = PersistenceController.shared.container.viewContext
        
        // Delete all receipts
        let receiptFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Receipt")
        let receiptDeleteRequest = NSBatchDeleteRequest(fetchRequest: receiptFetchRequest)
        
        // Delete all reports
        let reportFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Report")
        let reportDeleteRequest = NSBatchDeleteRequest(fetchRequest: reportFetchRequest)
        
        do {
            try context.execute(receiptDeleteRequest)
            try context.execute(reportDeleteRequest)
            try context.save()
            
        } catch {
            print("Error clearing scan history: \(error)")
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.largeTitle.bold())
                        .padding(.bottom)
                    
                    Text("Last updated: October 16, 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                    
                    Group {
                        Text("Information We Collect")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("Receipt Scanner collects and stores the following information:")
                        Text("• Receipt images you scan or upload")
                        Text("• Text extracted from receipts using OCR technology")
                        Text("• Expense data you manually enter")
                        Text("• App usage statistics and crash reports")
                        
                        Text("Data Storage")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("All your data is stored locally on your device. We do not transmit your personal information to external servers without your explicit consent.")
                        
                        Text("Data Security")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("We implement appropriate security measures to protect your data, including encryption of sensitive information and secure storage practices.")
                        
                        Text("Your Rights")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("You have the right to:")
                        Text("• Access your data")
                        Text("• Delete your data")
                        Text("• Export your data")
                        Text("• Withdraw consent at any time")
                        
                        Text("Contact Us")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("If you have any questions about this Privacy Policy, please contact us at smthisbrewing@gmail.com")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.largeTitle.bold())
                        .padding(.bottom)
                    
                    Text("Last updated: October 16, 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                    
                    Group {
                        Text("Acceptance of Terms")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("By using Receipt Scanner, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.")
                        
                        Text("Use License")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("Receipt Scanner is licensed for personal use only. You may not:")
                        Text("• Redistribute the app")
                        Text("• Reverse engineer the app")
                        Text("• Use the app for commercial purposes without permission")
                        
                        Text("User Responsibilities")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("You are responsible for:")
                        Text("• Ensuring the accuracy of data you enter")
                        Text("• Maintaining the security of your device")
                        Text("• Complying with applicable laws and regulations")
                        
                        Text("Limitation of Liability")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("Receipt Scanner is provided 'as is' without warranties of any kind. We shall not be liable for any damages arising from the use of this app.")
                        
                        Text("Changes to Terms")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.")
                        
                        Text("Contact Information")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("For questions about these Terms of Service, please contact us at smthisbrewing@gmail.com")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
