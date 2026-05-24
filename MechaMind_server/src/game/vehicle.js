/**
 * Create initial vehicle state from a validated build.
 */
export function createVehicle(build, x, y) {
  return {
    x,
    y,
    hull: build.hull,
    hull_max: build.hull,
    shields: build.shields,
    shields_max: build.shields,
    energy: build.generator,
    build: { ...build },
    last_scan: null,
    last_fire_feedback: null,
    energyAllocation: null,
    destroyed: false,
  };
}

/**
 * Start-of-turn setup: produce energy, attempt shield regen.
 */
export function beginTurn(vehicle) {
  vehicle.energy = vehicle.build.generator;

  if (vehicle.shields < vehicle.shields_max && vehicle.energy >= 1) {
    vehicle.shields += 1;
    vehicle.energy -= 1;
  }
}

/**
 * Apply damage: shields first, then hull.
 * @returns {number} hull damage actually applied after shields
 */
export function applyDamage(vehicle, amount) {
  if (amount <= 0 || vehicle.destroyed) return 0;

  let remaining = amount;

  if (vehicle.shields > 0) {
    const absorbed = Math.min(vehicle.shields, remaining);
    vehicle.shields -= absorbed;
    remaining -= absorbed;
  }

  if (remaining > 0) {
    vehicle.hull -= remaining;
    if (vehicle.hull <= 0) {
      vehicle.hull = 0;
      vehicle.destroyed = true;
    }
  }

  return remaining;
}

export function manhattanDistance(x1, y1, x2, y2) {
  return Math.abs(x1 - x2) + Math.abs(y1 - y2);
}

/**
 * Area scan: radius equals energy invested. Opponent found if within Manhattan radius.
 * @returns {{ found: boolean, scan_x: number, scan_y: number, radius: number, x?: number, y?: number }}
 */
export function performScan(scanX, scanY, radius, opponentX, opponentY) {
  const base = { scan_x: scanX, scan_y: scanY, radius };
  const dist = manhattanDistance(scanX, scanY, opponentX, opponentY);

  if (dist <= radius) {
    return { found: true, x: opponentX, y: opponentY, ...base };
  }

  return { found: false, ...base };
}

export function vehicleStatePayload(vehicle, turn) {
  return {
    turn,
    vehicle: {
      x: vehicle.x,
      y: vehicle.y,
      hull: vehicle.hull,
      hull_max: vehicle.hull_max,
      shields: vehicle.shields,
      shields_max: vehicle.shields_max,
      energy: vehicle.energy,
      build: { ...vehicle.build },
    },
    last_scan: vehicle.last_scan,
    last_fire_feedback: vehicle.last_fire_feedback,
  };
}
