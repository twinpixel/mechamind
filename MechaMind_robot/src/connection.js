import WebSocket from "ws";

const RECONNECT_DELAY_MS = 3000;
const MAX_RECONNECTS = 5;

/**
 * Gestisce la connessione WebSocket con il server MechaMind.
 * Traduce i messaggi grezzi in eventi comprensibili dalla classe Mecha.
 */
export class Connection {
  #url;
  #mecha;
  #ws = null;
  #reconnectCount = 0;
  #registered = false;

  constructor(url, mecha) {
    this.#url = url;
    this.#mecha = mecha;
  }

  connect() {
    this.#mecha._log(`Connessione a ${this.#url}…`);
    this.#ws = new WebSocket(this.#url);

    this.#ws.on("open", () => {
      this.#reconnectCount = 0;
      this.#mecha._log("WebSocket aperto. Invio register…");
      this.#send(this.#mecha._buildRegisterPayload());
    });

    this.#ws.on("message", (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        this.#mecha._log(`Messaggio non-JSON ignorato: ${raw}`);
        return;
      }
      this.#dispatch(msg);
    });

    this.#ws.on("close", (code, reason) => {
      this.#mecha._log(`WebSocket chiuso (${code}: ${reason})`);
      this.#registered = false;
      this.#mecha._onDisconnected();
      this.#maybeReconnect();
    });

    this.#ws.on("error", (err) => {
      this.#mecha._log(`Errore WebSocket: ${err.message}`);
    });
  }

  #dispatch(msg) {
    switch (msg.type) {
      case "registered":
        this.#registered = true;
        this.#mecha._onRegistered(msg);
        break;

      case "match_started":
        this.#mecha._onMatchStarted(msg);
        break;

      case "action_request":
        this.#handleActionRequest(msg);
        break;

      case "result":
        this.#mecha._onResult(msg);
        break;

      case "gameover":
        this.#mecha._onGameOver(msg);
        break;

      case "error":
        this.#mecha._log(`Errore server: ${msg.error} (campo: ${msg.field ?? "—"})`);
        this.#mecha._onServerError(msg);
        break;

      default:
        this.#mecha._log(`Tipo messaggio sconosciuto: ${msg.type}`);
    }
  }

  async #handleActionRequest(msg) {
    let action;
    try {
      action = await this.#mecha._computeAction(msg);
    } catch (err) {
      this.#mecha._log(`Errore in onTurn: ${err.message}. Invio IDLE.`);
      action = this.#mecha.idle();
    }

    action.type = "action";
    action.turn = msg.turn;

    this.#send(action);
  }

  #send(payload) {
    if (this.#ws?.readyState === WebSocket.OPEN) {
      this.#ws.send(JSON.stringify(payload));
    } else {
      this.#mecha._log("Tentativo di invio con WebSocket non aperto.");
    }
  }

  #maybeReconnect() {
    if (this.#reconnectCount >= MAX_RECONNECTS) {
      this.#mecha._log("Numero massimo di riconnessioni raggiunto. Abbandono.");
      return;
    }
    this.#reconnectCount++;
    this.#mecha._log(
      `Riconnessione ${this.#reconnectCount}/${MAX_RECONNECTS} tra ${RECONNECT_DELAY_MS / 1000}s…`
    );
    setTimeout(() => this.connect(), RECONNECT_DELAY_MS);
  }

  disconnect() {
    this.#ws?.close();
  }
}
