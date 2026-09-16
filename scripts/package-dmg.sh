#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="JSON Lens"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ARCH="$(uname -m)"
APP_PATH="$ROOT/dist/$APP_NAME.app"
DMG_PATH="$ROOT/dist/JSON-Lens-$VERSION-$ARCH.dmg"
STAGING="$ROOT/.build/dmg-root"
MOUNT_POINT="$ROOT/.build/dmg-mount"
MOUNTED=0

cleanup() {
  if [[ "$MOUNTED" -eq 1 ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  rm -rf "$STAGING" "$MOUNT_POINT"
}
trap cleanup EXIT

"$ROOT/scripts/build-app.sh" >/dev/null

rm -rf "$STAGING" "$MOUNT_POINT"
mkdir -p "$STAGING" "$MOUNT_POINT"

ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG_PATH" >/dev/null

hdiutil verify "$DMG_PATH" >/dev/null
hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "$MOUNT_POINT" \
  "$DMG_PATH" >/dev/null
MOUNTED=1

test -d "$MOUNT_POINT/$APP_NAME.app"
test -L "$MOUNT_POINT/Applications"
test "$(readlink "$MOUNT_POINT/Applications")" = "/Applications"
codesign --verify --deep --strict "$MOUNT_POINT/$APP_NAME.app"

hdiutil detach "$MOUNT_POINT" -quiet
MOUNTED=0

shasum -a 256 "$DMG_PATH"
echo "$DMG_PATH"
