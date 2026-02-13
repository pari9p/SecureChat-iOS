//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SQLite3

/// Advanced message search functionality with full-text search capabilities
final class MessageSearchManager {
    
    // MARK: - Properties
    
    static let shared = MessageSearchManager()
    
    private let searchQueue = DispatchQueue(label: "MessageSearchManager", qos: .userInitiated)
    private var searchHistory: [String] = []
    private let maxSearchHistoryItems = 50
    
    // MARK: - Search Types
    
    enum SearchScope {
        case allConversations
        case currentConversation(threadId: String)
        case contacts
        case groupNames
        case messageContent
    }
    
    enum SearchFilter {
        case dateRange(from: Date, to: Date)
        case messageType(MessageType)
        case sender(contactId: String)
        case hasAttachments
        case isUnread
    }
    
    enum MessageType {
        case text
        case image
        case video
        case audio
        case document
        case location
    }
    
    // MARK: - Search Results
    
    struct SearchResult {
        let messageId: String
        let threadId: String
        let content: String
        let senderName: String
        let timestamp: Date
        let messageType: MessageType
        let hasAttachments: Bool
        let highlightedText: String
        let contextBefore: String?
        let contextAfter: String?
    }
    
    struct SearchSuggestion {
        let text: String
        let type: SuggestionType
        let relevanceScore: Double
    }
    
    enum SuggestionType {
        case contact
        case recentSearch
        case keyword
        case phrase
    }
    
    // MARK: - Main Search Methods
    
