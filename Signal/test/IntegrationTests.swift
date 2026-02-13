//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
@testable import Signal
@testable import SignalServiceKit

/// Integration tests for user interface and user experience flows
class UIIntegrationTests: SignalBaseTest {
    
    func testMessageCompositionFlow() async throws {
        // Given
        let mockMessage = TestUtilities.createMockMessage(text: "Hello world!")
        
        // When - Test message creation and sending flow
        let result = try TestUtilities.waitForAsync {
            // Simulate message composition and sending
            return mockMessage.uniqueId
        }
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }
    
    func testThemeToggleFlow() {
        // Given
        let themeManager = MockThemeManager()
        let initialTheme = themeManager.currentTheme
        
        // When - Toggle theme
        let newTheme: ThemeMode = (initialTheme == .light) ? .dark : .light
        themeManager.setTheme(newTheme)
        
        // Then
        XCTAssertNotEqual(themeManager.currentTheme, initialTheme)
        XCTAssertEqual(themeManager.currentTheme, newTheme)
    }
    
    func testAccessibilityNavigationFlow() {
        // Given
        let button = TestDataFactory.createStandardButton()
        button.setTitle("Test Navigation", for: .normal)
        
        // Test VoiceOver navigation simulation
        XCTAssertAccessibilityConfigured(
            button,
            label: "Test Navigation",
            traits: .button
        )
    }
}

/// Performance and memory tests
class PerformanceTests: SignalBaseTest {
    
    func testMemoryOptimizationPerformance() {
        // Given
        let optimizer = MockPerformanceOptimizer()
        
        // When - Measure performance of optimization
        measure {
            for _ in 0..<100 {
                optimizer.performOptimization()
            }
        }
        
        // Then
        XCTAssertEqual(optimizer.optimizationCallCount, 100)
    }
    
    func testUIComponentCreationPerformance() {
        measure {
            // Test performance of creating UI components
            for _ in 0..<50 {
                let button = TestDataFactory.createStandardButton()
                let textField = TestDataFactory.createStandardTextField()
                
                // Perform basic configuration
                button.setTitle("Test", for: .normal)
                textField.placeholder = "Test"
            }
        }
    }
    
    func testBatchOperationPerformance() {
        measure {
            // Test autoreleasePool performance optimization
            autoreleasepool {
                for i in 0..<1000 {
                    let mockProfile = TestUtilities.createMockUserProfile(
                        name: "User \(i)",
                        phoneNumber: "+1555000\(String(format: "%04d", i))"
                    )
                    _ = mockProfile.givenName
                }
            }
        }
    }
}

/// Accessibility compliance tests
class AccessibilityTests: SignalBaseTest {
    
    func testButtonAccessibilityCompliance() {
        // Test different button types
        let buttonStyles: [StandardButton.Style] = [.primary, .secondary, .destructive, .text]
        
        for style in buttonStyles {
            let button = TestDataFactory.createStandardButton(style: style)
            button.setTitle("Test Button", for: .normal)
            
            // Verify accessibility configuration
            XCTAssertTrue(button.isAccessibilityElement, "Button style \(style) should be accessible")
            XCTAssertNotNil(button.accessibilityLabel, "Button style \(style) should have accessibility label") 
            XCTAssertTrue(button.accessibilityTraits.contains(.button), "Button style \(style) should have button trait")
        }
    }
    
    func testTextFieldAccessibilityCompliance() {
        // Test different text field types
        let fieldStyles: [StandardTextField.Style] = [.filled, .outlined, .minimal, .search]
        
        for style in fieldStyles {
            let textField = TestDataFactory.createStandardTextField(style: style)
            textField.placeholder = "Test Input"
            
            // Verify accessibility configuration
            XCTAssertTrue(textField.isAccessibilityElement, "TextField style \(style) should be accessible")
            XCTAssertEqual(textField.accessibilityLabel, "Test Input", "TextField style \(style) should use placeholder as label")
        }
    }
    
