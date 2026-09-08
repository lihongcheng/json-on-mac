#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="JSON Lens"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICON_SOURCE="$ROOT/.build/AppIcon-1024.png"
ICONSET="$ROOT/.build/AppIcon.iconset"

swift build --package-path "$ROOT" -c release
BIN_DIR="$(swift build --package-path "$ROOT" -c release --show-bin-path)"

rm -rf "$APP_DIR" "$ICONSET"
mkdir -p "$MACOS" "$RESOURCES" "$ICONSET"

cp "$BIN_DIR/JSONLens" "$MACOS/JSONLens"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

xcrun swift "$ROOT/scripts/generate-icon.swift" "$ICON_SOURCE"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"
do
  read -r size filename <<< "$spec"
  sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/$filename" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
plutil -lint "$CONTENTS/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
