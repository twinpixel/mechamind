# MECHAMIND

**Turn-based mecha combat — both pilots are LLM agents**

MechaMind is a **100×100** grid battle where two mechas fight turn by turn. The
server runs the rules; **each pilot is a program that chooses actions**. The main
use case is **two LLMs dueling**: each model receives its vehicle state through
[MCP](https://modelcontextprotocol.io) tools, reasons about movement, scanning,
and firing, and sends one action per turn over WebSocket.

You can also play with the Flutter GUI, Node.js bots, or a custom WebSocket
client — but the project is built around **LLM vs LLM** matches in Cursor (or any
MCP-compatible host).

> Rules aligned with the Node.js server in this repo (WebSocket gameplay,
> read-only REST monitoring). Derived from `MechaMind_Regolamento_v1.docx`.

---

## LLM vs LLM — quick start

1. **Start the game server**

   ```bash
   cd MechaMind_server
   npm install
   npm start
   ```

   WebSocket: `ws://127.0.0.1:3000/ws` — REST monitoring: `http://127.0.0.1:3000`

2. **Run the MCP adapter** (Python tools for LLM pilots)

   ```bash
   cd MechaMind_mcp
   python3 -m venv .venv && source .venv/bin/activate
   pip install -e ".[dev]"
   ```

   Configure Cursor MCP as described in
   [MechaMind_mcp/README.md](./MechaMind_mcp/README.md).

3. **Register two pilots** (two agents or two chats, same MCP server, different names)

   - Agent A: `mechamind_register_pilot(pilot_name="LLM_A", mecha_name="AlphaMind", …)`
   - Agent B: `mechamind_register_pilot(pilot_name="LLM_B", mecha_name="BetaMind", …)`

   When the **second** mecha registers, the server starts the match automatically.

4. **Play the match** — each LLM loops:

   - `mechamind_wait_for_turn(pilot_name)` — blocks until `action_request`
   - Decide build spend: MOVE, FIRE, SCAN, or IDLE
   - `mechamind_submit_action(pilot_name, turn, action, …)`

   Call `mechamind_rules` anytime for a concise rule summary tuned for models.

Optional: watch the battle with **MechaMind_console** (Flutter) or **MechaMind_gui**
(human vs bot / human vs human).

### Repository layout

| Directory | Role |
|-----------|------|
| **MechaMind_server** | Authoritative rules engine, WebSocket + REST |
| **MechaMind_mcp** | **MCP server for LLM pilots** (register, wait, act) |
| **MechaMind_gui** | Flutter client (human pilot) |
| **MechaMind_robot** | Reference Node.js bot |
| **MechaMind_console** | Match monitoring console |

---

## 1. Overview

MechaMind is turn-based combat for two vehicles on a discrete **100×100** grid.
Each turn, a pilot program (typically an **LLM** using MCP) receives partial
battlefield information and must pick **exactly one** action. You win by
destroying the opponent — reducing **Hull** to zero.

The sections below are the full **technical rules (v1.1)** for builds, protocol,
and server behavior.

---

## 2. Mecha Build

### 2.1 Build Points

Each mecha has **100 build points** split across six components. Each component
must be between **5** and **70** points. The total must be exactly **100**.

- Minimum per attribute: **5**
- Maximum per attribute: **70**
- Required fields: `generator`, `hull`, `shields`, `cannon`, `propulsion`, `radar`

### 2.2 Components

| Component   | Min | Max | Effect |
|-------------|-----|-----|--------|
| Generator   | 5   | 70  | Produces N energy at the start of each turn |
| Hull        | 5   | 70  | Structural HP. At 0 → destroyed |
| Shields     | 5   | 70  | Damage buffer. Max value = build points invested |
| Cannon      | 5   | 70  | Max damage per shot = energy spent (≤ cannon build) |
| Propulsion  | 5   | 70  | Max cells moved per turn = energy spent (≤ propulsion build) |
| Radar       | 5   | 70  | Max energy spendable on SCAN per turn (= max scan radius) |

Build points set the **per-turn cap** for each action type, not a fixed spend.
Pilots (LLM or bot) may use less than the maximum each turn.

---

## 3. Mecha Registration

### 3.1 WebSocket Connection

Before joining a match, each client must:

1. Open a WebSocket to `ws://<host>:<port>/ws`
2. Send a JSON `register` message with the mecha payload
3. Wait for `registered` or `error`

The server validates the payload. All gameplay uses the same WebSocket connection
(no HTTP callback URL on the client).

### 3.2 `register` Message (Client → Server)

```json
{
  "type": "register",
  "name": "IronSerpent",
  "version": "2.1.0",
  "author": "Team Nexus",
  "build": {
    "generator": 20,
    "hull": 25,
    "shields": 15,
    "cannon": 18,
    "propulsion": 12,
    "radar": 10
  }
}
```

| Field     | Type   | Required | Notes |
|-----------|--------|----------|-------|
| `type`    | string | yes      | Must be `"register"` |
| `name`    | string | yes      | Mecha name (unique per server session) |
| `version` | string | yes      | Bot/client version |
| `author`  | string | yes      | Author or team |
| `build`   | object | yes      | Six integers summing to 100 |

### 3.3 Server Validation

On failure the server sends `error` and rejects registration:

- All required fields present
- Each build attribute is an integer 5–70
- Build sum is exactly 100
- Mecha name is **unique** among connected clients
- Only one registration per WebSocket connection

### 3.4 `registered` Response (Server → Client)

```json
{
  "type": "registered",
  "client_id": "abc123-...",
  "status": "waiting",
  "message": "In lobby, waiting for opponent",
  "match_id": null
}
```

If a match starts immediately (two lobby clients connected):

```json
{
  "type": "registered",
  "client_id": "abc123-...",
  "status": "in_match",
  "message": "Match started",
  "match_id": "254de4a2-..."
}
```

### 3.5 `error` Response (Server → Client)

```json
{
  "type": "error",
  "error": "build.hull must be >= 5",
  "field": "build.hull"
}
```

### 3.6 Lobby and Auto-Start

After valid registration the client enters the **lobby**. When **two clients**
are in the lobby and **both have an active WebSocket**, the server:

1. Starts the match automatically
2. Assigns random starting positions (minimum Manhattan distance, default **20**)
3. Sends `match_started` to both
4. Begins turn 1 with `action_request` to the first player in shuffled order

No extra client action is required.

---

## 4. Battlefield

- Discrete grid **100×100** (coordinates `[0,0]` … `[99,99]`)
- Hard boundaries — cannot leave the grid
- Two vehicles cannot occupy the same cell
- Start positions are server-assigned (random, min distance configurable)

---

## 5. Turn Structure

Turns are numbered 1, 2, 3, … The server contacts clients in a **fixed random
order** chosen at match start.

Each client, when it is their slot in the turn:

1. Receives `action_request` with updated vehicle state
2. Sends an `action` message within the configured timeout
3. Receives `result` after the full turn resolves (both players acted, if the match continues)

**Exactly one action per client per turn:** MOVE, FIRE, SCAN, or IDLE.

### 5.1 Actions

| Action | Energy cost | Parameters | Effect |
|--------|-------------|------------|--------|
| **MOVE** | `energy` (≤ propulsion) | `dx`, `dy` | Move; `\|dx\| + \|dy\| ≤ energy` |
| **FIRE** | `energy` (≤ cannon) | `target_x`, `target_y` | Instant shot; damage = energy if hit |
| **SCAN** | `energy` (≤ radar, > 0) | `scan_x`, `scan_y` | Active scan; radius = energy (Manhattan) |
| **IDLE** | 0 | — | No action; unused energy is lost |

---

## 6. Energy System

### 6.1 Production

At the **start of each turn** (before `action_request`), the generator restores
energy equal to its build value. Unused energy at end of turn is **lost** (no
banking).

### 6.2 Shield Regeneration (Start of Turn)

Before `action_request`, if shields are below max **and** energy ≥ 1:

- Shields increase by **1**
- Energy decreases by **1**

If energy is 0 after production, shields do not regenerate that turn.

### 6.3 Action Spend

Each turn the client picks one action and optional `energy`:

- Spend cannot exceed the component build cap
- Spend cannot exceed available energy
- Invalid actions are treated as **IDLE** (see §16)

*Example: Generator 20, Cannon 15 — either FIRE with energy 15 or MOVE with
energy 10, not both.*

---

## 7. Movement

**MOVE** spends `energy` ≤ propulsion. The vehicle moves by `dx` on X and `dy`
on Y with:

**`|dx| + |dy| ≤ energy`**

- Any direction (no fixed facing)
- Must stay within `[0,99] × [0,99]`
- If the destination cell is occupied by the opponent, movement is cancelled
  (vehicle stays put; energy is still spent)

---

## 8. Combat

### 8.1 Firing

**FIRE** targets cell (`target_x`, `target_y`) with `energy` ≤ cannon.

- Target equals opponent position → **HIT**
- Otherwise → **MISS** (energy still spent)

### 8.2 Fire Feedback

After FIRE, the shooter receives feedback (in the next `action_request` as
`last_fire_feedback`, and in the current turn `result`):

- `hit`: boolean
- `distance`: Manhattan distance from target cell to opponent’s true position
- `turn`: turn number of the shot

### 8.3 Damage

On a hit, damage equals `energy` spent on FIRE. Application order:

**Shields → Hull**

- Shields absorb first; overflow damages hull
- Hull at **0** → vehicle destroyed (match ends unless simultaneous destruction)
- Hull **never regenerates**

---

## 9. Shields

- Max shields = shield build points
- Regenerate **+1** per turn at start of turn (costs 1 energy) — see §6.2
- Cannot exceed max shields

---

## 10. Radar (SCAN)

### 10.1 Active Scan

**SCAN** is an explicit turn action. Spend `energy` > 0 (≤ radar build) and
choose scan center (`scan_x`, `scan_y`).

- **Scan radius** = `energy` invested (Manhattan distance)
- Area = all cells where Manhattan distance from (`scan_x`, `scan_y`) ≤ radius
- Opponent inside area → `found: true` with exact `x`, `y`
- Opponent outside → `found: false` (no position revealed)
- Without SCAN, opponent position is unknown (except via fire feedback)

### 10.2 `last_scan` Result

After SCAN, the client receives `last_scan` on the next turn (and `scan_result`
in the current `result`):

**Enemy found**

```json
{
  "found": true,
  "x": 60,
  "y": 44,
  "scan_x": 55,
  "scan_y": 40,
  "radius": 8,
  "turn": 41
}
```

**Not found**

```json
{
  "found": false,
  "scan_x": 55,
  "scan_y": 40,
  "radius": 8,
  "turn": 41
}
```

---

## 11. End Conditions

| Outcome | Condition |
|---------|-----------|
| **WIN** | Opponent hull reaches 0 |
| **DRAW** | Both destroyed same turn |
| **FORFEIT / TIMEOUT** | Client misses action deadline |
| **DISCONNECT** | WebSocket closes mid-match → opponent wins |
| **MAX TURNS** | Turn > 500 (default) → higher hull wins; tie = DRAW |
| **ADMIN** | `POST /match/:id/end` → forced DRAW |

---

## 12. System Architecture

### 12.1 Roles

| Component | Role |
|-----------|------|
| **Node.js server** | Lobby, simulation, WebSocket game, REST monitoring |
| **LLM pilot (MCP)** | Primary client: MCP tools → WebSocket `register` / `action` |
| **Bot / GUI** | Alternative WebSocket clients (Node robot, Flutter GUI) |
| **Monitor console** | HTTP consumer of REST read endpoints (spectator) |

### 12.2 Match Flow

1. Client opens `ws://host:port/ws`, sends `register`
2. Server validates, adds to lobby
3. Two connected lobby clients → match starts
4. Server sends `match_started`
5. Each turn, for each client in order: `action_request` → wait `action` → apply
6. End of turn: `result` to both
7. Match end: `gameover` to both

### 12.3 WebSocket Protocol

Endpoint: **`ws://<host>:<port>/ws`** — all messages JSON with `type`.

**Client → Server**

| `type` | When | Payload |
|--------|------|---------|
| `register` | On connect | `name`, `version`, `author`, `build` |
| `action` | Turn response | `turn`, `action`, action fields |

**Server → Client**

| `type` | When | Payload |
|--------|------|---------|
| `registered` | After OK register | `client_id`, `status`, `match_id` |
| `error` | Validation failure | `error`, `field?` |
| `match_started` | Match begins | `match_id` |
| `action_request` | Your turn | `turn`, `vehicle`, `last_scan`, `last_fire_feedback`, `timeout_ms` |
| `result` | Turn done | `turn`, `vehicle`, `your_action`, `opponent_action`, `damage_taken` |
| `gameover` | Match end | `outcome`, `reason`, `turn`, `vehicle` |

### 12.4 REST Monitoring

Read endpoints are public. Admin actions need `Authorization: Bearer <adminToken>`.

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `GET /status` | GET | — | Uptime, lobby, matches |
| `GET /client/:id` | GET | — | Client status |
| `GET /match/:id` | GET | — | Live snapshot |
| `GET /match/:id/history` | GET | — | Turn log (in memory) |
| `POST /match/:id/end` | POST | Admin | Force DRAW |
| `DELETE /client/:id` | DELETE | Admin | Remove client / forfeit |

---

## 13. JSON Formats

### 13.1 Vehicle State (`action_request`)

```json
{
  "type": "action_request",
  "turn": 42,
  "timeout_ms": 180000,
  "vehicle": {
    "x": 34,
    "y": 17,
    "hull": 55,
    "hull_max": 60,
    "shields": 8,
    "shields_max": 20,
    "energy": 25,
    "build": {
      "generator": 25,
      "hull": 60,
      "shields": 20,
      "cannon": 15,
      "propulsion": 10,
      "radar": 20
    }
  },
  "last_scan": null,
  "last_fire_feedback": { "hit": false, "distance": 12, "turn": 41 }
}
```

### 13.2 Actions (Client → Server)

Include `type: "action"` and matching `turn`.

**MOVE**

```json
{ "type": "action", "turn": 42, "action": "MOVE", "energy": 8, "dx": 3, "dy": -5 }
```

**FIRE**

```json
{ "type": "action", "turn": 42, "action": "FIRE", "energy": 15, "target_x": 60, "target_y": 44 }
```

**SCAN**

```json
{ "type": "action", "turn": 42, "action": "SCAN", "energy": 8, "scan_x": 55, "scan_y": 40 }
```

`energy` is both cost and **scan radius**.

**IDLE**

```json
{ "type": "action", "turn": 42, "action": "IDLE" }
```

### 13.3 Turn Result (`result`)

```json
{
  "type": "result",
  "turn": 42,
  "vehicle": { "...": "updated state" },
  "your_action": {
    "energy_spent": 8,
    "moved": true,
    "damage_dealt": 0,
    "fire_feedback": null,
    "scan_result": { "found": false, "scan_x": 55, "scan_y": 40, "radius": 8 }
  },
  "opponent_action": { "action": "FIRE" },
  "damage_taken": 0
}
```

### 13.4 Game Over (`gameover`)

```json
{
  "type": "gameover",
  "match_id": "254de4a2-...",
  "outcome": "WIN",
  "reason": "destruction",
  "turn": 15,
  "vehicle": { "hull": 12, "shields": 3 }
}
```

`outcome`: `WIN`, `LOSE`, `DRAW`.  
Common `reason` values: `destruction`, `timeout`, `forfeit`, `max_turns`,
`simultaneous_destruction`, `admin_end`.

---

## 14. MCP layer — how LLMs pilot a mecha

The **`MechaMind_mcp`** package exposes the game as **MCP tools** so an LLM never
needs raw WebSocket JSON: the adapter maintains one WebSocket per `pilot_name` and
maps tool calls to the protocol below.

| Tool | Purpose |
|------|---------|
| `mechamind_rules` | Rule summary for the model |
| `mechamind_register_pilot` | Connect + `register` (build + mecha name) |
| `mechamind_wait_for_turn` | Block until `action_request` for that pilot |
| `mechamind_submit_action` | Send MOVE / FIRE / SCAN / IDLE |
| `mechamind_list_pilots` / `mechamind_pilot_status` | Session state |
| `mechamind_server_status` / `mechamind_match_snapshot` | REST monitoring |

**Two LLMs fighting:** use one MechaMind server and **two distinct `pilot_name`
values** (and two different `mecha_name` values). Each agent runs its own
register → wait → submit loop; the server alternates turns and resolves combat.

Full setup, Cursor `mcp.json`, and examples:
[MechaMind_mcp/README.md](./MechaMind_mcp/README.md).

The core server does **not** embed an LLM or MCP — it only enforces rules. Any
client that speaks WebSocket (GUI, bots, MCP) can be a pilot.

---

## 15. Server Configuration

`config/default.json`, overridable via environment:

| Parameter | Default | Env | Description |
|-----------|---------|-----|-------------|
| `port` | 3000 | `PORT` | HTTP + WebSocket port |
| `gridSize` | 100 | — | Grid dimension |
| `turnTimeoutMs` | 180000 (3 min) | `TURN_TIMEOUT_MS` | Action deadline |
| `maxTurns` | 500 | `MAX_TURNS` | Max turns per match |
| `minStartDistance` | 20 | — | Min Manhattan spawn distance |
| `adminToken` | `admin-secret` | `ADMIN_TOKEN` | Admin API token |
| `logLevel` | `info` | `LOG_LEVEL` | `debug`, `info`, `warn`, `error` |

```bash
cd MechaMind_server && npm start
cd MechaMind_server && TURN_TIMEOUT_MS=300000 npm start
```

---

## 16. Implementation Notes

- Invalid actions (bad coords, over-cap energy, etc.) become **IDLE** without extra penalty
- **No response** within `timeout_ms` → **forfeit** (not auto-IDLE)
- Turn order is random at start and fixed for the match
- Opponent state is **never** sent directly — only SCAN and fire feedback reveal information
- Match starts only when **both** lobby clients have active WebSocket (avoids race at start)
- Match history is **in-memory only** — no database persistence

---

## Appendix A — Migration from v1.0 (HTTP Callback)

Original docx v1.0 used HTTP callbacks on the client (`callback_url`, 5s timeout).
Current implementation uses **bidirectional WebSocket** plus REST for monitoring.
Core game rules (build, movement, damage, scan, shields) are unchanged.
