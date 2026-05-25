"""Client WebSocket + REST verso MechaMind server."""

from __future__ import annotations

import asyncio
import json
import os
from dataclasses import dataclass, field
from typing import Any
from urllib.parse import urlparse

import httpx
import websockets
from websockets.client import WebSocketClientProtocol

from .rules import BUILD_COMPONENTS, DEFAULT_BUILD


def http_base_from_env() -> str:
    return os.environ.get("MECHAMIND_URL", "http://127.0.0.1:3000").rstrip("/")


def ws_url_from_http(http_base: str) -> str:
    parsed = urlparse(http_base)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (443 if scheme == "wss" else 80)
    if (scheme == "ws" and port == 80) or (scheme == "wss" and port == 443):
        netloc = host
    else:
        netloc = f"{host}:{port}"
    return f"{scheme}://{netloc}/ws"


def validate_build(build: dict[str, int]) -> None:
    missing = [c for c in BUILD_COMPONENTS if c not in build]
    if missing:
        raise ValueError(f"build mancante: {', '.join(missing)}")
    total = sum(build[c] for c in BUILD_COMPONENTS)
    if total != 100:
        raise ValueError(f"build deve sommare a 100 (totale {total})")
    for c in BUILD_COMPONENTS:
        v = build[c]
        if not isinstance(v, int) or v < 5 or v > 70:
            raise ValueError(f"build.{c} deve essere intero 5–70")


@dataclass
class PilotSession:
    pilot_name: str
    http_base: str
    ws_url: str
    mecha_name: str | None = None
    client_id: str | None = None
    match_id: str | None = None
    status: str | None = None
    pending_action_request: dict[str, Any] | None = None
    last_result: dict[str, Any] | None = None
    last_gameover: dict[str, Any] | None = None
    last_error: dict[str, Any] | None = None
    last_match_started: dict[str, Any] | None = None

    _ws: WebSocketClientProtocol | None = field(default=None, repr=False)
    _listener: asyncio.Task | None = field(default=None, repr=False)
    _registered: asyncio.Event = field(default_factory=asyncio.Event, repr=False)
    _turn_ready: asyncio.Event = field(default_factory=asyncio.Event, repr=False)
    _lock: asyncio.Lock = field(default_factory=asyncio.Lock, repr=False)

    async def register(
        self,
        mecha_name: str,
        build: dict[str, int],
        *,
        author: str = "LLM",
        version: str = "1.0.0",
    ) -> dict[str, Any]:
        validate_build(build)
        self.mecha_name = mecha_name
        self._registered.clear()
        self._turn_ready.clear()

        if self._ws is not None:
            await self.disconnect()

        self._ws = await websockets.connect(self.ws_url)
        self._listener = asyncio.create_task(self._listen())

        await self._send(
            {
                "type": "register",
                "name": mecha_name,
                "version": version,
                "author": author,
                "build": build,
            }
        )

        try:
            await asyncio.wait_for(self._registered.wait(), timeout=10)
        except asyncio.TimeoutError as exc:
            raise TimeoutError("Timeout registrazione MechaMind") from exc

        return {
            "pilot_name": self.pilot_name,
            "mecha_name": mecha_name,
            "client_id": self.client_id,
            "status": self.status,
            "match_id": self.match_id,
        }

    async def wait_for_turn(self, timeout_seconds: float = 180) -> dict[str, Any]:
        if self.pending_action_request is not None:
            return self._turn_payload()

        self._turn_ready.clear()
        try:
            await asyncio.wait_for(self._turn_ready.wait(), timeout=timeout_seconds)
        except asyncio.TimeoutError:
            return {
                "status": "timeout",
                "pilot_name": self.pilot_name,
                "message": f"Nessun action_request entro {timeout_seconds}s",
                "last_result": self.last_result,
                "last_gameover": self.last_gameover,
            }

        return self._turn_payload()

    def _turn_payload(self) -> dict[str, Any]:
        req = self.pending_action_request or {}
        return {
            "status": "your_turn",
            "pilot_name": self.pilot_name,
            "turn": req.get("turn"),
            "timeout_ms": req.get("timeout_ms"),
            "vehicle": req.get("vehicle"),
            "last_scan": req.get("last_scan"),
            "last_fire_feedback": req.get("last_fire_feedback"),
            "match_id": self.match_id,
        }

    async def submit_action(
        self,
        turn: int,
        action: str,
        *,
        energy: int | None = None,
        dx: int | None = None,
        dy: int | None = None,
        target_x: int | None = None,
        target_y: int | None = None,
        scan_x: int | None = None,
        scan_y: int | None = None,
    ) -> dict[str, Any]:
        if self._ws is None:
            raise RuntimeError("Pilota non connesso — chiama register_pilot prima")

        payload: dict[str, Any] = {
            "type": "action",
            "turn": turn,
            "action": action.upper(),
        }
        if energy is not None:
            payload["energy"] = energy
        if action.upper() == "MOVE":
            payload["dx"] = dx or 0
            payload["dy"] = dy or 0
        elif action.upper() == "FIRE":
            payload["target_x"] = target_x if target_x is not None else 0
            payload["target_y"] = target_y if target_y is not None else 0
        elif action.upper() == "SCAN":
            payload["scan_x"] = scan_x if scan_x is not None else 0
            payload["scan_y"] = scan_y if scan_y is not None else 0

        await self._send(payload)
        self.pending_action_request = None
        self._turn_ready.clear()

        return {"status": "sent", "pilot_name": self.pilot_name, "payload": payload}

    def snapshot(self) -> dict[str, Any]:
        return {
            "pilot_name": self.pilot_name,
            "mecha_name": self.mecha_name,
            "client_id": self.client_id,
            "match_id": self.match_id,
            "status": self.status,
            "has_pending_turn": self.pending_action_request is not None,
            "last_result": self.last_result,
            "last_gameover": self.last_gameover,
            "last_error": self.last_error,
        }

    async def disconnect(self) -> None:
        if self._listener is not None:
            self._listener.cancel()
            try:
                await self._listener
            except asyncio.CancelledError:
                pass
            self._listener = None
        if self._ws is not None:
            await self._ws.close()
            self._ws = None

    async def _send(self, payload: dict[str, Any]) -> None:
        if self._ws is None:
            raise RuntimeError("WebSocket non connesso")
        async with self._lock:
            await self._ws.send(json.dumps(payload))

    async def _listen(self) -> None:
        assert self._ws is not None
        try:
            async for raw in self._ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                await self._dispatch(msg)
        except websockets.ConnectionClosed:
            pass

    async def _dispatch(self, msg: dict[str, Any]) -> None:
        msg_type = msg.get("type")
        if msg_type == "registered":
            self.client_id = msg.get("client_id")
            self.status = msg.get("status")
            self.match_id = msg.get("match_id")
            self._registered.set()
        elif msg_type == "match_started":
            self.last_match_started = msg
            self.match_id = msg.get("match_id")
            self.status = "in_match"
        elif msg_type == "action_request":
            self.pending_action_request = msg
            self._turn_ready.set()
        elif msg_type == "result":
            self.last_result = msg
        elif msg_type == "gameover":
            self.last_gameover = msg
            self.status = "finished"
        elif msg_type == "error":
            self.last_error = msg


