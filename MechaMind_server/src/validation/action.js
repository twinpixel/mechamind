import { ACTIONS } from '../constants.js';

/**
 * Normalize client action; invalid actions become IDLE.
 * @param {object|null|undefined} raw
 * @returns {{ action: string, energy?: number, dx?: number, dy?: number, target_x?: number, target_y?: number, scan_x?: number, scan_y?: number }}
 */
export function normalizeAction(raw) {
  if (!raw || typeof raw !== 'object' || !ACTIONS.includes(raw.action)) {
    return { action: 'IDLE' };
  }

  switch (raw.action) {
    case 'MOVE':
      return {
        action: 'MOVE',
        energy: toInt(raw.energy, 0),
        dx: toInt(raw.dx, 0),
        dy: toInt(raw.dy, 0),
      };
    case 'FIRE':
      return {
        action: 'FIRE',
        energy: toInt(raw.energy, 0),
        target_x: toInt(raw.target_x, 0),
        target_y: toInt(raw.target_y, 0),
      };
    case 'SCAN':
      return {
        action: 'SCAN',
        energy: toInt(raw.energy, 0),
        scan_x: toInt(raw.scan_x, 0),
        scan_y: toInt(raw.scan_y, 0),
      };
    case 'IDLE':
    default:
      return { action: 'IDLE' };
  }
}

function toInt(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}

/**
 * Validate action against vehicle state; returns IDLE if invalid.
 */
export function validateAction(action, vehicle, gridSize) {
  const normalized = normalizeAction(action);

  if (normalized.action === 'IDLE') {
    return normalized;
  }

  const energy = normalized.energy ?? 0;
  if (energy < 0 || energy > vehicle.energy) {
    return { action: 'IDLE' };
  }

  const { build } = vehicle;

  switch (normalized.action) {
    case 'MOVE': {
      if (energy > build.propulsion) return { action: 'IDLE' };
      const { dx, dy } = normalized;
      if (Math.abs(dx) + Math.abs(dy) > energy) return { action: 'IDLE' };
      const nx = vehicle.x + dx;
      const ny = vehicle.y + dy;
      if (nx < 0 || ny < 0 || nx >= gridSize || ny >= gridSize) {
        return { action: 'IDLE' };
      }
      return normalized;
    }
    case 'FIRE': {
      if (energy > build.cannon) return { action: 'IDLE' };
      const { target_x, target_y } = normalized;
      if (
        target_x < 0 ||
        target_y < 0 ||
        target_x >= gridSize ||
        target_y >= gridSize
      ) {
        return { action: 'IDLE' };
      }
      return normalized;
    }
    case 'SCAN': {
      if (energy <= 0 || energy > build.radar) return { action: 'IDLE' };
      const { scan_x, scan_y } = normalized;
      if (
        scan_x < 0 ||
        scan_y < 0 ||
        scan_x >= gridSize ||
        scan_y >= gridSize
      ) {
        return { action: 'IDLE' };
      }
      return normalized;
    }
    default:
      return { action: 'IDLE' };
  }
}