    func search(
        query: String,
        scope: SearchScope = .allConversations,
        filters: [SearchFilter] = [],
        limit: Int = 100
    ) async -> [SearchResult] {
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            searchQueue.async {
                let results = self.performSearch(
                    query: query,
                    scope: scope,
                    filters: filters,
                    limit: limit
                )
                
                // Add to search history
                self.addToSearchHistory(query)
                
                continuation.resume(returning: results)
            }
        }
    }
    
    private func performSearch(
        query: String,
        scope: SearchScope,
        filters: [SearchFilter],
        limit: Int
    ) -> [SearchResult] {
        
        // Normalize search query
        let normalizedQuery = normalizeSearchQuery(query)
        let searchTerms = tokenizeQuery(normalizedQuery)
        
        // Build search parameters
        let searchParams = buildSearchParameters(
            query: normalizedQuery,
            terms: searchTerms,
            scope: scope,
            filters: filters
        )
        
        // Execute search
        var results: [SearchResult] = []
        
        switch scope {
        case .allConversations:
            results = searchAllConversations(params: searchParams, limit: limit)
        case .currentConversation(let threadId):
            results = searchConversation(threadId: threadId, params: searchParams, limit: limit)
        case .contacts:
            results = searchContacts(params: searchParams, limit: limit)
        case .groupNames:
            results = searchGroupNames(params: searchParams, limit: limit)
        case .messageContent:
            results = searchMessageContent(params: searchParams, limit: limit)
        }
        
        // Rank and sort results
        return rankSearchResults(results, originalQuery: query)
    }
    
    // MARK: - Query Processing
    
    private func normalizeSearchQuery(_ query: String) -> String {
        return query.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private func tokenizeQuery(_ query: String) -> [String] {
        let components = query.components(separatedBy: .whitespacesAndPunctuation)
        return components.filter { !$0.isEmpty && $0.count > 1 }
    }
    
    private func buildSearchParameters(
        query: String,
        terms: [String],
        scope: SearchScope,
        filters: [SearchFilter]
    ) -> SearchParameters {
        
        return SearchParameters(
            originalQuery: query,
            normalizedQuery: query,
            searchTerms: terms,
            scope: scope,
            filters: filters,
            useFullTextSearch: terms.count > 1,
            enableFuzzyMatch: true
        )
    }
    
    // MARK: - Search Implementations
    
    private func searchAllConversations(params: SearchParameters, limit: Int) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // This would integrate with your database layer
        // For now, returning mock results to demonstrate the structure
        
        // Search in message content
        let contentResults = searchMessageContent(params: params, limit: limit / 2)
        results.append(contentsOf: contentResults)
        
        // Search in contact names
        let contactResults = searchContacts(params: params, limit: limit / 4)
        results.append(contentsOf: contactResults)
        
        // Search in group names
        let groupResults = searchGroupNames(params: params, limit: limit / 4)
        results.append(contentsOf: groupResults)
        
        return results
    }
    
    private func searchConversation(threadId: String, params: SearchParameters, limit: Int) -> [SearchResult] {
        // Search within a specific conversation
        
        let mockResults = createMockSearchResults(
            for: params.originalQuery,
            threadId: threadId,
            count: min(limit, 20)
        )
        
        return mockResults
    }
    
    private func searchContacts(params: SearchParameters, limit: Int) -> [SearchResult] {
        // Search through contact names and phone numbers
        
        return createMockSearchResults(
            for: params.originalQuery,
            threadId: "contact-search",
            count: min(limit, 10)
        )
    }
    
    private func searchGroupNames(params: SearchParameters, limit: Int) -> [SearchResult] {
        // Search through group conversation names
        
        return createMockSearchResults(
            for: params.originalQuery,
            threadId: "group-search",
            count: min(limit, 5)
        )
    }
    
    private func searchMessageContent(params: SearchParameters, limit: Int) -> [SearchResult] {
        // Full-text search through message content
        
        return createMockSearchResults(
            for: params.originalQuery,
            threadId: "message-content",
            count: min(limit, 50)
        )
    }
    
    // MARK: - Result Ranking
    
    private func rankSearchResults(_ results: [SearchResult], originalQuery: String) -> [SearchResult] {
        let rankedResults = results.map { result -> (SearchResult, Double) in
            let relevanceScore = calculateRelevanceScore(result: result, query: originalQuery)
            return (result, relevanceScore)
        }
        
        return rankedResults
            .sorted { $0.1 > $1.1 } // Sort by relevance score descending
            .map { $0.0 }
    }
    
    private func calculateRelevanceScore(result: SearchResult, query: String) -> Double {
        var score: Double = 0.0
        
        // Exact match bonus
        if result.content.lowercased().contains(query.lowercased()) {
            score += 10.0
        }
        
        // Title/sender name match bonus
        if result.senderName.lowercased().contains(query.lowercased()) {
            score += 5.0
        }
        
        // Recent message bonus
        let daysSinceMessage = Calendar.current.dateComponents([.day], from: result.timestamp, to: Date()).day ?? 0
        score += max(0, 3.0 - Double(daysSinceMessage) * 0.1)
        
        // Message type relevance
        switch result.messageType {
        case .text:
            score += 1.0
        case .image, .video:
            score += 0.8
        case .audio:
            score += 0.6
        case .document, .location:
            score += 0.4
        }
        
        return score
    }
    
    // MARK: - Search Suggestions
    
    func getSearchSuggestions(for partialQuery: String, limit: Int = 10) async -> [SearchSuggestion] {
        return await withCheckedContinuation { continuation in
            searchQueue.async {
                var suggestions: [SearchSuggestion] = []
                
                // Add recent searches
                let recentSuggestions = self.getRecentSearchSuggestions(for: partialQuery)
                suggestions.append(contentsOf: recentSuggestions)
                
                // Add contact suggestions
                let contactSuggestions = self.getContactSuggestions(for: partialQuery)
                suggestions.append(contentsOf: contactSuggestions)
                
                // Add keyword suggestions
                let keywordSuggestions = self.getKeywordSuggestions(for: partialQuery)
                suggestions.append(contentsOf: keywordSuggestions)
                
                // Sort by relevance and limit
                let sortedSuggestions = suggestions
                    .sorted { $0.relevanceScore > $1.relevanceScore }
                    .prefix(limit)
                
                continuation.resume(returning: Array(sortedSuggestions))
            }
        }
    }
    
    private func getRecentSearchSuggestions(for query: String) -> [SearchSuggestion] {
        return searchHistory
            .filter { $0.lowercased().contains(query.lowercased()) }
            .prefix(5)
            .map { SearchSuggestion(text: $0, type: .recentSearch, relevanceScore: 8.0) }
    }
    
    private func getContactSuggestions(for query: String) -> [SearchSuggestion] {
        // Mock contact suggestions
        let mockContacts = ["Alice Johnson", "Bob Smith", "Charlie Brown", "Diana Prince"]
        
        return mockContacts
            .filter { $0.lowercased().contains(query.lowercased()) }
            .map { SearchSuggestion(text: $0, type: .contact, relevanceScore: 7.0) }
    }
    
    private func getKeywordSuggestions(for query: String) -> [SearchSuggestion] {
        let commonKeywords = ["photo", "video", "document", "location", "call", "meeting", "lunch", "work"]
        
        return commonKeywords
            .filter { $0.lowercased().hasPrefix(query.lowercased()) }
            .map { SearchSuggestion(text: $0, type: .keyword, relevanceScore: 5.0) }
    }
    
    // MARK: - Search History
    
    private func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty, trimmedQuery.count > 2 else { return }
        
        // Remove if already exists
        searchHistory.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        searchHistory.insert(trimmedQuery, at: 0)
        
        // Limit history size
        if searchHistory.count > maxSearchHistoryItems {
            searchHistory.removeLast()
        }
        
        // Persist search history
        saveSearchHistory()
    }
    
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: "MessageSearchHistory")
    }
    
    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "MessageSearchHistory") ?? []
    }
    
    // MARK: - Highlighting
    
    private func highlightSearchTerms(in text: String, query: String) -> String {
        let highlightedText = text.replacingOccurrences(
            of: query,
            with: "<mark>\(query)</mark>",
            options: [.caseInsensitive, .diacriticInsensitive]
        )
        
        return highlightedText
    }
    
    private func extractContext(around searchTerm: String, in fullText: String, contextLength: Int = 50) -> (before: String?, after: String?) {
        guard let range = fullText.range(of: searchTerm, options: .caseInsensitive) else {
            return (nil, nil)
        }
        
        let beforeStart = fullText.index(fullText.startIndex, offsetBy: max(0, fullText.distance(from: fullText.startIndex, to: range.lowerBound) - contextLength))
        let beforeText = String(fullText[beforeStart..<range.lowerBound])
        
        let afterEnd = fullText.index(range.upperBound, offsetBy: min(contextLength, fullText.distance(from: range.upperBound, to: fullText.endIndex)))
        let afterText = String(fullText[range.upperBound..<afterEnd])
        
        return (beforeText.isEmpty ? nil : beforeText, afterText.isEmpty ? nil : afterText)
    }
    
    // MARK: - Mock Data (for demonstration)
    
    private func createMockSearchResults(for query: String, threadId: String, count: Int) -> [SearchResult] {
        return (0..<count).map { index in
            SearchResult(
                messageId: "msg-\(threadId)-\(index)",
                threadId: threadId,
                content: "This is a sample message containing \(query) for testing purposes #\(index)",
                senderName: "Contact \(index % 5 + 1)",
                timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                messageType: [.text, .image, .video, .audio][index % 4],
                hasAttachments: index % 3 == 0,
                highlightedText: highlightSearchTerms(in: "sample message containing \(query)", query: query),
                contextBefore: index > 0 ? "previous message context" : nil,
                contextAfter: "following message context"
            )
        }
    }
}

// MARK: - Supporting Types

private struct SearchParameters {
    let originalQuery: String
    let normalizedQuery: String
    let searchTerms: [String]
    let scope: MessageSearchManager.SearchScope
    let filters: [MessageSearchManager.SearchFilter]
    let useFullTextSearch: Bool
    let enableFuzzyMatch: Bool
}