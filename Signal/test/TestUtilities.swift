//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
@testable import SignalServiceKit

/// Test utilities and helpers for the SecureChat messaging app
class TestUtilities: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Setup test environment
    }
    
    override func tearDown() {
        super.tearDown()
        // Cleanup after tests
    }
    
    // MARK: - Helper Methods
    
    /// Creates a mock message for testing purposes
    static func createMockMessage(text: String = "Test message") -> TSOutgoingMessage {
        let thread = createMockThread()
        let messageBuilder = TSOutgoingMessageBuilder(
            thread: thread,
            messageBody: text
        )
        return messageBuilder.build()
    }
    
    /// Creates a mock thread for testing
    static func createMockThread() -> TSContactThread {
        let address = SignalServiceAddress(phoneNumber: "+15551234567")
        return TSContactThread(contactAddress: address)
    }
    
    /// Creates a mock user profile for testing
    static func createMockUserProfile(name: String = "Test User", phoneNumber: String = "+15551234567") -> OWSUserProfile {
        let profile = OWSUserProfile()
        profile.givenName = name
        return profile
    }
    
    /// Waits for async operation with timeout
    static func waitForAsync<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) throws -> T {
        var result: Result<T, Error>?
        let expectation = XCTestExpectation(description: "Async operation")
        
        Task {
            do {
                let value = try await operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            expectation.fulfill()
        }
        
        let waiter = XCTWaiter()
        let status = waiter.wait(for: [expectation], timeout: timeout)
        
        guard status == .completed else {
            throw TestError.timeout
        }
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw TestError.unexpectedNil
        }
    }
    
    enum TestError: Error {
        case timeout
        case unexpectedNil
    }
}

// MARK: - Mock Classes

/// Mock class for testing theme functionality
class MockThemeManager {
    var currentTheme: ThemeMode = .light
    var themeChangeCallbacks: [() -> Void] = []
    
    func setTheme(_ theme: ThemeMode) {
        currentTheme = theme
        notifyThemeChanged()
    }
    
    private func notifyThemeChanged() {
        themeChangeCallbacks.forEach { $0() }
    }
    
    func addThemeChangeListener(_ callback: @escaping () -> Void) {
        themeChangeCallbacks.append(callback)
    }
}

/// Mock class for testing performance optimization
class MockPerformanceOptimizer {
    var optimizationCallCount = 0
    var lastOptimizationTime: Date?
    
    func performOptimization() {
        optimizationCallCount += 1
        lastOptimizationTime = Date()
    }
    
    func reset() {
        optimizationCallCount = 0
        lastOptimizationTime = nil
    }
}

/// Mock class for testing accessibility features
class MockAccessibilityHelper {
    var announcementCount = 0
    var lastAnnouncement: String?
    
    func announce(_ text: String) {
        announcementCount += 1
        lastAnnouncement = text
    }
    
    func reset() {
        announcementCount = 0
        lastAnnouncement = nil
    }
}

// MARK: - Test Data Factories

/// Factory for creating test data
struct TestDataFactory {
    
    /// Creates a standardized button for testing
    static func createStandardButton(
        style: StandardButton.Style = .primary,
        size: StandardButton.Size = .medium
    ) -> StandardButton {
        return StandardButton(style: style, size: size)
    }
    
    /// Creates a standardized text field for testing  
    static func createStandardTextField(
        style: StandardTextField.Style = .filled,
        size: StandardTextField.Size = .medium
    ) -> StandardTextField {
        return StandardTextField(style: style, size: size)
    }
    
    /// Creates test user credentials
    static func createTestCredentials() -> (username: String, password: String) {
        return (
            username: "testuser_\(UUID().uuidString.prefix(8))",
            password: "TestPassword123!"
        )
    }
    
    /// Creates test phone numbers for various countries
    static func createTestPhoneNumbers() -> [String] {
        return [
            "+15551234567", // US
            "+447911123456", // UK  
            "+33123456789", // France
            "+4912345678", // Germany
            "+15559876543" // US alternate
        ]
    }
}

// MARK: - Assertion Helpers

extension XCTestCase {
    
    /// Asserts that two CGFloat values are approximately equal
    func XCTAssertApproximatelyEqual(
        _ expression1: CGFloat,
        _ expression2: CGFloat,
        accuracy: CGFloat = 0.01,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(expression1, expression2, accuracy: accuracy, file: file, line: line)
    }
    
    /// Asserts that view has expected accessibility properties
    func XCTAssertAccessibilityConfigured(
        _ view: UIView,
        label: String? = nil,
        hint: String? = nil,
        traits: UIAccessibilityTraits? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(view.isAccessibilityElement, "View should be accessibility element", file: file, line: line)
        
        if let label = label {
            XCTAssertEqual(view.accessibilityLabel, label, file: file, line: line)
        }
        
        if let hint = hint {
            XCTAssertEqual(view.accessibilityHint, hint, file: file, line: line)
        }
        
        if let traits = traits {
            XCTAssertEqual(view.accessibilityTraits, traits, file: file, line: line)
        }
    }
    
    /// Asserts that color scheme is properly implemented
    func XCTAssertColorSchemeSupport(
        _ view: UIView,
        lightColor: UIColor,
        darkColor: UIColor,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Test light mode
        view.overrideUserInterfaceStyle = .light
        let lightResolvedColor = lightColor.resolvedColor(with: view.traitCollection)
        
        // Test dark mode
        view.overrideUserInterfaceStyle = .dark
        let darkResolvedColor = darkColor.resolvedColor(with: view.traitCollection)
        
        XCTAssertNotEqual(lightResolvedColor, darkResolvedColor, "Colors should differ between light and dark mode", file: file, line: line)
        
        // Reset
        view.overrideUserInterfaceStyle = .unspecified
    }
}