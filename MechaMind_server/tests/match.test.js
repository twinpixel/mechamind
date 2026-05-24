import { Match } from '../src/game/match.js';
import { MockClientGateway } from './helpers/mockGateway.js';
import { VALID_BUILD, alternateBuild } from './helpers/fixtures.js';

const testConfig = {
  gridSize: 100,
  minStartDistance: 10,
  maxTurns: 500,
  turnTimeoutMs: 1000,
};

function makeClients() {
  return [
    {
      id: 'client-a',
      name: 'Alpha',
      build: { ...VALID_BUILD },
    },
    {
      id: 'client-b',
      name: 'Bravo',
      build: { ...alternateBuild() },
    },
  ];
}

describe('match simulation', () => {
  test('runTurn executes both clients in fixed order', async () => {
    const mock = new MockClientGateway();
    const actions = [];

    mock.registerBot('client-a', {
      onAction: () => {
        actions.push('a');
        return { action: 'IDLE' };
      },
    });
    mock.registerBot('client-b', {
      onAction: () => {
        actions.push('b');
        return { action: 'IDLE' };
      },
    });

    const match = new Match({
      id: 'm1',
      clients: makeClients(),
      config: testConfig,
      clientGateway: mock,
      rng: () => 0,
    });

    await match.runTurn();
    expect(match.turn).toBe(1);
    expect(actions).toEqual(['a', 'b']);
    expect(mock.results).toHaveLength(2);
  });

  test('lethal FIRE ends match with winner', async () => {
    const mock = new MockClientGateway();

    const match = new Match({
      id: 'm2',
      clients: makeClients(),
      config: testConfig,
      clientGateway: mock,
      rng: () => 0,
    });

    match.vehicles['client-b'].x = 30;
    match.vehicles['client-b'].y = 30;
    match.vehicles['client-a'].x = 30;
    match.vehicles['client-a'].y = 30;
    match.vehicles['client-b'].shields = 0;
    match.vehicles['client-b'].hull = 10;

    mock.registerBot('client-a', {
      onAction: () => ({
        action: 'FIRE',
        energy: 18,
        target_x: 30,
        target_y: 30,
      }),
    });
    mock.registerBot('client-b', {
      onAction: () => ({ action: 'IDLE' }),
    });

    await match.runTurn();
    expect(match.status).toBe('finished');
    expect(match.winnerId).toBe('client-a');
  });

  test('client timeout causes forfeit loss', async () => {
    const mock = new MockClientGateway();

    mock.registerBot('client-a', {
      onAction: () => ({ action: 'IDLE' }),
    });

    const match = new Match({
      id: 'm3',
      clients: makeClients(),
      config: testConfig,
      clientGateway: mock,
      rng: () => 0,
    });

    await match.runTurn();
    expect(match.status).toBe('finished');
    expect(match.winnerId).toBe('client-a');
    expect(match.endReason).toBe('timeout');
  });
});
