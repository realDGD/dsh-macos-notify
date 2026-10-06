#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dsh-native-layout.XXXXXX")"
swiftc -o "$BUILD_DIR/NativeQuestionLayoutTests" "$HERE/../tests/native-question-layout.swift" "$HERE/Interactions.swift"
"$BUILD_DIR/NativeQuestionLayoutTests"
echo "Native layout tests passed; test executable retained at $BUILD_DIR"
