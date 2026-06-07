#!/bin/bash
set -euo pipefail

APP_NAME="WindowManager"
BUNDLE_ID="com.windowmanager"
BINARY_NAME="windowmanager"
VERSION="${1:-1.0.0}"
SKIP_SIGN="${SKIP_SIGN:-false}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${SKIP_SIGN}" = "true" ]; then
    BUILD_DIR="${PROJECT_ROOT}/.build/release-bundle-unsigned"
    BUNDLE_NAME="${APP_NAME}-UNSIGNED.app"
    DMG_NAME="${APP_NAME}-${VERSION}-UNSIGNED.dmg"
else
    BUILD_DIR="${PROJECT_ROOT}/.build/release-bundle"
    BUNDLE_NAME="${APP_NAME}.app"
    DMG_NAME="${APP_NAME}-${VERSION}.dmg"
fi

APP_BUNDLE="${BUILD_DIR}/${BUNDLE_NAME}"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

if [ "${SKIP_SIGN}" = "true" ]; then
    cat >&2 <<'EOF'

################################################################################
# SKIP_SIGN=true -- producing an UNSIGNED development bundle.
#
# The output is named WindowManager-UNSIGNED.app and lives in
# .build/release-bundle-unsigned/ so it cannot be confused with a release build.
#
# DO NOT install this bundle to /Applications. It will run, but macOS TCC
# (Accessibility, Input Monitoring, etc.) cannot keep grants pinned to an
# unsigned binary across upgrades -- the grant will silently break the next
# time a properly signed build replaces it, and window operations will fail
# with no visible error.
#
# To produce an installable bundle, run scripts/setup-signing.sh once to
# install the local signing identity, then re-run this script without
# SKIP_SIGN. Or use `make install` for the full local install flow.
################################################################################

EOF
fi

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

if [ "${SKIP_SIGN}" = "true" ]; then
    echo "==> Skipping code signing (SKIP_SIGN=true)"
elif [ -n "${SELF_SIGN_IDENTITY:-}" ]; then
    echo "==> Self-signing .app with ${SELF_SIGN_IDENTITY}..."

    CERT_SHA1=$(security find-certificate -c "${SELF_SIGN_IDENTITY}" -p \
        | openssl x509 -outform der | shasum | awk '{print $1}')
    if [ -z "${CERT_SHA1}" ]; then
        echo "ERROR: cert '${SELF_SIGN_IDENTITY}' not found in keychain" >&2
        exit 1
    fi

    REQ_FILE=$(mktemp)
    cat > "${REQ_FILE}" <<EOF
designated => identifier "${BUNDLE_ID}" and certificate leaf = H"${CERT_SHA1}"
EOF

    codesign --force --options runtime \
        --sign "${SELF_SIGN_IDENTITY}" \
        --identifier "${BUNDLE_ID}" \
        --requirements "${REQ_FILE}" \
        "${APP_BUNDLE}"

    rm "${REQ_FILE}"
    codesign --verify --strict "${APP_BUNDLE}"

    echo "==> Designated requirement:"
    codesign -d -r- "${APP_BUNDLE}" 2>&1 | tail -1
elif [ -n "${DEVELOPER_ID:-}" ]; then
    : "${NOTARIZE_PROFILE:?Set NOTARIZE_PROFILE env var when using DEVELOPER_ID}"

    echo "==> Code signing .app with Developer ID..."
    codesign --force --options runtime \
        --sign "${DEVELOPER_ID}" \
        --entitlements "${PROJECT_ROOT}/Resources/Entitlements.plist" \
        --timestamp \
        "${APP_BUNDLE}"

    codesign --verify --deep --strict "${APP_BUNDLE}"
else
    cat >&2 <<EOF
ERROR: no code signing identity available.

Pick one:
  - Run scripts/setup-signing.sh once to install the local self-signed identity,
    then re-run this script (recommended for local installs).
  - Export SELF_SIGN_IDENTITY="<keychain identity name>" if you already have a
    different identity in your keychain.
  - Export DEVELOPER_ID="<Apple Developer ID>" plus NOTARIZE_PROFILE to build
    a notarized release.
  - Export SKIP_SIGN=true to produce a development-only unsigned bundle
    (cannot be installed to /Applications without breaking TCC -- see
    scripts/build-release.sh warning).
EOF
    exit 1
fi

echo "==> Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${APP_BUNDLE}" \
    -ov -format UDZO \
    "${DMG_PATH}"

if [ "${SKIP_SIGN}" != "true" ] && [ -n "${DEVELOPER_ID:-}" ] && [ -z "${SELF_SIGN_IDENTITY:-}" ]; then
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

if [ "${SKIP_SIGN}" = "true" ]; then
    cat >&2 <<'EOF'

################################################################################
# Reminder: this is an UNSIGNED build for development only.
# Do NOT copy it to /Applications -- it will silently break the TCC grant
# that any future signed build relies on. Use `make install` for the proper
# local install flow.
################################################################################

EOF
fi
