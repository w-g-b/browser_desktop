#!/bin/bash
# Browser Desktop session startup script
# This script launches the kiosk environment

set -e

# Configuration
PORTAL_URL="file:///opt/browser-desktop/portal/index.html"
CHROME_DATA_DIR="$HOME/.chrome-kiosk"
SESSION_CONF="/etc/browser-desktop/session.conf"

# Load session configuration
SESSION_MODE="disconnect_keep"
CLEANUP_ON_EXIT="true"

if [[ -f "$SESSION_CONF" ]]; then
    SESSION_MODE=$(grep "^mode=" "$SESSION_CONF" | cut -d'=' -f2 || echo "disconnect_keep")
    CLEANUP_ON_EXIT=$(grep "^cleanup_on_exit=" "$SESSION_CONF" | cut -d'=' -f2 || echo "true")
fi

# Set environment variables
export DISPLAY="${DISPLAY:-:10}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE="x11"

# Ensure runtime directory exists
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Start dbus session if not running
if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Function to clean up Chrome data
cleanup_chrome_data() {
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        rm -rf "$CHROME_DATA_DIR"
    fi
}

# Trap to clean up on exit
trap cleanup_chrome_data EXIT

# Determine Chrome executable
CHROME_BIN=""
if command -v google-chrome-stable >/dev/null 2>&1; then
    CHROME_BIN="google-chrome-stable"
elif command -v chromium >/dev/null 2>&1; then
    CHROME_BIN="chromium"
elif command -v chromium-browser >/dev/null 2>&1; then
    CHROME_BIN="chromium-browser"
else
    echo "ERROR: No Chrome/Chromium browser found" >&2
    exit 1
fi

# Start Openbox window manager in background
openbox-session &
OPENBOX_PID=$!

# Wait for Openbox to initialize
sleep 1

# Start Chrome in kiosk mode
exec "$CHROME_BIN" \
    --kiosk \
    --no-first-run \
    --no-default-browser-check \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --disable-features=TranslateUI \
    --disable-component-update \
    --disable-background-networking \
    --disable-sync \
    --disable-popup-blocking \
    --disable-translate \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --user-data-dir="$CHROME_DATA_DIR" \
    --disable-gpu \
    --no-sandbox \
    "$PORTAL_URL"
