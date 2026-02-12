//
// MessageSearchViewController.swift
// SecureChat
//
// Created by SecureChat Team on 2/12/2026.
// Copyright 2025 SecureChat Development Team
//

import UIKit
import Combine

public class MessageSearchViewController: UIViewController {
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private let emptyStateView = SearchEmptyStateView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    
    private var cancellables = Set<AnyCancellable>()
    private var searchResults: [SearchResult] = []
    private var searchDebouncer: Timer?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSearch()
        setupBindings()
        showEmptyState()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Track feature usage
        AnalyticsManager.shared.trackFeatureUsage("message_search_opened")
    }
    
    private func setupUI() {
        title = "Search Messages"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        view.backgroundColor = UIColor.secureChatBackground
        
        // Setup table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.secureChatBackground
        tableView.separatorColor = UIColor.separator.withAlphaComponent(0.3)
        tableView.register(SearchResultTableViewCell.self, forCellReuseIdentifier: SearchResultTableViewCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        // Setup loading view
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        loadingView.color = UIColor.secureChatPrimary
        
        // Setup empty state
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search messages, contacts, media..."
        searchController.searchBar.tintColor = UIColor.secureChatPrimary
        searchController.searchBar.searchTextField.textColor = UIColor.secureChatText
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    private func setupBindings() {
        MessageSearchManager.shared.$searchResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.searchResults = results
                self?.updateUI()
            }
            .store(in: &cancellables)
        
        MessageSearchManager.shared.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSearching in
                if isSearching {
                    self?.showLoading()
                } else {
                    self?.hideLoading()
                }
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        searchDebouncer?.invalidate()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            MessageSearchManager.shared.clearSearch()
            showEmptyState()
            return
        }
        
        // Debounce search by 300ms
        searchDebouncer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            MessageSearchManager.shared.search(query: query)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            AnalyticsManager.shared.track(.searchPerformed(
                query: query,
                resultsCount: self?.searchResults.count ?? 0,
                duration: duration
            ))
        }
    }
    
    private func updateUI() {
        tableView.reloadData()
        
        if searchResults.isEmpty && !MessageSearchManager.shared.searchQuery.isEmpty {
            showEmptyState(for: .noResults)
        } else if !searchResults.isEmpty {
            showResults()
        }
    }
    
    private func showEmptyState(for state: SearchEmptyStateView.State = .initial) {
        emptyStateView.configure(for: state)
        emptyStateView.isHidden = false
        tableView.isHidden = true
    }
    
    private func showResults() {
        emptyStateView.isHidden = true
        tableView.isHidden = false
    }
    
    private func showLoading() {
        loadingView.startAnimating()
        emptyStateView.isHidden = true
    }
    
    private func hideLoading() {
        loadingView.stopAnimating()
    }
}

// MARK: - UISearchResultsUpdating

extension MessageSearchViewController: UISearchResultsUpdating {
    
    public func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text else { return }
        performSearch(query: query)
    }
}

// MARK: - UITableViewDataSource

extension MessageSearchViewController: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultTableViewCell.identifier, for: indexPath) as! SearchResultTableViewCell
        
        let result = searchResults[indexPath.row]
        cell.configure(with: result)
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MessageSearchViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let result = searchResults[indexPath.row]
        
        // Navigate to the message
        // In a real app, this would navigate to the conversation and highlight the message
        print("Selected message: \(result.messageId) in thread: \(result.threadId)")
        
        // Track selection
        AnalyticsManager.shared.trackFeatureUsage("search_result_selected")
    }
}

// MARK: - Search Result Cell

private class SearchResultTableViewCell: UITableViewCell {
    static let identifier = "SearchResultTableViewCell"
    
    private let senderLabel = UILabel()
    private let timestampLabel = UILabel()
    private let contentLabel = UILabel()
    private let snippetLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.secureChatSecondaryBackground
        
        senderLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        senderLabel.textColor = UIColor.secureChatText
        
        timestampLabel.font = UIFont.systemFont(ofSize: 12)
        timestampLabel.textColor = UIColor.secureChatSecondaryText
        
        contentLabel.font = UIFont.systemFont(ofSize: 14)
        contentLabel.textColor = UIColor.secureChatText
        contentLabel.numberOfLines = 0
        
        snippetLabel.font = UIFont.systemFont(ofSize: 12)
        snippetLabel.textColor = UIColor.secureChatSecondaryText
        snippetLabel.numberOfLines = 2
        
        let headerStack = UIStackView(arrangedSubviews: [senderLabel, timestampLabel])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        
        let mainStack = UIStackView(arrangedSubviews: [headerStack, contentLabel, snippetLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 4
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with result: SearchResult) {
        senderLabel.text = result.senderName
        timestampLabel.text = DateFormatter.searchResult.string(from: result.timestamp)
        contentLabel.attributedText = result.highlightedContent
        snippetLabel.text = result.snippet
    }
}

// MARK: - Empty State View

private class SearchEmptyStateView: UIView {
    
    enum State {
        case initial
        case noResults
        case error
    }
    
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.secureChatSecondaryText
        
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        titleLabel.textColor = UIColor.secureChatText
        titleLabel.textAlignment = .center
        
        subtitleLabel.font = UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = UIColor.secureChatSecondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 80),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(for state: State) {
        switch state {
        case .initial:
            imageView.image = UIImage(systemName: "magnifyingglass")
            titleLabel.text = "Search Messages"
            subtitleLabel.text = "Find messages, contacts, and media across all your conversations"
            
        case .noResults:
            imageView.image = UIImage(systemName: "magnifyingglass")
            titleLabel.text = "No Results Found"
            subtitleLabel.text = "Try using different keywords or check your spelling"
            
        case .error:
            imageView.image = UIImage(systemName: "exclamationmark.triangle")
            titleLabel.text = "Search Error"
            subtitleLabel.text = "Something went wrong. Please try again"
        }
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let searchResult: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}