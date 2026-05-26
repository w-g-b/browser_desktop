#!/bin/bash
# Lightweight HTTP server for browser-desktop portal page
# Serves /opt/browser-desktop/portal on a local port
#
# Usage:
#   portal-server.sh start [port]   Start server (default port: 9080)
#   portal-server.sh stop           Stop server
#   portal-server.sh restart [port] Restart server
#   portal-server.sh status         Check server status

PORTAL_DIR="/opt/browser-desktop/portal"
DEFAULT_PORT=9080
PID_FILE="/run/browser-desktop-portal.pid"
LOG_FILE="/var/log/browser-desktop-portal.log"

# Find Python interpreter
find_python() {
    if command -v python3 >/dev/null 2>&1; then
        echo "python3"
    elif command -v python >/dev/null 2>&1; then
        echo "python"
    fi
}

start() {
    local port="${1:-$DEFAULT_PORT}"
    local python_bin
    python_bin="$(find_python)"

    if [[ -z "$python_bin" ]]; then
        echo "ERROR: Python not found, cannot start portal server" >&2
        return 1
    fi

    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Portal server already running (PID $(cat "$PID_FILE"))"
        return 0
    fi

    cd "$PORTAL_DIR" || { echo "ERROR: Portal directory not found: $PORTAL_DIR" >&2; return 1; }

    nohup "$python_bin" -m http.server "$port" \
        --bind 127.0.0.1 \
        --directory "$PORTAL_DIR" \
        >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Portal server started on http://127.0.0.1:${port} (PID $(cat "$PID_FILE"))"
}

stop() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            echo "Portal server stopped"
        else
            rm -f "$PID_FILE"
            echo "Portal server was not running (stale PID file removed)"
        fi
    else
        echo "Portal server is not running"
    fi
}

status() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Portal server running (PID $(cat "$PID_FILE")) on port ${1:-$DEFAULT_PORT}"
    else
        echo "Portal server is not running"
    fi
}

case "${1:-}" in
    start)   start "$2" ;;
    stop)    stop ;;
    restart) stop; sleep 1; start "$2" ;;
    status)  status "$2" ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} [port]"
        echo "Default port: $DEFAULT_PORT"
        exit 1
        ;;
esac
