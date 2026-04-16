#!/bin/bash
set -euo pipefail

APP_NAME="WindowManager"
BUNDLE_ID="com.windowmanager"
BINARY_NAME="windowmanager"
VERSION="${1:-1.0.0}"
SKIP_SIGN="${SKIP_SIGN:-false}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/.build/release-bundle"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} ${VERSION}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "==> Compiling release binary..."
swift build -c release

echo "==> Assembling .app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

BIN_PATH=$(swift build -c release --show-bin-path)
cp "${BIN_PATH}/${BINARY_NAME}" \
   "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"

cp "${PROJECT_ROOT}/Resources/Info.plist" \
   "${APP_BUNDLE}/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"

echo "==> App bundle: ${APP_BUNDLE}"

if [ "${SKIP_SIGN}" != "true" ]; then
    : "${DEVELOPER_ID:?Set DEVELOPER_ID env var or pass SKIP_SIGN=true for unsigned build}"
    : "${NOTARIZE_PROFILE:?Set NOTARIZE_PROFILE env var or pass SKIP_SIGN=true for unsigned build}"

    echo "==> Code signing .app..."
    codesign --force --options runtime \
        --sign "${DEVELOPER_ID}" \
        --entitlements "${PROJECT_ROOT}/Resources/Entitlements.plist" \
        --timestamp \
        "${APP_BUNDLE}"

    codesign --verify --deep --strict "${APP_BUNDLE}"
fi

echo "==> Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${APP_BUNDLE}" \
    -ov -format UDZO \
    "${DMG_PATH}"

if [ "${SKIP_SIGN}" != "true" ]; then
    codesign --force --sign "${DEVELOPER_ID}" --timestamp "${DMG_PATH}"

    echo "==> Submitting for notarization..."
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARIZE_PROFILE}" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "${DMG_PATH}"
fi

DMG_SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

echo "==> Done: ${DMG_PATH}"
echo "==> SHA256: ${DMG_SHA256}"
echo ""
echo "Homebrew cask values:"
echo "  version \"${VERSION}\""
echo "  sha256 \"${DMG_SHA256}\""
