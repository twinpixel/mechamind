import { createServer } from './app.js';
import { log } from './logger.js';

const { httpServer, config } = createServer();

httpServer.listen(config.port, () => {
  log.info('SERVER', `MechaMind server listening on port ${config.port}`, {
    turn_timeout_ms: config.turnTimeoutMs,
    max_turns: config.maxTurns,
    grid_size: config.gridSize,
    log_level: process.env.LOG_LEVEL ?? 'info',
  });
  log.info('SERVER', `WebSocket endpoint: ws://localhost:${config.port}/ws`);
});
