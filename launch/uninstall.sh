#!/usr/bin/env bash
# Stop and remove the OpenCodeStatusBall LaunchAgent.
set -euo pipefail

LABEL="com.opencode.statusball"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"
UID_NUM="$(id -u)"

echo "==> Booting out agent..."
launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null || true

if [[ -f "$PLIST_DST" ]]; then
    rm "$PLIST_DST"
    echo "==> Removed $PLIST_DST"
fi

echo "Done. Logs preserved at $HOME/Library/Logs/OpenCode/"
