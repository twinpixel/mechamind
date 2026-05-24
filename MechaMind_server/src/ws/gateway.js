import { log, clientLabel } from '../logger.js';
import { MSG } from './protocol.js';

/**
 * Routes game messages to connected clients over WebSocket.
 */
export class ClientGateway {
  constructor({ timeoutMs = 5000 } = {}) {
    this.timeoutMs = timeoutMs;
    /** @type {Map<string, import('ws').WebSocket>} */
    this.connections = new Map();
    /** @type {Map<import('ws').WebSocket, string>} */
    this.wsToClient = new Map();
    /** @type {Map<string, { turn: number, finish: Function, timer: NodeJS.Timeout }>} */
    this.pendingActions = new Map();
    /** @type {Map<string, string>} */
    this.clientNames = new Map();
  }

  setClientName(clientId, name) {
    if (name) this.clientNames.set(clientId, name);
  }

  bindClient(clientId, ws, name) {
    this.connections.set(clientId, ws);
    this.wsToClient.set(ws, clientId);
    if (name) this.clientNames.set(clientId, name);
    log.info('GATEWAY', `Client bound: ${clientLabel(clientId, name)}`);
  }

  getClientId(ws) {
    return this.wsToClient.get(ws) ?? null;
  }

  unbindWs(ws) {
    const clientId = this.wsToClient.get(ws);
    if (!clientId) return;

    log.info('GATEWAY', `Client unbound: ${clientLabel(clientId, this.clientNames.get(clientId))}`);
    this.connections.delete(clientId);
    this.wsToClient.delete(ws);
    this.clientNames.delete(clientId);
    this.#failPending(clientId, 'disconnected');
  }

  isConnected(clientId) {
    const ws = this.connections.get(clientId);
    return ws?.readyState === 1;
  }

  send(clientId, message) {
    const ws = this.connections.get(clientId);
    if (!ws || ws.readyState !== 1) {
      log.warn('GATEWAY', `Send failed — not connected: ${clientLabel(clientId, this.clientNames.get(clientId))}`, {
        type: message.type,
      });
      return false;
    }

    log.info('GATEWAY', `Message out → ${clientLabel(clientId, this.clientNames.get(clientId))}: ${message.type}`, {
      payload: summarizeOutbound(message),
    });
    ws.send(JSON.stringify(message));
    return true;
  }

  sendRaw(ws, message) {
    if (ws.readyState !== 1) return false;
    const clientId = this.getClientId(ws);
    log.info(
      'GATEWAY',
      `Message out → ${clientId ? clientLabel(clientId, this.clientNames.get(clientId)) : 'unregistered'}: ${message.type}`,
      { payload: summarizeOutbound(message) }
    );
    ws.send(JSON.stringify(message));
    return true;
  }

  async requestAction(clientId, state) {
    log.info('GATEWAY', `Requesting action from ${clientLabel(clientId, this.clientNames.get(clientId))}`, {
      turn: state.turn,
      position: { x: state.vehicle?.x, y: state.vehicle?.y },
      energy: state.vehicle?.energy,
      hull: state.vehicle?.hull,
      shields: state.vehicle?.shields,
    });

    const sent = this.send(clientId, {
      type: MSG.ACTION_REQUEST,
      turn: state.turn,
      vehicle: state.vehicle,
      last_scan: state.last_scan,
      last_fire_feedback: state.last_fire_feedback,
      timeout_ms: this.timeoutMs,
    });

    if (!sent) {
      log.warn('GATEWAY', `Action request failed — ${clientLabel(clientId, this.clientNames.get(clientId))} not connected`);
      return { ok: false, error: 'not_connected' };
    }

    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        this.pendingActions.delete(clientId);
        log.warn('GATEWAY', `Action timeout for ${clientLabel(clientId, this.clientNames.get(clientId))}`, {
          turn: state.turn,
          timeoutMs: this.timeoutMs,
        });
        resolve({ ok: false, error: 'timeout' });
      }, this.timeoutMs);

      this.pendingActions.set(clientId, {
        turn: state.turn,
        finish: resolve,
        timer,
      });
    });
  }

  handleActionResponse(clientId, message) {
    const pending = this.pendingActions.get(clientId);
    if (!pending || pending.turn !== message.turn) {
      return false;
    }

    clearTimeout(pending.timer);
    this.pendingActions.delete(clientId);
    pending.finish({ ok: true, data: message });
    return true;
  }

  async sendResult(clientId, payload) {
    this.send(clientId, { type: MSG.RESULT, ...payload });
    return { ok: true };
  }

  async sendGameOver(clientId, payload) {
    this.send(clientId, { type: MSG.GAMEOVER, ...payload });
    return { ok: true };
  }

  notifyMatchStarted(clientIds, matchId) {
    log.info('GATEWAY', `Notifying match start`, {
      match_id: matchId,
      clients: clientIds.map((id) => clientLabel(id, this.clientNames.get(id))),
    });
    for (const clientId of clientIds) {
      this.send(clientId, {
        type: MSG.MATCH_STARTED,
        match_id: matchId,
      });
    }
  }

  #failPending(clientId, reason) {
    const pending = this.pendingActions.get(clientId);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pendingActions.delete(clientId);
    log.warn('GATEWAY', `Pending action cancelled for ${clientLabel(clientId, this.clientNames.get(clientId))}`, {
      reason,
      turn: pending.turn,
    });
    pending.finish({ ok: false, error: reason });
  }
}

function summarizeOutbound(message) {
  switch (message.type) {
    case MSG.ACTION_REQUEST:
      return {
        turn: message.turn,
        position: { x: message.vehicle?.x, y: message.vehicle?.y },
        energy: message.vehicle?.energy,
        timeout_ms: message.timeout_ms,
      };
    case MSG.RESULT:
      return {
        turn: message.turn,
        damage_taken: message.damage_taken,
        hull: message.vehicle?.hull,
        shields: message.vehicle?.shields,
      };
    case MSG.GAMEOVER:
      return {
        outcome: message.outcome,
        reason: message.reason,
        turn: message.turn,
      };
    case MSG.REGISTERED:
      return {
        client_id: message.client_id,
        status: message.status,
        match_id: message.match_id,
      };
    case MSG.MATCH_STARTED:
      return { match_id: message.match_id };
    case MSG.ERROR:
      return { error: message.error, field: message.field };
    default:
      return { type: message.type };
  }
}
