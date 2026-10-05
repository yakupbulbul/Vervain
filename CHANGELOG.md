# Changelog

## 2.0.0

### Added
- Large & Old Files module with configurable size and age thresholds.
- Duplicates module (size → partial hash → SHA-256; oldest copy always kept).
- Privacy module for Safari, Chrome, Firefox, Edge and Brave caches, history and cookies.
- Login Items viewer for third-party launch agents and daemons; user agents can be removed through the review flow.
- Optional menu bar monitor (startup-disk usage and quick junk scan).
- Optional weekly reminder notification.
- Excluded Folders list in Settings, enforced at review time and again right before trashing.
- Manual "Check for Updates…" in Settings (the only network request Vervain makes).
- More developer caches: Gradle, Cargo, Maven, Go, JetBrains, pnpm, Xcode documentation, simulator devices.
- Smart Scan recommends browser cache cleanup, large files and duplicates.
- CI workflow that builds and runs unit tests on every push and pull request.

### Changed
- `~/Library/Caches` is listed per app folder instead of per file, keeping the review list small.
- Every module refreshes its results after a cleanup finishes.
- App version now comes from build settings, so release tags produce the right version.
- Release builds use the hardened runtime and the release entitlements; `get-task-allow` is Debug-only.
- Scanner titles and messages are localizable.

### Security
- Replaced the Finder/AppleScript trash fallback with `NSWorkspace.recycle`.
- `CleanupService` refuses protected locations, files changed since the scan, and paths that resolve into protected locations through symlinked parents.
- The language-change restart no longer shells out to `/usr/bin/open`.
