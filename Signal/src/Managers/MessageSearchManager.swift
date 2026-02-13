//
// MessageSearchManager.swift
// SecureChat
//
// Created by SecureChat Team on 2/12/2026.
// Copyright 2025 SecureChat Development Team
//

import Foundation
import Combine

public struct SearchResult {
    let messageId: String
    let threadId: String
    let content: String
    let snippet: String
    let timestamp: Date
    let senderName: String
    let relevanceScore: Double
    
    // Highlighted content with search terms marked
    let highlightedContent: NSAttributedString
}

public enum SearchFilter {
    case all
    case text
    case media
    case documents
    case links
    case fromContact(String)
    case dateRange(Date, Date)
    case thread(String)
}

public enum SearchSortOrder {
    case relevance
    case newest
    case oldest
}

@objc
public class MessageSearchManager: NSObject {
    
    public static let shared = MessageSearchManager()
    
    @Published public private(set) var isSearching = false
    @Published public private(set) var searchResults: [SearchResult] = []
    @Published public private(set) var searchQuery = ""
    
    private let searchQueue = DispatchQueue(label: "com.securechat.search", qos: .userInitiated)
    private var currentSearchTask: Task<Void, Never>?
    
    // Search index for faster lookups
    private var searchIndex: [String: Set<String>] = [:]
    private let indexUpdateQueue = DispatchQueue(label: "com.securechat.search-index")
    
    public override init() {
        super.init()
        buildSearchIndex()
    }
    
    // MARK: - Public Search Interface
    
    public func search(
        query: String,
        filters: [SearchFilter] = [.all],
        sortOrder: SearchSortOrder = .relevance,
        limit: Int = 50
    ) {
        // Cancel previous search
        currentSearchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            searchQuery = ""
            return
        }
        
        searchQuery = query
        isSearching = true
        
