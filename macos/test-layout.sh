#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/compiler-flags.sh"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dsh-native-layout.XXXXXX")"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeMenuIconTests" "$HERE/../tests/native-menu-icon.swift" "$HERE/MenuIcon.swift"
"$BUILD_DIR/NativeMenuIconTests"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeDesktopLifecycleTests" "$HERE/../tests/native-desktop-lifecycle.swift" "$HERE/DesktopLifecycle.swift"
"$BUILD_DIR/NativeDesktopLifecycleTests"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeMenuControlTests" "$HERE/../tests/native-menu-control.swift" "$HERE/UILocalization.swift" "$HERE/UIStrings.swift" "$HERE/SessionMenuControl.swift"
"$BUILD_DIR/NativeMenuControlTests"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeSessionMenuTests" "$HERE/../tests/native-session-menu.swift" "$HERE/SessionMenuModel.swift" "$HERE/MenuIcon.swift" "$HERE/MenuResizeAnimation.swift" "$HERE/UILocalization.swift" "$HERE/UIStrings.swift" "$HERE/SessionMenuControl.swift" "$HERE/MenuSessionList.swift" "$HERE/SessionMenuView.swift" "$HERE/SessionMenu.swift"
"$BUILD_DIR/NativeSessionMenuTests"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeMenuInteractionTests" "$HERE/../tests/native-menu-interactions.swift" "$HERE/UILocalization.swift" "$HERE/UIStrings.swift" "$HERE/Interactions.swift" "$HERE/MarkdownContext.swift" "$HERE/SessionMenuModel.swift" "$HERE/MenuIcon.swift" "$HERE/MenuResizeAnimation.swift" "$HERE/SessionMenuControl.swift" "$HERE/MenuSessionList.swift" "$HERE/SessionMenuView.swift" "$HERE/SessionMenu.swift"
"$BUILD_DIR/NativeMenuInteractionTests"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeNotificationDiagnosticsTests" "$HERE/../tests/native-notification-diagnostics.swift" "$HERE/UILocalization.swift" "$HERE/UIStrings.swift" "$HERE/NotificationPayload.swift" "$HERE/Diagnostics.swift"
"$BUILD_DIR/NativeNotificationDiagnosticsTests"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeQuestionLayoutTests" "$HERE/../tests/native-question-layout.swift" "$HERE/UILocalization.swift" "$HERE/UIStrings.swift" "$HERE/Interactions.swift" "$HERE/MarkdownContext.swift" "$HERE/SessionMenuModel.swift" "$HERE/MenuIcon.swift" "$HERE/MenuResizeAnimation.swift" "$HERE/SessionMenuControl.swift" "$HERE/MenuSessionList.swift" "$HERE/SessionMenuView.swift" "$HERE/SessionMenu.swift"
"$BUILD_DIR/NativeQuestionLayoutTests"
echo "Native layout tests passed; test executable retained at $BUILD_DIR"
xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeMarkdownContextTests" "$HERE/../tests/native-markdown-context.swift" "$HERE/UILocalization.swift" "$HERE/UIStrings.swift" "$HERE/Interactions.swift" "$HERE/MarkdownContext.swift" "$HERE/SessionMenuModel.swift" "$HERE/MenuIcon.swift" "$HERE/MenuResizeAnimation.swift"
CONTEXT_APP="$BUILD_DIR/Markdown Context Tests.app"
mkdir -p "$CONTEXT_APP/Contents/MacOS" "$CONTEXT_APP/Contents/Resources"
cp "$BUILD_DIR/NativeMarkdownContextTests" "$CONTEXT_APP/Contents/MacOS/NativeMarkdownContextTests"
cp -R "$HERE/assets" "$CONTEXT_APP/Contents/Resources/renderer"
cat > "$CONTEXT_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>NativeMarkdownContextTests</string><key>CFBundleIdentifier</key><string>local.dshnotify.markdown-tests</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
"$CONTEXT_APP/Contents/MacOS/NativeMarkdownContextTests"

xcrun swiftc "${DSH_NOTIFY_SWIFT_FLAGS[@]}" -o "$BUILD_DIR/NativeLocalizationTests" "$HERE/../tests/native-localization.swift" "$HERE/UILocalization.swift" "$HERE/UIStrings.swift" "$HERE/Interactions.swift" "$HERE/MarkdownContext.swift" "$HERE/SessionMenuModel.swift" "$HERE/MenuIcon.swift" "$HERE/MenuResizeAnimation.swift"
"$BUILD_DIR/NativeLocalizationTests"

# Deliberately omit the modern SDK flag to verify the SDK-13 timer path.
xcrun swiftc -target "$(uname -m)-apple-macosx13.0" -o "$BUILD_DIR/NativeSDKFallbackTests" "$HERE/../tests/native-sdk-fallback.swift" "$HERE/MenuResizeAnimation.swift"
"$BUILD_DIR/NativeSDKFallbackTests"
