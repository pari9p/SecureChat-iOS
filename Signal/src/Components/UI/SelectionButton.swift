//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import SignalUI
import UIKit

/// A checkmark in a circle to indicate an item (typically in a table view or collection view) is
/// selected. Enhanced with theme support and consistent styling.
class SelectionButton: UIView {
    private let outlineBadgeView: UIView = {
        let imageView = UIImageView(image: UIImage(imageLiteralResourceName: "circle"))
        imageView.contentMode = .center
        imageView.isHidden = true
        return imageView
    }()

    private let selectedBadgeView: UIView = {
        let imageView = UIImageView(image: UIImage(imageLiteralResourceName: "check-circle-fill"))
        imageView.contentMode = .center

        // Background circle for checkmark
        let backgroundView = CircleView(diameter: 18)

        let containerView = UIView(frame: imageView.bounds)
        containerView.isHidden = true

        containerView.addSubview(backgroundView)
        backgroundView.autoCenterInSuperview()

        containerView.addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()

        return containerView
    }()

    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    var allowsMultipleSelection: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    var hidesOutlineWhenSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    init() {
        super.init(frame: .zero)
        setupView()
        setupThemeObserver()
        applyConsistentStyling()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupThemeObserver()
        applyConsistentStyling()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupView() {
        addSubview(selectedBadgeView)
        selectedBadgeView.autoCenterInSuperview()

        addSubview(outlineBadgeView)
        outlineBadgeView.autoCenterInSuperview()

        autoSetDimensions(to: .square(24))
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
        applyConsistentStyling()
        updateAppearance()
    }
    
    private func applyConsistentStyling() {
        // Apply consistent theme colors
        outlineBadgeView.tintColor = UIColor.secureChatSecondaryText
        
        if let imageView = selectedBadgeView.subviews.last as? UIImageView {
            imageView.tintColor = UIColor.secureChatPrimary
        }
        
        if let backgroundView = selectedBadgeView.subviews.first as? CircleView {
            backgroundView.backgroundColor = UIColor.secureChatSecondaryBackground
        }
    }

    private func updateAppearance() {
        if isSelected {
            outlineBadgeView.isHidden = hidesOutlineWhenSelected
            selectedBadgeView.isHidden = false
        } else if allowsMultipleSelection {
            outlineBadgeView.isHidden = false
            selectedBadgeView.isHidden = true
        } else {
            outlineBadgeView.isHidden = true
            selectedBadgeView.isHidden = true
        }
    }

    func reset() {
        selectedBadgeView.isHidden = true
        outlineBadgeView.isHidden = true
    }
}
