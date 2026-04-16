#!/bin/bash
set -euo pipefail

# Updates the windowmanager cask in a local clone of the homebrew-apps tap.
#
# Usage: ./scripts/publish-cask.sh <version> [path-to-tap-repo]
#
# Env vars:
#   TAP_REPO       Path to local clone of homebrew-apps (default: ../homebrew-apps)
#
# After running: cd into the tap repo, review the diff, then git commit + push.

VERSION="${1:?Usage: $0 <version> [path-to-tap-repo]}"
TAP_REPO="${2:-${TAP_REPO:-../homebrew-apps}}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${PROJECT_ROOT}/.build/release-bundle/WindowManager-${VERSION}.dmg"
TEMPLATE="${PROJECT_ROOT}/homebrew/windowmanager.rb"

if [ ! -f "${DMG_PATH}" ]; then
    echo "Error: DMG not found at ${DMG_PATH}"
    echo "Run ./scripts/build-release.sh ${VERSION} first"
    exit 1
fi

# Resolve tap repo to absolute path
if [[ "${TAP_REPO}" != /* ]]; then
    TAP_REPO="${PROJECT_ROOT}/${TAP_REPO}"
fi

if [ ! -d "${TAP_REPO}" ]; then
    echo "Error: tap repo not found at ${TAP_REPO}"
    echo "Clone it first: git clone https://github.com/fhntvv/homebrew-apps.git ${TAP_REPO}"
    exit 1
fi

SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')
DEST="${TAP_REPO}/Casks/windowmanager.rb"

mkdir -p "${TAP_REPO}/Casks"

sed -e "s/@VERSION@/${VERSION}/g" \
    -e "s/@SHA256@/${SHA256}/g" \
    "${TEMPLATE}" > "${DEST}"

echo "==> Updated ${DEST}"
echo "    version: ${VERSION}"
echo "    sha256:  ${SHA256}"
echo ""
echo "Next: cd ${TAP_REPO} && git diff Casks/windowmanager.rb"
echo "Then: git commit -am 'windowmanager ${VERSION}' && git push"
