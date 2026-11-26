#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SlowWave"
VERSION="1.0.0"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
BG_IMAGE="$ROOT_DIR/Resources/dmg-background.png"

if [[ "${SKIP_APP_BUILD:-0}" != "1" ]]; then
  "$ROOT_DIR/scripts/build-app.sh"
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Error: $APP_BUNDLE not found." >&2
  exit 1
fi

if [[ ! -f "$BG_IMAGE" ]]; then
  echo "Generating DMG background image..."
  swift "$ROOT_DIR/scripts/generate-dmg-bg.swift" "$BG_IMAGE"
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/slowwave-dmg.XXXXXX")"
RW_DMG="$(mktemp -u "${TMPDIR:-/tmp}/slowwave-rw.XXXXXX").dmg"
MOUNT_DIR=""

cleanup() {
  if [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]]; then
    hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGING_DIR" "$RW_DMG"
}
trap cleanup EXIT

echo "Staging DMG contents..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"
cp "$BG_IMAGE" "$STAGING_DIR/.background/background.png"

echo "Creating temporary writable DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  "$RW_DMG" >/dev/null

echo "Mounting writable DMG to configure Finder layout..."
MOUNT_DIR="/Volumes/$APP_NAME"
if [[ -d "$MOUNT_DIR" ]]; then
  hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
fi
hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" >/dev/null
sleep 1

chflags hidden "$MOUNT_DIR/.background" 2>/dev/null || true

osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 140, 840, 598}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set text size of theViewOptions to 13
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {175, 165}
        set position of item "Applications" of container window to {465, 165}
        try
            set position of item ".background" of container window to {1000, 1000}
        end try
        try
            set position of item ".fseventsd" of container window to {1000, 1100}
        end try
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNT_DIR=""

echo "Compressing final DMG at $DMG_PATH..."
rm -f "$DMG_PATH"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null

echo "Done! DMG created at: $DMG_PATH"
