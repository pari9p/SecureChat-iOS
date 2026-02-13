//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit
import SignalUI

class BlockingErrorBottomPanelView: ConversationBottomPanelView {
    private let onTap: () -> Void

    init(
        text: NSAttributedString,
        onTap: @escaping () -> Void,
    ) {
        self.onTap = onTap

        super.init(frame: .zero)

        let label = UILabel()
        label.font = .dynamicTypeSubheadlineClamped
        label.textColor = .Signal.secondaryLabel
        label.attributedText = text
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapLearnMore)))
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Enhanced accessibility
        label.isAccessibilityElement = true
        label.accessibilityTraits = [.staticText, .button]
        label.accessibilityHint = OWSLocalizedString(
            "BLOCKING_ERROR_ACCESSIBILITY_HINT",
            comment: "Accessibility hint for blocking error message that can be tapped for more info"
        )
        
        contentView.addSubview(label)

        addConstraints([
            label.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            label.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
        ])
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func didTapLearnMore() {
        onTap()
    }
}
