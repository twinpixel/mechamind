import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const defaults = JSON.parse(
  readFileSync(join(__dirname, '../config/default.json'), 'utf8')
);

export function loadConfig(overrides = {}) {
  return {
    ...defaults,
    port: Number(process.env.PORT ?? defaults.port),
    turnTimeoutMs: Number(process.env.TURN_TIMEOUT_MS ?? defaults.turnTimeoutMs),
    maxTurns: Number(process.env.MAX_TURNS ?? defaults.maxTurns),
    adminToken: process.env.ADMIN_TOKEN ?? defaults.adminToken,
    logLevel: process.env.LOG_LEVEL ?? defaults.logLevel,
    ...overrides,
  };
}
