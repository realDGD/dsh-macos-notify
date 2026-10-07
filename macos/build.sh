#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="${1:-$HOME/Applications/DSH Notify.app}"
DESKTOP_APP="${DSH_DESKTOP_APP:-/Applications/DeepSeek Harness.app}"
if [[ -e "$APP" ]]; then
  echo "Target exists. Build into a fresh staging path or run macos/install.sh to upgrade with backup." >&2
  exit 1
fi
xcrun --find swiftc >/dev/null
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$DESKTOP_APP/Contents/Resources/icon.icns" ]]; then
  cp "$DESKTOP_APP/Contents/Resources/icon.icns" "$APP/Contents/Resources/icon.icns"
else
  /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' "$APP/Contents/Info.plist"
fi
cp -R "$HERE/assets" "$APP/Contents/Resources/renderer"
xcrun swiftc -O -target "$(uname -m)-apple-macosx13.0" -o "$APP/Contents/MacOS/DSHNotify" "$HERE/main.swift" "$HERE/Interactions.swift" "$HERE/MarkdownContext.swift" "$HERE/NotificationPayload.swift" "$HERE/Diagnostics.swift" "$HERE/SessionMenuModel.swift" "$HERE/SessionMenuControl.swift" "$HERE/SessionMenuView.swift" "$HERE/SessionMenu.swift"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP (local ad-hoc signature; no official assets are distributed)"
