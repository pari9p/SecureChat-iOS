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
    private var systemThemeObserver: NSObjectProtocol?
    
    public override init() {
        super.init()
        setupSystemThemeObserver()
        loadSavedTheme()
    }
    
    deinit {
        if let observer = systemThemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupSystemThemeObserver() {
        systemThemeObserver = NotificationCenter.default.addObserver(
            forName: .systemThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemThemeChange()
        }
    }
    
    private func handleSystemThemeChange() {
        if currentTheme == .system {
            applyTheme(currentTheme)
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        }
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
        
        // Post notification for legacy code and UI updates
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }
    
    public func getCurrentThemeStyle() -> UIUserInterfaceStyle {
        switch currentTheme {
        case .system:
            return UITraitCollection.current.userInterfaceStyle
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    public func isCurrentlyDark() -> Bool {
        return getCurrentThemeStyle() == .dark
    }
    
    private func applyTheme(_ theme: AppTheme) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }
            
            for window in windowScene.windows {
                UIView.transition(with: window, duration: ThemeConstants.Animation.themeTransitionDuration, options: .transitionCrossDissolve) {
                    window.overrideUserInterfaceStyle = theme.userInterfaceStyle
                }
            }
        }
    }
    
    // MARK: - Convenience Methods
    public func toggleTheme() {
        let nextTheme: AppTheme
        switch currentTheme {
        case .system:
            nextTheme = .light
        case .light:
            nextTheme = .dark
        case .dark:
            nextTheme = .system
        }
        setTheme(nextTheme)
    }
    
    public func setLightTheme() {
        setTheme(.light)
    }
    
    public func setDarkTheme() {
        setTheme(.dark)
    }
    
    public func setSystemTheme() {
        setTheme(.system)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let themeDidChange = Notification.Name("SecureChat.ThemeDidChange")
    static let systemThemeDidChange = Notification.Name("SecureChat.SystemThemeDidChange")
}

// MARK: - Theme Constants
public struct ThemeConstants {
    
    // MARK: - Brand Colors
    struct Brand {
        static let primaryBlue = UIColor(red: 0.13, green: 0.4, blue: 0.96, alpha: 1.0) // #2267F5
        static let accentBlue = UIColor(red: 0.17, green: 0.44, blue: 0.98, alpha: 1.0) // #2D70FA
        static let successGreen = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0) // #34C759
        static let warningYellow = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0) // #FFCC00
        static let dangerRed = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0) // #FF3B30
    }
    
    // MARK: - Semantic Colors
    struct Semantic {
        static let onlineStatus = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
        static let offlineStatus = UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
        static let typing = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        static let unreadBadge = Brand.dangerRed
        static let linkText = Brand.primaryBlue
    }
    
    // MARK: - Animation
    struct Animation {
        static let themeTransitionDuration: TimeInterval = 0.3
        static let standardDuration: TimeInterval = 0.25
    }
}

// MARK: - UIColor Extensions for Theme Support
extension UIColor {
    
    // MARK: - SecureChat Brand Colors
    static var secureChatPrimary: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.18, green: 0.44, blue: 0.98, alpha: 1.0) // Lighter blue for dark mode
            default:
                return ThemeConstants.Brand.primaryBlue
            }
        }
    }
    
    static var secureChatAccent: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.36, green: 0.57, blue: 1.0, alpha: 1.0) // #5D92FF
            default:
                return ThemeConstants.Brand.accentBlue
            }
        }
    }
    
    // MARK: - Background Colors
    static var secureChatBackground: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) // Pure black
            default:
                return UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0) // Off-white
            }
        }
    }
    
    static var secureChatSecondaryBackground: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Dark card color
            default:
                return UIColor.white
            }
        }
    }
    
    static var secureChatCardBackground: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
            default:
                return UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
            }
        }
    }
    
    // MARK: - Text Colors
    static var secureChatText: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.white
            default:
                return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            }
        }
    }
    
    static var secureChatSecondaryText: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.76, green: 0.76, blue: 0.78, alpha: 1.0)
            default:
                return UIColor(red: 0.43, green: 0.43, blue: 0.45, alpha: 1.0)
            }
        }
    }
    
    static var secureChatTertiaryText: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
            default:
                return UIColor(red: 0.69, green: 0.69, blue: 0.72, alpha: 1.0)
            }
        }
    }
    
    // MARK: - Message Bubble Colors
    static var secureChatOutgoingBubble: UIColor {
        return secureChatPrimary
    }
    
    static var secureChatIncomingBubble: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0)
            default:
                return UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1.0)
            }
        }
    }
    
    // MARK: - Semantic Colors
    static var secureChatSuccess: UIColor {
        return ThemeConstants.Brand.successGreen
    }
    
    static var secureChatWarning: UIColor {
        return ThemeConstants.Brand.warningYellow
    }
    
    static var secureChatDanger: UIColor {
        return ThemeConstants.Brand.dangerRed
    }
    
    static var secureChatSeparator: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.33, green: 0.33, blue: 0.35, alpha: 0.6)
            default:
                return UIColor(red: 0.78, green: 0.78, blue: 0.78, alpha: 0.6)
            }
        }
    }
}