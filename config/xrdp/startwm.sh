#!/bin/bash
# xrdp session entry point
# This script is executed when a user logs in via xrdp

LOG_FILE="$HOME/.browser-desktop-startwm.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "=========================================="
log "startwm.sh starting"
log "User: $(whoami)"
log "Home: $HOME"
log "DISPLAY: ${DISPLAY:-not set}"
log "=========================================="

# If user has a custom .xsession, use it
if [ -x "$HOME/.xsession" ]; then
    log "Found custom .xsession, executing..."
    exec "$HOME/.xsession"
fi

# Check if browser-desktop session script exists
SESSION_SCRIPT="/opt/browser-desktop/bin/start-session.sh"

if [ ! -f "$SESSION_SCRIPT" ]; then
    log "ERROR: Session script not found: $SESSION_SCRIPT"
    log "Listing /opt/browser-desktop/bin/..."
    ls -la /opt/browser-desktop/bin/ >> "$LOG_FILE" 2>&1 || true
    exit 1
fi

if [ ! -x "$SESSION_SCRIPT" ]; then
    log "WARNING: Session script not executable, fixing permissions..."
    chmod +x "$SESSION_SCRIPT" 2>> "$LOG_FILE" || true
fi

log "Executing session script: $SESSION_SCRIPT"
exec "$SESSION_SCRIPT"
