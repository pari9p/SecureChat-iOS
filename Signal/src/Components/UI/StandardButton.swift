//
// StandardButton.swift
// SecureChat
//
// Created by SecureChat Team on 2/13/2026.
// Copyright 2025 SecureChat Development Team
//

import UIKit

/// A standardized button component with consistent theming and styling across the app
class StandardButton: UIButton {
    
    // MARK: - Button Styles
    enum Style {
        case primary      // Filled background with primary color
        case secondary    // Outlined with primary color  
        case destructive  // Red color for dangerous actions
        case text         // Text-only button with no background
    }
    
    enum Size {
        case large       // 48pt height, 16pt padding
        case medium      // 40pt height, 12pt padding
        case small       // 32pt height, 8pt padding
        case compact     // 28pt height, 6pt padding
    }
    
    // MARK: - Properties
    private var buttonStyle: Style = .primary
    private var buttonSize: Size = .medium
    
    // MARK: - Initialization
    init(style: Style = .primary, size: Size = .medium) {
        self.buttonStyle = style
        self.buttonSize = size
        super.init(frame: .zero)
        setupButton()
        setupThemeObserver()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
        setupThemeObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
        setupThemeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupButton() {
        // Apply size configurations
        applySizeConfiguration()
        
        // Apply style configurations
        applyStyleConfiguration()
        
        // Common styling
        titleLabel?.font = fontForSize(buttonSize)
        titleLabel?.adjustsFontSizeToFitWidth = false
        titleLabel?.lineBreakMode = .byTruncatingTail
        adjustsImageWhenHighlighted = false
        adjustsImageWhenDisabled = false
    }
    
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }
    
    @objc private func themeDidChange() {
        applyStyleConfiguration()
    }
    
    // MARK: - Configuration Methods
    func configure(style: Style, size: Size = .medium) {
        self.buttonStyle = style
        self.buttonSize = size
        setupButton()
    }
    
    private func applySizeConfiguration() {
        let config = sizeConfiguration(for: buttonSize)
        
        // Set height constraint
        heightAnchor.constraint(equalToConstant: config.height).isActive = true
        
        // Set content insets
        contentEdgeInsets = UIEdgeInsets(
            top: 0,
            left: config.horizontalPadding,
            bottom: 0,
            right: config.horizontalPadding
        )
        
        // Corner radius based on height
        layer.cornerRadius = config.height / 2
    }
    
    private func applyStyleConfiguration() {
        let config = styleConfiguration(for: buttonStyle)
        
        // Background colors
        backgroundColor = config.backgroundColor
        setBackgroundImage(imageWithColor(config.pressedBackgroundColor), for: .highlighted)
        setBackgroundImage(imageWithColor(config.disabledBackgroundColor), for: .disabled)
        
        // Text colors
        setTitleColor(config.textColor, for: .normal)
        setTitleColor(config.pressedTextColor, for: .highlighted)
        setTitleColor(config.disabledTextColor, for: .disabled)
        
        // Border
        layer.borderWidth = config.borderWidth
        layer.borderColor = config.borderColor.cgColor
    }
    
    // MARK: - Configuration Structs
    private struct SizeConfiguration {
        let height: CGFloat
        let horizontalPadding: CGFloat
        let cornerRadius: CGFloat
    }
    
    private struct StyleConfiguration {
        let backgroundColor: UIColor
        let pressedBackgroundColor: UIColor
        let disabledBackgroundColor: UIColor
        let textColor: UIColor
        let pressedTextColor: UIColor
        let disabledTextColor: UIColor
        let borderColor: UIColor
        let borderWidth: CGFloat
    }
    
    private func sizeConfiguration(for size: Size) -> SizeConfiguration {
        switch size {
        case .large:
            return SizeConfiguration(height: 48, horizontalPadding: 16, cornerRadius: 24)
        case .medium:
            return SizeConfiguration(height: 40, horizontalPadding: 12, cornerRadius: 20)
        case .small:
            return SizeConfiguration(height: 32, horizontalPadding: 8, cornerRadius: 16)
        case .compact:
            return SizeConfiguration(height: 28, horizontalPadding: 6, cornerRadius: 14)
        }
    }
    
