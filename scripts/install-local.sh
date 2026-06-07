#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_DIR="${PROJECT_ROOT}/signing"
CRT="${SIGNING_DIR}/signing.crt"
APP_NAME="WindowManager"
BINARY_NAME="windowmanager"
DEST="/Applications/${APP_NAME}.app"
VERSION="${VERSION:-0.0.0-dev}"

if [ ! -f "${CRT}" ]; then
    cat >&2 <<EOF
ERROR: ${CRT} not found.

Obtain signing materials from the project maintainer, place them in
${SIGNING_DIR}/, then run scripts/setup-signing.sh.
EOF
    exit 1
fi

IDENTITY=$(openssl x509 -in "${CRT}" -noout -subject -nameopt RFC2253 \
    | sed -n 's/.*CN=\([^,]*\).*/\1/p')

if ! security find-identity -v -p codesigning \
    | grep -F "\"${IDENTITY}\"" >/dev/null; then
    cat >&2 <<EOF
ERROR: signing identity "${IDENTITY}" not installed in keychain.

Run scripts/setup-signing.sh first, then re-run \`make install\`.
EOF
    exit 1
fi

export SELF_SIGN_IDENTITY="${IDENTITY}"
unset SKIP_SIGN

"${PROJECT_ROOT}/scripts/build-release.sh" "${VERSION}"

NEW_APP="${PROJECT_ROOT}/.build/release-bundle/${APP_NAME}.app"

SIGN_INFO=$(codesign -dvv "${NEW_APP}" 2>&1) || true
if [[ "${SIGN_INFO}" != *"Authority=${IDENTITY}"* ]]; then
    echo "ERROR: freshly-built bundle is not signed with '${IDENTITY}'. Refusing to install." >&2
    printf '%s\n' "${SIGN_INFO}" >&2
    exit 1
fi

if pgrep -f "${DEST}/Contents/MacOS/${BINARY_NAME}" >/dev/null; then
    echo "==> Stopping running ${APP_NAME}..."
    osascript -e "tell application \"${DEST}\" to quit" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
        pgrep -f "${DEST}/Contents/MacOS/${BINARY_NAME}" >/dev/null || break
        sleep 1
    done
    pkill -f "${DEST}/Contents/MacOS/${BINARY_NAME}" 2>/dev/null || true
fi

echo "==> Installing to ${DEST}..."
if [ -d "${DEST}" ]; then
    rm -rf "${DEST}"
fi
ditto "${NEW_APP}" "${DEST}"

echo "==> Launching ${APP_NAME}..."
open "${DEST}"

echo "==> Installed. If Accessibility was previously granted to this identity, it remains in effect."
echo "==> To start automatically at login: make autostart"
