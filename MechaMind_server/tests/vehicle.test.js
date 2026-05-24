import {
  applyDamage,
  beginTurn,
  createVehicle,
  manhattanDistance,
  performScan,
} from '../src/game/vehicle.js';
import { VALID_BUILD } from './helpers/fixtures.js';

describe('vehicle mechanics', () => {
  test('createVehicle initializes hull and shields from build', () => {
    const v = createVehicle(VALID_BUILD, 5, 7);
    expect(v.x).toBe(5);
    expect(v.y).toBe(7);
    expect(v.hull).toBe(25);
    expect(v.shields).toBe(15);
    expect(v.energy).toBe(20);
  });

  test('applyDamage absorbs shields before hull', () => {
    const v = createVehicle(VALID_BUILD, 0, 0);
    applyDamage(v, 10);
    expect(v.shields).toBe(5);
    expect(v.hull).toBe(25);
    applyDamage(v, 20);
    expect(v.shields).toBe(0);
    expect(v.hull).toBe(10);
  });

  test('applyDamage destroys vehicle at zero hull', () => {
    const v = createVehicle(VALID_BUILD, 0, 0);
    v.shields = 0;
    applyDamage(v, 25);
    expect(v.hull).toBe(0);
    expect(v.destroyed).toBe(true);
  });

  test('beginTurn produces energy and regenerates shields', () => {
    const v = createVehicle(VALID_BUILD, 0, 0);
    v.shields = 10;
    v.energy = 0;
    beginTurn(v);
    expect(v.energy).toBe(19);
    expect(v.shields).toBe(11);
  });

  test('beginTurn skips shield regen without energy', () => {
    const v = createVehicle({ ...VALID_BUILD, generator: 0 }, 0, 0);
    v.shields = 10;
    v.energy = 0;
    beginTurn(v);
    expect(v.shields).toBe(10);
  });

  test('performScan finds opponent on radius boundary', () => {
    expect(performScan(10, 10, 5, 12, 8)).toEqual({
      found: true,
      x: 12,
      y: 8,
      scan_x: 10,
      scan_y: 10,
      radius: 5,
    });
  });

  test('performScan misses when opponent outside radius', () => {
    expect(performScan(0, 0, 3, 10, 10)).toEqual({
      found: false,
      scan_x: 0,
      scan_y: 0,
      radius: 3,
    });
  });

  test('manhattanDistance computes correctly', () => {
    expect(manhattanDistance(0, 0, 3, 4)).toBe(7);
  });
});
