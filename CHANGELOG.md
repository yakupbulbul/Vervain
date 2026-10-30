# Changelog

## 2.1.0

### Changed
- Updates: Settings has a new "Check for updates automatically" switch, off by default. When it is on, Vervain asks the GitHub releases API for the latest version at most once a day while it is open, and shows a dismissible banner with a link to the release. It never downloads or installs anything itself.

### Fixed
- Project Artifacts: a project now also counts as active when git shows recent work, meaning a recent commit, checkout or pull, edits that are not committed yet, or a recent change to the git index. Work deep inside `src/` is no longer missed. Git only adds to the file dates, so a project can look more active than before but never less.
- Review sheet: after you ticked or unticked an item, its checkmark could keep showing the old state while the totals changed. Items now compare by selection as well, so the row redraws.

## 2.0.0 (continued)

### Added since the first 2.0 draft
- Project Artifacts module: finds `node_modules`, `target`, `.build`, `Pods`, Python virtual environments, `dist` and `build` folders inside your projects, grouped by project. A folder only counts when a project file next to it (`package.json`, `Cargo.toml`, `Package.swift`, `Podfile` …) shows what it is. Only git-ignored folders of projects idle for 7 days or more (configurable) are pre-selected; folders git does not ignore are low confidence and never pre-selected. Symlinks and nested repositories are skipped, and everything goes to the Trash.
- AI Models module: lists model downloads from Hugging Face (per repository), LM Studio (per model), Ollama (one item, because its blobs are shared), PyTorch, Whisper, Keras and GPT4All. Nothing is pre-selected, since downloading a model again can take a long time.
- Maintenance module: reset Quick Look previews and restart Finder, the Dock or the menu bar with one click, no password needed. Jobs that need administrator rights (flush DNS cache, rebuild the Spotlight index, free inactive memory) are never run by Vervain; it shows and copies the exact Terminal command instead. Tasks come from a fixed list, so nothing typed or read from disk becomes a command.
- Local Snapshots, a section of Maintenance: shows Time Machine local snapshots and the space macOS can free on its own. It is read-only: removing a snapshot is permanent and needs administrator rights, so Vervain copies the exact `tmutil` command for you to run in Terminal instead.
- System Status module: a live view of CPU (per core, load average), memory, startup disk, network rates, battery (charge, maximum capacity, cycles, temperature, time remaining), thermal state, uptime and the busiest processes. It refreshes every two seconds while open and does nothing otherwise.
- Smart Scan score reworked. Junk now costs points on a smooth scale from 0.5 GB to 15 GB instead of in steps, and files that need your review count a quarter as much as ones that are safe to remove. A full disk only costs points when little room is left in absolute terms, so 96% of a 4 TB drive is not punished like 96% of a 256 GB one. Smart Scan also shows the score you would reach after cleaning the safe items. The Trash is scored on its own, and Smart Scan now includes Project Artifacts, so old build folders count toward the score and the Review Cleanup list, with cards for emptying the Trash and clearing build folders.
- Demo mode for screenshots: start Vervain with `VERVAIN_DEMO_ROOT` pointing at a folder and App Uninstaller lists `<folder>/Applications`, leftovers come from `<folder>/Library`, and Disk Analyzer measures the folder's top-level directories. Nothing else on the Mac is read, and no disk capacity is invented. There is no setting for it in the app.
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
