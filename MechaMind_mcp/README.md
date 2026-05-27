# MechaMind MCP

Python **[Model Context Protocol](https://modelcontextprotocol.io)** server that exposes
MechaMind as **tools for LLM agents**. This is how **two LLMs fight**: each agent uses
a unique `pilot_name`, registers a mecha, then loops on `wait_for_turn` /
`submit_action` while the [game server](../MechaMind_server) resolves combat.

You can also pit an LLM against a [Node bot](../MechaMind_robot) or a human in
[MechaMind_gui](../MechaMind_gui).

Full rules: [readme.md](../readme.md).

## Prerequisites

- Python ≥ 3.10
- MechaMind server running: `cd ../MechaMind_server && npm install && npm start`

## Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Cursor MCP configuration

Add to `.cursor/mcp.json` (project root or user settings):

```json
{
  "mcpServers": {
    "mechamind": {
      "command": "/absolute/path/to/MechaMind/MechaMind_mcp/.venv/bin/python",
      "args": ["-m", "mechamind_mcp.server"],
      "env": {
        "MECHAMIND_URL": "http://127.0.0.1:3000"
      }
    }
  }
}
```

Replace `/absolute/path/to/MechaMind` with your clone path.

Debug manually:

```bash
MECHAMIND_URL=http://127.0.0.1:3000 python -m mechamind_mcp.server
```

## MCP tools

| Tool | Description |
|------|-------------|
| `mechamind_rules` | Concise rules text for the LLM |
| `mechamind_server_status` | `GET /status` |
| `mechamind_register_pilot` | WebSocket register (build + mecha name) |
| `mechamind_list_pilots` | Active pilots in this MCP session |
| `mechamind_wait_for_turn` | Block until `action_request` |
| `mechamind_submit_action` | Send MOVE / FIRE / SCAN / IDLE |
| `mechamind_pilot_status` | Pilot snapshot |
| `mechamind_match_snapshot` | REST match view |
| `mechamind_disconnect_pilot` | Close WebSocket |

## Two LLMs fighting

Use **two Cursor chats or agents** against the **same MCP server** with different
`pilot_name` values.

### LLM A

1. Call `mechamind_rules`
2. `mechamind_register_pilot(pilot_name="LLM_A", mecha_name="AlphaMind")`
3. Loop: `mechamind_wait_for_turn("LLM_A")` → decide → `mechamind_submit_action(...)`

### LLM B

1. `mechamind_register_pilot(pilot_name="LLM_B", mecha_name="BetaMind")`
2. Same loop with `pilot_name="LLM_B"`

When the **second** mecha registers, the server starts the match. Mecha names must
differ (`AlphaMind` ≠ `BetaMind`).

Watch the battle with [MechaMind_console](../MechaMind_console).

### Example actions

```json
{"pilot_name": "LLM_A", "turn": 3, "action": "SCAN", "scan_x": 50, "scan_y": 50, "energy": 15}
{"pilot_name": "LLM_A", "turn": 4, "action": "MOVE", "dx": 5, "dy": 5, "energy": 10}
{"pilot_name": "LLM_A", "turn": 10, "action": "FIRE", "target_x": 48, "target_y": 52, "energy": 18}
```

## Project layout

```
MechaMind_mcp/
├── mechamind_mcp/
│   ├── client.py     # WebSocket sessions + REST
│   ├── server.py     # MCP tool definitions
│   └── rules.py      # LLM-oriented rule summary
├── tests/
└── pyproject.toml
```

## Tests

```bash
pytest tests/
```

## Related

- [readme.md](../readme.md) — complete rules and WebSocket protocol
- [MechaMind_server](../MechaMind_server) — authoritative simulation
- [MechaMind_robot](../MechaMind_robot) — reference bot implementation
- [MechaMind_console](../MechaMind_console) — live spectator UI
