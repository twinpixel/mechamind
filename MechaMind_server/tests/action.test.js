import { validateAction, normalizeAction } from '../src/validation/action.js';
import { createVehicle } from '../src/game/vehicle.js';
import { VALID_BUILD } from './helpers/fixtures.js';

function makeVehicle() {
  const v = createVehicle(VALID_BUILD, 10, 10);
  v.energy = 12;
  return v;
}

describe('action validation', () => {
  test('normalizes invalid actions to IDLE', () => {
    expect(normalizeAction(null)).toEqual({ action: 'IDLE' });
    expect(normalizeAction({ action: 'JUMP' })).toEqual({ action: 'IDLE' });
  });

  test('accepts valid MOVE within energy and bounds', () => {
    const v = makeVehicle();
    v.energy = 12;
    const action = validateAction(
      { action: 'MOVE', energy: 5, dx: 2, dy: 3 },
      v,
      100
    );
    expect(action.action).toBe('MOVE');
  });

  test('rejects MOVE exceeding Manhattan distance', () => {
    const v = makeVehicle();
    v.energy = 12;
    const action = validateAction(
      { action: 'MOVE', energy: 3, dx: 2, dy: 2 },
      v,
      100
    );
    expect(action.action).toBe('IDLE');
  });

  test('rejects MOVE out of grid bounds', () => {
    const v = createVehicle(VALID_BUILD, 0, 0);
    v.energy = 12;
    const action = validateAction(
      { action: 'MOVE', energy: 5, dx: -1, dy: 0 },
      v,
      100
    );
    expect(action.action).toBe('IDLE');
  });

  test('rejects FIRE with energy above cannon build', () => {
    const v = makeVehicle();
    v.energy = 30;
    const action = validateAction(
      { action: 'FIRE', energy: 19, target_x: 20, target_y: 20 },
      v,
      100
    );
    expect(action.action).toBe('IDLE');
  });

  test('accepts valid FIRE', () => {
    const v = makeVehicle();
    v.energy = 20;
    const action = validateAction(
      { action: 'FIRE', energy: 10, target_x: 50, target_y: 50 },
      v,
      100
    );
    expect(action.action).toBe('FIRE');
  });

  test('accepts valid SCAN with energy and coordinates', () => {
    const v = makeVehicle();
    v.energy = 10;
    const action = validateAction(
      { action: 'SCAN', energy: 5, scan_x: 20, scan_y: 30 },
      v,
      100
    );
    expect(action).toEqual({
      action: 'SCAN',
      energy: 5,
      scan_x: 20,
      scan_y: 30,
    });
  });

  test('rejects SCAN with zero energy', () => {
    const v = makeVehicle();
    v.energy = 10;
    const action = validateAction(
      { action: 'SCAN', energy: 0, scan_x: 10, scan_y: 10 },
      v,
      100
    );
    expect(action.action).toBe('IDLE');
  });

  test('rejects SCAN with energy above radar build', () => {
    const v = makeVehicle();
    v.energy = 20;
    const action = validateAction(
      { action: 'SCAN', energy: 11, scan_x: 10, scan_y: 10 },
      v,
      100
    );
    expect(action.action).toBe('IDLE');
  });

  test('rejects SCAN out of grid bounds', () => {
    const v = makeVehicle();
    v.energy = 10;
    const action = validateAction(
      { action: 'SCAN', energy: 5, scan_x: 100, scan_y: 10 },
      v,
      100
    );
    expect(action.action).toBe('IDLE');
  });
});
