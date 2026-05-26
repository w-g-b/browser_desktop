#!/bin/bash
# xrdp session entry point
# This script is executed when a user logs in via xrdp

# If user has a custom .xsession, use it
if [ -x "$HOME/.xsession" ]; then
    exec "$HOME/.xsession"
fi

# Otherwise, use the default browser desktop session
exec /opt/browser-desktop/bin/start-session.sh
