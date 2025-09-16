# Repository Guidelines
Contributions keep Latest healthy and dependable. Review the expectations below before proposing code or documentation changes.

## Project Structure & Module Organization
- `Latest/` holds the production app, split into `Model`, `View Model`, `Interface`, `Utilities`, and `Resources` for localized strings and assets.
- `Frameworks/` brings in vendor code such as `StoreFoundation` and `CommerceKit`; keep submodules updated when touching bundled SDKs.
- `Sparkle/` tracks the upstream update framework; update via the submodule rather than copying files.
- `Tests/` contains all XCTest cases and the shared `Info.plist`. Mirror new features here.

## Build, Test, and Development Commands
- `xed Latest.xcodeproj` opens the project in Xcode with the correct schemes.
- `xcodebuild -scheme Latest -configuration Debug build` produces a debug build for local verification.
- `xcodebuild -scheme Latest test -destination 'platform=macOS'` runs the XCTest suite headlessly; use this in CI or before review.

## Coding Style & Naming Conventions
- Write Swift 5 with 4-space indentation, braces on the same line as declarations, and favor `guard` for early exits.
- Types and protocols use UpperCamelCase, methods and properties use lowerCamelCase, and localization keys stay consistent with the `.strings` files in `Resources/*/*.lproj`.
- Keep files focused: separate view models, views, and services into their existing folders, and prefer extensions for protocol conformances.

## Testing Guidelines
- Add or update XCTests beside the feature, following the `*Test.swift` naming pattern (e.g., `VersionParserTest.swift`).
- Cover parsing and update logic with deterministic data; stub file reads via fixtures in `Tests/` when possible.
- Ensure new code passes `xcodebuild ... test`; include expectations for async flows using `XCTestExpectation`.

## Commit & Pull Request Guidelines
- Follow the existing history by writing short, imperative commit subjects ("Fix version comparison tests") and group related changes together.
- Reference GitHub issues in the body when applicable and document user-facing changes.
- Pull requests need: a clear summary, before/after screenshots for UI tweaks, test evidence (`xcodebuild` output or steps), and notes on localization or Sparkle changes.

## Localization & Update Assets
When altering content under `Resources/*.lproj`, list affected languages and sync Weblate contributions before merging. For Sparkle feed changes, explain how dsa keys or appcast updates were validated.
