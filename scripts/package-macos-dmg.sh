#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/TimeTracker.xcodeproj"
SCHEME="TimeTracker"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
VOLUME_NAME="TimeTracker Installer"
OUTPUT_DMG="$DIST_DIR/TimeTracker-macOS.dmg"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

rm -rf "$DERIVED_DATA_PATH"

echo "Building macOS app ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >/tmp/timetracker-build.log

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/TimeTracker.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded, but app was not found at: $APP_PATH"
  echo "xcodebuild log is at /tmp/timetracker-build.log"
  exit 1
fi

STAGING_DIR="$(mktemp -d /tmp/timetracker-dmg.XXXXXX)"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$DIST_DIR" "$STAGING_DIR/installer"
cp -R "$APP_PATH" "$STAGING_DIR/installer/"
ln -s /Applications "$STAGING_DIR/installer/Applications"

rm -f "$OUTPUT_DMG"
echo "Creating DMG installer..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR/installer" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG" >/tmp/timetracker-dmg.log

echo "DMG created: $OUTPUT_DMG"
echo "Users can open it and drag TimeTracker.app to Applications."
