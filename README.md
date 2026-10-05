<p align="center">
  <img src="Vervain/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="Vervain icon" />
</p>

<h1 align="center">Vervain</h1>

<p align="center">
  <strong>Free, open-source macOS cleaner that respects your files and your privacy.</strong>
</p>

<p align="center">
  <a href="https://vervain.app"><img src="https://img.shields.io/badge/website-vervain.app-8B5E3C?style=flat-square" alt="Website" /></a>
  <a href="https://github.com/yakupbulbul/Vervain/releases/latest"><img src="https://img.shields.io/github/v/release/yakupbulbul/Vervain?style=flat-square&color=8B5E3C" alt="Latest Release" /></a>
  <a href="https://github.com/yakupbulbul/Vervain/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-8B5E3C?style=flat-square" alt="MIT License" /></a>
  <img src="https://img.shields.io/badge/platform-macOS_15+-8B5E3C?style=flat-square" alt="macOS 15+" />
  <img src="https://img.shields.io/badge/Swift-6-8B5E3C?style=flat-square" alt="Swift 6" />
</p>

<br>

<p align="center">
  <img src="https://vervain.app/images/screenshots/smart-scan-dark.png" width="720" alt="Vervain Smart Scan" />
</p>

<br>

## Why Vervain?

Every Mac cleaner I tried either wanted a subscription, phoned home with analytics, or auto-deleted files I didn't ask it to touch. Vervain does none of that. It moves things to Trash so you can undo, it shows you everything before acting, and it never talks to a server.

| | Vervain | CleanMyMac | OnyX |
|---|:---:|:---:|:---:|
| Price | **Free forever** | $40/year | Free |
| Open source | **Yes** | No | No |
| Analytics/tracking | **None** | Yes | None |
| Deletes to Trash (undoable) | **Yes** | No | No |
| App uninstaller with leftovers | **Yes** | Yes | No |
| Disk analyzer | **Yes** | Yes | No |
| Duplicate finder | **Yes** | Yes | No |
| Review before cleanup | **Always** | Partial | Partial |
| Multi-language | **6 languages** | Yes | No |

## Install

**Homebrew:**
```bash
brew install yakupbulbul/vervain/vervain
```

**Direct download:**

> [Download the latest Vervain DMG](https://github.com/yakupbulbul/Vervain/releases/latest) — Signed & notarized by Apple.

## Features

<table>
<tr>
<td width="50%">

### Smart Scan
Health score with a transparent breakdown. Every deduction is explained, and each recommendation links directly to the thing it found.

</td>
<td width="50%">

### System Junk
Finds caches, logs, leftover language files, old installers, and stale downloads. Downloads are never pre-selected — you pick what goes.

</td>
</tr>
<tr>
<td>
<img src="https://vervain.app/images/screenshots/smart-scan-dark.png" width="100%" alt="Smart Scan" />
</td>
<td>
<img src="https://vervain.app/images/screenshots/system-junk-dark.png" width="100%" alt="System Junk" />
</td>
</tr>
<tr>
<td width="50%">

### App Uninstaller
Shows installed apps with leftover files tagged by confidence level (high, medium, low). Apple system apps are protected and can't be uninstalled.

</td>
<td width="50%">

### Disk Analyzer
Donut chart of what's eating your disk, with drill-down into folders and largest files list. Honest about folders it can't access.

</td>
</tr>
<tr>
<td>
<img src="https://vervain.app/images/screenshots/app-uninstaller-dark.png" width="100%" alt="App Uninstaller" />
</td>
<td>
<img src="https://vervain.app/images/screenshots/disk-analyzer-dark.png" width="100%" alt="Disk Analyzer" />
</td>
</tr>
</table>

### New in 2.0

- **Large & Old Files** — big files you have not touched in months, with size and age thresholds you choose. Nothing is pre-selected.
- **Duplicates** — byte-identical files found by size, partial hash and SHA-256. The oldest copy is always kept and never listed.
- **Privacy** — Safari, Chrome, Firefox, Edge and Brave caches (pre-selected), history (review) and cookies (risky, never pre-selected).
- **Login Items** — see third-party launch agents and daemons; remove your own through the normal review flow.
- **Menu bar monitor** — optional startup-disk gauge and a quick junk scan.
- **Weekly reminder** and an **exclusion list** for folders Vervain must never touch, both in Settings.
- **More developer caches** — Gradle, Cargo, Maven, Go, JetBrains, pnpm, Xcode documentation and simulators.
- Safer deletion: protected-path guard, files changed since the scan are refused, and the Finder/AppleScript fallback is gone.

## Languages

Available in 6 languages — switch anytime via **Settings** (⌘,):

🇬🇧 English · 🇫🇷 Français · 🇩🇪 Deutsch · 🇹🇷 Türkçe · 🇪🇸 Español · 🇨🇳 中文(简体)

Vervain automatically uses your Mac's system language, or you can choose a different one in the app.

## Three Promises

1. **Nothing gets permanently deleted.** Every cleanup moves items to the Trash. You can always restore from Trash.
2. **Nothing gets cleaned without your say-so.** Every module goes through a review → confirm → clean flow. Risky items are never pre-selected.
3. **Nothing leaves your Mac.** No analytics, no accounts, no background network calls. The only request Vervain ever makes is the optional **Check for Updates** button in Settings.

## Building from Source

You need macOS 15+, Xcode 16+, and Swift 6.

```bash
git clone https://github.com/yakupbulbul/Vervain.git
cd Vervain
open Vervain.xcodeproj
# ⌘R to run
```

### Full Disk Access

Vervain works without Full Disk Access — it just skips protected folders and tells you what it couldn't reach. If you want a complete scan, go to **System Settings → Privacy & Security → Full Disk Access** and add Vervain. The app detects the change automatically.

## How It's Built

Swift 6 with strict concurrency. SwiftUI for the UI, actor-isolated services for file system work, `@Observable` view models on the main actor. The only deletion primitives in the entire codebase are `FileManager.trashItem` and `NSWorkspace.recycle` (both move items to the Trash), called from a single `CleanupService` — everything else routes through it. No AppleScript and no shell commands are used.

The `CleanupCoordinator` owns the review flow state machine (idle → reviewing → confirming → executing → done) and is shared across all modules.

## Roadmap

- [x] Login items viewer
- [x] Large & old files scanner
- [x] Duplicate file finder
- [x] Privacy cleanup (browser caches, history, cookies)
- [x] Menu bar disk monitor
- [ ] Memory monitor and maintenance tasks
- [ ] Toggle launch agents on and off (currently view and remove only)
- [ ] Translations for the new v2 screens

## Contributing

Pull requests are welcome. If you're adding a new cleanup module, all deletion must go through `CleanupService` — this is how the safety model works. Items need a risk level and a confidence level so the review UI can make good default selections.

Have a look at `CleanupSelectionPolicy` to understand which items get pre-selected and which don't.

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <a href="https://vervain.app">Website</a> · <a href="https://github.com/yakupbulbul/Vervain/releases">Releases</a> · <a href="https://buymeacoffee.com/yakupbulbul">Buy Me a Coffee</a>
</p>
<p align="center">Made by <a href="https://github.com/yakupbulbul">Yakup Bulbul</a></p>
