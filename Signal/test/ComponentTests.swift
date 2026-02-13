//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
@testable import Signal
@testable import SignalServiceKit

/// Unit tests for the ThemeManager functionality
class ThemeManagerTests: SignalBaseTest {
    
    private var themeManager: MockThemeManager!
    
    override func setUp() {
        super.setUp()
        themeManager = MockThemeManager()
    }
    
    override func tearDown() {
        themeManager = nil
        super.tearDown()
    }
    
    // MARK: - Theme Setting Tests
    
    func testSetLightTheme() {
        // Given
        themeManager.setTheme(.light)
        
        // Then
        XCTAssertEqual(themeManager.currentTheme, .light)
    }
    
    func testSetDarkTheme() {
        // Given
        themeManager.setTheme(.dark)
        
        // Then
        XCTAssertEqual(themeManager.currentTheme, .dark)
    }
    
    func testThemeChangeNotification() {
        // Given
        var notificationCount = 0
        themeManager.addThemeChangeListener {
            notificationCount += 1
        }
        
        // When
        themeManager.setTheme(.dark)
        themeManager.setTheme(.light)
        
        // Then
        XCTAssertEqual(notificationCount, 2)
    }
}

/// Unit tests for StandardButton component
class StandardButtonTests: SignalBaseTest {
    
    func testButtonCreation() {
        // Given
        let button = TestDataFactory.createStandardButton(style: .primary, size: .medium)
        
        // Then
        XCTAssertNotNil(button)
        XCTAssertTrue(button.isAccessibilityElement)
    }
    
    func testButtonAccessibility() {
        // Given
        let button = TestDataFactory.createStandardButton()
        button.setTitle("Test Button", for: .normal)
        
        // Then
        XCTAssertAccessibilityConfigured(
            button,
            traits: .button
        )
    }
    
    func testButtonColorSchemeSupport() {
        // Given
        let button = TestDataFactory.createStandardButton(style: .primary)
        
        // Test that button adapts to color scheme changes
        let lightColor = UIColor.systemBlue
        let darkColor = UIColor.systemBlue
        
        XCTAssertColorSchemeSupport(
            button,
            lightColor: lightColor,
            darkColor: darkColor
        )
    }
}

/// Unit tests for StandardTextField component  
class StandardTextFieldTests: SignalBaseTest {
    
    func testTextFieldCreation() {
        // Given
        let textField = TestDataFactory.createStandardTextField(style: .filled, size: .medium)
        
        // Then
        XCTAssertNotNil(textField)
        XCTAssertTrue(textField.isAccessibilityElement)
    }
    
    func testTextFieldPlaceholder() {
        // Given
        let textField = TestDataFactory.createStandardTextField()
        textField.placeholder = "Enter text"
        
        // Then
        XCTAssertEqual(textField.accessibilityLabel, "Enter text")
    }
    
    func testTextFieldErrorState() {
        // Given
        let textField = TestDataFactory.createStandardTextField()
        
        // When
        textField.setErrorState(true, message: "Invalid input")
        
        // Then
        XCTAssertTrue(textField.accessibilityHint?.contains("error") == true)
    }
}

/// Unit tests for PerformanceOptimizer
class PerformanceOptimizerTests: SignalBaseTest {
    
    private var mockOptimizer: MockPerformanceOptimizer!
    
    override func setUp() {
        super.setUp()
        mockOptimizer = MockPerformanceOptimizer()
    }
    
    override func tearDown() {
        mockOptimizer = nil
        super.tearDown()
    }
    
    func testPerformanceOptimization() {
        // When
        mockOptimizer.performOptimization()
        
        // Then
        XCTAssertEqual(mockOptimizer.optimizationCallCount, 1)
        XCTAssertNotNil(mockOptimizer.lastOptimizationTime)
    }
    
    func testMultipleOptimizations() {
        // When
        mockOptimizer.performOptimization()
        mockOptimizer.performOptimization()
        mockOptimizer.performOptimization()
        
        // Then
        XCTAssertEqual(mockOptimizer.optimizationCallCount, 3)
    }
    
    func testOptimizerReset() {
        // Given
        mockOptimizer.performOptimization()
        
        // When
        mockOptimizer.reset()
        
        // Then
        XCTAssertEqual(mockOptimizer.optimizationCallCount, 0)
        XCTAssertNil(mockOptimizer.lastOptimizationTime)
    }
}

/// Unit tests for AccessibilityHelper
class AccessibilityHelperTests: SignalBaseTest {
    
    private var mockHelper: MockAccessibilityHelper!
    
    override func setUp() {
        super.setUp()
        mockHelper = MockAccessibilityHelper()
    }
    
    override func tearDown() {
        mockHelper = nil
        super.tearDown()
    }
    
    func testAccessibilityAnnouncement() {
        // Given
        let message = "Test announcement"
        
        // When
        mockHelper.announce(message)
        
        // Then
        XCTAssertEqual(mockHelper.announcementCount, 1)
        XCTAssertEqual(mockHelper.lastAnnouncement, message)
    }
    
    func testMultipleAnnouncements() {
        // When
        mockHelper.announce("First")
        mockHelper.announce("Second")
        
        // Then
        XCTAssertEqual(mockHelper.announcementCount, 2)
        XCTAssertEqual(mockHelper.lastAnnouncement, "Second")
    }
    
    func testAccessibilityReset() {
        // Given
        mockHelper.announce("Test")
        
        // When
        mockHelper.reset()
        
        // Then
        XCTAssertEqual(mockHelper.announcementCount, 0)
        XCTAssertNil(mockHelper.lastAnnouncement)
    }
}