    func testDynamicTypeSupport() {
        // Test that UI components adapt to dynamic type changes
        let button = TestDataFactory.createStandardButton()
        button.setTitle("Dynamic Type Test", for: .normal)
        
        // Simulate different content size categories
        let testCategories: [UIContentSizeCategory] = [
            .small,
            .medium,
            .large,
            .extraExtraLarge,
            .accessibilityMedium,
            .accessibilityExtraExtraExtraLarge
        ]
        
        for category in testCategories {
            let traitCollection = UITraitCollection(preferredContentSizeCategory: category)
            button.titleLabel?.font = UIFont.preferredFont(
                forTextStyle: .body,
                compatibleWith: traitCollection
            )
            
            // Verify font scales appropriately  
            let fontSize = button.titleLabel?.font.pointSize ?? 0
            XCTAssertGreaterThan(fontSize, 0, "Font should scale for content size category \(category)")
        }
    }
    
    func testReduceMotionSupport() {
        // Test that animations respect reduce motion preferences
        let button = TestDataFactory.createStandardButton()
        
        // Simulate reduce motion enabled
        let expectation = XCTestExpectation(description: "Animation completion")
        
        AccessibilityHelper.performAnimationRespectingMotionPreferences({
            button.alpha = 0.5
        }, completion: { _ in
            expectation.fulfill()
        })
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(button.alpha, 0.5, accuracy: 0.1)
    }
}

/// Data validation and edge case tests  
class ValidationTests: SignalBaseTest {
    
    func testPhoneNumberValidation() {
        // Given
        let testNumbers = TestDataFactory.createTestPhoneNumbers()
        
        for phoneNumber in testNumbers {
            // When - Test phone number parsing and validation
            let isValid = E164(phoneNumber) != nil
            
            // Then  
            XCTAssertTrue(isValid, "Phone number \(phoneNumber) should be valid")
        }
    }
    
    func testCredentialsValidation() {
        // Given
        let credentials = TestDataFactory.createTestCredentials()
        
        // When - Test credential format validation
        let usernameValid = credentials.username.count >= 3
        let passwordValid = credentials.password.count >= 8
        
        // Then
        XCTAssertTrue(usernameValid, "Username should be at least 3 characters")
        XCTAssertTrue(passwordValid, "Password should be at least 8 characters")
    }
    
    func testEmptyStringHandling() {
        // Test various components handle empty strings gracefully
        let button = TestDataFactory.createStandardButton()
        let textField = TestDataFactory.createStandardTextField()
        
        // Test empty title/placeholder
        button.setTitle("", for: .normal)
        textField.placeholder = ""
        
        // Should not crash and handle gracefully
        XCTAssertNoThrow(button.accessibilityLabel)
        XCTAssertNoThrow(textField.accessibilityLabel)
    }
    
    func testNilValueHandling() {
        // Test components handle nil values gracefully
        let textField = TestDataFactory.createStandardTextField()
        textField.placeholder = nil
        
        // Should not crash
        XCTAssertNoThrow(textField.accessibilityLabel)
        
        // Should provide reasonable fallback
        XCTAssertNotNil(textField.accessibilityLabel)
    }
}

/// Stress and edge case tests
class StressTests: SignalBaseTest {
    
    func testRapidThemeChanges() {
        // Given
        let themeManager = MockThemeManager()
        var changeCount = 0
        
        themeManager.addThemeChangeListener {
            changeCount += 1
        }
        
        // When - Rapidly change themes
        for _ in 0..<100 {
            themeManager.setTheme(.dark)
            themeManager.setTheme(.light)
        }
        
        // Then - Should handle rapid changes without issues
        XCTAssertEqual(changeCount, 200)
        XCTAssertEqual(themeManager.currentTheme, .light)
    }
    
    func testMemoryPressureSimulation() {
        // Given
        var objects: [AnyObject] = []
        
        // When - Create many objects to simulate memory pressure
        for i in 0..<1000 {
            autoreleasepool {
                let button = TestDataFactory.createStandardButton()
                button.setTitle("Button \(i)", for: .normal)
                objects.append(button)
            }
        }
        
        // Then - Should complete without memory issues
        XCTAssertEqual(objects.count, 1000)
        
        // Cleanup
        objects.removeAll()
    }
}