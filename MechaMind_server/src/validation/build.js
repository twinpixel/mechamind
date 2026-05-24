import {
  BUILD_COMPONENTS,
  BUILD_MIN,
  BUILD_MAX,
  BUILD_TOTAL,
} from '../constants.js';

const REQUIRED_TOP_LEVEL = ['name', 'version', 'author', 'build'];

/**
 * @returns {{ valid: true, build: Record<string, number> } | { valid: false, error: string, field?: string }}
 */
export function validateRegistrationPayload(body) {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be a JSON object', field: null };
  }

  for (const field of REQUIRED_TOP_LEVEL) {
    if (body[field] === undefined || body[field] === null || body[field] === '') {
      return {
        valid: false,
        error: `${field} is required`,
        field,
      };
    }
  }

  if (typeof body.name !== 'string') {
    return { valid: false, error: 'name must be a string', field: 'name' };
  }
  if (typeof body.version !== 'string') {
    return { valid: false, error: 'version must be a string', field: 'version' };
  }
  if (typeof body.author !== 'string') {
    return { valid: false, error: 'author must be a string', field: 'author' };
  }

  const buildResult = validateBuild(body.build);
  if (!buildResult.valid) {
    return buildResult;
  }

  return { valid: true, build: buildResult.build };
}

/**
 * @returns {{ valid: true, build: Record<string, number> } | { valid: false, error: string, field: string }}
 */
export function validateBuild(build) {
  if (!build || typeof build !== 'object') {
    return { valid: false, error: 'build is required', field: 'build' };
  }

  let sum = 0;
  const normalized = {};

  for (const component of BUILD_COMPONENTS) {
    const value = build[component];
    if (value === undefined || value === null) {
      return {
        valid: false,
        error: `build.${component} is required`,
        field: `build.${component}`,
      };
    }
    if (!Number.isInteger(value)) {
      return {
        valid: false,
        error: `build.${component} must be an integer`,
        field: `build.${component}`,
      };
    }
    if (value < BUILD_MIN) {
      return {
        valid: false,
        error: `build.${component} must be >= ${BUILD_MIN}`,
        field: `build.${component}`,
      };
    }
    if (value > BUILD_MAX) {
      return {
        valid: false,
        error: `build.${component} must be <= ${BUILD_MAX}`,
        field: `build.${component}`,
      };
    }
    normalized[component] = value;
    sum += value;
  }

  if (sum !== BUILD_TOTAL) {
    return {
      valid: false,
      error: `build attributes must sum to exactly ${BUILD_TOTAL} (got ${sum})`,
      field: 'build',
    };
  }

  return { valid: true, build: normalized };
}

/**
 * Strip protocol fields and return the action payload for the game engine.
 */
export function extractActionFromMessage(message) {
  if (!message || typeof message !== 'object') {
    return { action: 'IDLE' };
  }

  const { type, turn, ...rest } = message;
  if (rest.action) {
    return rest;
  }
  return { action: 'IDLE' };
}
