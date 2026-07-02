# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

iMessage Forwarding Server — a macOS server that reads messages from the native `chat.db` SQLite database and exposes them over WebSocket + REST API. A vanilla web client connects from any browser.

**Tech stack**: Swift 5.9+, Vapor 4 (HTTP/WebSocket), GRDB.swift (SQLite), macOS 14 Sonoma+ minimum.

## Development Environment

- **Swift is not installed on this Linux dev box** — none of the build/test commands below run here. Development on this machine is source-editing only; build, test, and run happen on the target Mac (which also needs Full Disk Access for `chat.db` and Automation permission for Messages.app).
- This is the **only GitHub-hosted repo** (everything else lives on Forgejo at `git.timfinn.dev`) — use `gh` for PR/issue work, not `tea`.

## Build & Development Commands

```bash
swift build                                              # Debug build
swift build -c release                                   # Release build
swift test                                               # Run tests
IMESSAGE_AUTH_TOKEN=secret swift run imessage-forwarder   # Run dev server
```

**Environment variables:**
- `IMESSAGE_AUTH_TOKEN` (required) — auth token for API/WebSocket
- `IMESSAGE_PORT` — server port (default: 8080)
- `IMESSAGE_POLL_INTERVAL` — polling interval in seconds (default: 1.5)
- `IMESSAGE_CHAT_DB_PATH` — path to chat.db (default: ~/Library/Messages/chat.db)

## Architecture

- **Sources/App** — Vapor bootstrap (configure, entrypoint)
- **Sources/Core** — Models, database (GRDB), polling, sending (AppleScript), config
- **Sources/WebSocketModule** — WebSocket upgrade handler + connection manager
- **Sources/REST** — Auth middleware + REST controllers
- **Public/** — Vanilla HTML/CSS/JS web client
- **Tests/CoreTests** — Unit tests

The server polls chat.db every 1.5s for new messages (ROWID watermark) and broadcasts via WebSocket. Sending uses AppleScript to drive Messages.app.
