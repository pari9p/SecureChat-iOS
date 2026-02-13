//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import UIKit
import SignalServiceKit

/// Utility class for enhanced accessibility support across the app
public class AccessibilityHelper {
    
    /// Announces text to VoiceOver users after a delay to ensure it's heard
    public static func announce(_ text: String, delay: TimeInterval = 0.3) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }
    
    /// Configures a button with comprehensive accessibility support
    public static func configureButton(
        _ button: UIButton,
        label: String,
        hint: String? = nil,
        traits: UIAccessibilityTraits = .button
    ) {
        button.isAccessibilityElement = true
        button.accessibilityLabel = label
        button.accessibilityHint = hint
        button.accessibilityTraits = traits
    }
    
    /// Creates an accessibility-friendly grouped element
    public static func createAccessibilityGroup(
        elements: [UIView],
        label: String,
        traits: UIAccessibilityTraits = .none
    ) -> UIAccessibilityElement {
        let container = elements.first?.superview ?? UIView()
        let element = UIAccessibilityElement(accessibilityContainer: container)
        
        // Calculate combined frame
        let combinedFrame = elements.reduce(CGRect.zero) { result, view in
            guard let superview = view.superview else { return result }
            let viewFrame = superview.convert(view.frame, to: container)
            return result.isNull ? viewFrame : result.union(viewFrame)
        }
        
        element.accessibilityFrameInContainerSpace = combinedFrame
        element.accessibilityLabel = label
        element.accessibilityTraits = traits
        
        return element
    }
    
    /// Improves accessibility for custom controls with value tracking
    public static func configureCustomControl(
        _ control: UIControl,
        label: String,
        value: String? = nil,
        hint: String? = nil,
        traits: UIAccessibilityTraits = .adjustable
    ) {
        control.isAccessibilityElement = true
        control.accessibilityLabel = label
        control.accessibilityValue = value
        control.accessibilityHint = hint
        control.accessibilityTraits = traits
    }
    
    /// Enhanced accessibility for media content
    public static func configureMediaAccessibility(
        _ view: UIView,
        mediaType: String,
        duration: TimeInterval? = nil,
        additionalInfo: String? = nil
    ) {
        var label = mediaType
        
        if let duration = duration {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .abbreviated
            if let formattedDuration = formatter.string(from: duration) {
                label += ", \(formattedDuration)"
            }
        }
        
        if let additionalInfo = additionalInfo {
            label += ", \(additionalInfo)"
        }
        
        view.isAccessibilityElement = true
        view.accessibilityLabel = label
        view.accessibilityTraits = .button
    }
    
    /// Focus management for better navigation
    public static func focusElement(_ element: UIView, delay: TimeInterval = 0.1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
    
    /// Checks if reduce motion is enabled and provides alternative
    public static func performAnimationRespectingMotionPreferences(
        _ animation: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        if UIAccessibility.isReduceMotionEnabled {
            animation()
            completion?(true)
        } else {
            UIView.animate(withDuration: 0.3, animations: animation, completion: completion)
        }
    }
}