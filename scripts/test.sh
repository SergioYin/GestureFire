#!/bin/bash
# Run all tests using Xcode's toolchain.
#
# Swift Testing (`import Testing`) requires Xcode's bundled framework.
# The CLI-only toolchain (/Library/Developer/CommandLineTools) does not
# include it, causing "no such module 'Testing'" errors.
#
# This script temporarily switches to Xcode's developer directory,
# runs `swift test`, then restores the original setting.
#
# Usage:
#   ./scripts/test.sh          # run all tests
#   ./scripts/test.sh --filter GestureFireRecognitionTests  # filter

set -euo pipefail

XCODE_PATH="/Applications/Xcode.app/Contents/Developer"
ORIGINAL_PATH="$(xcode-select -p 2>/dev/null || true)"

if [ ! -d "$XCODE_PATH" ]; then
    echo "Error: Xcode not found at $XCODE_PATH"
    echo "Install Xcode from the App Store, or adjust XCODE_PATH."
    exit 1
fi

cleanup() {
    if [ -n "$ORIGINAL_PATH" ] && [ "$ORIGINAL_PATH" != "$XCODE_PATH" ]; then
        sudo xcode-select -s "$ORIGINAL_PATH" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [ "$(xcode-select -p)" != "$XCODE_PATH" ]; then
    echo "Switching to Xcode toolchain..."
    sudo xcode-select -s "$XCODE_PATH"
fi

echo "Running: swift test $*"
swift test "$@"
