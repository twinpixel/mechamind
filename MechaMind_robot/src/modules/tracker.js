/**
 * Modulo opzionale: tracking della posizione avversaria.
 */
export class Tracker {
  #estimates = [];
  #staleTurns = 5;

  constructor({ staleTurns = 5 } = {}) {
    this.#staleTurns = staleTurns;
  }

  updateFromScan(lastScan) {
    if (!lastScan || !lastScan.found) return;
    this.#estimates.push({
      x: lastScan.x,
      y: lastScan.y,
      turn: lastScan.turn,
      source: "scan",
      confidence: 1.0,
    });
  }

  updateFromFireFeedback(feedback, shooterPos, targetPos) {
    if (!feedback) return;

    if (feedback.hit) {
      this.#estimates.push({
        x: targetPos.x,
        y: targetPos.y,
        turn: feedback.turn,
        source: "fire_hit",
        confidence: 1.0,
      });
    } else {
      this.#estimates.push({
        x: null,
        y: null,
        distance: feedback.distance,
        fromX: shooterPos.x,
        fromY: shooterPos.y,
        turn: feedback.turn,
        source: "fire_miss",
        confidence: 0,
      });
    }
  }

  bestGuess() {
    const withPos = this.#estimates.filter((e) => e.x !== null).at(-1);
    return withPos ?? null;
  }

  isKnown(currentTurn) {
    const guess = this.bestGuess();
    if (!guess) return false;
    return currentTurn - guess.turn <= this.#staleTurns;
  }

  missHistory(sinceTurn = 0) {
    return this.#estimates.filter(
      (e) => e.source === "fire_miss" && e.turn >= sinceTurn
    );
  }

  filterByMissDistance(candidates, sinceTurn = 0) {
    const misses = this.missHistory(sinceTurn);
    if (misses.length === 0) return candidates;

    return candidates.filter(({ x, y }) =>
      misses.every((m) => {
        const dist = Math.abs(x - m.fromX) + Math.abs(y - m.fromY);
        return dist === m.distance;
      })
    );
  }

  reset() {
    this.#estimates = [];
  }

  get size() {
    return this.#estimates.length;
  }
}
