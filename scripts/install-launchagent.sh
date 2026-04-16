#!/bin/bash
set -euo pipefail

PLIST_LABEL="com.windowmanager"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

usage() {
    echo "Usage: $0 [install [/path/to/WindowManager.app] | uninstall]"
    echo "  install   Install and start the LaunchAgent (default app: /Applications/WindowManager.app)"
    echo "  uninstall Stop and remove the LaunchAgent"
    exit 1
}

case "${1:-install}" in
    install)
        APP_PATH="${2:-/Applications/WindowManager.app}"
        BINARY="${APP_PATH}/Contents/MacOS/windowmanager"

        if [ ! -f "${BINARY}" ]; then
            echo "Error: binary not found at ${BINARY}"
            echo "Make sure the app is installed at ${APP_PATH}"
            exit 1
        fi

        # Stop existing agent if running
        launchctl bootout "${GUI_DOMAIN}/${PLIST_LABEL}" 2>/dev/null || true

        # Write plist with correct binary path
        cat > "${PLIST_DEST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BINARY}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST

        launchctl bootstrap "${GUI_DOMAIN}" "${PLIST_DEST}"
        echo "Installed and started ${PLIST_LABEL}"
        echo "  Binary: ${BINARY}"
        echo "  Plist:  ${PLIST_DEST}"
        ;;

    uninstall)
        launchctl bootout "${GUI_DOMAIN}/${PLIST_LABEL}" 2>/dev/null || true
        rm -f "${PLIST_DEST}"
        echo "Uninstalled ${PLIST_LABEL}"
        ;;

    *)
        usage
        ;;
esac
