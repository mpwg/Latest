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
- The owner currently authorizes direct work and intermediate commits on `main`
  in `mpwg/Latest`; pull requests are premature and must not be created yet.
  Keep packages focused. Upstream is read-only. Do not publish a release without
  explicit approval.

- Reuse the already approved localhost test certificate and retain its user-domain
  SSL trust until natural expiry. Do not rotate, remove or re-add it between test
  runs. Explicit fixture cleanup remains a separate user-directed operation.
