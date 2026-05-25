# PureMac — Phase 0 Audit

**Baseline:** `main` @ `0e5d3ad` · 28 Swift files · macOS 15 · Swift 6 strict concurrency · BUILD SUCCEEDED · 0 warnings

## Inventory

| Layer | Count | Notes |
|---|---|---|
| Models | 5 | `AppFeature`, `AppInfo`, `DiskNode`, `HealthScore`, `JunkCategory` |
| Services (actors) | 4 | `JunkScanner`, `AppScanner`, `DiskAnalyzerService`, `FileUtils` (free fn) |
| ViewModels (@Observable @MainActor) | 4 | one per module |
| Views | 14 | sidebar, smart scan, system junk, app uninstaller, disk analyzer, shared |

## Concurrency posture

- ✅ All filesystem work in `actor` services
- ✅ ViewModels stay on `@MainActor`
- ✅ Models are `Sendable` value types (`DiskNode` is `final class @unchecked Sendable` — needed for recursive tree)
- ✅ `Task.checkCancellation()` present in scan loops
- ✅ `NSImage` deliberately not stored in models — fetched on `@MainActor` in `AppIconView`

## Safety risks identified (drives Phases 1–5)

| # | Risk | Location | Phase fix |
|---|---|---|---|
| 1 | All junk categories default-selected, including Downloads | `JunkCategory.isSelected: Bool = true` | 1, 2 |
| 2 | Clean button deletes immediately — no review screen | `SystemJunkViewModel.clean()` | 3 |
| 3 | No per-item risk or confidence tier | `JunkFile`, `AppInfo.leftoverFiles: [URL]` | 1, 5 |
| 4 | Leftover detection uses loose substring match — no confidence | `AppScanner.scanLeftovers` `localizedCaseInsensitiveContains` | 5 |
| 5 | Health score has no breakdown — black box | `HealthScore.compute` returns single `Int` | 4 |
| 6 | Each module deletes via its own scanner — no shared chokepoint | `JunkScanner.deleteFiles`, `AppScanner.uninstall` | 2 |
| 7 | Permission errors silently swallowed via `try?` | scanners | 2 |
| 8 | No protection against uninstalling Apple system apps | `AppScanner.scanInstalledApps` | 5 |
| 9 | Language file deletion warned in README but not in UI | `JunkScanner.scanLanguageFiles` | 2 |

## Non-issues confirmed

- `FileManager.trashItem` already used for all deletions (no permanent delete primitive in codebase) ✅
- No telemetry, no analytics, no network calls except FDA deep-link via `NSWorkspace` ✅
- Sandbox disabled in `PureMac.entitlements` (intentional for full-disk scanning) ✅
- Build is clean (0 warnings, 0 errors) — no compile fixes needed ✅

## Phase 0 outcome

Project is buildable and architecturally sound. No code changes required for baseline. AUDIT.md added to record findings that drive Phases 1–14.
