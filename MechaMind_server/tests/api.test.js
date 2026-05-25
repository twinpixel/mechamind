import request from 'supertest';
import { createApp } from '../src/app.js';
import { MockClientGateway } from './helpers/mockGateway.js';
import { alternateBuild, registrationMessage } from './helpers/fixtures.js';

describe('HTTP monitoring API', () => {
  let app;
  let mockGateway;
  let gameState;

  beforeEach(() => {
    mockGateway = new MockClientGateway();

    ({ app, gameState } = createApp({
      clientGateway: mockGateway,
      configOverrides: {
        adminToken: 'test-admin',
        maxTurns: 5,
      },
    }));
  });

  afterEach(() => {
    gameState.destroy();
  });

  function registerViaState(name, build) {
    const result = gameState.registerClient({
      name,
      version: '1.0.0',
      author: 'Test',
      build,
    });
    mockGateway.registerBot(result.client_id, {
      onAction: () => ({ action: 'IDLE' }),
    });
    mockGateway.bindClient(result.client_id, {});
    gameState.afterClientConnected(result.client_id);
    return result.client_id;
  }

  test('GET /status reports lobby state', async () => {
    registerViaState('IronSerpent', registrationMessage().build);
    const res = await request(app).get('/status');

    expect(res.status).toBe(200);
    expect(res.body.lobby_count).toBe(1);
    expect(res.body.uptime_ms).toBeGreaterThanOrEqual(0);
    expect(res.body.lobby).toHaveLength(1);
    expect(res.body.lobby[0].name).toBe('IronSerpent');
    expect(res.body.matches).toEqual([]);
  });

  test('GET /client/:id returns client status', async () => {
    const clientId = registerViaState('IronSerpent', registrationMessage().build);
    const res = await request(app).get(`/client/${clientId}`);

    expect(res.status).toBe(200);
    expect(res.body.client_id).toBe(clientId);
    expect(res.body.status).toBe('waiting');
    expect(res.body.connected).toBe(true);
  });

  test('two registrations auto-start a match', async () => {
    registerViaState('IronSerpent', registrationMessage().build);
    registerViaState('SteelWolf', alternateBuild());

    await new Promise((r) => setTimeout(r, 50));

    expect(gameState.matches.size).toBe(1);
    expect(gameState.lobby.size).toBe(0);
  });

  test('GET /match/:id returns snapshot', async () => {
    registerViaState('IronSerpent', registrationMessage().build);
    registerViaState('SteelWolf', alternateBuild());

    await new Promise((r) => setTimeout(r, 50));

    const match = [...gameState.matches.values()][0];
    const res = await request(app).get(`/match/${match.id}`);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(match.id);
    expect(res.body.clients).toHaveLength(2);

    const statusRes = await request(app).get('/status');
    expect(statusRes.body.matches).toHaveLength(1);
    expect(statusRes.body.matches[0].id).toBe(match.id);
    expect(statusRes.body.total_matches).toBe(1);
  });

  test('POST /match/:id/end requires admin auth', async () => {
    const res = await request(app).post('/match/fake/end');
    expect(res.status).toBe(401);
  });

  test('DELETE /client/:id removes lobby client', async () => {
    const clientId = registerViaState('IronSerpent', registrationMessage().build);
    const res = await request(app)
      .delete(`/client/${clientId}`)
      .set('Authorization', 'Bearer test-admin');

    expect(res.status).toBe(200);
    expect(gameState.lobby.size).toBe(0);
  });
});
