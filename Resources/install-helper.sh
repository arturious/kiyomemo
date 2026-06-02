#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER_SOURCE="$SCRIPT_DIR/dev.kiyomemo.helper"
PLIST_SOURCE="$SCRIPT_DIR/dev.kiyomemo.helper.plist"
HELPER_DEST="/Library/PrivilegedHelperTools/dev.kiyomemo.helper"
PLIST_DEST="/Library/LaunchDaemons/dev.kiyomemo.helper.plist"

launchctl bootout system/dev.kiyomemo.helper 2>/dev/null || true
install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools
install -o root -g wheel -m 755 "$HELPER_SOURCE" "$HELPER_DEST"
install -o root -g wheel -m 644 "$PLIST_SOURCE" "$PLIST_DEST"
launchctl bootstrap system "$PLIST_DEST"
