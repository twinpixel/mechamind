/**
 * Modulo opzionale: memoria dei turni passati.
 */
export class Memory {
  #turns = [];

  record(request, action, result = null) {
    this.#turns.push({
      turn: request.turn,
      vehicle: structuredClone(request.vehicle),
      lastScan: request.last_scan ?? null,
      lastFireFeedback: request.last_fire_feedback ?? null,
      action: structuredClone(action),
      result: result ? structuredClone(result) : null,
      timestamp: Date.now(),
    });
  }

  updateLastResult(result) {
    if (this.#turns.length === 0) return;
    this.#turns[this.#turns.length - 1].result = structuredClone(result);
  }

  all() {
    return this.#turns;
  }

  lastN(n) {
    return this.#turns.slice(-n);
  }

  current() {
    return this.#turns.at(-1) ?? null;
  }

  previous() {
    return this.#turns.at(-2) ?? null;
  }

  scanHistory() {
    return this.#turns.filter((t) => t.action.action === "SCAN");
  }

  fireHistory(hitFilter = null) {
    return this.#turns.filter((t) => {
      if (t.action.action !== "FIRE") return false;
      if (hitFilter === null) return true;
      const hit = t.result?.your_action?.fire_feedback?.hit ?? t.lastFireFeedback?.hit;
      return hit === hitFilter;
    });
  }

  totalDamageTaken() {
    return this.#turns.reduce((sum, t) => sum + (t.result?.damage_taken ?? 0), 0);
  }

  get size() {
    return this.#turns.length;
  }

  reset() {
    this.#turns = [];
  }
}
