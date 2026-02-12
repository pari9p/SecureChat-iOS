# Building SecureChat iOS

This guide will help you set up your development environment and build SecureChat iOS from source.

## Prerequisites

- Xcode 14.0 or later
- macOS 12.0 or later
- iOS 15.0+ deployment target
- CocoaPods

## 1. Clone the Repository

Clone the repo to a working directory:

```bash
git clone --recurse-submodules https://github.com/<YOUR_USERNAME>/SecureChat-iOS.git
```

Since we use git submodules, you must use `git clone` rather than downloading a zip file.

If you plan to contribute, we recommend forking the repository first:

```bash
git clone --recurse-submodules https://github.com/<YOUR_FORK>/SecureChat-iOS.git
```

## 2. Install Dependencies

Install the required dependencies using CocoaPods:

```bash
make dependencies
```

## 3. Configure Xcode

Open the workspace in Xcode:

```bash
open Signal.xcworkspace
```

### Development Team Setup
1. In Xcode, select the project in the navigator
2. For each target (Signal, SignalShareExtension, SignalNSE), go to the "Signing & Capabilities" tab
3. Change the "Team" to your Apple Developer account
4. The bundle identifier prefix is set to `com.securechat` by default

### Capabilities Configuration
For development builds, you may need to adjust capabilities:
- **Background Modes**: Keep enabled for message sync
- **App Groups**: Keep enabled for data sharing between app and extensions
- **Push Notifications**: Enable if you want to test notifications
- **Data Protection**: Configure as needed for your use case

### Bundle Identifier
The bundle identifier is controlled by the `SIGNAL_BUNDLEID_PREFIX` setting in the project configuration. By default, this is set to `com.securechat`.

## 4. Build and Run

Build the project in Xcode or using the command line:

```bash
xcodebuild -workspace Signal.xcworkspace -scheme Signal -configuration Debug
```

## Troubleshooting

### Common Issues
- **CocoaPods Issues**: Try `pod install --clean-install`
- **Signing Issues**: Ensure your Apple Developer account is properly configured
- **Build Failures**: Clean build folder (⌘+Shift+K) and rebuild

### Getting Help
If you encounter issues:
1. Check the [Issues](../../issues) page for similar problems
2. Search existing [discussions](../../discussions)
3. Create a new issue with detailed information about your problem

Happy coding! 🚀
