#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_DIR="${PROJECT_ROOT}/signing"
CRT="${SIGNING_DIR}/signing.crt"
P12="${SIGNING_DIR}/signing.p12"

if [ ! -f "${CRT}" ] || [ ! -f "${P12}" ]; then
    cat >&2 <<EOF
ERROR: signing materials not found.

Expected:
  ${CRT}
  ${P12}

These files are not checked in. Obtain them from the project maintainer.
EOF
    exit 1
fi

IDENTITY=$(openssl x509 -in "${CRT}" -noout -subject -nameopt RFC2253 \
    | sed -n 's/.*CN=\([^,]*\).*/\1/p')

if [ -z "${IDENTITY}" ]; then
    echo "ERROR: could not extract CN from ${CRT}" >&2
    exit 1
fi

echo "==> Identity: ${IDENTITY}"

if security find-identity -v -p codesigning \
    | grep -F "\"${IDENTITY}\"" >/dev/null; then
    echo "==> Already installed -- nothing to do."
    exit 0
fi

PASS="${CODESIGN_P12_PASSWORD:-}"
if [ -z "${PASS}" ]; then
    read -rsp "Enter password for ${P12}: " PASS
    echo
fi

KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

echo "==> Importing into login keychain..."
security import "${P12}" \
    -k "${KEYCHAIN}" \
    -P "${PASS}" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

if security find-identity -v -p codesigning \
    | grep -F "\"${IDENTITY}\"" >/dev/null; then
    cat <<EOF
==> Identity installed.

Note: on first \`codesign\` use you may see a one-time keychain password
prompt. Click "Always Allow" to silence future prompts.

Next: run \`make install\` to build and install WindowManager locally.
EOF
else
    echo "ERROR: import succeeded but identity not visible to codesign." >&2
    exit 1
fi