        currentSearchTask = Task {
            await performSearch(query: query, filters: filters, sortOrder: sortOrder, limit: limit)
        }
    }
    
    public func quickSearch(query: String, limit: Int = 10) async -> [SearchResult] {
        return await performQuickSearch(query: query, limit: limit)
    }
    
    public func clearSearch() {
        currentSearchTask?.cancel()
        searchResults = []
        searchQuery = ""
        isSearching = false
    }
    
    // MARK: - Search Implementation
    
    private func performSearch(
        query: String,
        filters: [SearchFilter],
        sortOrder: SearchSortOrder,
        limit: Int
    ) async {
        let results = await searchMessages(
            query: query,
            filters: filters,
            sortOrder: sortOrder,
            limit: limit
        )
        
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
        }
    }
    
    private func performQuickSearch(query: String, limit: Int) async -> [SearchResult] {
        return await searchMessages(
            query: query,
            filters: [.all],
            sortOrder: .relevance,
            limit: limit
        )
    }
    
    private func searchMessages(
        query: String,
        filters: [SearchFilter],
        sortOrder: SearchSortOrder,
        limit: Int
    ) async -> [SearchResult] {
        
        let searchTerms = preprocessQuery(query)
        var results: [SearchResult] = []
        
        // Simulate database search - replace with actual implementation
        let mockMessages = generateMockMessages()
        
        for message in mockMessages {
            guard !Task.isCancelled else { break }
            
            if let result = evaluateMessage(message, searchTerms: searchTerms, filters: filters) {
                results.append(result)
            }
        }
        
        // Sort results
        switch sortOrder {
        case .relevance:
            results.sort { $0.relevanceScore > $1.relevanceScore }
        case .newest:
            results.sort { $0.timestamp > $1.timestamp }
        case .oldest:
            results.sort { $0.timestamp < $1.timestamp }
        }
        
        return Array(results.prefix(limit))
    }
    
    // MARK: - Query Processing
    
    private func preprocessQuery(_ query: String) -> [String] {
        return query
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private func evaluateMessage(
        _ message: MockMessage,
        searchTerms: [String],
        filters: [SearchFilter]
    ) -> SearchResult? {
        
        // Apply filters
        guard passesFilters(message, filters: filters) else { return nil }
        
        let content = message.content.lowercased()
        var relevanceScore: Double = 0
        var matchedTerms: [String] = []
        
        // Calculate relevance score
        for term in searchTerms {
            if content.contains(term) {
                matchedTerms.append(term)
                
                // Exact match bonus
                if content == term {
                    relevanceScore += 100
                } else if content.hasPrefix(term) {
                    relevanceScore += 50
                } else {
                    relevanceScore += 10
                }
                
                // Word boundary bonus
                if content.range(of: "\\b\(term)\\b", options: .regularExpression) != nil {
                    relevanceScore += 20
                }
            }
        }
        
        guard !matchedTerms.isEmpty else { return nil }
        
        // Create highlighted content
        let highlightedContent = highlightSearchTerms(
            in: message.content,
            searchTerms: matchedTerms
        )
        
        // Create snippet
        let snippet = createSnippet(from: message.content, searchTerms: matchedTerms)
        
        return SearchResult(
            messageId: message.id,
            threadId: message.threadId,
            content: message.content,
            snippet: snippet,
            timestamp: message.timestamp,
            senderName: message.senderName,
            relevanceScore: relevanceScore,
            highlightedContent: highlightedContent
        )
    }
    
    private func passesFilters(_ message: MockMessage, filters: [SearchFilter]) -> Bool {
        for filter in filters {
            switch filter {
            case .all:
                continue
            case .text:
                if message.type != .text { return false }
            case .media:
                if message.type != .media { return false }
            case .documents:
                if message.type != .document { return false }
            case .links:
                if !message.content.contains("http") { return false }
            case .fromContact(let contactId):
                if message.senderId != contactId { return false }
            case .dateRange(let start, let end):
                if !(start...end).contains(message.timestamp) { return false }
            case .thread(let threadId):
                if message.threadId != threadId { return false }
            }
        }
        return true
    }
    
    // MARK: - Text Processing
    
    private func highlightSearchTerms(in text: String, searchTerms: [String]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: UIColor.systemYellow.withAlphaComponent(0.3),
            .foregroundColor: UIColor.label
        ]
        
        for term in searchTerms {
            let range = NSString(string: text.lowercased()).range(of: term.lowercased())
            if range.location != NSNotFound {
                attributedString.addAttributes(highlightAttributes, range: range)
            }
        }
        
        return attributedString
    }
    
    private func createSnippet(from content: String, searchTerms: [String]) -> String {
        guard let firstTerm = searchTerms.first else { return String(content.prefix(100)) }
        
        let range = content.lowercased().range(of: firstTerm.lowercased())
        guard let matchRange = range else { return String(content.prefix(100)) }
        
        let snippetStart = max(content.startIndex, content.index(matchRange.lowerBound, offsetBy: -50))
        let snippetEnd = min(content.endIndex, content.index(matchRange.upperBound, offsetBy: 50))
        
        let snippet = String(content[snippetStart..<snippetEnd])
        return snippet.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Search Index
    
    private func buildSearchIndex() {
        indexUpdateQueue.async { [weak self] in
            // Simulate building search index from database
            // In real implementation, this would index all message content
            print("Building search index...")
        }
    }
    
    public func updateIndex(for messageId: String, content: String) {
        indexUpdateQueue.async { [weak self] in
            // Update search index when new message is added
            let words = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
            for word in words where !word.isEmpty {
                self?.searchIndex[word, default: Set()].insert(messageId)
            }
        }
    }
}

// MARK: - Mock Data for Demo

private struct MockMessage {
    let id: String
    let threadId: String
    let content: String
    let timestamp: Date
    let senderId: String
    let senderName: String
    let type: MessageType
    
    enum MessageType {
        case text, media, document
    }
}

private func generateMockMessages() -> [MockMessage] {
    let now = Date()
    return [
        MockMessage(
            id: "1",
            threadId: "thread1",
            content: "Hey, how are you doing today?",
            timestamp: now.addingTimeInterval(-3600),
            senderId: "user1",
            senderName: "Alice",
            type: .text
        ),
        MockMessage(
            id: "2",
            threadId: "thread1",
            content: "I'm working on the SecureChat project. It's going really well!",
            timestamp: now.addingTimeInterval(-3200),
            senderId: "user2",
            senderName: "Bob",
            type: .text
        ),
        MockMessage(
            id: "3",
            threadId: "thread2",
            content: "Can you send me the document we discussed?",
            timestamp: now.addingTimeInterval(-2800),
            senderId: "user3",
            senderName: "Carol",
            type: .text
        ),
        MockMessage(
            id: "4",
            threadId: "thread1",
            content: "The new search feature is amazing! I can find messages so quickly now.",
            timestamp: now.addingTimeInterval(-2400),
            senderId: "user1",
            senderName: "Alice",
            type: .text
        ),
        MockMessage(
            id: "5",
            threadId: "thread3",
            content: "Check out this link: https://github.com/securechat/ios",
            timestamp: now.addingTimeInterval(-2000),
            senderId: "user4",
            senderName: "Dave",
            type: .text
        )
    ]
}