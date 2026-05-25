# MechaMind MCP

Python **[Model Context Protocol](https://modelcontextprotocol.io)** server that exposes MechaMind as **tools for LLM agents**. Lets two LLMs (or an LLM vs a bot) play MechaMind through Cursor or any MCP-compatible client.

## Prerequisites

- Python ≥ 3.10
- MechaMind server running: `cd ../MechaMind_server && npm start`

## Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Cursor MCP configuration

Add to `.cursor/mcp.json` (or Cursor Settings → MCP):

```json
{
  "mcpServers": {
    "mechamind": {
      "command": "/absolute/path/to/MechaMind_mdc/.venv/bin/python",
      "args": ["-m", "mechamind_mcp.server"],
      "env": {
        "MECHAMIND_URL": "http://127.0.0.1:3000"
      }
    }
  }
}
```

Debug manually:

```bash
MECHAMIND_URL=http://127.0.0.1:3000 python -m mechamind_mcp.server
```

## MCP tools

| Tool | Description |
|------|-------------|
| `mechamind_rules` | Concise rules for the LLM |
| `mechamind_server_status` | `GET /status` |
| `mechamind_register_pilot` | WebSocket register (build + mecha name) |
| `mechamind_list_pilots` | Active pilots in this MCP session |
| `mechamind_wait_for_turn` | Block until `action_request` |
| `mechamind_submit_action` | Send MOVE / FIRE / SCAN / IDLE |
| `mechamind_pilot_status` | Pilot snapshot |
| `mechamind_match_snapshot` | REST match view |
| `mechamind_disconnect_pilot` | Close WebSocket |

## Two LLMs fighting

Use **two Cursor chats/agents** with the **same MCP server** but different `pilot_name` values.

### LLM A

1. Call `mechamind_rules`
2. `mechamind_register_pilot(pilot_name="LLM_A", mecha_name="AlphaMind")`
3. Loop: `mechamind_wait_for_turn("LLM_A")` → decide → `mechamind_submit_action(...)`

### LLM B

1. `mechamind_register_pilot(pilot_name="LLM_B", mecha_name="BetaMind")`
2. Same loop with `pilot_name="LLM_B"`

When the **second** mecha registers, the server starts the match. Mecha names must differ (`AlphaMind` ≠ `BetaMind`).

### Example actions

```json
{"pilot_name": "LLM_A", "turn": 3, "action": "SCAN", "scan_x": 50, "scan_y": 50, "energy": 15}
{"pilot_name": "LLM_A", "turn": 4, "action": "MOVE", "dx": 5, "dy": 5, "energy": 10}
{"pilot_name": "LLM_A", "turn": 10, "action": "FIRE", "target_x": 48, "target_y": 52, "energy": 18}
```

## Project layout

```
MechaMind_mdc/
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

- [MechaMind_server](../MechaMind_server) — authoritative rules in `MechaMind_Rules_v1.md`
- [MechaMind_robot](../MechaMind_robot) — reference bot implementation
