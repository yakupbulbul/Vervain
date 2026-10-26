# Changelog

## 2.0.0 (continued)

### Added since the first 2.0 draft
- Undo: the done screen can put everything back, and a History module lists past cleanups with Put Back.
- Review sheet: search, sort, file-type filter, "only safe items", Quick Look, Reveal in Finder, Never offer this; Cmd-1…9, Cmd-R, Cmd-F shortcuts.
- Export scan results as CSV or Markdown.
- App Uninstaller: last opened, source badges, "not opened in 6 months" and "has leftovers" filters, drag and drop, quit running apps, scan cancel and error banner, more leftover locations, whole-word name matching.
- Leftovers module for data of apps that are no longer installed.
- Disk Analyzer: analyze a folder or external disk, pruning after cleanup, per-item trash, sizes no longer drop to 0 below the depth limit.
- Device backups category, more developer caches, extra scan folders, duplicate keep rules (oldest, newest, shallowest), hard links ignored.
- Weekly reminder day and time, low-disk alert, notification tap starts a Smart Scan, memory use and top apps in the menu bar, Shortcuts actions, open at login, scan on launch.
- Guided three-step welcome tour (replayable), Full Disk Access status and an "always confirm" switch in Settings.
- Complete translations of every screen in six languages; CI warns about untranslated strings and prints test coverage.

### Fixed
- Cleanup now reports a cancelled run as a partial result, removes only items that reached the Trash from the list, and measures files right before trashing.
- Onboarding texts were never translated.

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
