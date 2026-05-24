/**
 * Mock WebSocket client gateway for tests.
 */
export class MockClientGateway {
  constructor() {
    this.bots = new Map();
    this.results = [];
    this.gameOvers = [];
    this.matchStarted = [];
  }

  registerBot(clientId, handlers = {}) {
    this.bots.set(clientId, {
      onAction: handlers.onAction ?? (() => ({ action: 'IDLE' })),
      onResult: handlers.onResult ?? (() => {}),
      onGameOver: handlers.onGameOver ?? (() => {}),
    });
  }

  bindClient() {}

  setClientName() {}

  unbindWs() {}

  getClientId() {
    return null;
  }

  isConnected(clientId) {
    return this.bots.has(clientId);
  }

  send() {
    return true;
  }

  sendRaw() {
    return true;
  }

  async requestAction(clientId, state) {
    const bot = this.bots.get(clientId);
    if (!bot) {
      return { ok: false, error: 'timeout' };
    }
    const data = await bot.onAction(state);
    return { ok: true, data: { type: 'action', turn: state.turn, ...data } };
  }

  handleActionResponse() {
    return false;
  }

  async sendResult(clientId, result) {
    this.results.push({ clientId, result });
    const bot = this.bots.get(clientId);
    if (bot?.onResult) await bot.onResult(result);
    return { ok: true };
  }

  async sendGameOver(clientId, payload) {
    this.gameOvers.push({ clientId, payload });
    const bot = this.bots.get(clientId);
    if (bot?.onGameOver) await bot.onGameOver(payload);
    return { ok: true };
  }

  notifyMatchStarted(clientIds, matchId) {
    this.matchStarted.push({ clientIds, matchId });
  }
}
