# Contributing to SecureChat iOS

Thank you for your interest in contributing to SecureChat! We welcome contributions from developers who share our commitment to privacy and security.

## Getting Started

Before contributing, please:

1. Read our [Code of Conduct](./CODE_OF_CONDUCT.md)
2. Check the [issues](https://github.com/yourusername/SecureChat-iOS/issues) for existing bug reports or feature requests
3. Set up your development environment following the [BUILDING.md](./BUILDING.md) guide

## Development Philosophy

Our development is guided by these principles:

1. **Privacy First** - User privacy is our top priority in all decisions
2. **Security by Design** - Security considerations should be built in, not bolted on
3. **User Experience** - Complex security should be simple to use
4. **Code Quality** - Clean, maintainable, and well-tested code
5. **Performance** - Efficient and responsive user experience

## How to Contribute

### Reporting Bugs

Before reporting a bug, please:
- Search existing issues to avoid duplicates
- Include steps to reproduce the issue
- Provide device information and iOS version
- Include relevant logs or screenshots

### Suggesting Features

Feature requests should:
- Have a clear use case and benefit
- Align with our privacy and security principles
- Include detailed implementation considerations

### Submitting Code

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with appropriate tests
4. Follow our coding standards and style guide
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Pull Request Guidelines

### Code Quality Standards

- **Swift Style**: Follow [Swift.org style guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Architecture**: Use MVVM patterns for view controllers
- **Theme Support**: All UI components should integrate with `ThemeManager`
- **Logging**: Use `Logger` instead of `print()` statements
- **Error Handling**: Prefer proper error handling over force unwrapping
- **Unit Tests**: Write tests for business logic and utility functions
- **UI Tests**: Add UI tests for critical user flows

### Code Review Checklist

- [ ] Code follows Swift style guidelines
- [ ] All new UI respects dark/light theme settings
- [ ] Unit tests cover new functionality  
- [ ] No debug print statements in final code
- [ ] Proper error handling implementation
- [ ] Documentation updated if needed
- [ ] Performance impact considered for data operations

### Development Tools

- **Linting**: Use SwiftLint for code consistency
- **Debugging**: Leverage `InternalSettingsViewController` for development tools
- **Performance**: Use Xcode Instruments for optimization
- **Testing**: Run both `SignalTests` and `SignalUITests` suites

### Security Considerations

When contributing features that handle sensitive data:
- Review cryptographic implementations 
- Ensure proper key management practices
- Consider privacy implications of new data storage
- Test with disappearing message scenarios

### Review Process

1. All pull requests require review before merging
2. Address feedback constructively and promptly
3. Keep pull requests focused on a single feature or fix
4. Provide clear description of changes and reasoning

### Code Style

- Use SwiftLint for code formatting
- Follow established patterns in the codebase
- Write descriptive commit messages
- Keep commits atomic and focused

## Development Setup

1. Install Xcode 14+ and iOS SDK
2. Install CocoaPods (`gem install cocoapods`)
3. Run `pod install` in the project directory
4. Open `SecureChat.xcworkspace` in Xcode

## Testing

- Run unit tests before submitting PR
- Test on multiple iOS versions when possible
- Verify functionality on different device sizes
- Check for memory leaks and performance issues

## Community

We welcome all contributors and strive to create an inclusive environment. Please:
- Be respectful in discussions and code reviews
- Help newcomers get started
- Share knowledge and best practices
- Report any inappropriate behavior

Thank you for contributing to SecureChat!

## Additional Ways to Help

We appreciate all forms of contribution:
- **Documentation**: Help improve our documentation and guides
- **Testing**: Test new features and report issues
- **Code Review**: Review pull requests from other contributors
- **Community Support**: Help other users with questions and issues
- **Spread the Word**: Share SecureChat with others who value privacy

## Questions or Need Help?

If you have questions about contributing:
1. Check our [documentation](./README.md)
2. Look through existing [issues](../../issues)
3. Start a [discussion](../../discussions)
4. Contact the maintainers

---

**SecureChat** is built by the community, for the community. Thank you for helping make secure communication accessible to everyone!
