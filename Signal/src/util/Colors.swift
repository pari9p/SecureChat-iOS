//
// Colors.swift
// SecureChat
//
// Created by SecureChat Team on 2/13/2026.
// Copyright 2025 SecureChat Development Team
//

import UIKit

// MARK: - SecureChat Color System
public struct Colors {
    
    // MARK: - Brand Colors
    public struct Brand {
        /// Primary brand blue - used for main actions and branding
        public static let primary = UIColor.secureChatPrimary
        
        /// Accent blue - used for highlights and interactive elements
        public static let accent = UIColor.secureChatAccent
        
        /// Success green - used for positive actions and status
        public static let success = UIColor.secureChatSuccess
        
        /// Warning yellow - used for caution and alerts
        public static let warning = UIColor.secureChatWarning
        
        /// Danger red - used for destructive actions and errors
        public static let danger = UIColor.secureChatDanger
    }
    
    // MARK: - Background Colors
    public struct Background {
        /// Primary background color - main app background
        public static let primary = UIColor.secureChatBackground
        
        /// Secondary background - card and modal backgrounds
        public static let secondary = UIColor.secureChatSecondaryBackground
        
        /// Card background - used for individual components
        public static let card = UIColor.secureChatCardBackground
        
        /// Separator lines and borders
        public static let separator = UIColor.secureChatSeparator
    }
    
    // MARK: - Text Colors
    public struct Text {
        /// Primary text color - main content and headers
        public static let primary = UIColor.secureChatText
        
        /// Secondary text color - descriptions and metadata
        public static let secondary = UIColor.secureChatSecondaryText
        
        /// Tertiary text color - disabled states and captions
        public static let tertiary = UIColor.secureChatTertiaryText
        
        /// Link text color
        public static let link = UIColor.secureChatPrimary
    }
    
    // MARK: - Message Bubble Colors
    public struct Message {
        /// Outgoing message bubble color
        public static let outgoing = UIColor.secureChatOutgoingBubble
        
        /// Incoming message bubble color
        public static let incoming = UIColor.secureChatIncomingBubble
        
        /// Text color for outgoing messages
        public static let outgoingText = UIColor.white
        
        /// Text color for incoming messages
        public static let incomingText = UIColor.secureChatText
    }
    
    // MARK: - Status Colors
    public struct Status {
        /// Online status indicator
        public static let online = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
        
        /// Offline status indicator
        public static let offline = UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
        
        /// Typing indicator
        public static let typing = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        
        /// Unread message badge
        public static let unreadBadge = Brand.danger
        
        /// Message sent status
        public static let sent = UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1.0)
        
        /// Message delivered status
        public static let delivered = Brand.primary
        
        /// Message read status
        public static let read = Brand.success
    }
    
    // MARK: - Navigation Colors
    public struct Navigation {
        /// Navigation bar background
        public static let background = Background.primary
        
        /// Navigation bar title text
        public static let title = Text.primary
        
        /// Navigation bar button tint
        public static let buttonTint = Brand.primary
        
        /// Tab bar background
        public static let tabBarBackground = Background.secondary
        
        /// Tab bar selected item
        public static let tabBarSelected = Brand.primary
        
        /// Tab bar unselected item
        public static let tabBarUnselected = Text.tertiary
    }
    
    // MARK: - Button Colors
    public struct Button {
        /// Primary button background
        public static let primaryBackground = Brand.primary
        
        /// Primary button text
        public static let primaryText = UIColor.white
        
        /// Secondary button background
        public static let secondaryBackground = UIColor.clear
        
        /// Secondary button text
        public static let secondaryText = Brand.primary
        
        /// Secondary button border
        public static let secondaryBorder = Brand.primary
        
        /// Destructive button background
        public static let destructiveBackground = Brand.danger
        
        /// Destructive button text
        public static let destructiveText = UIColor.white
    }
    
    // MARK: - Input Field Colors
    public struct Input {
        /// Input field background
        public static let background = Background.card
        
        /// Input field text
        public static let text = Text.primary
        
        /// Input field placeholder text
        public static let placeholder = Text.tertiary
        
        /// Input field border
        public static let border = Background.separator
        
        /// Input field border when focused
        public static let focusedBorder = Brand.primary
    }
}

// MARK: - Color Utilities
extension Colors {
    /// Returns a color that adapts to the current theme
    public static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            default:
                return light
            }
        }
    }
    
    /// Returns a color with specified opacity
    public static func withAlpha(_ color: UIColor, _ alpha: CGFloat) -> UIColor {
        return color.withAlphaComponent(alpha)
    }
}