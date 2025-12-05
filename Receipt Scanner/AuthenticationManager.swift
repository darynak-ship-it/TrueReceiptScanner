//
//  AuthenticationManager.swift
//  Receipt Scanner
//
//  Created by AI Assistant
//

import Foundation
import AuthenticationServices
import SwiftUI
import Combine

// Conditionally import GoogleSignIn if available
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum AuthProvider: String, Codable {
    case apple = "apple"
    case google = "google"
    case none = "none"
}

enum AuthError: LocalizedError {
    case providerSwitchNotAllowed
    case googleSignInNotConfigured
    case googleSignInFailed(String)
    case appleSignInFailed(String)
    case networkError
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .providerSwitchNotAllowed:
            return "Cannot switch authentication providers. Please sign out first."
        case .googleSignInNotConfigured:
            return "Google Sign-In is not configured. Please contact support."
        case .googleSignInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .appleSignInFailed(let message):
            return "Sign in with Apple failed: \(message)"
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .unknownError(let message):
            return "An error occurred: \(message)"
        }
    }
}

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var userIdentifier: String?
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var authProvider: AuthProvider = .none
    @Published var authProviderName: String?
    @Published var lastError: AuthError?
    
    private let userDefaults = UserDefaults.standard
    private let userIdentifierKey = "userIdentifier"
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"
    private let authProviderKey = "authProvider"
    
    override init() {
        super.init()
        // Restore authentication state
        if let providerString = userDefaults.string(forKey: authProviderKey),
           let provider = AuthProvider(rawValue: providerString) {
            self.authProvider = provider
            
            if let identifier = userDefaults.string(forKey: userIdentifierKey) {
                self.userIdentifier = identifier
                self.userName = userDefaults.string(forKey: userNameKey)
                self.userEmail = userDefaults.string(forKey: userEmailKey)
                self.isAuthenticated = true
                self.authProviderName = provider == .apple ? "Apple" : (provider == .google ? "Google" : nil)
            }
        }
    }
    
    func signInWithApple() {
        // Prevent switching providers if already authenticated
        guard authProvider == .none || authProvider == .apple else {
            lastError = .providerSwitchNotAllowed
            print("Cannot switch authentication providers. Please sign out first.")
            return
        }
        
        lastError = nil
        
        // Check if Sign in with Apple is available
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        
        // Create the request
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Create authorization controller
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        // Perform requests - this will show the Sign in with Apple UI
        authorizationController.performRequests()
    }
    
    func signInWithGoogle() {
        #if canImport(GoogleSignIn)
        // Prevent switching providers if already authenticated
        guard authProvider == .none || authProvider == .google else {
            lastError = .providerSwitchNotAllowed
            print("Cannot switch authentication providers. Please sign out first.")
            return
        }
        
        lastError = nil
        
        guard let presentingViewController = getRootViewController() else {
            lastError = .unknownError("Could not get root view controller for Google Sign-In")
            print("Error: Could not get root view controller for Google Sign-In")
            return
        }
        
        // Check if Google Sign-In is configured
        guard GIDSignIn.sharedInstance.configuration != nil else {
            lastError = .googleSignInNotConfigured
            print("Error: Google Sign-In client ID not configured")
            return
        }
        
        // Sign in with Google
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
                guard let self = self else { return }
                
                // Ensure UI updates happen on main thread
                Task { @MainActor in
                    if let error = error {
                        let nsError = error as NSError
                        let errorCode = nsError.code
                        let errorDescription = error.localizedDescription.lowercased()
                        
                        // Handle specific error cases
                        if errorCode == -5 || errorDescription.contains("cancel") || errorDescription.contains("cancelled") {
                            // User cancelled - don't show error
                            print("Google Sign-In cancelled by user")
                            return
                        } else if errorCode == -1009 || errorDescription.contains("network") || errorDescription.contains("internet") {
                            self.lastError = .networkError
                        } else {
                            self.lastError = .googleSignInFailed("Error code \(errorCode): \(error.localizedDescription)")
                        }
                        
                        print("Google Sign-In error (code \(errorCode)): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let result = result else {
                        self.lastError = .googleSignInFailed("No user data received")
                        print("Google Sign-In failed: No user data")
                        return
                    }
                    
                    let user = result.user
                    let identifier = user.userID ?? UUID().uuidString
                    let name = user.profile?.name
                    let email = user.profile?.email
                    
                    self.saveUserInfo(
                        identifier: identifier,
                        name: name,
                        email: email,
                        provider: .google
                    )
                }
            }
        #else
        lastError = .googleSignInNotConfigured
        print("Google Sign-In SDK not available. Please add GoogleSignIn package to your project.")
        #endif
    }
    
    func signOut() {
        lastError = nil
        
        // Handle provider-specific sign-out
        switch authProvider {
        case .google:
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.signOut()
            #endif
        case .apple:
            // Apple Sign-In doesn't require explicit sign-out
            break
        case .none:
            break
        }
        
        // Clear all stored data
        userDefaults.removeObject(forKey: userIdentifierKey)
        userDefaults.removeObject(forKey: userNameKey)
        userDefaults.removeObject(forKey: userEmailKey)
        userDefaults.removeObject(forKey: authProviderKey)
        
        userIdentifier = nil
        userName = nil
        userEmail = nil
        authProvider = .none
        authProviderName = nil
        isAuthenticated = false
    }
    
    // Legacy method for backward compatibility
    func signIn() {
        signInWithApple()
    }
    
    func checkAuthenticationStatus() {
        guard let userIdentifier = userIdentifier else {
            isAuthenticated = false
            return
        }
        
        switch authProvider {
        case .apple:
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userIdentifier) { [weak self] credentialState, error in
                DispatchQueue.main.async {
                    switch credentialState {
                    case .authorized:
                        self?.isAuthenticated = true
                    case .revoked, .notFound:
                        self?.isAuthenticated = false
                        self?.signOut()
                    default:
                        break
                    }
                }
            }
        case .google:
            #if canImport(GoogleSignIn)
            // Check if Google user is still signed in
            if GIDSignIn.sharedInstance.currentUser != nil {
                isAuthenticated = true
            } else {
                isAuthenticated = false
                signOut()
            }
            #else
            isAuthenticated = false
            signOut()
            #endif
        case .none:
            isAuthenticated = false
        }
    }
    
    func saveUserInfo(identifier: String, name: String?, email: String?, provider: AuthProvider = .apple) {
        // Store provider type
        userDefaults.set(provider.rawValue, forKey: authProviderKey)
        
        // Store user info
        userDefaults.set(identifier, forKey: userIdentifierKey)
        if let name = name {
            userDefaults.set(name, forKey: userNameKey)
        }
        if let email = email {
            userDefaults.set(email, forKey: userEmailKey)
        }
        
        // Update published properties
        self.userIdentifier = identifier
        self.userName = name
        self.userEmail = email
        self.authProvider = provider
        self.authProviderName = provider == .apple ? "Apple" : (provider == .google ? "Google" : nil)
        self.isAuthenticated = true
    }
    
    // Helper methods
    private func getRootViewController() -> UIViewController? {
        // Try multiple methods to get the root view controller
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            return rootViewController
        }
        
        // Fallback: try to get any window's root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            return rootViewController
        }
        
        // Last resort: create a temporary view controller
        print("Warning: Could not find root view controller, creating temporary one")
        return UIViewController()
    }
    
    // Helper method to clear errors
    func clearError() {
        lastError = nil
    }
}

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            
            let displayName = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            saveUserInfo(
                identifier: userIdentifier,
                name: displayName.isEmpty ? nil : displayName,
                email: email,
                provider: .apple
            )
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        let errorCode = nsError.code
        
        // Handle specific error cases
        if errorCode == ASAuthorizationError.canceled.rawValue {
            // User cancelled - don't show error, just return silently
            print("Sign in with Apple cancelled by user")
            return
        } else if errorCode == ASAuthorizationError.failed.rawValue {
            // Network or other failure - try to provide helpful message
            lastError = .networkError
            print("Sign in with Apple failed: Network error or service unavailable")
        } else if errorCode == ASAuthorizationError.invalidResponse.rawValue {
            lastError = .appleSignInFailed("Invalid response from Apple. Please try again.")
            print("Sign in with Apple failed: Invalid response")
        } else if errorCode == ASAuthorizationError.notHandled.rawValue {
            lastError = .appleSignInFailed("Sign in with Apple is not available. Please ensure you're signed in to iCloud.")
            print("Sign in with Apple failed: Not handled")
        } else if errorCode == ASAuthorizationError.unknown.rawValue || errorCode == 1001 {
            // Error 1001 or unknown - this usually means configuration issue
            // Try to provide actionable guidance
            #if targetEnvironment(simulator)
            lastError = .appleSignInFailed("Sign in with Apple requires a real device. Please test on a physical iPhone or iPad.")
            print("Sign in with Apple failed: Simulator limitation")
            #else
            // On real device, this might be a configuration issue
            lastError = .appleSignInFailed("Sign in with Apple configuration issue. Please ensure:\n1. You're signed in to iCloud\n2. The app is properly configured in Apple Developer Portal\n3. Your device is connected to the internet")
            print("Sign in with Apple failed: Configuration issue (code \(errorCode))")
            #endif
        } else {
            // Generic error - show the actual error message
            let errorMessage = error.localizedDescription.isEmpty ? "Unknown error occurred (code \(errorCode))" : error.localizedDescription
            lastError = .appleSignInFailed(errorMessage)
            print("Sign in with Apple failed (code: \(errorCode)): \(error.localizedDescription)")
        }
    }
}

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the first active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            // Fallback: create a new window if none found (shouldn't happen in normal operation)
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let window = windowScene?.windows.first ?? UIWindow()
            return window
        }
        return window
    }
}

