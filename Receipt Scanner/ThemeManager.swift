//
//  ThemeManager.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var appTheme: String = "system"
    
    private init() {
        // Load from UserDefaults
        self.appTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "system"
    }
    
    func setTheme(_ theme: String) {
        appTheme = theme
        UserDefaults.standard.set(theme, forKey: "appTheme")
    }
    
    var colorScheme: ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // Use system default
        }
    }
    
    // Theme-aware colors
    var backgroundColor: Color {
        switch appTheme {
        case "light":
            return Color(.systemBackground)
        case "dark":
            return Color(.systemBackground)
        default:
            return Color(.systemBackground)
        }
    }
    
    var secondaryBackgroundColor: Color {
        switch appTheme {
        case "light":
            return Color(.secondarySystemBackground)
        case "dark":
            return Color.gray.opacity(0.2)
        default:
            return Color(.secondarySystemBackground)
        }
    }
    
    var textFieldBackgroundColor: Color {
        // Use system color that automatically adapts to light/dark mode
        // This provides proper contrast in both themes
        return Color(UIColor.secondarySystemBackground)
    }
    
    var selectionColor: Color {
        switch appTheme {
        case "light":
            return Color.gray.opacity(0.3)
        case "dark":
            return Color.gray.opacity(0.4)
        default:
            return Color.gray.opacity(0.3)
        }
    }
}

// Extension to apply theme to the app
extension View {
    func applyTheme() -> some View {
        self.preferredColorScheme(ThemeManager.shared.colorScheme)
    }
}
