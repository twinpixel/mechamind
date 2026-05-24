export const VALID_BUILD = {
  generator: 20,
  hull: 25,
  shields: 15,
  cannon: 18,
  propulsion: 12,
  radar: 10,
};

export function registrationMessage(overrides = {}) {
  return {
    type: 'register',
    name: 'IronSerpent',
    version: '2.1.0',
    author: 'Team Nexus',
    build: { ...VALID_BUILD },
    ...overrides,
  };
}

export function alternateBuild() {
  return {
    generator: 15,
    hull: 30,
    shields: 10,
    cannon: 20,
    propulsion: 15,
    radar: 10,
  };
}
