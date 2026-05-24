# MechaMind Robot

**Node.js framework** for writing MechaMind bots. Handles WebSocket connection, registration, and the turn loop — you only implement `onTurn()` strategy.

## Quick start

```bash
npm install
npm start          # HunterBot (bot 1)
npm run bot2       # HunterBot2 in a second terminal
```

Requires [MechaMind_server](../MechaMind_server) running (`npm start`). Mecha names must be **unique** per session.

## Minimal bot

```js
import { Mecha } from "./src/Mecha.js";

class MyBot extends Mecha {
  onTurn({ vehicle, lastScan, lastFireFeedback, turn }) {
    return this.scan(50, 50, 10);
  }
}

new MyBot({
  name: "MyBot",
  build: {
    generator: 20,
    hull: 25,
    shields: 15,
    cannon: 18,
    propulsion: 12,
    radar: 10,
  },
}).connect("ws://localhost:3000/ws");
```

## Project layout

```
MechaMind_robot/
├── examples/
│   ├── HunterBot.js      # Bot 1 — converge search strategy
│   └── HunterBot2.js     # Bot 2 — same strategy, different name
├── src/
│   ├── Mecha.js          # Base class
│   ├── connection.js     # WebSocket client
│   ├── bots/ConvergeHunter.js
│   ├── strategies/convergeSearch.js
│   └── modules/
│       ├── memory.js     # Turn history
│       ├── tracker.js    # Enemy position estimates
│       └── pathfinder.js # Grid movement helpers
└── test/
```

## Actions in `onTurn`

| Method | Description |
|--------|-------------|
| `this.move(dx, dy, energy)` | Move; `\|dx\| + \|dy\| ≤ energy` |
| `this.fire(x, y, energy)` | Shoot cell `(x, y)` |
| `this.scan(x, y, energy)` | Area scan; radius = energy (Manhattan) |
| `this.idle()` | No action |

Context: `vehicle` (position, HP, energy, build), `lastScan`, `lastFireFeedback`, `turn`.

Optional hooks: `onRegistered`, `onMatchStarted`, `onResult`, `onGameOver`, `onDisconnected`, `onServerError`.

## HunterBot strategy (converge)

1. **Enemy known** → FIRE if in range, else MOVE toward enemy  
2. **Enemy unknown** → MOVE toward arena center `(50, 50)` until close  
3. **At center** → SCAN `(50, 50)` with max radar  

Two bots using this strategy reliably find each other within ~25 turns (see `test/converge.test.js`).

## Scripts

| Command | Description |
|---------|-------------|
| `npm run bot1` | Start HunterBot |
| `npm run bot2` | Start HunterBot2 |
| `npm test` | Unit tests |

Custom server: `SERVER_URL=ws://192.168.1.10:3000/ws npm run bot1`

## Requirements

- Node.js ≥ 18
- Running MechaMind server
