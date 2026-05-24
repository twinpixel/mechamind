import { applyDamage, manhattanDistance, performScan } from './vehicle.js';
import { validateAction } from '../validation/action.js';

/**
 * Execute a single validated action for a vehicle against an opponent.
 */
export function executeAction(action, vehicle, opponent, gridSize) {
  const valid = validateAction(action, vehicle, gridSize);

  if (valid.action === 'IDLE') {
    vehicle.energy = 0;
    return {
      energySpent: 0,
      moved: false,
      damageDealt: 0,
      fireFeedback: null,
      scanResult: null,
      action: valid,
    };
  }

  const requestedEnergy = valid.energy ?? 0;
  const energySpent = Math.min(requestedEnergy, vehicle.energy);
  vehicle.energy -= energySpent;

  let moved = false;
  let damageDealt = 0;
  let fireFeedback = null;
  let scanResult = null;

  switch (valid.action) {
    case 'MOVE': {
      if (
        energySpent >= requestedEnergy &&
        energySpent <= vehicle.build.propulsion &&
        Math.abs(valid.dx) + Math.abs(valid.dy) <= energySpent
      ) {
        const nx = vehicle.x + valid.dx;
        const ny = vehicle.y + valid.dy;
        if (!(nx === opponent.x && ny === opponent.y)) {
          vehicle.x = nx;
          vehicle.y = ny;
          moved = true;
        }
      }
      break;
    }
    case 'FIRE': {
      if (energySpent > 0 && energySpent <= vehicle.build.cannon) {
        const dist = manhattanDistance(
          valid.target_x,
          valid.target_y,
          opponent.x,
          opponent.y
        );
        const hit =
          valid.target_x === opponent.x && valid.target_y === opponent.y;
        fireFeedback = { hit, distance: dist };
        vehicle.last_fire_feedback = { ...fireFeedback, turn: null };

        if (hit) {
          const hullBefore = opponent.hull;
          const shieldsBefore = opponent.shields;
          applyDamage(opponent, energySpent);
          damageDealt = hullBefore - opponent.hull + (shieldsBefore - opponent.shields);
        }
      }
      break;
    }
    case 'SCAN': {
      if (energySpent > 0 && energySpent <= vehicle.build.radar) {
        const radius = energySpent;
        scanResult = performScan(
          valid.scan_x,
          valid.scan_y,
          radius,
          opponent.x,
          opponent.y
        );
        vehicle.last_scan = { ...scanResult, turn: null };
      }
      break;
    }
    default:
      break;
  }

  vehicle.energy = 0;
  return {
    energySpent,
    moved,
    damageDealt,
    fireFeedback,
    scanResult,
    action: valid,
  };
}
