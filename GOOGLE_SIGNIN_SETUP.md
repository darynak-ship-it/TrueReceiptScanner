# Google Sign-In Setup Instructions

## Prerequisites

1. **Add Google Sign-In SDK to Xcode Project**
   - Open the project in Xcode
   - Go to File > Add Package Dependencies
   - Enter URL: `https://github.com/google/GoogleSignIn-iOS`
   - Select version: Latest (or specific version)
   - Add to target: "Receipt Scanner"

2. **Configure Google OAuth 2.0 Client ID**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one
   - Enable Google Sign-In API
   - Create OAuth 2.0 Client ID for iOS
   - Add your app's bundle identifier: `com.darynakalnichenko.app.Receipt-Scanner`
   - Download `GoogleService-Info.plist` and add it to your Xcode project

3. **Configure URL Scheme**
   - In Xcode, select your project target
   - Go to Info tab
   - Under URL Types, add a new URL Type:
     - Identifier: `GoogleSignIn`
     - URL Schemes: Use the reversed client ID from `GoogleService-Info.plist`
       (Format: `com.googleusercontent.apps.YOUR_CLIENT_ID`)

4. **Update Info.plist (if needed)**
   - The app will automatically read the client ID from `GoogleService-Info.plist`
   - If you prefer to hardcode it, update `Receipt_ScannerApp.swift` with your client ID

## Testing

1. Test Sign in with Apple (should work immediately)
2. Test Sign in with Google (requires GoogleService-Info.plist)
3. Verify iCloud sync works with both providers
4. Test sign-out functionality
5. Verify provider switching is prevented (as per requirements)

## Notes

- The app prevents switching between authentication providers once signed in
- Both authentication methods work with iCloud sync
- User data is stored locally and synced to iCloud when enabled

