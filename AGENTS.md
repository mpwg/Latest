# Repository instructions

- Use German umlauts in German text. Repository prose, source comments,
  commits and pull requests remain English; interface strings are localized.
- Put application decisions and workflows in `LatestCore` / `LatestApplication`.
  Neither module may import AppKit, SwiftUI, Sparkle or LatestPlatform.
  The GUI renders shared application state and forwards commands. A future CLI
  must use the same session and native runtime without duplicating policy.
- Automated correctness tests must run without GUI automation. Use injected
  runtime capabilities for deterministic application tests and real native
  adapters for explicitly isolated installation tests. Manual keyboard,
  VoiceOver and layout acceptance remain distinct from headless correctness.
- Manage Xcode project structure through Xcode MCP. Do not generate or rewrite
  the project using Python or another external project generator.
- Work on focused `codex/` branches and pull requests in `mpwg/Latest`.
  Do not push directly to main or publish a release without explicit approval.
