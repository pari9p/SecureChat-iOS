# SecureChat iOS

[![iOS](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)]()

A secure, modern messaging application for iOS built with privacy-first principles and end-to-end encryption. Built on the proven Signal Protocol foundation with additional production-ready features for modern mobile communication.

## Features

### 🔐 Security & Privacy
- **End-to-end encryption** powered by Signal Protocol
- **Perfect forward secrecy** with automatic key rotation  
- **Zero-knowledge architecture** - messages are unreadable to us
- **Disappearing messages** with customizable timers
- **Screen protection** against unauthorized screenshots

### 💬 Messaging
- **Real-time messaging** with delivery and read receipts
- **Group conversations** with admin controls and member management
- **Rich media support** - photos, videos, documents, voice messages
- **Message reactions** and reply threading
- **Typing indicators** and presence status

### 📱 User Experience  
- **Offline message queue** - send messages without internet connection
- **Global message search** with advanced filtering capabilities
- **Dark/Light theme** with manual toggle and system integration
- **Customizable notifications** with granular privacy controls
- **Voice and video calling** with crystal-clear quality

### 🛠 Developer Features
- **Privacy-conscious analytics** for performance optimization
- **Crash reporting** with automatic collection
- **A/B testing framework** for feature experimentation
- **Performance monitoring** and optimization tools

## Screenshots

<!-- Coming Soon: App screenshots showcasing the interface -->
*Screenshots will be added to demonstrate the app's user interface and key features*

## Architecture

**Built with modern iOS development practices:**

- **Language**: Swift 5.0+ with strategic Objective-C interop
- **Architecture**: MVVM with reactive programming patterns
- **Security**: Signal Protocol for cryptographic operations
- **Storage**: SQLCipher for encrypted local data persistence
- **Networking**: WebSocket real-time communication + REST API
- **UI**: UIKit with programmatic Auto Layout
- **Dependencies**: CocoaPods for package management

## Getting Started

## Getting Started

### Prerequisites
- Xcode 14.0 or later
- iOS 15.0+ deployment target  
- CocoaPods installed
- Apple Developer Account (for device testing)

### Quick Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/SecureChat-iOS.git
cd SecureChat-iOS

# Install dependencies
make dependencies

# Open workspace
open Signal.xcworkspace
```

### Developer Onboarding

1. **First Run Setup**
   - Build and run the project in Simulator
   - Create a test account for development
   - Familiarize yourself with the app's core features

2. **Code Architecture**
   - Review [FEATURE_IMPLEMENTATION.md](./FEATURE_IMPLEMENTATION.md) for feature patterns
   - Study the `SignalServiceKit` framework for core functionality
   - Understand the theme system in `Signal/src/util/ThemeUtils.swift`

3. **Testing**
   - Run unit tests: `Cmd+U` in Xcode  
   - Run UI tests: Select `SignalUITests` scheme
   - Use `TestingViewController` for internal testing features

For detailed build instructions, see [BUILDING.md](./BUILDING.md)

## Project Structure

```
Signal-iOS/
├── Signal/               # Main iOS app target
│   ├── src/             # Swift source files
│   │   ├── Components/  # UI components and views  
│   │   ├── util/        # Utility classes and extensions
│   │   └── ViewControllers/ # App screens and navigation
│   └── Images.xcassets/ # App images and icons
├── SignalServiceKit/    # Core framework for messaging
├── SignalUI/           # Shared UI components
├── SignalNSE/          # Notification Service Extension  
└── Pods/               # Third-party dependencies

