import { v4 as uuidv4 } from 'uuid';
import { createVehicle, beginTurn, vehicleStatePayload } from './vehicle.js';
import { executeAction } from './engine.js';
import { generateStartPositions, randomizeTurnOrder } from './positions.js';
import { extractActionFromMessage } from '../validation/build.js';
import { GAME_OUTCOMES } from '../constants.js';
import { log, clientLabel, matchLabel } from '../logger.js';

export class Match {
  constructor({
    id,
    clients,
    config,
    clientGateway,
    onFinished,
    rng = Math.random,
  }) {
    this.id = id;
    this.clients = clients;
    this.config = config;
    this.clientGateway = clientGateway;
    this.onFinished = onFinished;
    this.rng = rng;

    this.status = 'running';
    this.turn = 0;
    this.history = [];
    this.winnerId = null;
    this.endReason = null;
    this.finishedAt = null;

    const positions = generateStartPositions(
      config.gridSize,
      config.minStartDistance,
      rng
    );
    this.turnOrder = randomizeTurnOrder(clients[0].id, clients[1].id, rng);

    this.vehicles = {};
    clients.forEach((client, index) => {
      this.vehicles[client.id] = createVehicle(
        client.build,
        positions[index].x,
        positions[index].y
      );
    });

    this.clientMap = Object.fromEntries(clients.map((c) => [c.id, c]));

    log.debug('MATCH', `Match ${matchLabel(this.id)} initialized`, {
      turn_order: this.turnOrder.map((id) => this.#label(id)),
      spawns: clients.map((c, i) => ({
        client: this.#label(c.id),
        x: positions[i].x,
        y: positions[i].y,
      })),
    });
  }

  #label(clientId) {
    return clientLabel(clientId, this.clientMap[clientId]?.name);
  }

  opponentId(clientId) {
    return this.turnOrder.find((id) => id !== clientId);
  }

  snapshot() {
    return {
      id: this.id,
      status: this.status,
      turn: this.turn,
      turnOrder: [...this.turnOrder],
      clients: this.turnOrder.map((id) => ({
        client_id: id,
        name: this.clientMap[id].name,
        position: { x: this.vehicles[id].x, y: this.vehicles[id].y },
        hull: this.vehicles[id].hull,
        hull_max: this.vehicles[id].hull_max,
        shields: this.vehicles[id].shields,
        shields_max: this.vehicles[id].shields_max,
        destroyed: this.vehicles[id].destroyed,
      })),
      winner_id: this.winnerId,
      end_reason: this.endReason,
    };
  }

  async runTurn() {
    if (this.status !== 'running') return;

    this.turn += 1;
    log.info('MATCH', `${matchLabel(this.id)} — turn ${this.turn} started`);

    const turnRecord = {
      turn: this.turn,
      actions: {},
      results: {},
    };

    for (const clientId of this.turnOrder) {
      const vehicle = this.vehicles[clientId];
      const opponentId = this.opponentId(clientId);
      const opponent = this.vehicles[opponentId];

      if (vehicle.destroyed || opponent.destroyed) continue;

      beginTurn(vehicle);

      const state = vehicleStatePayload(vehicle, this.turn);

      const response = await this.clientGateway.requestAction(clientId, state);

      let action = { action: 'IDLE' };
      if (response.ok && response.data) {
        action = extractActionFromMessage(response.data);
      } else if (!response.ok) {
        if (this.status !== 'running') {
          return;
        }
        log.warn('MATCH', `${matchLabel(this.id)} turn ${this.turn}: forfeit ${this.#label(clientId)}`, {
          reason: response.error,
        });
        this.#finishForfeit(opponentId, clientId, response.error === 'timeout' ? 'timeout' : 'forfeit');
        return;
      }

      const outcome = executeAction(
        action,
        vehicle,
        opponent,
        this.config.gridSize
      );

      if (vehicle.last_fire_feedback) {
        vehicle.last_fire_feedback.turn = this.turn;
      }
      if (vehicle.last_scan) {
        vehicle.last_scan.turn = this.turn;
      }

      turnRecord.actions[clientId] = outcome.action;
      turnRecord.results[clientId] = {
        energy_spent: outcome.energySpent,
        moved: outcome.moved,
        damage_dealt: outcome.damageDealt,
        fire_feedback: outcome.fireFeedback,
        scan_result: outcome.scanResult,
      };

      log.info('MATCH', `${matchLabel(this.id)} turn ${this.turn}: ${this.#label(clientId)} → ${action.action}`, {
        energy_spent: outcome.energySpent,
        moved: outcome.moved,
        damage_dealt: outcome.damageDealt,
        position: { x: vehicle.x, y: vehicle.y },
        hull: vehicle.hull,
        shields: vehicle.shields,
        fire_feedback: outcome.fireFeedback,
        scan_result: outcome.scanResult,
      });

      if (vehicle.destroyed && opponent.destroyed) {
        log.info('MATCH', `${matchLabel(this.id)} ended: simultaneous destruction`);
        this.#finishDraw('simultaneous_destruction');
        this.history.push(turnRecord);
        return;
      }
      if (opponent.destroyed) {
        log.info('MATCH', `${matchLabel(this.id)} ended: ${this.#label(clientId)} wins by destruction`);
        this.#finishWin(clientId, 'destruction');
        this.history.push(turnRecord);
        await this.#sendTurnResults(turnRecord);
        return;
      }
    }

    this.history.push(turnRecord);
    await this.#sendTurnResults(turnRecord);

    if (this.turn >= this.config.maxTurns) {
      log.info('MATCH', `${matchLabel(this.id)} reached max turns (${this.config.maxTurns})`);
      this.#finishByMaxTurns();
    }

    log.debug('MATCH', `${matchLabel(this.id)} turn ${this.turn} completed`);
  }

