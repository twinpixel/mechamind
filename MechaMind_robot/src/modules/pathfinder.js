/**
 * Modulo opzionale: utilità di movimento sulla griglia MechaMind.
 */
export class Pathfinder {
  #gridSize;

  constructor({ gridSize = 100 } = {}) {
    this.#gridSize = gridSize;
  }

  manhattanDistance(a, b) {
    return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
  }

  clamp({ x, y }) {
    return {
      x: Math.max(0, Math.min(this.#gridSize - 1, x)),
      y: Math.max(0, Math.min(this.#gridSize - 1, y)),
    };
  }

  isInRange(from, to, range) {
    return this.manhattanDistance(from, to) <= range;
  }

  moveToward(from, to, energy) {
    let remX = to.x - from.x;
    let remY = to.y - from.y;
    let budget = energy;

    let dx = 0;
    let dy = 0;

    if (Math.abs(remX) >= Math.abs(remY)) {
      const stepX = Math.sign(remX) * Math.min(Math.abs(remX), budget);
      dx = stepX;
      budget -= Math.abs(stepX);
      const stepY = Math.sign(remY) * Math.min(Math.abs(remY), budget);
      dy = stepY;
    } else {
      const stepY = Math.sign(remY) * Math.min(Math.abs(remY), budget);
      dy = stepY;
      budget -= Math.abs(stepY);
      const stepX = Math.sign(remX) * Math.min(Math.abs(remX), budget);
      dx = stepX;
    }

    const newPos = this.clamp({ x: from.x + dx, y: from.y + dy });
    dx = newPos.x - from.x;
    dy = newPos.y - from.y;

    return { dx, dy, energy: Math.abs(dx) + Math.abs(dy), newPos };
  }

  moveAway(from, threat, energy) {
    const fleeTarget = this.clamp({
      x: from.x + (from.x - threat.x),
      y: from.y + (from.y - threat.y),
    });
    return this.moveToward(from, fleeTarget, energy);
  }

  cellsInRadius(center, radius) {
    const cells = [];
    for (let dx = -radius; dx <= radius; dx++) {
      for (let dy = -radius; dy <= radius; dy++) {
        if (Math.abs(dx) + Math.abs(dy) <= radius) {
          cells.push(this.clamp({ x: center.x + dx, y: center.y + dy }));
        }
      }
    }
    return cells;
  }

  midpoint(a, b) {
    return this.clamp({
      x: Math.round((a.x + b.x) / 2),
      y: Math.round((a.y + b.y) / 2),
    });
  }
}
