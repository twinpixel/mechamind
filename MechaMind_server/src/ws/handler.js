import { validateRegistrationPayload } from '../validation/build.js';
import { log, clientLabel } from '../logger.js';
import { MSG } from './protocol.js';

export function attachWebSocket(wss, gameState, clientGateway) {
  wss.on('connection', (ws, req) => {
    const remote = req.socket.remoteAddress ?? 'unknown';
    log.info('WS', `New connection from ${remote}`);

    ws.on('message', (raw) => {
      let message;
      try {
        message = JSON.parse(raw.toString());
      } catch {
        log.warn('WS', 'Invalid JSON received', { raw: raw.toString().slice(0, 200) });
        clientGateway.sendRaw(ws, {
          type: MSG.ERROR,
          error: 'Invalid JSON message',
        });
        return;
      }

      const clientId = clientGateway.getClientId(ws);
      log.info('WS', `Message in: ${message.type}`, {
        client: clientId ? clientLabel(clientId) : 'unregistered',
        payload: summarizeInbound(message),
      });

      handleMessage(ws, message, gameState, clientGateway);
    });

    ws.on('close', () => {
      const clientId = clientGateway.getClientId(ws);
      log.info(
        'WS',
        `Connection closed${clientId ? `: ${clientLabel(clientId)}` : ''}`
      );
      clientGateway.unbindWs(ws);
      if (clientId) {
        gameState.handleDisconnect(clientId);
      }
    });

    ws.on('error', (err) => {
      log.error('WS', 'Socket error', { error: err.message });
    });
  });
}

function handleMessage(ws, message, gameState, clientGateway) {
  switch (message.type) {
    case MSG.REGISTER:
      return handleRegister(ws, message, gameState, clientGateway);
    case MSG.ACTION:
      return handleAction(ws, message, clientGateway);
    default:
      log.warn('WS', `Unknown message type: ${message.type}`);
      clientGateway.sendRaw(ws, {
        type: MSG.ERROR,
        error: `Unknown message type: ${message.type}`,
      });
  }
}

function handleRegister(ws, message, gameState, clientGateway) {
  if (clientGateway.getClientId(ws)) {
    log.warn('WS', 'Register rejected: already registered on connection');
    return clientGateway.sendRaw(ws, {
      type: MSG.ERROR,
      error: 'Already registered on this connection',
    });
  }

  const validation = validateRegistrationPayload(message);
  if (!validation.valid) {
    log.warn('WS', 'Register rejected: validation failed', {
      error: validation.error,
      field: validation.field,
      name: message.name,
    });
    return clientGateway.sendRaw(ws, {
      type: MSG.ERROR,
      error: validation.error,
      field: validation.field ?? undefined,
    });
  }

  const result = gameState.registerClient({
    name: message.name,
    version: message.version,
    author: message.author,
    build: validation.build,
  });

  if (!result.ok) {
    log.warn('WS', 'Register rejected', {
      name: message.name,
      error: result.error,
      field: result.field,
    });
    return clientGateway.sendRaw(ws, {
      type: MSG.ERROR,
      error: result.error,
      field: result.field,
    });
  }

  clientGateway.bindClient(result.client_id, ws, message.name);

  const connected = gameState.afterClientConnected(result.client_id);

  log.info('WS', `Registered mecha "${message.name}"`, {
    client_id: result.client_id,
    author: message.author,
    version: message.version,
    build: validation.build,
    status: connected.status,
    match_id: connected.match_id,
  });

  clientGateway.sendRaw(ws, {
    type: MSG.REGISTERED,
    client_id: result.client_id,
    status: connected.status,
    message:
      connected.status === 'in_match'
        ? 'Match started'
        : 'In lobby, waiting for opponent',
    match_id: connected.match_id,
  });
}

function handleAction(ws, message, clientGateway) {
  const clientId = clientGateway.getClientId(ws);
  if (!clientId) {
    log.warn('WS', 'Action rejected: not registered');
    return clientGateway.sendRaw(ws, {
      type: MSG.ERROR,
      error: 'Register before sending actions',
    });
  }

  if (!clientGateway.handleActionResponse(clientId, message)) {
    log.warn('WS', 'Action rejected: no pending request', {
      client: clientLabel(clientId),
      turn: message.turn,
      action: message.action,
    });
    return clientGateway.sendRaw(ws, {
      type: MSG.ERROR,
      error: 'No pending action for this turn',
    });
  }

  log.info('WS', `Action received from ${clientLabel(clientId)}`, {
    turn: message.turn,
    action: summarizeAction(message),
  });
}

function summarizeInbound(message) {
  if (message.type === MSG.REGISTER) {
    return {
      name: message.name,
      author: message.author,
      version: message.version,
      build: message.build,
    };
  }
  if (message.type === MSG.ACTION) {
    return summarizeAction(message);
  }
  return { type: message.type };
}

function summarizeAction(message) {
  const base = { action: message.action, energy: message.energy, turn: message.turn };
  if (message.action === 'MOVE') {
    return { ...base, dx: message.dx, dy: message.dy };
  }
  if (message.action === 'FIRE') {
    return { ...base, target_x: message.target_x, target_y: message.target_y };
  }
  if (message.action === 'SCAN') {
    return { ...base, scan_x: message.scan_x, scan_y: message.scan_y };
  }
  return base;
}
