import WebSocket from 'ws';
import { createServer } from '../src/app.js';
import { MSG } from '../src/ws/protocol.js';
import { alternateBuild, registrationMessage } from './helpers/fixtures.js';

function connect(port) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function collectMessages(ws, minCount, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    const messages = [];
    const timer = setTimeout(() => {
      reject(new Error(`Timeout: got ${messages.length}/${minCount} messages`));
    }, timeoutMs);

    ws.on('message', (raw) => {
      messages.push(JSON.parse(raw.toString()));
      if (messages.length >= minCount) {
        clearTimeout(timer);
        resolve(messages);
      }
    });
  });
}

describe('WebSocket API', () => {
  let httpServer;
  let wss;
  let gameState;
  let port;

  beforeEach(async () => {
    ({ httpServer, gameState, wss } = createServer({
      configOverrides: { maxTurns: 500, turnTimeoutMs: 2000 },
    }));

    await new Promise((resolve) => {
      httpServer.listen(0, '127.0.0.1', resolve);
    });
    port = httpServer.address().port;
  });

  afterEach(async () => {
    gameState.destroy();
    await new Promise((resolve) => wss.close(resolve));
    await new Promise((resolve) => httpServer.close(resolve));
  });

  test('register via WebSocket enters lobby', async () => {
    const ws = await connect(port);
    const pending = collectMessages(ws, 1);
    ws.send(JSON.stringify(registrationMessage()));
    const [msg] = await pending;

    expect(msg.type).toBe(MSG.REGISTERED);
    expect(msg.client_id).toBeDefined();
    expect(msg.status).toBe('waiting');
    ws.close();
  });

  test('rejects invalid build', async () => {
    const ws = await connect(port);
    const pending = collectMessages(ws, 1);
    ws.send(
      JSON.stringify(
        registrationMessage({ build: { ...alternateBuild(), hull: 3 } })
      )
    );
    const [msg] = await pending;

    expect(msg.type).toBe(MSG.ERROR);
    expect(msg.error).toContain('>= 5');
    expect(msg.field).toBe('build.hull');
    ws.close();
  });

  test('rejects duplicate mecha name', async () => {
    const ws1 = await connect(port);
    ws1.send(JSON.stringify(registrationMessage()));
    await collectMessages(ws1, 1);

    const ws2 = await connect(port);
    const pending = collectMessages(ws2, 1);
    ws2.send(JSON.stringify(registrationMessage()));
    const [err] = await pending;

    expect(err.type).toBe(MSG.ERROR);
    expect(err.field).toBe('name');
    ws1.close();
    ws2.close();
  });

  test('two WebSocket clients auto-start match and receive action_request', async () => {
    const ws1 = await connect(port);
    const ws2 = await connect(port);

    const ws1Messages = [];
    const ws2Messages = [];
    ws1.on('message', (raw) => ws1Messages.push(JSON.parse(raw.toString())));
    ws2.on('message', (raw) => ws2Messages.push(JSON.parse(raw.toString())));

    ws1.send(JSON.stringify(registrationMessage({ name: 'Alpha' })));
    ws2.send(
      JSON.stringify(
        registrationMessage({ name: 'Bravo', build: alternateBuild() })
      )
    );

    await new Promise((r) => setTimeout(r, 150));

    const allMessages = [...ws1Messages, ...ws2Messages];
    const types = allMessages.map((m) => m.type);

    expect(types).toContain(MSG.REGISTERED);
    expect(types).toContain(MSG.MATCH_STARTED);
    expect(types).toContain(MSG.ACTION_REQUEST);
    expect(gameState.matches.size).toBe(1);

    const actionReq = allMessages.find((m) => m.type === MSG.ACTION_REQUEST);
    const responder = ws1Messages.some((m) => m.type === MSG.ACTION_REQUEST)
      ? ws1
      : ws2;
    responder.send(
      JSON.stringify({
        type: MSG.ACTION,
        turn: actionReq.turn,
        action: 'IDLE',
      })
    );

    ws1.close();
    ws2.close();
  });
});
