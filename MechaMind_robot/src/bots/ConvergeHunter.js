import { Mecha } from "../Mecha.js";
import { Memory } from "../modules/memory.js";
import { Tracker } from "../modules/tracker.js";
import { Pathfinder } from "../modules/pathfinder.js";
import { planConvergeSearch } from "../strategies/convergeSearch.js";

/**
 * Bot base con ricerca garantita (converge al centro) + combattimento.
 */
export class ConvergeHunter extends Mecha {
  memory = new Memory();
  tracker = new Tracker({ staleTurns: 8 });
  pf = new Pathfinder();

  #lastAction = null;

  onTurn({ vehicle, lastScan, lastFireFeedback, turn }) {
    this.tracker.updateFromScan(lastScan);
    if (lastFireFeedback && this.#lastAction?.action === "FIRE") {
      this.tracker.updateFromFireFeedback(
        lastFireFeedback,
        { x: vehicle.x, y: vehicle.y },
        { x: this.#lastAction.target_x, y: this.#lastAction.target_y }
      );
    }

    const guess = this.tracker.bestGuess();
    const enemyKnown = this.tracker.isKnown(turn);

    let action;
    if (enemyKnown && guess) {
      action = this.#combat(vehicle, guess);
    } else {
      action = this.#applySearchPlan(vehicle, turn);
    }

    this.memory.record(
      { turn, vehicle, last_scan: lastScan, last_fire_feedback: lastFireFeedback },
      action
    );
    this.#lastAction = action;
    return action;
  }

  #combat(vehicle, target) {
    const dist = this.pf.manhattanDistance(vehicle, target);

    if (dist <= vehicle.build.cannon && vehicle.energy >= 1) {
      const energy = Math.min(vehicle.build.cannon, vehicle.energy);
      this._log(`FIRE (${target.x},${target.y}) e=${energy}`);
      return this.fire(target.x, target.y, energy);
    }

    const moveEnergy = Math.min(vehicle.build.propulsion, vehicle.energy);
    if (moveEnergy >= 1) {
      const { dx, dy, energy } = this.pf.moveToward(vehicle, target, moveEnergy);
      this._log(`MOVE → nemico (${target.x},${target.y}) dx=${dx} dy=${dy}`);
      return this.move(dx, dy, energy);
    }

    return this.idle();
  }

  #applySearchPlan(vehicle, turn) {
    const plan = planConvergeSearch(vehicle, this.pf, turn);
    this._log(plan.label);

    switch (plan.kind) {
      case "move":
        return this.move(plan.dx, plan.dy, plan.energy);
      case "scan":
        return this.scan(plan.scanX, plan.scanY, plan.energy);
      default:
        return this.idle();
    }
  }

  onResult(result) {
    this.memory.updateLastResult(result);
  }

  onGameOver({ outcome, reason, turn }) {
    console.log(`\n══ ${this.name} — fine partita ══`);
    console.log(`Esito: ${outcome} (${reason}) al turno ${turn}`);
    console.log(`Turni: ${this.memory.size} | Scan: ${this.memory.scanHistory().length}`);
    const hits = this.memory.scanHistory().filter((t) => t.lastScan?.found);
    console.log(`Scan riusciti: ${hits.length} | Colpi: ${this.memory.fireHistory().length}`);
  }
}