  async #sendTurnResults(turnRecord) {
    for (const clientId of this.turnOrder) {
      const vehicle = this.vehicles[clientId];
      const opponentId = this.opponentId(clientId);
      const myResult = turnRecord.results[clientId] ?? null;
      const opponentAction = turnRecord.actions[opponentId] ?? null;

      const payload = {
        turn: this.turn,
        vehicle: {
          x: vehicle.x,
          y: vehicle.y,
          hull: vehicle.hull,
          hull_max: vehicle.hull_max,
          shields: vehicle.shields,
          shields_max: vehicle.shields_max,
          energy: vehicle.energy,
          build: { ...vehicle.build },
        },
        your_action: myResult,
        opponent_action: opponentAction
          ? { action: opponentAction.action }
          : null,
        damage_taken: this.#damageTakenThisTurn(clientId, turnRecord),
      };

      await this.clientGateway.sendResult(clientId, payload);
    }
  }

  #damageTakenThisTurn(clientId, turnRecord) {
    const opponentId = this.opponentId(clientId);
    const oppResult = turnRecord.results[opponentId];
    if (!oppResult || !oppResult.fire_feedback?.hit) return 0;
    return oppResult.energy_spent ?? 0;
  }

  async finishGameOver() {
    log.info('MATCH', `${matchLabel(this.id)} sending gameover`, {
      status: this.status,
      winner: this.winnerId ? this.#label(this.winnerId) : null,
      reason: this.endReason,
      turn: this.turn,
    });

    for (const clientId of this.turnOrder) {
      const outcome = this.#outcomeForClient(clientId);
      await this.clientGateway.sendGameOver(clientId, {
        match_id: this.id,
        outcome,
        reason: this.endReason,
        turn: this.turn,
        vehicle: {
          hull: this.vehicles[clientId].hull,
          shields: this.vehicles[clientId].shields,
        },
      });
    }
    if (this.onFinished) {
      this.onFinished(this);
    }
  }

  #outcomeForClient(clientId) {
    if (this.endReason === 'draw' || this.endReason === 'simultaneous_destruction') {
      return GAME_OUTCOMES.DRAW;
    }
    if (this.winnerId === clientId) return GAME_OUTCOMES.WIN;
    if (this.winnerId && this.winnerId !== clientId) return GAME_OUTCOMES.LOSE;
    return GAME_OUTCOMES.DRAW;
  }

  #finishWin(winnerId, reason) {
    this.status = 'finished';
    this.winnerId = winnerId;
    this.endReason = reason;
    this.finishedAt = Date.now();
    log.info('MATCH', `${matchLabel(this.id)} finished — WIN ${this.#label(winnerId)}`, { reason });
  }

  #finishDraw(reason) {
    this.status = 'finished';
    this.winnerId = null;
    this.endReason = reason === 'simultaneous_destruction' ? 'simultaneous_destruction' : 'draw';
    this.finishedAt = Date.now();
    log.info('MATCH', `${matchLabel(this.id)} finished — DRAW`, { reason: this.endReason });
  }

  #finishForfeit(winnerId, loserId, reason) {
    this.status = 'finished';
    this.winnerId = winnerId;
    this.endReason = reason;
    this.finishedAt = Date.now();
    this.vehicles[loserId].destroyed = true;
    log.info('MATCH', `${matchLabel(this.id)} finished — forfeit`, {
      winner: this.#label(winnerId),
      loser: this.#label(loserId),
      reason,
    });
  }

  #finishByMaxTurns() {
    const [a, b] = this.turnOrder;
    const hullA = this.vehicles[a].hull;
    const hullB = this.vehicles[b].hull;

    this.status = 'finished';
    this.finishedAt = Date.now();
    this.endReason = 'max_turns';

    if (hullA > hullB) this.winnerId = a;
    else if (hullB > hullA) this.winnerId = b;
    else this.winnerId = null;

    log.info('MATCH', `${matchLabel(this.id)} finished — max turns`, {
      winner: this.winnerId ? this.#label(this.winnerId) : null,
      hull: {
        [this.#label(a)]: hullA,
        [this.#label(b)]: hullB,
      },
    });
  }

  forceEndDraw() {
    if (this.status !== 'running') return false;
    this.#finishDraw('admin_end');
    return true;
  }

  forceEndForfeit(clientId) {
    if (this.status !== 'running') return false;
    const opponentId = this.opponentId(clientId);
    this.#finishForfeit(opponentId, clientId, 'forfeit');
    return true;
  }
}

export function createMatch(options) {
  return new Match({ id: uuidv4(), ...options });
}
