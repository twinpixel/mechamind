/**
 * Bot 2 — stessa strategia di HunterBot (converge al centro).
 * Nome diverso obbligatorio per il matchmaking.
 */

import { ConvergeHunter } from "../src/bots/ConvergeHunter.js";

const DEFAULT_BUILD = {
  generator: 25,
  hull: 20,
  shields: 10,
  cannon: 20,
  propulsion: 10,
  radar: 15,
};

const bot = new ConvergeHunter({
  name: process.env.MECHA_NAME ?? "HunterBot2",
  version: "2.0.0",
  author: "MechaMind",
  build: DEFAULT_BUILD,
});

const serverUrl = process.env.SERVER_URL ?? "ws://localhost:3000/ws";
bot.connect(serverUrl);