class MechaMindHub:
    """Gestisce più piloti LLM sullo stesso server MCP."""

    def __init__(self, http_base: str | None = None) -> None:
        self.http_base = (http_base or http_base_from_env()).rstrip("/")
        self.ws_url = ws_url_from_http(self.http_base)
        self._pilots: dict[str, PilotSession] = {}

    def get(self, pilot_name: str) -> PilotSession:
        if pilot_name not in self._pilots:
            raise KeyError(f"Pilota '{pilot_name}' non registrato")
        return self._pilots[pilot_name]

    async def register_pilot(
        self,
        pilot_name: str,
        mecha_name: str,
        build: dict[str, int] | None = None,
        *,
        author: str = "LLM",
        version: str = "1.0.0",
    ) -> dict[str, Any]:
        if pilot_name in self._pilots:
            await self._pilots[pilot_name].disconnect()

        session = PilotSession(
            pilot_name=pilot_name,
            http_base=self.http_base,
            ws_url=self.ws_url,
        )
        result = await session.register(
            mecha_name,
            build or dict(DEFAULT_BUILD),
            author=author,
            version=version,
        )
        self._pilots[pilot_name] = session
        return result

    async def server_status(self) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(f"{self.http_base}/status")
            res.raise_for_status()
            return res.json()

    async def match_snapshot(self, match_id: str) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(f"{self.http_base}/match/{match_id}")
            res.raise_for_status()
            return res.json()

    async def client_status(self, client_id: str) -> dict[str, Any]:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(f"{self.http_base}/client/{client_id}")
            res.raise_for_status()
            return res.json()

    def list_pilots(self) -> list[dict[str, Any]]:
        return [s.snapshot() for s in self._pilots.values()]

    async def disconnect_pilot(self, pilot_name: str) -> dict[str, Any]:
        session = self.get(pilot_name)
        await session.disconnect()
        del self._pilots[pilot_name]
        return {"status": "disconnected", "pilot_name": pilot_name}
