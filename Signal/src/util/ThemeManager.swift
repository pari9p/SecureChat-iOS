//
// ThemeManager.swift
// SecureChat
//
// Created by SecureChat Team on 2/12/2026.
// Copyright 2025 SecureChat Development Team
//

import UIKit
import Combine

public enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@objc
public class ThemeManager: NSObject {
    
    public static let shared = ThemeManager()
    
    @Published public private(set) var currentTheme: AppTheme = .system
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "SecureChat.SelectedTheme"
    
    public override init() {
        super.init()
        loadSavedTheme()
    }
    
    private func loadSavedTheme() {
        if let savedTheme = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
        applyTheme(currentTheme)
    }
    
    public func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        userDefaults.set(theme.rawValue, forKey: themeKey)
        applyTheme(theme)
        
        // Post notification for legacy code
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }
    
    private func applyTheme(_ theme: AppTheme) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.overrideUserInterfaceStyle = theme.userInterfaceStyle
            }
        }
    }
}

// MARK: - Notification
extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}

// MARK: - UIColor Extensions for Theme Support
extension UIColor {
    
    static var secureChatPrimary: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0) // Light blue for dark mode
            default:
                return UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0) // Darker blue for light mode
            }
        }
    }
    
    static var secureChatBackground: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            default:
                return UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
            }
        }
    }
    
    static var secureChatSecondaryBackground: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
            default:
                return UIColor.white
            }
        }
    }
    
    static var secureChatText: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.white
            default:
                return UIColor.black
            }
        }
    }
    
    static var secureChatSecondaryText: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
            default:
                return UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            }
        }
    }
}