# Vervain — Release Readiness

This document captures the decisions, risks, and outstanding work needed to ship Vervain as a notarized, signed macOS app. It is not a build script — it is the audit trail Developer ID distribution will rely on.

---

## 1. Current build settings (`project.yml`)

| Setting | Value | Why |
|---|---|---|
| `MACOSX_DEPLOYMENT_TARGET` | `15.0` | SwiftUI APIs used: `SectorMark`, `.contentTransition(.numericText)`, `@Observable`, `ContentUnavailableView` |
| `SWIFT_VERSION` | `6.0` | Strict concurrency, `Sendable` enforcement |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | No data-race silently slips by |
| `ENABLE_HARDENED_RUNTIME` | **NO** (dev) | Must be **YES** for notarization. See §3. |
| `CODE_SIGN_IDENTITY` | `-` (ad-hoc) | Must be Developer ID Application for distribution. See §4. |
| `com.apple.security.app-sandbox` (entitlement) | `false` | Cleaning tool needs full FS access. See §2. |

---

## 2. Sandbox decision

**Decision: ship outside the App Sandbox.**

Vervain's value proposition requires reading and trashing files in arbitrary user-owned locations (`~/Library/Caches`, `/Applications/*.app`, `~/Downloads`, …). The App Sandbox forbids this without user-granted Bookmark Files per cleanup, which would destroy the UX.

This means:

- ❌ Cannot ship on the Mac App Store
- ✅ Can ship as a Developer ID signed + notarized direct download (Sparkle-friendly)
- ✅ Already what every comparable utility (CleanMyMac, OnyX, AppCleaner) does

**Required entitlements after notarization:**

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.cs.allow-jit</key>
<false/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<false/>
<key>com.apple.security.cs.disable-library-validation</key>
<false/>
```

These are the **safest defaults** for a non-sandboxed Hardened Runtime app.

---

## 3. Hardened Runtime

**Required for notarization. Currently disabled for development convenience.**

Flip these before tagging a release:

```yaml
# project.yml — release config
settings:
  base:
    ENABLE_HARDENED_RUNTIME: YES
```

Regenerate the Xcode project and run a smoke build to catch any code-signing-incompatible code (we don't use JIT, dynamic libraries, or runtime patching, so this should be uneventful).

---

## 4. Code signing & notarization

### One-time setup
1. Apple Developer Program membership (annual fee).
2. **Developer ID Application** certificate downloaded into the login keychain.
3. App-specific password for `notarytool` stored in keychain:
   ```bash
   xcrun notarytool store-credentials "Vervain-Notary" \
     --apple-id you@example.com \
     --team-id ABCDEF1234 \
     --password app-specific-password
   ```

### Per-release build
```bash
# 1. Archive
xcodebuild -project Vervain.xcodeproj -scheme Vervain \
  -configuration Release \
  -archivePath build/Vervain.xcarchive archive

# 2. Export Developer ID app
xcodebuild -exportArchive \
  -archivePath build/Vervain.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/Export

# 3. Zip for notarytool
ditto -c -k --keepParent build/Export/Vervain.app build/Vervain.zip

# 4. Submit for notarization (~2 min typical)
xcrun notarytool submit build/Vervain.zip \
  --keychain-profile "Vervain-Notary" --wait

# 5. Staple the notarization ticket onto the app
xcrun stapler staple build/Export/Vervain.app

# 6. (Optional) build a DMG with create-dmg
```

`ExportOptions.plist` template lives at `docs/ExportOptions.plist.template`.

---

## 5. Auto-update

**Not implemented. Recommended: Sparkle.**

When you're ready:
- Add `Sparkle` via SPM
- Generate Ed25519 keys, ship public key with the app
- Host an `appcast.xml` on your own server (or GitHub Releases)
- Sign each release ZIP with the private key

This is out of scope for the current release and explicitly **not** added without your sign-off.

---

## 6. Security review checklist (per release)

Run through this before every tag:

- [ ] `xcodebuild ... test` — all unit tests pass
- [ ] `grep -r "removeItem\|unlink\b" Vervain/` — must return no hits except inside `CleanupService` (currently: zero hits anywhere — only `trashItem` is used)
- [ ] `grep -r "Process()\|URLSession\|URLRequest" Vervain/` — should be empty (no network, no shell)
- [ ] Onboarding sheet promises still match behavior
- [ ] AUDIT.md risk register has no new red rows
- [ ] FDA banner only appears when probe denies (`FullDiskAccessProbe` heuristic)
- [ ] Apple system apps (`com.apple.*`) still filtered out of `AppScanner`

### Current state (commit `a1aa3e4`)

```bash
$ grep -rn "removeItem\|unlink\b" Vervain/
# (no output — clean)

$ grep -rn "Process()\|URLSession\|URLRequest" Vervain/
# (no output — clean)
```

All deletion goes through `CleanupService.execute()` which calls `FileManager.trashItem` exclusively. There is no network code in the entire codebase. The only `NSWorkspace.shared.open` calls are:
1. `FullDiskAccessProbe.openSystemSettings()` — `x-apple.systempreferences:` deep link
2. `SystemJunkView.openTrash()` / `CleanupDoneView.openTrash()` — open `~/.Trash`

---

## 7. Known limitations carried into release

| Area | Limitation | Workaround for v1 |
|---|---|---|
| FDA probe | Heuristic (no first-party API) | Status documented in code + UI says "appears granted" |
| Sandboxing | Not feasible | Documented in §2 above |
| Sparkle updater | Not implemented | Manual download for v1; Sparkle in v2 |
| Language-file removal | Invalidates app signature | UI tags as `.review` with explicit subtitle warning |
| Post-cleanup VM refresh | User must press Re-Scan after closing review sheet | Tracked as follow-up; doesn't affect safety |

---

## 8. Distribution channels

| Channel | Feasible? | Notes |
|---|---|---|
| Direct download (notarized DMG) | ✅ Recommended | Standard for cleaner utilities |
| Mac App Store | ❌ | Requires sandbox; defeats core functionality |
| Homebrew Cask | ✅ Optional | After first signed release |
| Setapp | 🟡 Possible | Requires Setapp partnership negotiation |
