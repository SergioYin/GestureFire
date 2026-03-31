#!/bin/bash
set -euo pipefail

# Build GestureFire.app bundle from SPM executable
# Usage: ./scripts/build-app.sh [release|debug]

CONFIG="${1:-release}"
PRODUCT_NAME="GestureFireApp"
APP_NAME="GestureFire.app"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}"

echo "==> Building GestureFire (${CONFIG})..."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
if [ "$CONFIG" = "release" ]; then
    swift build -c release
    BUILD_DIR=".build/release"
else
    swift build
    BUILD_DIR=".build/debug"
fi

echo "==> Assembling ${APP_NAME}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

# Copy executable
cp "${BUILD_DIR}/${PRODUCT_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy Info.plist
cp "Sources/GestureFireApp/Info.plist" "${APP_BUNDLE}/Contents/"

# Copy the OpenMultitouchSupport XCFramework binary
FRAMEWORK_PATH=$(find .build -name "OpenMultitouchSupportXCF.framework" -path "*/macos-*" | head -1)
if [ -n "$FRAMEWORK_PATH" ]; then
    cp -R "$FRAMEWORK_PATH" "${APP_BUNDLE}/Contents/Frameworks/"
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
        "${APP_BUNDLE}/Contents/MacOS/${PRODUCT_NAME}" 2>/dev/null || true
fi

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Ad-hoc code sign
echo "==> Code signing (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Built: ${APP_BUNDLE}"
echo "    Size: $(du -sh "${APP_BUNDLE}" | cut -f1)"
echo ""
echo "To install: cp -r ${APP_BUNDLE} /Applications/"
echo "To run:     open ${APP_BUNDLE}"
