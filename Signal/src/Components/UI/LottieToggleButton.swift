//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Lottie
import SignalServiceKit

class LottieToggleButton: UIButton {

    var animationName: String? {
        didSet {
            updateAnimationView()
        }
    }

    var animationSize: CGSize = .zero {
        didSet {
            updateAnimationView()
        }
    }

    var animationSpeed: CGFloat {
        get {
            animationView?.animationSpeed ?? 0
        }
        set {
            animationView?.animationSpeed = newValue
        }
    }

    override var isSelected: Bool {
        didSet {
            animationView?.currentProgress = isSelected ? 1 : 0
            updateThemeColors()
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            updateThemeColors()
        }
    }

    func setValueProvider(_ valueProvider: AnyValueProvider, keypath: AnimationKeypath) {
        animationView?.setValueProvider(valueProvider, keypath: keypath)
    }

    func setSelected(_ isSelected: Bool, animated: Bool) {
        AssertIsOnMainThread()
        
        guard let animationView = animationView else {
            Logger.warn("Animation view not available, setting selection state directly")
            self.isSelected = isSelected
            return
        }

        if animated {
            animationView.play(
                fromProgress: animationView.currentProgress,
                toProgress: isSelected ? 1 : 0,
                loopMode: .playOnce,
            ) { [weak self] complete in
                guard complete else { return }
                self?.isSelected = isSelected
            }
        } else {
            self.isSelected = isSelected
        }
    }

    private weak var animationView: LottieAnimationView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupThemeObserver()
        applyConsistentStyling()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupThemeObserver()
        applyConsistentStyling()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        updateThemeColors()
    }
    
    private func applyConsistentStyling() {
        // Apply consistent button styling
        layer.cornerRadius = 8.0
        layer.borderWidth = 1.0
        clipsToBounds = true
        updateThemeColors()
    }
    
    private func updateThemeColors() {
        if isSelected {
            backgroundColor = UIColor.secureChatPrimary
            layer.borderColor = UIColor.secureChatPrimary.cgColor
            tintColor = UIColor.secureChatSecondaryBackground
        } else {
            backgroundColor = UIColor.secureChatSecondaryBackground
            layer.borderColor = UIColor.secureChatSeparator.cgColor
            tintColor = UIColor.secureChatText
        }
        
        if !isEnabled {
            alpha = 0.6
        } else {
            alpha = 1.0
        }
    }
    
    private func updateAnimationView() {
        animationView?.removeFromSuperview()
        guard let animationName else { return }

        let animationView = LottieAnimationView(name: animationName)
        self.animationView = animationView

        animationView.isUserInteractionEnabled = false
        animationView.loopMode = .playOnce
        animationView.backgroundBehavior = .forceFinish
        animationView.currentProgress = isSelected ? 1 : 0
        animationView.contentMode = .scaleAspectFit

        addSubview(animationView)

        if animationSize != .zero {
            animationView.autoSetDimensions(to: animationSize)
            animationView.autoCenterInSuperview()
        } else {
            animationView.autoPinEdgesToSuperviewEdges()
        }
    }
}
