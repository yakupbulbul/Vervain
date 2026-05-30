#!/bin/bash
set -euo pipefail

# PureMac release build script
# Usage: TEAM_ID=DP95N34FAN ./scripts/release.sh 1.0.0

VERSION="${1:?Usage: scripts/release.sh <version>  (e.g. 1.0.0)}"

# Configuration — override via env vars
TEAM_ID="${TEAM_ID:?Set TEAM_ID env var (e.g. DP95N34FAN)}"
APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-PureMac-Notary}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/PureMac.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Export"
APP_PATH="${EXPORT_PATH}/PureMac.app"
DMG_PATH="${BUILD_DIR}/PureMac-${VERSION}.dmg"
ZIP_PATH="${BUILD_DIR}/PureMac.zip"
EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"

# Preflight
command -v xcodebuild >/dev/null || { echo "Error: xcodebuild not found"; exit 1; }
command -v create-dmg >/dev/null || { echo "Error: create-dmg not found. Install: brew install create-dmg"; exit 1; }

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Generate ExportOptions.plist from template
sed "s/REPLACE_WITH_YOUR_TEAM_ID/${TEAM_ID}/g" \
    "${PROJECT_DIR}/docs/ExportOptions.plist.template" > "${EXPORT_OPTIONS}"

# Step 1: Archive
echo "==> Archiving PureMac ${VERSION}..."
xcodebuild -project "${PROJECT_DIR}/PureMac.xcodeproj" \
    -scheme PureMac \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    MARKETING_VERSION="${VERSION}" \
    CURRENT_PROJECT_VERSION="${VERSION}" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_ENTITLEMENTS="${PROJECT_DIR}/PureMac/PureMac.Release.entitlements" \
    archive

# Step 2: Export
echo "==> Exporting signed app..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -exportPath "${EXPORT_PATH}"

# Step 3: Notarize
echo "==> Creating zip for notarization..."
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "==> Submitting for notarization (this may take a few minutes)..."
if [ -n "${APPLE_ID}" ] && [ -n "${APP_PASSWORD}" ]; then
    xcrun notarytool submit "${ZIP_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${TEAM_ID}" \
        --password "${APP_PASSWORD}" \
        --wait
else
    xcrun notarytool submit "${ZIP_PATH}" \
        --keychain-profile "${KEYCHAIN_PROFILE}" \
        --wait
fi

# Step 4: Staple
echo "==> Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"

# Step 5: Create DMG
echo "==> Creating DMG..."
DMG_STAGING="${BUILD_DIR}/dmg-staging"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/"

create-dmg \
    --volname "PureMac" \
    --volicon "${PROJECT_DIR}/PureMac/Assets.xcassets/AppIcon.appiconset/AppIcon.png" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "PureMac.app" 150 190 \
    --app-drop-link 450 190 \
    --hide-extension "PureMac.app" \
    "${DMG_PATH}" \
    "${DMG_STAGING}/" \
    || test $? -eq 2  # create-dmg returns 2 on "success with warnings"

# Step 6: Hash
SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

echo ""
echo "============================================"
echo "  Release build complete!"
echo "  DMG:     ${DMG_PATH}"
echo "  SHA-256: ${SHA256}"
echo "  Version: ${VERSION}"
echo "============================================"
echo ""
echo "Homebrew cask update:"
echo "  sha256 \"${SHA256}\""
echo "  url \"https://github.com/yakupbulbul/PureMac/releases/download/v${VERSION}/PureMac-${VERSION}.dmg\""
echo "  version \"${VERSION}\""
