import { Connection } from "./connection.js";

/**
 * Classe base del framework MechaMind.
 *
 * Estendila, implementa `onTurn()` e chiama `.connect()`.
 */
export class Mecha {
  name;
  version = "1.0.0";
  author = "anonymous";
  build;

  vehicle = null;
  lastScan = null;
  lastFireFeedback = null;
  turn = 0;
  matchId = null;
  clientId = null;

  #connection = null;
  #verbose;

  constructor({ name, build, version, author, verbose = true }) {
    if (!name) throw new Error("options.name è obbligatorio");
    if (!build) throw new Error("options.build è obbligatorio");

    this.name = name;
    this.build = build;
    if (version) this.version = version;
    if (author) this.author = author;
    this.#verbose = verbose;
  }

  connect(url) {
    this.#connection = new Connection(url, this);
    this.#connection.connect();
  }

  disconnect() {
    this.#connection?.disconnect();
  }

  move(dx, dy, energy) {
    return { action: "MOVE", dx, dy, energy };
  }

  fire(x, y, energy) {
    return { action: "FIRE", target_x: x, target_y: y, energy };
  }

  scan(x, y, energy) {
    return { action: "SCAN", scan_x: x, scan_y: y, energy };
  }

  idle() {
    return { action: "IDLE" };
  }

  onTurn(ctx) {
    throw new Error(`${this.constructor.name} deve implementare onTurn(ctx)`);
  }

  onRegistered(msg) {}
  onMatchStarted(msg) {}
  onResult(result) {}
  onGameOver(msg) {}
  onDisconnected() {}
  onServerError(msg) {}

  _log(msg) {
    if (this.#verbose) {
      console.log(`[${this.name}][T${this.turn}] ${msg}`);
    }
  }

  _buildRegisterPayload() {
    return {
      type: "register",
      name: this.name,
      version: this.version,
      author: this.author,
      build: this.build,
    };
  }

  _onRegistered(msg) {
    this.clientId = msg.client_id;
    this.matchId = msg.match_id;
    this._log(`Registrato. Status: ${msg.status}. client_id: ${this.clientId}`);
    this.onRegistered(msg);
  }

  _onMatchStarted(msg) {
    this.matchId = msg.match_id;
    this._log(`Partita iniziata! match_id: ${this.matchId}`);
    this.onMatchStarted(msg);
  }

  async _computeAction(msg) {
    this.turn = msg.turn;
    this.vehicle = msg.vehicle;
    this.lastScan = msg.last_scan ?? null;
    this.lastFireFeedback = msg.last_fire_feedback ?? null;

    this._log(
      `Turno ${this.turn} | HP: ${this.vehicle.hull}/${this.vehicle.hull_max} ` +
        `| Scudi: ${this.vehicle.shields}/${this.vehicle.shields_max} ` +
        `| Energia: ${this.vehicle.energy} ` +
        `| Pos: (${this.vehicle.x}, ${this.vehicle.y})`
    );

    return await this.onTurn({
      vehicle: this.vehicle,
      lastScan: this.lastScan,
      lastFireFeedback: this.lastFireFeedback,
      turn: this.turn,
    });
  }

  _onResult(result) {
    this._log(
      `Result T${result.turn} | Danno subito: ${result.damage_taken} ` +
        `| Azione avversario: ${result.opponent_action?.action ?? "?"}`
    );
    this.onResult(result);
  }

  _onGameOver(msg) {
    this._log(`GAME OVER — ${msg.outcome} (${msg.reason}) al turno ${msg.turn}`);
    this.onGameOver(msg);
  }

  _onDisconnected() {
    this.onDisconnected();
  }

  _onServerError(msg) {
    this.onServerError(msg);
  }
}
