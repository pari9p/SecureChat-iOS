//
// ThemeSettingsViewController.swift
// SecureChat
//
// Created by SecureChat Team on 2/12/2026.
// Copyright 2025 SecureChat Development Team
//

import UIKit
import Combine

public class ThemeSettingsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var cancellables = Set<AnyCancellable>()
    
    private let themes = AppTheme.allCases
    private var selectedTheme: AppTheme = .system
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupBindings()
        loadCurrentTheme()
    }
    
    private func setupUI() {
        title = "Theme"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        view.backgroundColor = UIColor.secureChatBackground
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.secureChatBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ThemeCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupBindings() {
        ThemeManager.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                self?.selectedTheme = theme
                self?.tableView.reloadData()
                
                // Track theme change
                AnalyticsManager.shared.track(.themeChanged(
                    from: self?.selectedTheme.rawValue ?? "unknown",
                    to: theme.rawValue
                ))
            }
            .store(in: &cancellables)
        
        // Listen for theme changes to update UI colors
        NotificationCenter.default.publisher(for: .themeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateColors()
            }
            .store(in: &cancellables)
    }
    
    private func loadCurrentTheme() {
        selectedTheme = ThemeManager.shared.currentTheme
    }
    
    private func updateColors() {
        view.backgroundColor = UIColor.secureChatBackground
        tableView.backgroundColor = UIColor.secureChatBackground
        navigationController?.navigationBar.tintColor = UIColor.secureChatPrimary
    }
}

// MARK: - UITableViewDataSource

extension ThemeSettingsViewController: UITableViewDataSource {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return themes.count
        case 1:
            return 1 // Preview section
        default:
            return 0
        }
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Appearance"
        case 1:
            return "Preview"
        default:
            return nil
        }
    }
    
    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "System automatically switches between light and dark themes based on your device settings."
        default:
            return nil
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeCell", for: indexPath)
        
        switch indexPath.section {
        case 0:
            let theme = themes[indexPath.row]
            cell.textLabel?.text = theme.displayName
            cell.textLabel?.textColor = UIColor.secureChatText
            cell.backgroundColor = UIColor.secureChatSecondaryBackground
            
            // Add theme icon
            let iconName = iconName(for: theme)
            cell.imageView?.image = UIImage(systemName: iconName)
            cell.imageView?.tintColor = UIColor.secureChatSecondaryText
            
            // Show checkmark for selected theme
            if theme == selectedTheme {
                cell.accessoryType = .checkmark
                cell.tintColor = UIColor.secureChatPrimary
            } else {
                cell.accessoryType = .none
            }
            
        case 1:
            cell.textLabel?.text = "Message Preview"
            cell.detailTextLabel?.text = "This is how messages will appear"
            cell.backgroundColor = UIColor.secureChatSecondaryBackground
            cell.textLabel?.textColor = UIColor.secureChatText
            cell.detailTextLabel?.textColor = UIColor.secureChatSecondaryText
            cell.selectionStyle = .none
            
        default:
            break
        }
        
        return cell
    }
    
    private func iconName(for theme: AppTheme) -> String {
        switch theme {
        case .system:
            return "circle.lefthalf.fill"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}

// MARK: - UITableViewDelegate

extension ThemeSettingsViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.section == 0 else { return }
        
        let selectedTheme = themes[indexPath.row]
        ThemeManager.shared.setTheme(selectedTheme)
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Track analytics
        AnalyticsManager.shared.trackFeatureUsage("theme_selection")
    }
}