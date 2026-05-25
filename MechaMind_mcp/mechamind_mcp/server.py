"""Server MCP stdio — espone MechaMind come tool per LLM."""

from __future__ import annotations

import json
from typing import Any

from mcp.server.fastmcp import FastMCP

from .client import MechaMindHub, validate_build
from .rules import DEFAULT_BUILD, RULES_SUMMARY

mcp = FastMCP(
    "MechaMind",
    instructions=(
        "Tool per giocare a MechaMind (combattimento mecha a turni). "
        "Ogni LLM usa un pilot_name univoco. Flusso: register_pilot → "
        "wait_for_turn → submit_action. Due piloti registrati avviano una partita."
    ),
)

_hub = MechaMindHub()


def _json(data: Any) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False)


def _build_from_args(
    generator: int | None = None,
    hull: int | None = None,
    shields: int | None = None,
    cannon: int | None = None,
    propulsion: int | None = None,
    radar: int | None = None,
) -> dict[str, int]:
    base = dict(DEFAULT_BUILD)
    for key, val in (
        ("generator", generator),
        ("hull", hull),
        ("shields", shields),
        ("cannon", cannon),
        ("propulsion", propulsion),
        ("radar", radar),
    ):
        if val is not None:
            base[key] = val
    validate_build(base)
    return base


@mcp.tool()
async def mechamind_rules() -> str:
    """Restituisce le regole MechaMind sintetiche per decidere le azioni."""
    return RULES_SUMMARY


@mcp.tool()
async def mechamind_server_status() -> str:
    """Stato server MechaMind: lobby, partite attive, client connessi (REST GET /status)."""
    return _json(await _hub.server_status())


@mcp.tool()
async def mechamind_list_pilots() -> str:
    """Elenco piloti LLM registrati in questa sessione MCP."""
    return _json(_hub.list_pilots())


@mcp.tool()
async def mechamind_register_pilot(
    pilot_name: str,
    mecha_name: str,
    author: str = "LLM",
    version: str = "1.0.0",
    generator: int | None = None,
    hull: int | None = None,
    shields: int | None = None,
    cannon: int | None = None,
    propulsion: int | None = None,
    radar: int | None = None,
) -> str:
    """Registra un pilota LLM via WebSocket. Apre connessione e invia register.

    pilot_name: identificatore sessione MCP (es. LLM_A, LLM_B) — univoco per agente.
    mecha_name: nome mecha sul server — deve essere univoco tra i client connessi.
    build: 6 componenti che sommano a 100 (default bilanciato se omessi).
    Quando due mecha sono in lobby la partita parte automaticamente.
    """
    build = _build_from_args(generator, hull, shields, cannon, propulsion, radar)
    result = await _hub.register_pilot(
        pilot_name,
        mecha_name,
        build,
        author=author,
        version=version,
    )
    return _json(result)


@mcp.tool()
async def mechamind_wait_for_turn(
    pilot_name: str,
    timeout_seconds: int = 180,
) -> str:
    """Attende action_request per il pilota (è il tuo turno).

    Restituisce vehicle (posizione, HP, energia, build), last_scan, last_fire_feedback,
    turn e timeout_ms. Usa submit_action con lo stesso turn.
    """
    session = _hub.get(pilot_name)
    result = await session.wait_for_turn(float(timeout_seconds))
    return _json(result)


@mcp.tool()
async def mechamind_submit_action(
    pilot_name: str,
    turn: int,
    action: str,
    energy: int | None = None,
    dx: int | None = None,
    dy: int | None = None,
    target_x: int | None = None,
    target_y: int | None = None,
    scan_x: int | None = None,
    scan_y: int | None = None,
) -> str:
    """Invia azione turno via WebSocket.

    action: MOVE | FIRE | SCAN | IDLE
    MOVE: energy, dx, dy (|dx|+|dy| <= energy)
    FIRE: energy, target_x, target_y
    SCAN: energy (= raggio Manhattan), scan_x, scan_y (centro area)
  """
    session = _hub.get(pilot_name)
    result = await session.submit_action(
        turn,
        action,
        energy=energy,
        dx=dx,
        dy=dy,
        target_x=target_x,
        target_y=target_y,
        scan_x=scan_x,
        scan_y=scan_y,
    )
    return _json(result)


@mcp.tool()
async def mechamind_pilot_status(pilot_name: str) -> str:
    """Snapshot pilota: connessione, match_id, turno in attesa, ultimo result/gameover."""
    return _json(_hub.get(pilot_name).snapshot())


@mcp.tool()
async def mechamind_match_snapshot(pilot_name: str) -> str:
    """Snapshot REST partita del pilota (posizioni, HP — osservazione)."""
    session = _hub.get(pilot_name)
    if not session.match_id:
        return _json({"error": "Nessuna partita attiva per questo pilota"})
    data = await _hub.match_snapshot(session.match_id)
    return _json(data)


@mcp.tool()
async def mechamind_disconnect_pilot(pilot_name: str) -> str:
    """Chiude WebSocket e rimuove pilota dalla sessione MCP."""
    return _json(await _hub.disconnect_pilot(pilot_name))


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
