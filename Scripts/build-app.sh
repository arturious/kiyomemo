#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/MemoryBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/release/MemoryBar" "$MACOS_DIR/MemoryBar"
cp ".build/release/MemoryBarHelper" "$RESOURCES_DIR/dev.memorybar.helper"
cp "Resources/dev.memorybar.helper.plist" "$RESOURCES_DIR/dev.memorybar.helper.plist"
cp "Resources/install-helper.sh" "$RESOURCES_DIR/install-helper.sh"
cp "Resources/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
chmod 755 "$RESOURCES_DIR/dev.memorybar.helper" "$RESOURCES_DIR/install-helper.sh"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MemoryBar</string>
    <key>CFBundleIdentifier</key>
    <string>dev.memorybar.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MemoryBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$RESOURCES_DIR/dev.memorybar.helper"
codesign --force --sign - "$APP_DIR"
echo "Built $APP_DIR"
