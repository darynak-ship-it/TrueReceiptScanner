//
//  SettingsView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import CoreData
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @AppStorage("defaultCurrency") private var defaultCurrency: String = "USD"
    @AppStorage("defaultCategory") private var defaultCategory: String = "Other"
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false
    @State private var showClearHistoryAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showSupport = false
    @State private var showSignInSheet = false
    @State private var showiCloudSyncAlert = false
    @State private var iCloudSyncAlertMessage = ""
    
    private let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "CNY", "INR", "BRL"]
    private let categories = ["Food & Dining", "Transportation", "Office supplies", "Travel expenses", "Entertainment", "Healthcare", "Shopping", "Utilities", "Other"]
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    if authManager.isAuthenticated {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.userName ?? "Signed In")
                                    .font(.headline)
                                if let email = authManager.userEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let providerName = authManager.authProviderName {
                                    Text("Signed in with \(providerName)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        
                        Button(action: {
                            authManager.signOut()
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        Button(action: {
                            showSignInSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Sign In")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // iCloud Sync Section
                Section("iCloud Sync") {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable iCloud Sync")
                                    .font(.headline)
                                Text("Sync your data across devices")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: iCloudSyncEnabled) { newValue in
                        handleiCloudSyncToggle(newValue)
                    }
                    
                    if iCloudSyncEnabled {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Your data will be synced to iCloud and can be recovered if the app is deleted.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
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
                    .onChange(of: defaultCurrency) { newValue in
                        // Mark that user has manually set currency
                        UserDefaults.standard.set(true, forKey: "hasManualCurrency")
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
        .sheet(isPresented: $showSignInSheet) {
            SignInView()
        }
        .alert("iCloud Sync", isPresented: $showiCloudSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(iCloudSyncAlertMessage)
        }
    }
    
    private func handleiCloudSyncToggle(_ enabled: Bool) {
        if enabled {
            // Check if user is authenticated
            if !authManager.isAuthenticated {
                // Reset toggle and show alert
                DispatchQueue.main.async {
                    self.iCloudSyncEnabled = false
                    self.iCloudSyncAlertMessage = "Please sign in to enable iCloud sync. Go to Settings → Account to sign in."
                    self.showiCloudSyncAlert = true
                }
                print("iCloud sync blocked: User not authenticated")
                return
            }
            
            // Check iCloud availability
            if FileManager.default.ubiquityIdentityToken == nil {
                // Reset toggle and show alert
                DispatchQueue.main.async {
                    self.iCloudSyncEnabled = false
                    self.iCloudSyncAlertMessage = "iCloud is not available on this device. Please:\n1. Sign in to iCloud in Settings → [Your Name] → iCloud\n2. Make sure iCloud Drive is enabled\n3. Try again"
                    self.showiCloudSyncAlert = true
                }
                print("iCloud sync blocked: iCloud not available (ubiquityIdentityToken is nil)")
                return
            }
            
            // Success - enable iCloud sync
            DispatchQueue.main.async {
                self.iCloudSyncAlertMessage = "iCloud sync enabled. Your data will be synced across all your devices. Note: You may need to restart the app for changes to take effect."
                self.showiCloudSyncAlert = true
            }
            print("iCloud sync enabled successfully")
        } else {
            // Disable iCloud sync
            DispatchQueue.main.async {
                self.iCloudSyncAlertMessage = "iCloud sync disabled. Your data will only be stored locally on this device."
                self.showiCloudSyncAlert = true
            }
            print("iCloud sync disabled")
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

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var isSigningIn = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text("Sign In")
                    .font(.title2.bold())
                
                Text("Sign in to enable iCloud sync and protect your data. Your information will be securely synced across all your devices.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .frame(height: 50)
                    .disabled(isSigningIn || authManager.isAuthenticated)
                    
                    // Sign in with Google
                    Button(action: {
                        handleGoogleSignIn()
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 18))
                            Text("Sign in with Google")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 0.26, green: 0.52, blue: 0.96))
                        .cornerRadius(8)
                    }
                    .disabled(isSigningIn || authManager.isAuthenticated)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                let email = appleIDCredential.email
                
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                Task { @MainActor in
                    isSigningIn = false
                    authManager.saveUserInfo(
                        identifier: userIdentifier,
                        name: displayName.isEmpty ? nil : displayName,
                        email: email,
                        provider: .apple
                    )
                    dismiss()
                }
            } else {
                // Unexpected credential type
                Task { @MainActor in
                    isSigningIn = false
                    errorMessage = "Unexpected credential type received from Apple."
                    showError = true
                }
            }
        case .failure(let error):
            let nsError = error as NSError
            let errorCode = nsError.code
            
            Task { @MainActor in
                isSigningIn = false
                
                // Handle specific error codes
                switch errorCode {
                case ASAuthorizationError.canceled.rawValue:
                    // User cancelled - don't show error, just return
                    print("Sign in with Apple cancelled by user")
                    return
                case ASAuthorizationError.failed.rawValue:
                    errorMessage = "Sign in with Apple failed. Please check your internet connection and try again."
                case ASAuthorizationError.invalidResponse.rawValue:
                    errorMessage = "Invalid response from Apple. Please try again."
                case ASAuthorizationError.notHandled.rawValue:
                    errorMessage = "Sign in with Apple is not available. Please ensure you're signed in to iCloud and try again."
                case ASAuthorizationError.unknown.rawValue, 1001:
                    // Error 1001 is ASAuthorizationErrorUnknown
                    // On simulator, provide specific message
                    #if targetEnvironment(simulator)
                    errorMessage = "Sign in with Apple requires a real device. Please test on a physical iPhone or iPad."
                    #else
                    errorMessage = "Sign in with Apple configuration issue. Please ensure:\n1. You're signed in to iCloud\n2. The app is properly configured in Apple Developer Portal\n3. Your device is connected to the internet"
                    #endif
                default:
                    errorMessage = "Sign in with Apple failed (error \(errorCode)): \(error.localizedDescription)"
                }
                showError = true
            }
        }
    }
    
    private func handleGoogleSignIn() {
        guard !authManager.isAuthenticated else {
            errorMessage = "You are already signed in. Please sign out first."
            showError = true
            return
        }
        
        isSigningIn = true
        authManager.clearError()
        authManager.signInWithGoogle()
        
        // Monitor for authentication success or errors
        // Store timer reference in a way that avoids Sendable warnings
        var timerRef: Timer?
        timerRef = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                if authManager.isAuthenticated {
                    timerRef?.invalidate()
                    timerRef = nil
                    isSigningIn = false
                    dismiss()
                } else if let error = authManager.lastError {
                    timerRef?.invalidate()
                    timerRef = nil
                    isSigningIn = false
                    errorMessage = error.localizedDescription
                    showError = true
                    authManager.clearError()
                }
            }
        }
        
        // Stop monitoring after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            timerRef?.invalidate()
            timerRef = nil
            if !authManager.isAuthenticated {
                isSigningIn = false
            }
        }
    }
}

#Preview {
    SettingsView()
}
