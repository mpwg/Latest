# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build Commands
- `xed Latest.xcodeproj` - Opens the project in Xcode with the correct schemes
- `xcodebuild -scheme Latest -configuration Debug build` - Produces a debug build for local verification
- `xcodebuild -scheme Latest -configuration Release build` - Creates a release build

### Testing Commands
- `xcodebuild -scheme Latest test -destination 'platform=macOS'` - Runs the XCTest suite headlessly; use this for CI or before review
- Tests are located in the `Tests/` directory and follow the `*Test.swift` naming pattern

## Project Architecture

Latest is a Swift macOS application that checks for app updates. The codebase follows MVVM architecture:

### Core Directory Structure
- `Latest/Model/` - Core data models and business logic
  - `App.swift` - Main app representation combining bundle and update info
  - `Update.swift` - Update information model
  - `UpdateCheckCoordinator.swift` - Coordinates update checking operations
  - `Version/` - Version parsing and comparison logic
  - `Update Checker Extensions/` - Extensions for different update sources
  - `Updater/` - Update execution logic
- `Latest/View Model/` - MVVM view models bridging UI and business logic
  - `AppListViewModel.swift` - Manages the main app list
  - `MainWindowViewModel.swift` - Controls main window state
  - `ReleaseNotesProvider.swift` - Handles release notes display
- `Latest/Interface/` - All UI components and view controllers
  - `Main Window/` - Main application window and table views
  - `Settings/` - Settings UI components
- `Latest/Utilities/` - Shared utilities and helpers
- `Latest/Resources/` - Localization files, assets, and configuration

### Key Components
- **Update Sources**: Supports Mac App Store and Sparkle-based updates
- **Bundle Detection**: Scans system for installed applications
- **Version Parsing**: Handles semantic versioning and build numbers
- **Update Operations**: Manages async update checking and installation

### External Dependencies
- `Frameworks/` - Contains vendor frameworks like `CommerceKit` and `StoreFoundation`
- `Sparkle/` - Update framework (managed as submodule)

## Coding Standards

- Swift 5 with 4-space indentation
- Braces on the same line as declarations
- Favor `guard` statements for early exits
- UpperCamelCase for types and protocols, lowerCamelCase for methods and properties
- Keep files focused: separate view models, views, and services into appropriate folders
- Use extensions for protocol conformances

## Testing Guidelines

- Add XCTests for new features following existing patterns
- Cover parsing and update logic with deterministic data
- Use `XCTestExpectation` for async flows
- All tests must pass before submitting changes

## Key Technologies
- Swift 5
- AppKit (macOS native UI)
- XCTest for testing
- Sparkle framework for updates
- Mac App Store integration via CommerceKit/StoreFoundation
- please ensure that it stil builds