Key Files:
- ThemeManager.swift     # App-wide theme system
- AppOptimizer.swift     # Performance utilities  
- StandardButton.swift   # Standardized UI components
```

## Troubleshooting

### Common Build Issues

**Pod Installation Problems**
```bash
# Clear pod cache and reinstall
rm -rf Pods/ Podfile.lock
pod install --repo-update
```

**Code Signing Issues**
- Verify your Apple Developer account is active
- Check bundle identifiers in project settings  
- Ensure provisioning profiles are up to date

**Missing Dependencies**
```bash
# Reinstall project dependencies
make dependencies
# If Makefile missing, run directly:
./Scripts/setup_private_pods && pod install
```

**Runtime Crashes**  
- Check Xcode console for error logs
- Verify all required frameworks are linked
- Test on latest iOS Simulator version

### Getting Help

- Check [existing issues](https://github.com/yourusername/SecureChat-iOS/issues) for known problems
- Join our developer discussion in [Discussions](https://github.com/yourusername/SecureChat-iOS/discussions)  
- Review [BUILDING.md](./BUILDING.md) for detailed setup instructions

```
Signal-iOS/
├── Signal/                 # Main application target
│   ├── src/               # Core application source
│   ├── ConversationView/  # Chat interface components
│   ├── Settings/          # App configuration screens
│   └── Registration/      # User onboarding flow
├── SignalServiceKit/      # Networking & protocol layer
├── SignalUI/             # Reusable UI components
├── SignalNSE/            # Notification service extension
└── ThirdParty/           # External dependencies
```

## Development

### Building the Project
1. Install [CocoaPods](https://cocoapods.org/) dependency manager
2. Install required dependencies with `make dependencies`
3. Open `Signal.xcworkspace` in Xcode
4. Build and run on simulator or device

### Code Architecture
- **MVVM Pattern**: Clear separation between views, view models, and models
- **Protocol-Oriented**: Extensive use of protocols for modularity
- **Reactive Programming**: Event-driven architecture with modern patterns
- **Dependency Injection**: Testable and maintainable code structure

## Contributing

We welcome contributions to SecureChat! Please review our guidelines:

- **[Contributing Guide](./CONTRIBUTING.md)** - Development workflow and standards
- **[Code of Conduct](./CODE_OF_CONDUCT.md)** - Community guidelines  
- **[Security Policy](./SECURITY.md)** - Responsible disclosure process

### Development Roadmap
- [ ] Enhanced group permissions and moderation tools
- [ ] Message scheduling and delayed send features  
- [ ] Voice message transcription with privacy
- [ ] Cross-platform desktop companion app
- [ ] Advanced message formatting and rich text

## Privacy & Analytics

SecureChat includes privacy-conscious analytics to improve the user experience:
- **No personal data** collection - analytics are fully anonymized
- **Usage patterns** help optimize app performance and reliability
- **Crash reports** improve stability without exposing user content  
- **Optional participation** - users control all analytics preferences

All analytics respect user privacy and can be completely disabled in settings.

## Legal & Attribution

### License
This project is licensed under the MIT License for new contributions - see [LICENSE](./LICENSE) for details.

### Signal Protocol Attribution
This application builds upon the cryptographic foundations of the [Signal Protocol](https://signal.org/docs/) and extends the architecture from the open-source [Signal iOS](https://github.com/signalapp/Signal-iOS) codebase.

**Original Copyright**: Signal iOS codebase © 2013-2025 Signal Messenger, LLC  
**License**: GNU AGPL v3.0 (for original Signal components)

All original Signal copyright notices and licensing are preserved as required.

### Purpose & Educational Use
This project serves as a **portfolio/educational demonstration** of:
- Advanced iOS development skills and Swift programming
- Production-ready mobile application architecture
- Privacy-focused software engineering practices
- Modern user experience design and implementation

**Not intended for commercial distribution** - built for learning and skills demonstration.

## Security

Privacy and security are our top priorities. For security concerns:
- Review our [Security Policy](./SECURITY.md)
- Report vulnerabilities responsibly through proper channels
- All security issues are handled with appropriate urgency

## Support & Contact

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)  
- **Documentation**: See project wiki and documentation files
- **Security**: Follow responsible disclosure in [SECURITY.md](./SECURITY.md)

---

**Built with privacy and security as core principles**  
*SecureChat - Modern messaging that respects your privacy*