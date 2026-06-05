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
| Review before cleanup | **Always** | Partial | Partial |
| Multi-language | **6 languages** | Yes | No |

## Install

**Homebrew:**
```bash
brew install yakupbulbul/vervain/vervain
```

**Direct download:**

> [Download Vervain-1.1.0.dmg](https://github.com/yakupbulbul/Vervain/releases/latest/download/Vervain-1.1.0.dmg) — Signed & notarized by Apple.

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

## Languages

Available in 6 languages — switch anytime via **Settings** (⌘,):

🇬🇧 English · 🇫🇷 Français · 🇩🇪 Deutsch · 🇹🇷 Türkçe · 🇪🇸 Español · 🇨🇳 中文(简体)

Vervain automatically uses your Mac's system language, or you can choose a different one in the app.

## Three Promises

1. **Nothing gets permanently deleted.** Every cleanup goes through `trashItem`. You can always restore from Trash.
2. **Nothing gets cleaned without your say-so.** Every module goes through a review → confirm → clean flow. Risky items are never pre-selected.
3. **Nothing leaves your Mac.** No analytics, no accounts, no network calls. Zero.

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

Swift 6 with strict concurrency. SwiftUI for the UI, actor-isolated services for file system work, `@Observable` view models on the main actor. The only deletion primitive in the entire codebase is `FileManager.trashItem`, called from a single `CleanupService` — everything else routes through it.

The `CleanupCoordinator` owns the review flow state machine (idle → reviewing → confirming → executing → done) and is shared across all modules.

## Roadmap

- [ ] Login items viewer and maintenance tasks
- [ ] Large & old files scanner
- [ ] Duplicate file finder
- [ ] Privacy cleanup (browser caches, cookies)
- [ ] Menu bar disk/memory monitor

## Contributing

Pull requests are welcome. If you're adding a new cleanup module, all deletion must go through `CleanupService.trashItem` — this is how the safety model works. Items need a risk level and a confidence level so the review UI can make good default selections.

Have a look at `CleanupSelectionPolicy` to understand which items get pre-selected and which don't.

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <a href="https://vervain.app">Website</a> · <a href="https://github.com/yakupbulbul/Vervain/releases">Releases</a> · <a href="https://buymeacoffee.com/yakupbulbul">Buy Me a Coffee</a>
</p>
<p align="center">Made by <a href="https://github.com/yakupbulbul">Yakup Bulbul</a></p>
