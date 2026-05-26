#!/bin/bash
# Browser Desktop session startup script
# This script launches the kiosk environment

# DO NOT use set -e - we want the session to stay alive even if individual commands fail

# Configuration
PORTAL_URL="file:///opt/browser-desktop/portal/index.html"
CHROME_DATA_DIR="$HOME/.chrome-kiosk"
SESSION_CONF="/etc/browser-desktop/session.conf"
LOG_FILE="$HOME/.browser-desktop-session.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Browser Desktop session starting"
log "User: $(whoami)"
log "Home: $HOME"
log "=========================================="

# Load session configuration
SESSION_MODE="disconnect_keep"
CLEANUP_ON_EXIT="true"

if [[ -f "$SESSION_CONF" ]]; then
    log "Loading session configuration from $SESSION_CONF"
    SESSION_MODE=$(grep "^mode=" "$SESSION_CONF" 2>/dev/null | cut -d'=' -f2 || echo "disconnect_keep")
    CLEANUP_ON_EXIT=$(grep "^cleanup_on_exit=" "$SESSION_CONF" 2>/dev/null | cut -d'=' -f2 || echo "true")
    log "Session mode: $SESSION_MODE"
    log "Cleanup on exit: $CLEANUP_ON_EXIT"
else
    log "WARNING: Session configuration not found at $SESSION_CONF, using defaults"
fi

# Set environment variables
# DISPLAY should be set by xrdp, but provide fallback
if [[ -z "$DISPLAY" ]]; then
    export DISPLAY=":10"
    log "WARNING: DISPLAY not set, defaulting to $DISPLAY"
else
    log "DISPLAY: $DISPLAY"
fi

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE="x11"

log "XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
log "XDG_SESSION_TYPE: $XDG_SESSION_TYPE"

# Ensure runtime directory exists
if ! mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null; then
    log "WARNING: Could not create $XDG_RUNTIME_DIR (may already exist or permission issue)"
fi

if [[ -d "$XDG_RUNTIME_DIR" ]]; then
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi

# Start dbus session if not running
if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    log "Starting dbus session..."
    if command -v dbus-launch >/dev/null 2>&1; then
        eval $(dbus-launch --sh-syntax 2>>"$LOG_FILE")
        export DBUS_SESSION_BUS_ADDRESS
        log "DBus session started: $DBUS_SESSION_BUS_ADDRESS"
    else
        log "WARNING: dbus-launch not found, continuing without dbus"
    fi
else
    log "DBus session already running: $DBUS_SESSION_BUS_ADDRESS"
fi

# Function to clean up Chrome data
cleanup_chrome_data() {
    log "Cleaning up Chrome data..."
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        if [[ -d "$CHROME_DATA_DIR" ]]; then
            rm -rf "$CHROME_DATA_DIR"
            log "Removed $CHROME_DATA_DIR"
        fi
    else
        log "Cleanup disabled, keeping Chrome data"
    fi
}

# Trap to clean up on exit
trap cleanup_chrome_data EXIT

# Determine Chrome executable
CHROME_BIN=""
if command -v google-chrome-stable >/dev/null 2>&1; then
    CHROME_BIN="google-chrome-stable"
elif command -v google-chrome >/dev/null 2>&1; then
    CHROME_BIN="google-chrome"
elif command -v chromium >/dev/null 2>&1; then
    CHROME_BIN="chromium"
elif command -v chromium-browser >/dev/null 2>&1; then
    CHROME_BIN="chromium-browser"
fi

if [[ -z "$CHROME_BIN" ]]; then
    log "ERROR: No Chrome/Chromium browser found in PATH"
    log "PATH: $PATH"
    log "Searching for Chrome binaries..."
    which google-chrome-stable 2>>"$LOG_FILE" || true
    which google-chrome 2>>"$LOG_FILE" || true
    which chromium 2>>"$LOG_FILE" || true
    which chromium-browser 2>>"$LOG_FILE" || true
    log "Session cannot continue without a browser"
    exit 1
fi

log "Using browser: $CHROME_BIN"
log "Browser version: $($CHROME_BIN --version 2>&1 || echo 'unknown')"

# Check if portal page exists
if [[ ! -f "/opt/browser-desktop/portal/index.html" ]]; then
    log "WARNING: Portal page not found at /opt/browser-desktop/portal/index.html"
    log "Chrome will start but may show an error page"
fi

# Start Openbox window manager in background
log "Starting Openbox window manager..."
if command -v openbox-session >/dev/null 2>&1; then
    openbox-session >>"$LOG_FILE" 2>&1 &
    OPENBOX_PID=$!
    log "Openbox started with PID: $OPENBOX_PID"

    # Wait for Openbox to initialize
    sleep 2

    # Check if Openbox is still running
    if ! kill -0 "$OPENBOX_PID" 2>/dev/null; then
        log "WARNING: Openbox may have failed to start, continuing anyway"
    else
        log "Openbox is running"
    fi
else
    log "WARNING: openbox-session not found, Chrome will run without window manager"
fi

# Main loop - restart Chrome if it crashes
CHROME_RESTART_COUNT=0
MAX_RESTARTS=5

while [[ $CHROME_RESTART_COUNT -lt $MAX_RESTARTS ]]; do
    log "Starting Chrome (attempt $((CHROME_RESTART_COUNT + 1))/$MAX_RESTARTS)..."

    "$CHROME_BIN" \
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
        "$PORTAL_URL" \
        >>"$LOG_FILE" 2>&1

    CHROME_EXIT_CODE=$?
    log "Chrome exited with code: $CHROME_EXIT_CODE"

    # If Chrome exited with 0, user intentionally closed it
    if [[ $CHROME_EXIT_CODE -eq 0 ]]; then
        log "Chrome exited normally, ending session"
        break
    fi

    # Otherwise, Chrome crashed - restart it
    CHROME_RESTART_COUNT=$((CHROME_RESTART_COUNT + 1))

    if [[ $CHROME_RESTART_COUNT -lt $MAX_RESTARTS ]]; then
        log "Chrome crashed, restarting in 3 seconds..."
        sleep 3
    else
        log "ERROR: Chrome has crashed $MAX_RESTARTS times, giving up"
        log "Session will end"
        break
    fi
done

log "=========================================="
log "Browser Desktop session ending"
log "=========================================="

# Cleanup will be called by the EXIT trap
exit 0
