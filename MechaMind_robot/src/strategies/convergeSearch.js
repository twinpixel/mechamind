/**
 * Strategia di ricerca garantita: entrambi i bot convergono su (50,50)
 * e scansionano il centro arena quando sono abbastanza vicini.
 *
 * Due bot con la stessa strategia si incontrano sempre entro pochi turni
 * (griglia 100×100, propulsion 10, radar 15).
 */

const ARENA_CENTER = { x: 50, y: 50 };

/**
 * @param {object} vehicle - stato veicolo da action_request
 * @param {import('../modules/pathfinder.js').Pathfinder} pf
 * @param {number} turn - turno corrente (per sweep di backup)
 * @returns {{ kind: 'move'|'scan'|'idle', dx?, dy?, energy?, scanX?, scanY?, label: string }}
 */
export function planConvergeSearch(vehicle, pf, turn) {
  const radar = Math.min(vehicle.build.radar, vehicle.energy);
  const propulsion = Math.min(vehicle.build.propulsion, vehicle.energy);
  const dist = pf.manhattanDistance(vehicle, ARENA_CENTER);

  // 1) Lontano dal centro → avvicinati sempre (entrambi i bot convergono)
  if (dist > 1 && propulsion >= 1) {
    const step = pf.moveToward(vehicle, ARENA_CENTER, propulsion);
    return {
      kind: "move",
      dx: step.dx,
      dy: step.dy,
      energy: step.energy,
      label: `MOVE → centro dist=${dist} → (${step.newPos.x},${step.newPos.y})`,
    };
  }

  // 2) Vicino al centro → scan sul punto d'incontro (50,50) raggio max
  if (radar >= 1) {
    return {
      kind: "scan",
      scanX: ARENA_CENTER.x,
      scanY: ARENA_CENTER.y,
      energy: radar,
      label: `SCAN centro arena (${ARENA_CENTER.x},${ARENA_CENTER.y}) r=${radar}`,
    };
  }

  // 3) Backup: scan intorno a sé con offset alternato
  const offsets = [
    [0, 0],
    [3, 0],
    [-3, 0],
    [0, 3],
    [0, -3],
  ];
  const [ox, oy] = offsets[turn % offsets.length];
  const c = pf.clamp({ x: vehicle.x + ox, y: vehicle.y + oy });
  if (radar >= 1) {
    return {
      kind: "scan",
      scanX: c.x,
      scanY: c.y,
      energy: radar,
      label: `SCAN sweep (${c.x},${c.y}) r=${radar}`,
    };
  }

  return { kind: "idle", label: "IDLE (senza energia)" };
}

/**
 * Simula due bot finché uno entrerebbe nel rombo scan dell'altro al centro.
 * @returns {{ turn: number, a: object, b: object }}
 */
export function simulateConvergence({
  startA = { x: 5, y: 5 },
  startB = { x: 95, y: 95 },
  build = { radar: 15, propulsion: 10, generator: 25 },
  maxTurns = 80,
  PathfinderClass,
} = {}) {
  const pf = new PathfinderClass();
  let a = { ...startA };
  let b = { ...startB };
  const vehicle = (pos) => ({ ...pos, build, energy: build.generator });

  for (let turn = 1; turn <= maxTurns; turn++) {
    const dist = pf.manhattanDistance(a, b);
    const radar = build.radar;

    // Entrambi al centro: scan (50,50) r=radar si vedono
    if (dist <= radar * 2) {
      return { turn, a, b, dist, found: true };
    }

    for (const [pos, other] of [
      [a, b],
      [b, a],
    ]) {
      const plan = planConvergeSearch(vehicle(pos), pf, turn);
      if (plan.kind === "move") {
        pos.x += plan.dx;
        pos.y += plan.dy;
      }
    }

    if (pf.manhattanDistance(a, b) <= radar) {
      return { turn, a, b, dist: pf.manhattanDistance(a, b), found: true };
    }
  }

  return { turn: maxTurns, a, b, dist: pf.manhattanDistance(a, b), found: false };
}

export { ARENA_CENTER };
