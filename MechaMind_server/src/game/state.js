import { v4 as uuidv4 } from 'uuid';
import { createMatch } from './match.js';
import { log, clientLabel, matchLabel } from '../logger.js';

export class GameState {
  constructor({ config, clientGateway, onMatchUpdate } = {}) {
    this.config = config;
    this.clientGateway = clientGateway;
    this.onMatchUpdate = onMatchUpdate ?? (() => {});

    this.startedAt = Date.now();
    this.lobby = new Map();
    this.matches = new Map();
    this.clients = new Map();
    this.lastFinishedMatch = null;
  }

  get uptimeMs() {
    return Date.now() - this.startedAt;
  }

  registerClient({ name, version, author, build }) {
    if ([...this.clients.values()].some((c) => c.name === name)) {
      return {
        ok: false,
        error: 'Mecha name must be unique in the current session',
        field: 'name',
      };
    }

    const client = {
      id: uuidv4(),
      name,
      version,
      author,
      build,
      status: 'waiting',
      matchId: null,
      registeredAt: Date.now(),
    };

    this.clients.set(client.id, client);
    this.lobby.set(client.id, client);

    log.info('LOBBY', `${name} joined lobby`, {
      client_id: client.id,
      lobby_count: this.lobby.size,
    });

    return {
      ok: true,
      client_id: client.id,
      status: client.status,
      message: 'In lobby, waiting for opponent',
      match_id: client.matchId,
    };
  }

  /** Call after the WebSocket is bound — starts a match only when both lobby clients are connected. */
  afterClientConnected(clientId) {
    this.#tryStartMatch();
    const client = this.clients.get(clientId);
    return {
      status: client?.status ?? 'waiting',
      match_id: client?.matchId ?? null,
    };
  }

  handleDisconnect(clientId) {
    const client = this.clients.get(clientId);
    log.warn('LOBBY', `Client disconnected: ${clientLabel(clientId, client?.name)}`);
    this.removeClient(clientId, { disconnected: true });
  }

  removeClient(clientId, { disconnected = false } = {}) {
    const client = this.clients.get(clientId);
    if (!client) return { ok: false, error: 'Client not found' };

    log.info('LOBBY', `Removing client ${clientLabel(clientId, client.name)}`, {
      disconnected,
      in_match: Boolean(client.matchId),
    });

    this.lobby.delete(clientId);

    if (client.matchId) {
      const match = this.matches.get(client.matchId);
      if (match && match.status === 'running') {
        log.warn('MATCH', `Forfeit due to client removal in ${matchLabel(client.matchId)}`, {
          client: clientLabel(clientId, client.name),
        });
        match.forceEndForfeit(clientId);
        match.finishGameOver().catch(() => {});
      }
    }

    this.clients.delete(clientId);
    return { ok: true, disconnected };
  }

  getMatch(matchId) {
    return this.matches.get(matchId) ?? null;
  }

  getStatusSummary() {
    const activeMatches = [...this.matches.values()].filter(
      (m) => m.status === 'running'
    ).length;

    const connectedClients = [...this.clients.keys()].filter((id) =>
      this.clientGateway.isConnected(id)
    ).length;

    return {
      uptime_ms: this.uptimeMs,
      lobby_count: this.lobby.size,
      active_matches: activeMatches,
      total_matches: this.matches.size,
      registered_clients: this.clients.size,
      connected_clients: connectedClients,
    };
  }

  #tryStartMatch() {
    if (this.lobby.size < 2) return;

    const waiting = [...this.lobby.values()].slice(0, 2);
    const allConnected = waiting.every((c) =>
      this.clientGateway.isConnected(c.id)
    );

    if (!allConnected) {
      log.debug('LOBBY', 'Waiting for all lobby clients to connect before starting match', {
        waiting: waiting.map((c) => ({
          name: c.name,
          connected: this.clientGateway.isConnected(c.id),
        })),
      });
      return;
    }

    waiting.forEach((c) => this.lobby.delete(c.id));

    const match = createMatch({
      clients: waiting,
      config: this.config,
      clientGateway: this.clientGateway,
      onFinished: (finished) => {
        this.lastFinishedMatch = finished;
        this.onMatchUpdate(finished);
      },
    });

    waiting.forEach((c) => {
      c.status = 'in_match';
      c.matchId = match.id;
    });

    this.matches.set(match.id, match);

    log.info('MATCH', `Match started: ${matchLabel(match.id)}`, {
      match_id: match.id,
      clients: waiting.map((c) => ({
        id: c.id,
        name: c.name,
        position: {
          x: match.vehicles[c.id].x,
          y: match.vehicles[c.id].y,
        },
      })),
      turn_order: match.turnOrder.map((id) => clientLabel(id, this.clients.get(id)?.name)),
    });

    for (const c of waiting) {
      this.clientGateway.setClientName(c.id, c.name);
    }

    this.clientGateway.notifyMatchStarted(
      waiting.map((c) => c.id),
      match.id
    );
    this.#startMatchLoop(match);
  }

  #startMatchLoop(match) {
    const tick = async () => {
      if (match.status !== 'running') {
        await match.finishGameOver();
        return;
      }

      try {
        await match.runTurn();
      } catch (err) {
        log.error('MATCH', `Turn error in ${matchLabel(match.id)}`, {
          error: err.message,
          turn: match.turn,
        });
        return;
      }

      if (match.status !== 'running') {
        await match.finishGameOver();
        return;
      }

      setImmediate(tick);
    };

    tick();
  }

  destroy() {
    for (const match of this.matches.values()) {
      if (match.status === 'running') {
        match.status = 'finished';
        match.endReason = 'aborted';
      }
    }
  }
}
