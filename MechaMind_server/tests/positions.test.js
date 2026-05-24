import {
  generateStartPositions,
  randomizeTurnOrder,
} from '../src/game/positions.js';

describe('positions', () => {
  test('generateStartPositions respects minimum distance', () => {
    const rng = () => 0.1;
    const [a, b] = generateStartPositions(100, 20, rng);
    const dist = Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
    expect(dist).toBeGreaterThanOrEqual(20);
  });

  test('randomizeTurnOrder includes both clients', () => {
    const order = randomizeTurnOrder('a', 'b', () => 0.9);
    expect(order.sort()).toEqual(['a', 'b']);
  });
});
