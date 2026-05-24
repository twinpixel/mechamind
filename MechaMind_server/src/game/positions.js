/**
 * Generate two starting positions with minimum Manhattan distance.
 */
export function generateStartPositions(gridSize, minDistance, rng = Math.random) {
  const maxAttempts = 1000;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const x1 = Math.floor(rng() * gridSize);
    const y1 = Math.floor(rng() * gridSize);
    const x2 = Math.floor(rng() * gridSize);
    const y2 = Math.floor(rng() * gridSize);

    const dist = Math.abs(x1 - x2) + Math.abs(y1 - y2);
    if (dist >= minDistance && !(x1 === x2 && y1 === y2)) {
      return [{ x: x1, y: y1 }, { x: x2, y: y2 }];
    }
  }

  return [
    { x: 0, y: 0 },
    { x: Math.min(minDistance, gridSize - 1), y: 0 },
  ];
}

/**
 * Randomize turn order for two client ids.
 */
export function randomizeTurnOrder(clientA, clientB, rng = Math.random) {
  return rng() < 0.5 ? [clientA, clientB] : [clientB, clientA];
}
