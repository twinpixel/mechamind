import test from "node:test";
import assert from "node:assert/strict";

import { Memory } from "../src/modules/memory.js";
import { Tracker } from "../src/modules/tracker.js";
import { Pathfinder } from "../src/modules/pathfinder.js";
import { Mecha } from "../src/Mecha.js";

test("Pathfinder moveToward rispetta energia Manhattan", () => {
  const pf = new Pathfinder();
  const step = pf.moveToward({ x: 10, y: 10 }, { x: 20, y: 30 }, 8);
  assert.equal(step.dx + step.dy, step.energy);
  assert.ok(step.energy <= 8);
});

test("Pathfinder cellsInRadius conta celle rombo", () => {
  const pf = new Pathfinder();
  const cells = pf.cellsInRadius({ x: 50, y: 50 }, 2);
  assert.equal(cells.length, 13);
});

test("Tracker aggiorna posizione da scan", () => {
  const tracker = new Tracker();
  tracker.updateFromScan({ found: true, x: 40, y: 60, turn: 3 });
  const guess = tracker.bestGuess();
  assert.deepEqual(guess, { x: 40, y: 60, turn: 3, source: "scan", confidence: 1 });
  assert.equal(tracker.isKnown(4), true);
  assert.equal(tracker.isKnown(10), false);
});

test("Memory registra turni e danni", () => {
  const memory = new Memory();
  memory.record({ turn: 1, vehicle: { x: 1, y: 2 } }, { action: "IDLE" });
  memory.updateLastResult({ damage_taken: 5 });
  assert.equal(memory.size, 1);
  assert.equal(memory.totalDamageTaken(), 5);
});

test("Mecha espone helper azioni", () => {
  class Dummy extends Mecha {
    onTurn() {
      return this.idle();
    }
  }
  const bot = new Dummy({
    name: "T",
    build: { generator: 20, hull: 20, shields: 20, cannon: 20, propulsion: 10, radar: 10 },
  });
  assert.deepEqual(bot.scan(1, 2, 5), { action: "SCAN", scan_x: 1, scan_y: 2, energy: 5 });
});
