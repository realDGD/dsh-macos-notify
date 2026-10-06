#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dsh-native-layout.XXXXXX")"
swiftc -o "$BUILD_DIR/NativeQuestionLayoutTests" "$HERE/../tests/native-question-layout.swift" "$HERE/Interactions.swift" "$HERE/MarkdownContext.swift"
"$BUILD_DIR/NativeQuestionLayoutTests"
echo "Native layout tests passed; test executable retained at $BUILD_DIR"
swiftc -o "$BUILD_DIR/NativeMarkdownContextTests" "$HERE/../tests/native-markdown-context.swift" "$HERE/Interactions.swift" "$HERE/MarkdownContext.swift"
"$BUILD_DIR/NativeMarkdownContextTests"
