# MechaMind Console

**Flutter monitoring app** for live MechaMind matches. Read-only observer over the server REST API (no WebSocket registration required).

## Features

- Server status: uptime, lobby, connected clients, active matches
- Pick a running match from the list or open by match ID
- Live map with **both mechas** (cyan / orange)
- Hull and shield bars per mecha
- Turn-by-turn history (`GET /match/:id/history`)
- Auto-refresh (2s on home, 1s while watching a match)

## Requirements

- Flutter SDK (same as [MechaMind_gui](../MechaMind_gui))
- [MechaMind_server](../MechaMind_server) running on port 3000

## Run

```bash
cd MechaMind_console
flutter pub get
flutter run -d macos
```

Other targets: `windows`, `linux`, `chrome`.

Default server URL: `http://127.0.0.1:3000` (editable in the app).

## API used

| Endpoint | Purpose |
|----------|---------|
| `GET /status` | Lobby, match list, last finished match |
| `GET /match/:id` | Positions, HP, turn, outcome |
| `GET /match/:id/history` | Action log |

## Typical workflow

1. Start the server: `cd MechaMind_server && npm start`
2. Start two pilots (GUI, robots, or MCP)
3. Open **MechaMind Console** and tap a match to watch

## Project layout

```
MechaMind_console/
├── lib/
│   ├── main.dart
│   ├── models/          # REST DTOs
│   ├── services/        # HTTP client
│   ├── providers/       # Polling controller
│   ├── screens/         # Home + monitor
│   └── widgets/         # Map, stats, history
└── pubspec.yaml
```

## Related

- [MechaMind_server](../MechaMind_server) — game server and rules
- [MechaMind_gui](../MechaMind_gui) — human pilot client
