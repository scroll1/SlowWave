#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SlowWave"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.png"

echo "Building $APP_NAME (release)..."
cd "$ROOT_DIR"
# shellcheck disable=SC2086
swift build -c release ${SWIFT_BUILD_FLAGS:-}

# shellcheck disable=SC2086
BIN_PATH="$(swift build -c release ${SWIFT_BUILD_FLAGS:-} --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Error: Built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -f "$ICON_SOURCE" ]]; then
  echo "Generating AppIcon.icns from $ICON_SOURCE..."
  ICONSET_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/iconset.XXXXXX")"
  ICONSET_DIR="$ICONSET_PARENT/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"
  sips -s format png -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
  sips -s format png -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
  sips -s format png -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
  sips -s format png -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
  sips -s format png -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
  sips -s format png -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -s format png -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
  sips -s format png -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -s format png -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
  sips -s format png -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  if ! iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null; then
    python3 - "$ICONSET_DIR" "$RESOURCES_DIR/AppIcon.icns" << 'PYEOF'
import os, struct, sys

iconset_dir, out_path = sys.argv[1], sys.argv[2]
entries = [
    (b"icp4", "icon_16x16.png"),
    (b"ic11", "icon_16x16@2x.png"),
    (b"icp5", "icon_32x32.png"),
    (b"ic12", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic13", "icon_128x128@2x.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic14", "icon_256x256@2x.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
]

chunks = bytearray()
for ostype, filename in entries:
    with open(os.path.join(iconset_dir, filename), "rb") as f:
        data = f.read()
    chunks += ostype + struct.pack(">I", 8 + len(data)) + data

with open(out_path, "wb") as f:
    f.write(b"icns" + struct.pack(">I", 8 + len(chunks)) + chunks)
PYEOF
  fi
  rm -rf "$ICONSET_PARENT"
fi

cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SlowWave</string>
    <key>CFBundleDisplayName</key>
    <string>SlowWave</string>
    <key>CFBundleIdentifier</key>
    <string>com.brennanlabs.SlowWave</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 BrennanLabs. MIT License.</string>
    <key>CFBundleExecutable</key>
    <string>SlowWave</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Audio File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.audio</string>
                <string>public.mp3</string>
                <string>public.mpeg-4-audio</string>
                <string>com.microsoft.waveform-audio</string>
                <string>public.aiff-audio</string>
                <string>org.xiph.flac</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "Ad-hoc signing $APP_BUNDLE..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Done! App bundle created at: $APP_BUNDLE"
