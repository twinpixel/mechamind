# MechaMind GUI

**Flutter** client for human players. Connects to MechaMind server over WebSocket, lets you configure a mecha build, join the lobby, and play turn-by-turn battles with a tactical map and action panel.

## Features

- Mecha build editor (100-point allocation across 6 components)
- WebSocket registration and real-time turn loop
- Tactical map centered on your position (scan overlay, fire target, tap-to-scan)
- Side action panel: SCAN / FIRE / MOVE / IDLE with energy sliders and countdown
- Scan feedback banner and match status

## Prerequisites

- Flutter SDK (stable channel)
- MechaMind server running: `cd ../MechaMind_server && npm start`

## Run

```bash
flutter pub get
flutter run -d macos    # or chrome, ios, android
```

Default server URL in the app: `http://127.0.0.1:3000`

## Project layout

```
MechaMind_gui/
├── lib/
│   ├── main.dart
│   ├── providers/game_controller.dart   # WebSocket + game state
│   ├── services/websocket_client.dart
│   ├── screens/                           # setup, lobby, battle, finished
│   └── widgets/                           # battle grid, action panel, scan banner
└── pubspec.yaml
```

## Playing a match

1. **Setup** — set mecha name, author, and build (must sum to 100)
2. **Register** — connects to `ws://host:3000/ws`
3. **Lobby** — wait for a second client (another GUI instance, bot, or LLM via MCP)
4. **Battle** — on your turn, pick an action on the right panel; tap the map for scan center or fire target
5. **Finished** — outcome shown when the match ends

## Two human players locally

Run two app instances with **different mecha names** (e.g. `HumanPilot` and `HumanPilot2`):

```bash
# Terminal 1
flutter run -d macos

# Terminal 2 (another device/window)
flutter run -d chrome
```

## Analyze

```bash
dart analyze lib/
```

## Related projects

- [MechaMind_server](../MechaMind_server) — game rules & server
- [MechaMind_robot](../MechaMind_robot) — automated bots
- [MechaMind_mdc](../MechaMind_mdc) — LLM pilots via MCP
