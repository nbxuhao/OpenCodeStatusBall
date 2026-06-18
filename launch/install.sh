#!/usr/bin/env bash
# Build OpenCodeStatusBall in release mode and install it as a per-user
# LaunchAgent so it auto-starts at login and restarts on crash.
#
# Usage: ./launch/install.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.opencode.statusball"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"
PLIST_SRC="$REPO/launch/${LABEL}.plist"
BIN="$REPO/.build/release/OpenCodeStatusBall"
UID_NUM="$(id -u)"

echo "==> Building (release)..."
( cd "$REPO" && swift build -c release )

if [[ ! -x "$BIN" ]]; then
    echo "ERROR: build did not produce $BIN" >&2
    exit 1
fi

echo "==> Preparing log directory..."
mkdir -p "$HOME/Library/Logs/OpenCode"

echo "==> Materializing plist with absolute paths..."
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|__HOME__|${HOME}|g" \
    -e "s|__BIN__|${BIN}|g" \
    "$PLIST_SRC" > "$PLIST_DST"
chmod 644 "$PLIST_DST"

echo "==> Booting out any prior instance..."
launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null || true

echo "==> Bootstrapping new agent..."
launchctl bootstrap "gui/${UID_NUM}" "$PLIST_DST"
launchctl enable    "gui/${UID_NUM}/${LABEL}"
launchctl kickstart -k "gui/${UID_NUM}/${LABEL}"

sleep 0.4
if launchctl print "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1; then
    echo "==> Installed. Status:"
    launchctl print "gui/${UID_NUM}/${LABEL}" | grep -E "state|pid|path" | head -6
    echo
    echo "Logs: $HOME/Library/Logs/OpenCode/statusball.{out,err}.log"
    echo "Uninstall: ./launch/uninstall.sh"
else
    echo "ERROR: agent failed to register" >&2
    exit 1
fi
