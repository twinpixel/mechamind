import test from "node:test";
import assert from "node:assert/strict";

import { Pathfinder } from "../src/modules/pathfinder.js";

const SEARCH_HUBS = [
  { x: 50, y: 50 },
  { x: 25, y: 25 },
  { x: 75, y: 25 },
];

test("due bot lontani: MOVE riduce distanza verso hub", () => {
  const pf = new Pathfinder();
  const a = { x: 5, y: 5 };
  const b = { x: 95, y: 95 };
  const hub = { x: 50, y: 50 };

  const stepA = pf.moveToward(a, hub, 10);
  const stepB = pf.moveToward(b, hub, 10);

  assert.ok(pf.manhattanDistance(stepA.newPos, hub) < pf.manhattanDistance(a, hub));
  assert.ok(pf.manhattanDistance(stepB.newPos, hub) < pf.manhattanDistance(b, hub));
});

test("scan r=15 da (50,50) non raggiunge spawn agli angoli", () => {
  const pf = new Pathfinder();
  const center = { x: 50, y: 50 };
  const corner = { x: 5, y: 5 };
  assert.ok(pf.manhattanDistance(center, corner) > 15);
});

test("midpoint scan verso hub copre area diversa ogni turno", () => {
  const pf = new Pathfinder();
  const vehicle = { x: 10, y: 10 };
  const hub0 = SEARCH_HUBS[0];
  const hub1 = SEARCH_HUBS[1];
  const c0 = pf.midpoint(vehicle, hub0);
  const c1 = pf.midpoint(vehicle, hub1);
  assert.notDeepEqual(c0, c1);
});
