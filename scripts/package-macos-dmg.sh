#!/usr/bin/env bash
# Builds dist/TimeTracker.dmg for downloading: TimeTracker.app next to a shortcut to Applications.
# Also builds dist/TimeTracker.zip, the app on its own, which TimeTracker's updater installs, and
# signs it into dist/TimeTracker.zip.sig with the update key in your Keychain (macOS asks you to
# allow that). Attach all three to a release.
# Usage: scripts/package-macos-dmg.sh
#        UNSIGNED=1 scripts/package-macos-dmg.sh     no signature, for builds that won't be released
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_PATH="$ROOT_DIR/TimeTracker.xcodeproj"
SCHEME="TimeTracker"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
BUILD_LOG="$ROOT_DIR/build/xcodebuild.log"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

# The Xcode project is generated from project.yml, so it always matches what's committed.
if ! command -v xcodegen >/dev/null; then
  echo "XcodeGen is needed to generate the Xcode project: brew install xcodegen"
  exit 1
fi
xcodegen generate --quiet --spec "$ROOT_DIR/project.yml" --project "$ROOT_DIR"

rm -rf "$DERIVED_DATA_PATH"
mkdir -p "$ROOT_DIR/build" "$DIST_DIR"

echo "Building macOS app ($CONFIGURATION)..."
if ! xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >"$BUILD_LOG" 2>&1; then
  echo "Build failed; see $BUILD_LOG"
  exit 1
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/TimeTracker.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded, but app was not found at: $APP_PATH"
  exit 1
fi
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/TimeTracker"
# Only owner-writable files, and no extended attributes, quarantine or ACLs.
ditto --norsrc --noextattr --noqtn --noacl "$APP_PATH" "$STAGE/TimeTracker/TimeTracker.app"
chmod -R go-w "$STAGE/TimeTracker/TimeTracker.app"
codesign --verify --strict "$STAGE/TimeTracker/TimeTracker.app"

# The disk image opens as a styled window (scripts/dmg/settings.py): dmgbuild writes Finder's
# layout without scripting Finder, so building it asks for no permissions. It lives in a local
# virtualenv; without it the image is a plain window.
DMGBUILD="$ROOT_DIR/build/dmg-venv/bin/dmgbuild"
if [[ ! -x "$DMGBUILD" ]]; then
  python3 -m venv "$ROOT_DIR/build/dmg-venv" && \
    "$ROOT_DIR/build/dmg-venv/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==1.6.5" || true
fi

rm -f "$DIST_DIR/TimeTracker.dmg"
if [[ -x "$DMGBUILD" ]]; then
  "$DMGBUILD" -s scripts/dmg/settings.py -D app="$STAGE/TimeTracker/TimeTracker.app" \
    -D background="$ROOT_DIR/scripts/dmg/background.tiff" \
    "TimeTracker" "$DIST_DIR/TimeTracker.dmg" >"$ROOT_DIR/build/dmgbuild.log" 2>&1
else
  echo "dmgbuild isn't available, so the disk image gets a plain window."
  ln -s /Applications "$STAGE/TimeTracker/Applications"
  hdiutil create -volname "TimeTracker" -srcfolder "$STAGE/TimeTracker" -format UDZO -quiet "$DIST_DIR/TimeTracker.dmg"
fi

# Check the copy people will install, since the image tools copy files their own way.
MOUNT="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DIST_DIR/TimeTracker.dmg" -quiet
if ! codesign --verify --strict "$MOUNT/TimeTracker.app"; then
  hdiutil detach "$MOUNT" -quiet
  echo "The app inside dist/TimeTracker.dmg fails its signature check." >&2
  exit 1
fi
hdiutil detach "$MOUNT" -quiet
echo "Built dist/TimeTracker.dmg"

rm -f "$DIST_DIR/TimeTracker.zip"
ditto -c -k --norsrc --keepParent "$STAGE/TimeTracker/TimeTracker.app" "$DIST_DIR/TimeTracker.zip"
echo "Built dist/TimeTracker.zip"

# TimeTracker's updater installs nothing without this signature.
rm -f "$DIST_DIR/TimeTracker.zip.sig"
if [[ "${UNSIGNED:-0}" != 1 ]]; then
  swiftc -O -suppress-warnings scripts/sign-update.swift -o build/sign-update
  build/sign-update "$DIST_DIR/TimeTracker.zip" > "$DIST_DIR/TimeTracker.zip.sig.tmp"
  mv "$DIST_DIR/TimeTracker.zip.sig.tmp" "$DIST_DIR/TimeTracker.zip.sig"
  echo "Signed dist/TimeTracker.zip"
fi

echo "TimeTracker $VERSION is ready in dist/."
