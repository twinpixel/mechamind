import test from "node:test";
import assert from "node:assert/strict";

import { planConvergeSearch, simulateConvergence } from "../src/strategies/convergeSearch.js";
import { Pathfinder } from "../src/modules/pathfinder.js";

const BUILD = { radar: 15, propulsion: 10, generator: 25, cannon: 20 };

test("piano ricerca: lontano dal centro → MOVE", () => {
  const pf = new Pathfinder();
  const plan = planConvergeSearch(
    { x: 10, y: 10, build: BUILD, energy: 25 },
    pf,
    1
  );
  assert.equal(plan.kind, "move");
});

test("piano ricerca: al centro → SCAN su (50,50)", () => {
  const pf = new Pathfinder();
  const plan = planConvergeSearch(
    { x: 50, y: 50, build: BUILD, energy: 25 },
    pf,
    1
  );
  assert.equal(plan.kind, "scan");
  assert.equal(plan.scanX, 50);
  assert.equal(plan.scanY, 50);
  assert.equal(plan.energy, 15);
});

test("simulazione: due bot agli angoli si avvicinano entro 80 turni", () => {
  const result = simulateConvergence({
    startA: { x: 3, y: 7 },
    startB: { x: 97, y: 88 },
    build: BUILD,
    PathfinderClass: Pathfinder,
  });
  assert.equal(result.found, true, `non trovati: dist=${result.dist} turn=${result.turn}`);
  assert.ok(result.turn <= 25, `troppo lenti: ${result.turn} turni`);
});

test("simulazione: spawn minimo dist=20 si incontrano", () => {
  const result = simulateConvergence({
    startA: { x: 10, y: 10 },
    startB: { x: 30, y: 10 },
    build: BUILD,
    PathfinderClass: Pathfinder,
  });
  assert.equal(result.found, true);
});
