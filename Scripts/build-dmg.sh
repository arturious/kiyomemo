#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/Kiyomemo.app"
STAGING_DIR="$OUTPUT_DIR/dmg"
VERSION="${1:-dev}"
DMG_PATH="$OUTPUT_DIR/Kiyomemo-$VERSION.dmg"

cd "$ROOT_DIR"
./Scripts/build-app.sh "$VERSION"

rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/Kiyomemo.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Kiyomemo" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "Built $DMG_PATH"