    private func styleConfiguration(for style: Style) -> StyleConfiguration {
        switch style {
        case .primary:
            return StyleConfiguration(
                backgroundColor: UIColor.secureChatPrimary,
                pressedBackgroundColor: UIColor.secureChatPrimary.withAlphaComponent(0.8),
                disabledBackgroundColor: UIColor.secureChatPrimary.withAlphaComponent(0.4),
                textColor: UIColor.white,
                pressedTextColor: UIColor.white.withAlphaComponent(0.9),
                disabledTextColor: UIColor.white.withAlphaComponent(0.6),
                borderColor: UIColor.clear,
                borderWidth: 0
            )
        case .secondary:
            return StyleConfiguration(
                backgroundColor: UIColor.clear,
                pressedBackgroundColor: UIColor.secureChatPrimary.withAlphaComponent(0.1),
                disabledBackgroundColor: UIColor.clear,
                textColor: UIColor.secureChatPrimary,
                pressedTextColor: UIColor.secureChatPrimary.withAlphaComponent(0.8),
                disabledTextColor: UIColor.secureChatSecondaryText,
                borderColor: UIColor.secureChatPrimary,
                borderWidth: 1.0\n            )\n        case .destructive:\n            return StyleConfiguration(\n                backgroundColor: UIColor.secureChatDanger,\n                pressedBackgroundColor: UIColor.secureChatDanger.withAlphaComponent(0.8),\n                disabledBackgroundColor: UIColor.secureChatDanger.withAlphaComponent(0.4),\n                textColor: UIColor.white,\n                pressedTextColor: UIColor.white.withAlphaComponent(0.9),\n                disabledTextColor: UIColor.white.withAlphaComponent(0.6),\n                borderColor: UIColor.clear,\n                borderWidth: 0\n            )\n        case .text:\n            return StyleConfiguration(\n                backgroundColor: UIColor.clear,\n                pressedBackgroundColor: UIColor.secureChatSecondaryText.withAlphaComponent(0.1),\n                disabledBackgroundColor: UIColor.clear,\n                textColor: UIColor.secureChatPrimary,\n                pressedTextColor: UIColor.secureChatPrimary.withAlphaComponent(0.8),\n                disabledTextColor: UIColor.secureChatSecondaryText,\n                borderColor: UIColor.clear,\n                borderWidth: 0\n            )\n        }\n    }\n    \n    private func fontForSize(_ size: Size) -> UIFont {\n        switch size {\n        case .large:\n            return UIFont.systemFont(ofSize: 17, weight: .semibold)\n        case .medium:\n            return UIFont.systemFont(ofSize: 16, weight: .semibold)\n        case .small:\n            return UIFont.systemFont(ofSize: 15, weight: .medium)\n        case .compact:\n            return UIFont.systemFont(ofSize: 14, weight: .medium)\n        }\n    }\n    \n    // MARK: - Helper Methods\n    private func imageWithColor(_ color: UIColor) -> UIImage? {\n        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)\n        UIGraphicsBeginImageContext(rect.size)\n        let context = UIGraphicsGetCurrentContext()\n        context?.setFillColor(color.cgColor)\n        context?.fill(rect)\n        let image = UIGraphicsGetImageFromCurrentImageContext()\n        UIGraphicsEndImageContext()\n        return image\n    }\n}\n\n// MARK: - Convenience Factory Methods\nextension StandardButton {\n    \n    /// Creates a primary button with the specified title\n    static func primary(_ title: String, size: Size = .medium) -> StandardButton {\n        let button = StandardButton(style: .primary, size: size)\n        button.setTitle(title, for: .normal)\n        return button\n    }\n    \n    /// Creates a secondary button with the specified title\n    static func secondary(_ title: String, size: Size = .medium) -> StandardButton {\n        let button = StandardButton(style: .secondary, size: size)\n        button.setTitle(title, for: .normal)\n        return button\n    }\n    \n    /// Creates a destructive button with the specified title\n    static func destructive(_ title: String, size: Size = .medium) -> StandardButton {\n        let button = StandardButton(style: .destructive, size: size)\n        button.setTitle(title, for: .normal)\n        return button\n    }\n    \n    /// Creates a text-only button with the specified title\n    static func text(_ title: String, size: Size = .medium) -> StandardButton {\n        let button = StandardButton(style: .text, size: size)\n        button.setTitle(title, for: .normal)\n        return button\n    }\n}"