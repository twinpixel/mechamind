import {
  validateBuild,
  validateRegistrationPayload,
} from '../src/validation/build.js';
import { registrationMessage, VALID_BUILD } from './helpers/fixtures.js';

describe('build validation', () => {
  test('accepts a valid registration payload', () => {
    const result = validateRegistrationPayload(registrationMessage());
    expect(result.valid).toBe(true);
    expect(result.build).toEqual(VALID_BUILD);
  });

  test('rejects missing required fields', () => {
    const result = validateRegistrationPayload({ name: 'X' });
    expect(result.valid).toBe(false);
    expect(result.field).toBe('version');
  });

  test('rejects attribute below minimum', () => {
    const result = validateBuild({ ...VALID_BUILD, hull: 4 });
    expect(result.valid).toBe(false);
    expect(result.error).toContain('>= 5');
    expect(result.field).toBe('build.hull');
  });

  test('rejects attribute above maximum', () => {
    const result = validateBuild({ ...VALID_BUILD, cannon: 71 });
    expect(result.valid).toBe(false);
    expect(result.error).toContain('<= 70');
    expect(result.field).toBe('build.cannon');
  });

  test('rejects build sum not equal to 100', () => {
    const result = validateBuild({ ...VALID_BUILD, radar: 11 });
    expect(result.valid).toBe(false);
    expect(result.error).toContain('sum to exactly 100');
    expect(result.field).toBe('build');
  });

  test('rejects non-integer build values', () => {
    const result = validateBuild({ ...VALID_BUILD, generator: 20.5 });
    expect(result.valid).toBe(false);
    expect(result.field).toBe('build.generator');
  });
});
