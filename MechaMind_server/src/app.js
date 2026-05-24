import express from 'express';
import { createServer as createHttpServer } from 'node:http';
import { WebSocketServer } from 'ws';
import { GameState } from './game/state.js';
import { loadConfig } from './config.js';
import { ClientGateway } from './ws/gateway.js';
import { attachWebSocket } from './ws/handler.js';
import { log } from './logger.js';

export function createApp(options = {}) {
  const config = loadConfig(options.configOverrides ?? {});
  const clientGateway =
    options.clientGateway ??
    new ClientGateway({ timeoutMs: config.turnTimeoutMs });

  const gameState =
    options.gameState ??
    new GameState({
      config,
      clientGateway,
      onMatchUpdate: options.onMatchUpdate,
    });

  const app = express();
  app.use(express.json());

  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      log.info('HTTP', `${req.method} ${req.originalUrl} → ${res.statusCode}`, {
        duration_ms: Date.now() - start,
      });
    });
    next();
  });

  app.get('/status', (_req, res) => {
    res.json(gameState.getStatusSummary());
  });

  app.get('/client/:id', (req, res) => {
    const client = gameState.clients.get(req.params.id);
    if (!client) {
      return res.status(404).json({ error: 'Client not found' });
    }
    return res.json({
      client_id: client.id,
      name: client.name,
      status: client.status,
      match_id: client.matchId,
      connected: clientGateway.isConnected(client.id),
    });
  });

  app.get('/match/:id', (req, res) => {
    const match = gameState.getMatch(req.params.id);
    if (!match) {
      return res.status(404).json({ error: 'Match not found' });
    }
    return res.json(match.snapshot());
  });

  app.get('/match/:id/history', (req, res) => {
    const match = gameState.getMatch(req.params.id);
    if (!match) {
      const last = gameState.lastFinishedMatch;
      if (last && last.id === req.params.id) {
        return res.json({ match_id: last.id, history: last.history });
      }
      return res.status(404).json({ error: 'Match not found' });
    }
    return res.json({ match_id: match.id, history: match.history });
  });

  app.post('/match/:id/end', (req, res) => {
    if (!isAdmin(req, config.adminToken)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const match = gameState.getMatch(req.params.id);
    if (!match) {
      return res.status(404).json({ error: 'Match not found' });
    }

    if (!match.forceEndDraw()) {
      return res.status(409).json({ error: 'Match is not running' });
    }

    log.warn('ADMIN', `Force-ending match ${req.params.id} as DRAW`);
    match.finishGameOver().catch(() => {});
    return res.json({ status: 'finished', outcome: 'DRAW' });
  });

  app.delete('/client/:id', (req, res) => {
    if (!isAdmin(req, config.adminToken)) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const result = gameState.removeClient(req.params.id);
    if (!result.ok) {
      return res.status(404).json({ error: result.error });
    }

    log.warn('ADMIN', `Removed client ${req.params.id}`);
    return res.status(200).json({ status: 'removed' });
  });

  return { app, gameState, config, clientGateway };
}

export function createServer(options = {}) {
  const { app, gameState, config, clientGateway } = createApp(options);
  const httpServer = createHttpServer(app);
  const wss = new WebSocketServer({ server: httpServer, path: '/ws' });
  attachWebSocket(wss, gameState, clientGateway);
  return { httpServer, app, gameState, config, clientGateway, wss };
}

function isAdmin(req, adminToken) {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  return token === adminToken;
}
