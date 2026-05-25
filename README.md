# PureMac

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2015%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange" />
  <img src="https://img.shields.io/badge/Concurrency-Strict-purple" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-pink" />
  <img src="https://img.shields.io/badge/Tests-35%20passing-brightgreen" />
</p>

A safe, transparent macOS cleaning utility built with **Swift 6** and **SwiftUI**.

> CleanMyMac-style functionality, none of the dark patterns. Everything is reviewed before it's removed; nothing is deleted permanently; nothing leaves your Mac.

---

## Safety Model

PureMac is built around three non-negotiable rules:

1. **No permanent deletion.** Every cleanup uses `FileManager.trashItem`. You can restore anything from Trash until you empty it yourself.
2. **No cleanup without explicit review.** Every module routes through a universal **Review → Confirm → Execute → Done** flow owned by `CleanupCoordinator`. Risky or low-confidence items never default-on.
3. **No telemetry.** Zero analytics, zero accounts, zero network traffic outside the user-initiated Full Disk Access deep-link.

These rules are pinned by **35 unit tests** covering `CleanupSelectionPolicy`, `HealthScoreBreakdown`, and `CleanupCategory` invariants.

---

## Features

| Module | What it does | Safety highlights |
|---|---|---|
| 🛡️ **Smart Scan** | Animated health score + transparent breakdown + top-3 recommendations | Score deductions are itemised; each recommendation links to the review flow |
| 🗑️ **System Junk** | Caches, logs, language files, trash, downloads, old installers | Downloads never auto-selected; language files always require review |
| 📦 **App Uninstaller** | Lists installed apps with bundle + leftover sizes | High/Medium/Low/Unknown confidence per leftover; Apple system apps protected |
| 🍩 **Disk Analyzer** | Donut chart + drill-down + largest files | Cancellable; inaccessible folders reported honestly; large files can be sent to review |

---

## Architecture

```
MVVM · actor services · @Observable @MainActor ViewModels · SwiftUI Views
```

```
PureMac/
├── Models/
│   ├── Cleanup/                       ← shared domain
│   │   ├── CleanupItem.swift          ← fully described candidate
│   │   ├── CleanupCategory.swift      ← grouping
│   │   ├── CleanupRiskLevel.swift     ← safe < review < risky
│   │   ├── CleanupConfidenceLevel.swift ← high/medium/low/unknown
│   │   ├── CleanupReason.swift        ← human-readable explanation
│   │   ├── CleanupSourceModule.swift
│   │   └── CleanupSelectionPolicy.swift ← sole authority for default selection
│   ├── HealthScoreBreakdown.swift     ← explainable Smart Scan
│   ├── SmartRecommendation.swift
│   ├── ScanMetadata.swift             ← inaccessible/skipped/error reporting
│   ├── AppFeature, AppInfo, DiskNode, HealthScore
├── Services/
│   ├── Cleanup/CleanupService.swift   ← single trashItem chokepoint
│   ├── JunkScanner.swift              ← per-category risk/confidence tagging
│   ├── AppScanner.swift               ← graded leftover matching, system-app guards
│   ├── DiskAnalyzerService.swift      ← cancellable, FDA-aware
│   ├── FullDiskAccessProbe.swift      ← TCC probe (heuristic)
│   └── FileUtils.swift
├── ViewModels/                        ← all @Observable @MainActor
│   ├── CleanupCoordinator.swift       ← idle → reviewing → confirming → executing → done
│   ├── FullDiskAccessViewModel.swift
│   ├── SmartScan, SystemJunk, AppUninstaller, DiskAnalyzer
├── Views/
│   ├── Cleanup/                       ← Review, Confirmation, Progress, Done, Row
│   ├── SmartScan/                     ← Health ring, breakdown, recommendation cards
│   ├── SystemJunk/                    ← Category rows
│   ├── AppUninstaller/                ← App list, detail panel, leftover groups
│   ├── DiskAnalyzer/                  ← Donut chart, drill-down, large-files pane
│   ├── Onboarding/OnboardingView.swift
│   └── Shared/                        ← FeatureToolbar, FullDiskAccessBanner, badges
└── Extensions/
```

### Concurrency invariants

- All filesystem work happens on `actor` services
- ViewModels stay on `@MainActor`
- Models are `Sendable` value types (only `DiskNode` is `final class @unchecked Sendable` — needed for recursive tree)
- `Task.checkCancellation()` in every scan/cleanup loop
- `FileManager.trashItem` is the **only** deletion primitive — enforced by routing all deletion through `CleanupService`

---

## Getting Started

### Requirements
- macOS 15.0+
- Xcode 16+
- Swift 6
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build & run
```bash
git clone https://github.com/yakupbulbul/PureMac.git
cd PureMac
xcodegen generate
open PureMac.xcodeproj
# ⌘R in Xcode
```

### Run tests
```bash
xcodebuild -project PureMac.xcodeproj -scheme PureMac \
  -destination 'platform=macOS' test
```

### Full Disk Access (optional)
PureMac probes a few protected paths at launch. If they're unreadable, the yellow FDA banner appears. Click **Grant Access**, add PureMac in **System Settings → Privacy & Security → Full Disk Access**, and return — the banner re-probes and dismisses itself.

You can use PureMac without granting FDA — protected folders are simply reported as "inaccessible" in scan stats instead of being scanned.

---

## Roadmap

Completed: **Phases 0–7 + 13** (safe core + Disk Analyzer 2.0 + FDA probe + safety tests).

Not yet started:
- **Phase 8** — Login Items viewer (SMAppService), maintenance tasks with confirmations
- **Phase 9** — Large & Old Files scanner, Duplicate Finder MVP
- **Phase 10** — Privacy module (browser cache/history/cookies — cookies always risky)
- **Phase 11** — Optional menu bar monitor (disk, memory)
- **Phase 12** — Settings panel for thresholds (onboarding ✅)
- **Phase 14** — Hardened runtime / sandbox / notarization documentation

See `docs/AUDIT.md` for the safety risk register that drove the v2 rework.

---

## License

MIT — see [LICENSE](LICENSE)
