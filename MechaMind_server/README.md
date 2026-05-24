# MechaMind Server

Authoritative **Node.js game server** for MechaMind: turn-based mecha combat on a 100×100 grid. Handles lobby, match simulation, WebSocket gameplay, and read-only REST monitoring.

## What it does

- Validates mecha builds and registers clients over **WebSocket** (`/ws`)
- Starts a match automatically when **two connected clients** are in the lobby
- Runs the full rules engine: movement, combat, shields, energy, area scan
- Exposes **REST endpoints** for observers and admin actions

Full rules: [MechaMind_Rules_v1.md](./MechaMind_Rules_v1.md)

## Quick start

```bash
npm install
npm start
```

Server listens on **http://127.0.0.1:3000** (WebSocket at `ws://127.0.0.1:3000/ws`).

```bash
# Longer turn timeout (5 minutes)
TURN_TIMEOUT_MS=300000 npm start
```

## Tests

```bash
npm test
```

## Project layout

```
MechaMind_server/
├── src/
│   ├── index.js          # Entry point
│   ├── app.js            # Express + WebSocket setup
│   ├── game/             # Match engine, vehicles, positions
│   ├── ws/               # WebSocket gateway & protocol
│   └── validation/       # Build & action validation
├── config/default.json
├── tests/
└── MechaMind_Rules_v1.md
```

## WebSocket protocol (summary)

| Client → Server | Purpose |
|---------------|---------|
| `register` | Join lobby with mecha build |
| `action` | Respond to `action_request` (MOVE, FIRE, SCAN, IDLE) |

| Server → Client | Purpose |
|---------------|---------|
| `registered` | Registration OK |
| `match_started` | Match begins |
| `action_request` | Your turn — vehicle state + feedback |
| `result` | Turn resolved |
| `gameover` | Match ended (WIN / LOSE / DRAW) |
| `error` | Validation or protocol error |

## REST monitoring

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /status` | — | Uptime, lobby, active matches |
| `GET /client/:id` | — | Client status |
| `GET /match/:id` | — | Live match snapshot |
| `GET /match/:id/history` | — | Turn-by-turn log (in memory) |
| `POST /match/:id/end` | Admin | Force DRAW |
| `DELETE /client/:id` | Admin | Remove client / forfeit |

Admin header: `Authorization: Bearer <adminToken>` (default in `config/default.json`).

## Configuration

| Setting | Default | Env override |
|---------|---------|--------------|
| Port | 3000 | `PORT` |
| Turn timeout | 180000 ms (3 min) | `TURN_TIMEOUT_MS` |
| Max turns | 500 | `MAX_TURNS` |
| Min spawn distance | 20 (Manhattan) | — |
| Admin token | `admin-secret` | `ADMIN_TOKEN` |
| Log level | `info` | `LOG_LEVEL` |

## Ecosystem

| Project | Role |
|---------|------|
| **MechaMind_server** | This server |
| **MechaMind_gui** | Human pilot (Flutter) |
| **MechaMind_robot** | Node.js bot framework |
| **MechaMind_mdc** | Python MCP server for LLM pilots |
| **MechaMind_console** | Monitoring console (planned) |

## Requirements

- Node.js ≥ 18
