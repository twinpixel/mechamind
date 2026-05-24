# MechaMind Console

**Monitoring console** for MechaMind matches (planned).

## Purpose

Web or desktop UI to observe live matches using the server’s **read-only REST API**:

- `GET /status` — lobby and active games
- `GET /match/:id` — positions, HP, turn number
- `GET /match/:id/history` — turn-by-turn log

Admin operations (optional): force end match, remove client.

## Status

This repository is a **placeholder**. Implementation is not started yet.

## Until then

Use REST directly or server logs while developing:

```bash
curl http://127.0.0.1:3000/status
curl http://127.0.0.1:3000/match/<match_id>
```

## Related

- [MechaMind_server](../MechaMind_server) — server and API documentation
