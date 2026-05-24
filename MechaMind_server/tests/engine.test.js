import { executeAction } from '../src/game/engine.js';
import { createVehicle } from '../src/game/vehicle.js';
import { VALID_BUILD } from './helpers/fixtures.js';

describe('game engine', () => {
  test('MOVE updates position when cell is free', () => {
    const actor = createVehicle(VALID_BUILD, 10, 10);
    actor.energy = 12;
    const opponent = createVehicle(VALID_BUILD, 50, 50);

    const result = executeAction(
      { action: 'MOVE', energy: 5, dx: 2, dy: 3 },
      actor,
      opponent,
      100
    );

    expect(result.moved).toBe(true);
    expect(actor.x).toBe(12);
    expect(actor.y).toBe(13);
    expect(result.energySpent).toBe(5);
  });

  test('MOVE blocked by opponent still consumes energy', () => {
    const actor = createVehicle(VALID_BUILD, 10, 10);
    actor.energy = 12;
    const opponent = createVehicle(VALID_BUILD, 12, 13);

    const result = executeAction(
      { action: 'MOVE', energy: 5, dx: 2, dy: 3 },
      actor,
      opponent,
      100
    );

    expect(result.moved).toBe(false);
    expect(actor.x).toBe(10);
    expect(result.energySpent).toBe(5);
  });

  test('FIRE hit deals damage through shields then hull', () => {
    const actor = createVehicle(VALID_BUILD, 10, 10);
    actor.energy = 18;
    const opponent = createVehicle(VALID_BUILD, 20, 20);
    opponent.shields = 5;

    const result = executeAction(
      { action: 'FIRE', energy: 10, target_x: 20, target_y: 20 },
      actor,
      opponent,
      100
    );

    expect(result.fireFeedback.hit).toBe(true);
    expect(opponent.shields).toBe(0);
    expect(opponent.hull).toBe(20);
    expect(result.damageDealt).toBe(10);
  });

  test('FIRE miss still consumes energy and reports distance', () => {
    const actor = createVehicle(VALID_BUILD, 10, 10);
    actor.energy = 18;
    const opponent = createVehicle(VALID_BUILD, 20, 20);

    const result = executeAction(
      { action: 'FIRE', energy: 8, target_x: 25, target_y: 25 },
      actor,
      opponent,
      100
    );

    expect(result.fireFeedback.hit).toBe(false);
    expect(result.fireFeedback.distance).toBe(10);
    expect(opponent.hull).toBe(25);
    expect(result.energySpent).toBe(8);
  });

  test('SCAN finds opponent within Manhattan radius', () => {
    const actor = createVehicle(VALID_BUILD, 0, 0);
    actor.energy = 10;
    const opponent = createVehicle(VALID_BUILD, 12, 8);

    const result = executeAction(
      { action: 'SCAN', energy: 5, scan_x: 10, scan_y: 10 },
      actor,
      opponent,
      100
    );

    expect(result.scanResult).toEqual({
      found: true,
      x: 12,
      y: 8,
      scan_x: 10,
      scan_y: 10,
      radius: 5,
    });
    expect(actor.last_scan).toEqual({
      found: true,
      x: 12,
      y: 8,
      scan_x: 10,
      scan_y: 10,
      radius: 5,
      turn: null,
    });
  });

  test('SCAN misses when opponent outside radius', () => {
    const actor = createVehicle(VALID_BUILD, 0, 0);
    actor.energy = 10;
    const opponent = createVehicle(VALID_BUILD, 50, 50);

    const result = executeAction(
      { action: 'SCAN', energy: 5, scan_x: 0, scan_y: 0 },
      actor,
      opponent,
      100
    );

    expect(result.scanResult).toEqual({
      found: false,
      scan_x: 0,
      scan_y: 0,
      radius: 5,
    });
    expect(actor.last_scan.found).toBe(false);
  });

  test('SCAN with zero energy is IDLE', () => {
    const actor = createVehicle(VALID_BUILD, 0, 0);
    actor.energy = 10;
    const opponent = createVehicle(VALID_BUILD, 5, 5);

    const result = executeAction(
      { action: 'SCAN', energy: 0, scan_x: 0, scan_y: 0 },
      actor,
      opponent,
      100
    );

    expect(result.action.action).toBe('IDLE');
    expect(result.scanResult).toBeNull();
  });

  test('invalid action treated as IDLE', () => {
    const actor = createVehicle(VALID_BUILD, 10, 10);
    actor.energy = 12;
    const opponent = createVehicle(VALID_BUILD, 50, 50);

    const result = executeAction(
      { action: 'FIRE', energy: 100, target_x: 50, target_y: 50 },
      actor,
      opponent,
      100
    );

    expect(result.action.action).toBe('IDLE');
    expect(result.energySpent).toBe(0);
  });
});
