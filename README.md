# StatusBall

A lightweight macOS floating indicator for [opencode](https://opencode.ai) sessions. Shows one colored dot per active session in a capsule that floats above all windows — including fullscreen apps, on every Space.

![screenshot](screenshots/capsule.png)

## Status Colors

| Color | Meaning |
|---|---|
| ![#3DC284](https://via.placeholder.com/12/3DC284/000000?text=+) **Emerald** | Running — the agent is actively working (pulses) |
| ![#9CA3AF](https://via.placeholder.com/12/9CA3AF/000000?text=+) **Gray** | Idle — session is open but not active |
| ![#60A5FA](https://via.placeholder.com/12/60A5FA/000000?text=+) **Blue** | Waiting for a sub-agent to complete |
| ![#F59E0B](https://via.placeholder.com/12/F59E0B/000000?text=+) **Amber** | Asking a question or waiting for permission (pulses) |
| ![#FB7185](https://via.placeholder.com/12/FB7185/000000?text=+) **Rose** | Stopped or errored (auto-dismisses after 1.2s) |

Sessions with active sub-agents show tiny white orbiting satellites around their dot.

## Features

- **Always on top** — uses `NSPanel` with `level = .statusBar` + `fullScreenAuxiliary`, visible over every window
- **Per-session dots** — new dot appears for each opencode session, color reflects current state
- **Sub-agent satellites** — when a session spawns background agents, small orbiting dots appear around it
- **Hover tooltip** — shows session label, status, model name, current task, and running duration
- **Auto-eviction** — idle dots disappear after 3 seconds; stopped dots after 1.2s
- **No Dock icon** — runs as a background accessory
- **LaunchAgent** — auto-starts at login, restarts on crash

## Prerequisites

- macOS 13 (Ventura) or later
- [opencode](https://opencode.ai) (tested with recent versions)
- Swift 5.9+ (included with Xcode or Command Line Tools)

## Installation

```bash
git clone https://github.com/YOUR_USER/StatusBall.git
cd StatusBall
./launch/install.sh
```

This builds the release binary, installs a LaunchAgent to auto-start at login, and launches it immediately.

### Wire up the opencode plugin

Add the plugin to your `~/.config/opencode/opencode.json`:

```json
{
  "plugin": [
    "/path/to/StatusBall/plugin/opencode-status-ball.ts"
  ]
}
```

Restart opencode. Dots will appear in the capsule as sessions become active.

### Manual run (no auto-start)

```bash
swift build -c release
.build/release/OpenCodeStatusBall &
```

## Uninstall

```bash
cd StatusBall
./launch/uninstall.sh
```

Remove the plugin entry from `opencode.json`.

## How it works

```
┌─────────────┐  events   ┌───────────────────┐  JSON lines  ┌──────────────┐
│  opencode   │ ────────▶ │  TS plugin        │ ────────────▶ │  macOS App   │
│  (session)  │           │  (per-session)    │  unix socket  │  (SwiftUI)   │
└─────────────┘           └───────────────────┘               └──────────────┘
```

- **MacOS app** — Swift Package executable. Runs as an accessory, opens a transparent `NSPanel` with the capsule UI. Listens on `/tmp/opencode-status.sock` for JSON status updates.
- **Plugin** — TypeScript plugin loaded by opencode per session. Tracks session state (idle/running/error, model name, current task) and pushes changes to the socket.

## Project Structure

```
StatusBall/
├── Package.swift
├── Sources/OpenCodeStatusBall/
│   ├── AppDelegate.swift          — @main, NSApp.accessory, wires panel + server
│   ├── FloatingBallPanel.swift    — NSPanel subclass, always-on-top configuration
│   ├── CapsuleBarView.swift       — SwiftUI capsule with session dots and tooltip
│   ├── StatusModel.swift          — Multi-session state container with auto-eviction
│   └── StatusServer.swift         — Unix domain socket server
├── plugin/
│   └── opencode-status-ball.ts    — opencode plugin
├── launch/
│   ├── com.opencode.statusball.plist  — LaunchAgent template
│   ├── install.sh                     — Build + install + bootstrap
│   └── uninstall.sh                   — Bootout + remove plist
├── screenshots/
├── LICENSE
└── README.md
```

## License

MIT
