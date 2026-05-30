<p align="center">
  <img src="PureMac/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="PureMac icon" />
</p>

<h1 align="center">PureMac</h1>

<p align="center">
  A free, open-source macOS cleaner that respects your files and your privacy.<br>
  <a href="https://puremac.app">puremac.app</a>
</p>

---

I built PureMac because every Mac cleaner I tried either wanted a subscription, phoned home with analytics, or auto-deleted files I didn't ask it to touch. PureMac does none of that. It moves things to Trash so you can undo, it shows you everything before acting, and it never talks to a server.

<p align="center">
  <img src="https://puremac.app/images/screenshots/smart-scan-dark.png" width="720" alt="PureMac Smart Scan" />
</p>

## What it does

**Smart Scan** — Gives you a health score with a transparent breakdown. Every deduction is explained, and each recommendation links directly to the thing it found.

**System Junk** — Finds caches, logs, leftover language files, old installers, and stale downloads. Downloads are never pre-selected for cleanup — you pick what goes.

**App Uninstaller** — Shows your installed apps alongside any leftover files they'd leave behind. Each leftover is tagged with a confidence level (high, medium, low, unknown) so you know what's safe to remove. Apple system apps are protected and can't be uninstalled.

**Disk Analyzer** — A donut chart view of what's eating your disk space, with drill-down into folders and a list of your largest files. Fully cancellable, and honest about folders it can't access.

## Three promises

1. **Nothing gets permanently deleted.** Every cleanup goes through `trashItem`. You can always restore from Trash.
2. **Nothing gets cleaned without your say-so.** Every module goes through a review → confirm → clean flow. Risky items are never pre-selected.
3. **Nothing leaves your Mac.** No analytics, no accounts, no network calls.

## Building from source

You need macOS 15+, Xcode 16+, and Swift 6.

```bash
git clone https://github.com/yakupbulbul/PureMac.git
cd PureMac
open PureMac.xcodeproj
# ⌘R to run
```

To run tests:
```bash
xcodebuild -project PureMac.xcodeproj -scheme PureMac \
  -destination 'platform=macOS' test
```

### Full Disk Access

PureMac works without Full Disk Access — it just skips protected folders and tells you what it couldn't reach. If you want a complete scan, go to **System Settings → Privacy & Security → Full Disk Access** and add PureMac. The app detects the change automatically.

## How it's built

Swift 6 with strict concurrency. SwiftUI for the UI, actor-isolated services for file system work, `@Observable` view models on the main actor. The only deletion primitive in the entire codebase is `FileManager.trashItem`, called from a single `CleanupService` — everything else routes through it.

The `CleanupCoordinator` owns the review flow state machine (idle → reviewing → confirming → executing → done) and is shared across all modules.

## What's next

- Login items viewer and maintenance tasks
- Large & old files scanner
- Duplicate file finder
- Privacy cleanup (browser caches, cookies)
- Menu bar disk/memory monitor
- Notarization and sandboxing

## Contributing

Pull requests are welcome. If you're adding a new cleanup module, the main thing to know is that all deletion must go through `CleanupService.trashItem` — this is how the safety model works. Items need a risk level and a confidence level so the review UI can make good default selections.

Have a look at `CleanupSelectionPolicy` to understand which items get pre-selected and which don't.

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">Made by <a href="https://github.com/yakupbulbul">Yakup Bülbül</a></p>
