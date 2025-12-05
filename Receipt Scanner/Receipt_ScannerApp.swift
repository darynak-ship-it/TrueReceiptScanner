//
//  Receipt_ScannerApp.swift
//  Receipt Scanner
//
//  Created by Daryna Kalnichenko on 10/15/25.
//

import SwiftUI
import CoreData

// Conditionally import GoogleSignIn if available
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct Receipt_ScannerApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Detect currency from location on app launch
        // This will only set currency if user hasn't manually set it
        LocationManager.shared.detectCurrencyFromLocation()
        #if canImport(GoogleSignIn)
        // Configure Google Sign-In
        // Try to get client ID from GoogleService-Info.plist first
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String, !clientID.isEmpty {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            #if DEBUG
            print("Google Sign-In configured with client ID from GoogleService-Info.plist")
            #endif
        } else {
            // For development/testing: Use a placeholder that allows the app to compile
            // In production, you MUST replace this with your actual Google OAuth 2.0 Client ID
            // Get it from: https://console.cloud.google.com/apis/credentials
            // Format: "YOUR_CLIENT_ID.apps.googleusercontent.com"
            let placeholderClientID = "YOUR_CLIENT_ID_HERE.apps.googleusercontent.com"
            
            // Only configure if it's not the placeholder (to avoid runtime errors)
            if placeholderClientID != "YOUR_CLIENT_ID_HERE.apps.googleusercontent.com" {
                let config = GIDConfiguration(clientID: placeholderClientID)
                GIDSignIn.sharedInstance.configuration = config
                #if DEBUG
                print("Google Sign-In configured with client ID")
                #endif
            } else {
                // Only show warning in debug builds to avoid cluttering production logs
                #if DEBUG
                print("Note: Google Sign-In client ID not configured. Google Sign-In will be disabled until configured.")
                print("To enable: Add GoogleService-Info.plist or set client ID in Receipt_ScannerApp.swift")
                #endif
            }
        }
        #else
        #if DEBUG
        print("Google Sign-In SDK not available. Add GoogleSignIn package to enable Google Sign-In.")
        #endif
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    // Handle Google Sign-In URL callback
                    // Check if this is a Google Sign-In URL
                    if url.scheme?.hasPrefix("com.googleusercontent.apps") == true {
                        _ = GIDSignIn.sharedInstance.handle(url)
                    }
                    #endif
                }
        }
    }
}
