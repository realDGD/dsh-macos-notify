#!/usr/bin/env bash
# Sourced by build and native-test scripts. Bash 3.2 / Swift 5.7 compatible.
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple Command Line Tools are required. Run xcode-select --install, complete installation, then retry the plugin installation." >&2
  exit 1
fi
DSH_NOTIFY_SDK_VERSION="$(xcrun --show-sdk-version)"
if [[ ! "$DSH_NOTIFY_SDK_VERSION" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
  echo "Unable to identify the selected macOS SDK. Check xcode-select -p and xcrun --show-sdk-version." >&2
  exit 1
fi
DSH_NOTIFY_SWIFT_FLAGS=(-target "$(uname -m)-apple-macosx13.0")
if (( ${DSH_NOTIFY_SDK_VERSION%%.*} >= 14 )); then
  DSH_NOTIFY_SWIFT_FLAGS+=(-D DSH_HAS_DISPLAY_LINK)
fi
