# Code Organization Structure

This document outlines the organized structure for the SecureChat iOS codebase.

## Folder Structure

### `/Managers`
**Purpose**: Singleton classes and service managers that handle app-wide functionality
**Contents**:
- `AnalyticsManager.swift` - Handles analytics and telemetry
- `MessageSearchManager.swift` - Manages message search functionality
- `ThemeManager.swift` - Manages app theming and appearance

**Guidelines**:
- Use for classes that manage global state or services
- Typically singleton pattern implementations
- Handle cross-feature functionality

### `/Utilities`
**Purpose**: Helper classes, extensions, and utility functions
**Contents**:
- `Colors.swift` - Centralized color definitions
- `ThemeUtils.swift` - Theme-related utility functions
- `OfflineMessageQueue.swift` - Message queuing utilities
- `SharingActivityHelper.swift` - Sharing functionality helpers
- `MessageResendPromptBuilder.swift` - Message resend prompt utilities

**Guidelines**:
- Stateless helper functions and classes
- Extensions to existing classes
- Common functionality used across multiple features

### `/Components`
**Purpose**: Reusable UI components and custom views

#### `/Components/UI`
**Purpose**: Basic reusable UI components
**Contents**:
- `AnimatedProgressView.swift` - Progress indicators
- `LottieToggleButton.swift` - Custom animated buttons
- `MarqueeLabel.swift` - Scrolling text labels
- `SelectionButton.swift` - Custom selection controls

**Guidelines**:
- Reusable across multiple screens
- Self-contained UI components
- No business logic, only presentation

### `/BackgroundTasks`
**Purpose**: Background processing and task management
**Contents**:
- `BackupBGProcessingTaskRunner.swift` - Backup task processing
- `BGProcessingTaskRunner.swift` - General background task runner
- `MessageFetchBGRefreshTask.swift` - Background message fetching
- `AttachmentValidationBackfillRunner.swift` - Attachment validation tasks

**Guidelines**:
- Background processing implementations
- System-level task management
- Non-UI related background operations

## File Naming Conventions

### Do ✅
- Use descriptive, clear names: `MessageSearchManager.swift`
- Include the component type: `AnimatedProgressView.swift`
- Use proper Swift naming: `ThemeUtils.swift`

### Don't ❌ 
- Use abbreviations: `ShareActivityUtil.swift` → `SharingActivityHelper.swift`
- Generic names: `Helper.swift`
- Unclear purpose: `BGTaskRunner.swift` → `BackgroundTaskRunner.swift`

## Adding New Files

When adding new files, consider:

1. **What is the primary responsibility?**
   - Business logic → `/Managers`
   - UI components → `/Components/UI` 
   - Helper functions → `/Utilities`
   - Background processing → `/BackgroundTasks`

2. **Is it reusable?**
   - Yes → Place in appropriate shared folder
   - No → Consider if it belongs in feature-specific folder

3. **Does the name clearly indicate purpose?**
   - Use descriptive names that explain functionality
   - Include component type when relevant

This structure helps maintain clean, organized, and maintainable code as the project grows.