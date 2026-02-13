//
// ThemeUtils.swift
// SecureChat
//
// Created by SecureChat Team on 2/13/2026.
// Copyright 2025 SecureChat Development Team
//

import UIKit

// MARK: - Theme Utilities
public enum ThemeUtils {
    
    // MARK: - View Configuration
    /// Configure a view with theme-aware background colors
    public static func configureBackground(for view: UIView, style: BackgroundStyle = .primary) {
        switch style {
        case .primary:
            view.backgroundColor = Colors.Background.primary
        case .secondary:
            view.backgroundColor = Colors.Background.secondary
        case .card:
            view.backgroundColor = Colors.Background.card
        }
    }
    
    /// Configure a label with theme-aware text colors
    public static func configureText(for label: UILabel, style: TextStyle = .primary) {
        switch style {
        case .primary:
            label.textColor = Colors.Text.primary
        case .secondary:
            label.textColor = Colors.Text.secondary
        case .tertiary:
            label.textColor = Colors.Text.tertiary
        case .link:
            label.textColor = Colors.Text.link
        }
    }
    
    /// Configure a button with theme-aware colors
    public static func configureButton(_ button: UIButton, style: ButtonStyle = .primary) {
        switch style {
        case .primary:
            button.backgroundColor = Colors.Button.primaryBackground
            button.setTitleColor(Colors.Button.primaryText, for: .normal)
            button.layer.borderWidth = 0
        case .secondary:
            button.backgroundColor = Colors.Button.secondaryBackground
            button.setTitleColor(Colors.Button.secondaryText, for: .normal)
            button.layer.borderColor = Colors.Button.secondaryBorder.cgColor
            button.layer.borderWidth = 1.0
        case .destructive:
            button.backgroundColor = Colors.Button.destructiveBackground
            button.setTitleColor(Colors.Button.destructiveText, for: .normal)
            button.layer.borderWidth = 0
        }\n        \n        // Standard button styling\n        button.layer.cornerRadius = 8.0\n        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)\n    }\n    \n    /// Configure a text field with theme-aware colors\n    public static func configureTextField(_ textField: UITextField) {\n        textField.backgroundColor = Colors.Input.background\n        textField.textColor = Colors.Input.text\n        textField.layer.borderColor = Colors.Input.border.cgColor\n        textField.layer.borderWidth = 1.0\n        textField.layer.cornerRadius = 8.0\n        \n        // Placeholder color\n        if let placeholder = textField.placeholder {\n            textField.attributedPlaceholder = NSAttributedString(\n                string: placeholder,\n                attributes: [.foregroundColor: Colors.Input.placeholder]\n            )\n        }\n    }\n    \n    /// Add theme change observer to a view controller\n    public static func observeThemeChanges(for viewController: UIViewController, selector: Selector) {\n        NotificationCenter.default.addObserver(\n            viewController,\n            selector: selector,\n            name: .themeDidChange,\n            object: nil\n        )\n    }\n    \n    /// Remove theme change observer\n    public static func removeThemeObserver(for viewController: UIViewController) {\n        NotificationCenter.default.removeObserver(viewController, name: .themeDidChange, object: nil)\n    }\n}\n\n// MARK: - Style Enums\npublic enum BackgroundStyle {\n    case primary\n    case secondary\n    case card\n}\n\npublic enum TextStyle {\n    case primary\n    case secondary\n    case tertiary\n    case link\n}\n\npublic enum ButtonStyle {\n    case primary\n    case secondary\n    case destructive\n}\n\n// MARK: - UIView Extensions\nextension UIView {\n    /// Apply theme-aware styling to the view\n    public func applyTheme(backgroundStyle: BackgroundStyle = .primary) {\n        ThemeUtils.configureBackground(for: self, style: backgroundStyle)\n    }\n}\n\n// MARK: - UILabel Extensions\nextension UILabel {\n    /// Apply theme-aware text styling\n    public func applyTheme(textStyle: TextStyle = .primary) {\n        ThemeUtils.configureText(for: self, style: textStyle)\n    }\n}\n\n// MARK: - UIButton Extensions\nextension UIButton {\n    /// Apply theme-aware button styling\n    public func applyTheme(buttonStyle: ButtonStyle = .primary) {\n        ThemeUtils.configureButton(self, style: buttonStyle)\n    }\n}\n\n// MARK: - UITextField Extensions\nextension UITextField {\n    /// Apply theme-aware text field styling\n    public func applyTheme() {\n        ThemeUtils.configureTextField(self)\n    }\n}"