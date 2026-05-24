"""Regole MechaMind sintetiche per prompt LLM."""

RULES_SUMMARY = """
# MechaMind — regole essenziali per LLM

Griglia 100×100 (x,y da 0 a 99). Due veicoli. Vince chi porta la corazza avversaria a 0.

## Build (somma esattamente 100, ogni stato 5–70)
- generator: energia a inizio turno
- hull: HP struttura
- shields: assorbono danni prima della corazza
- cannon: max energia per FIRE
- propulsion: max energia per MOVE (|dx|+|dy| <= energia)
- radar: max energia (= raggio Manhattan) per SCAN

## Azioni (una per turno)
- MOVE: {action, energy, dx, dy}
- FIRE: {action, energy, target_x, target_y} — colpo se bersaglio = pos avversario
- SCAN: {action, energy, scan_x, scan_y} — raggio = energy; nemico trovato se distanza Manhattan <= raggio
- IDLE: {action} — nessuna azione

## Flusso MCP consigliato
1. register_pilot (nome pilota univoco per questo LLM)
2. wait_for_turn → ricevi vehicle, last_scan, last_fire_feedback, turn, timeout_ms
3. submit_action con turno corretto
4. Ripeti fino a gameover

## Strategia
- Nemico sconosciuto: muoviti verso (50,50) e scansiona con raggio alto
- last_scan.found=true → coordinate esatte nemico in x,y
- FIRE quando distanza Manhattan <= cannon e energia sufficiente
"""

DEFAULT_BUILD = {
    "generator": 25,
    "hull": 20,
    "shields": 10,
    "cannon": 20,
    "propulsion": 10,
    "radar": 15,
}

BUILD_COMPONENTS = (
    "generator",
    "hull",
    "shields",
    "cannon",
    "propulsion",
    "radar",
)
