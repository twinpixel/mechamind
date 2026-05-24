const LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

function resolveLevel(name) {
  return LEVELS[name?.toLowerCase()] ?? LEVELS.info;
}

export function createLogger(options = {}) {
  const minLevel = resolveLevel(options.level ?? process.env.LOG_LEVEL ?? 'info');

  function write(level, category, message, data) {
    if (LEVELS[level] < minLevel) return;

    const ts = new Date().toISOString();
    const tag = `[${ts}] [${level.toUpperCase()}] [${category}]`;

    if (data === undefined) {
      console.log(`${tag} ${message}`);
      return;
    }

    console.log(`${tag} ${message}`, JSON.stringify(data));
  }

  return {
    debug: (category, message, data) => write('debug', category, message, data),
    info: (category, message, data) => write('info', category, message, data),
    warn: (category, message, data) => write('warn', category, message, data),
    error: (category, message, data) => write('error', category, message, data),
  };
}

export const log = createLogger();

export function clientLabel(clientId, name) {
  if (name) return `${name} (${clientId.slice(0, 8)})`;
  return clientId?.slice(0, 8) ?? 'unknown';
}

export function matchLabel(matchId) {
  return matchId?.slice(0, 8) ?? 'unknown';
}
