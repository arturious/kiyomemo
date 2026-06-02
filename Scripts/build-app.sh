#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/Kiyomemo.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VERSION="${1:-0.1.0}"
VERSION="${VERSION#v}"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"
cp ".build/release/Kiyomemo" "$MACOS_DIR/Kiyomemo"
cp -R ".build/release/Sparkle.framework" "$FRAMEWORKS_DIR/Sparkle.framework"
cp ".build/release/KiyomemoHelper" "$RESOURCES_DIR/dev.kiyomemo.helper"
cp "Resources/dev.kiyomemo.helper.plist" "$RESOURCES_DIR/dev.kiyomemo.helper.plist"
cp "Resources/install-helper.sh" "$RESOURCES_DIR/install-helper.sh"
cp "Resources/KiyomemoIcon.png" "$RESOURCES_DIR/KiyomemoIcon.png"
cp "Resources/KiyomemoIcon.icns" "$RESOURCES_DIR/KiyomemoIcon.icns"
chmod 755 "$RESOURCES_DIR/dev.kiyomemo.helper" "$RESOURCES_DIR/install-helper.sh"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/Kiyomemo"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Kiyomemo</string>
    <key>CFBundleIdentifier</key>
    <string>dev.kiyomemo.app</string>
    <key>CFBundleIconFile</key>
    <string>KiyomemoIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Kiyomemo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://github.com/arturious/kiyomemo/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>7WktUpS6WfUPVqLIw/bGj4zS1kPNjdE/mOjNr6OF1Bk=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUAutomaticallyUpdate</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$RESOURCES_DIR/dev.kiyomemo.helper"
codesign --force --sign - "$FRAMEWORKS_DIR/Sparkle.framework"
codesign --force --sign - "$APP_DIR"
echo "Built $APP_DIR"
