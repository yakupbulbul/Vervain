# PureMac

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2015%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-purple" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

A native macOS cleaning utility built with **Swift 6** and **SwiftUI**, inspired by CleanMyMac X.

---

## Features

| Feature | Description |
|---|---|
| 🛡️ **Smart Scan** | Animated health score (0–100) — scans all categories in parallel and gives an at-a-glance system health report |
| 🗑️ **System Junk** | Removes user caches, system logs, language files, trash, and downloads |
| 📦 **App Uninstaller** | Lists all apps with bundle sizes; detects leftover files in `~/Library`; moves to Trash |
| 🍩 **Disk Analyzer** | Donut chart breakdown of home folder usage with drill-down navigation |

---

## Architecture

```
MVVM  ·  actor Services  ·  @Observable @MainActor ViewModels  ·  SwiftUI Views
```

- **Services** (`actor`) — `JunkScanner`, `AppScanner`, `DiskAnalyzerService` run off the main actor and are Swift 6 concurrency-safe
- **ViewModels** (`@Observable @MainActor`) — own the UI state, call services via `await`
- **Models** — all `Sendable` value types (structs), except `DiskNode` (`final class @unchecked Sendable`)

---

## Getting Started

### Requirements
- macOS 15.0+
- Xcode 16+
- Swift 6

### Build

```bash
# Clone
git clone https://github.com/yakupbulbul/PureMac.git
cd PureMac

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Open in Xcode
open PureMac.xcodeproj
```

> **Full Disk Access:** For scanning protected directories, grant Full Disk Access in  
> **System Settings → Privacy & Security → Full Disk Access → PureMac**

---

## Privacy & Safety

- All deletions use **`FileManager.trashItem`** — files go to Trash, never permanently deleted
- No network requests — everything runs locally on your Mac
- No telemetry, no analytics, no accounts required

---

## License

MIT — see [LICENSE](LICENSE)
