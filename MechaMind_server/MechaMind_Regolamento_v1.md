# MECHAMIND

**Regolamento Tecnico v1.1**

*Gioco di combattimento tra veicoli guidati da programmi*

> Documento convertito da `MechaMind_Regolamento_v1.docx` e aggiornato
> all'implementazione del server Node.js in questo repository (protocollo
> WebSocket, REST di sola osservazione).
>
> **English version:** [MechaMind_Rules_v1.md](./MechaMind_Rules_v1.md)

---

## 1. Panoramica

MechaMind è un gioco di combattimento a turni tra due veicoli controllati da
programmi (bot remoti, client GUI o LLM). I veicoli si affrontano su una griglia
discreta 100×100. Vince chi distrugge il veicolo avversario riducendone la
**Corazza** a zero.

---

## 2. Costruzione del Mecha

### 2.1 Punti Build

Ogni mecha dispone di **100 punti build** da distribuire tra i sei componenti.
Ogni componente deve ricevere almeno **5** punti e al massimo **70**. La somma
deve essere esattamente **100**.

- Minimo per attributo: **5** punti (vincolo su tutti e sei i componenti)
- Massimo per attributo: **70** punti
- Somma totale: esattamente **100** punti
- Campi obbligatori: `generator`, `hull`, `shields`, `cannon`, `propulsion`, `radar`

### 2.2 Componenti

| Componente   | Min | Max | Effetto |
|--------------|-----|-----|---------|
| Generatore   | 5   | 70  | Produce N energia all'inizio di ogni turno |
| Corazza      | 5   | 70  | Punti strutturali. A 0 → distrutto |
| Scudi        | 5   | 70  | Buffer danni. Valore massimo = punti investiti |
| Cannone      | 5   | 70  | Danno massimo per colpo = energia investita (≤ punti cannone) |
| Propulsione  | 5   | 70  | Celle percorribili per turno = energia investita (≤ punti propulsione) |
| Radar        | 5   | 70  | Energia max investibile in SCAN per turno |

*Nota: i punti investiti in un componente definiscono il **massimo erogabile**
per turno su quell'azione, non un valore fisso. Il programma può sempre
scegliere di usarne meno.*

---

## 3. Registrazione del Mecha

### 3.1 Connessione WebSocket

Prima di poter partecipare a una partita, ogni client deve:

1. Aprire una connessione WebSocket verso `ws://<host>:<port>/ws`
2. Inviare un messaggio JSON di tipo `register` con i
   payload del mecha
3. Attendere la risposta `registered` o `error`

Il server valida il payload e risponde con esito positivo o con un errore
descrittivo. Non è più richiesto un `callback_url` HTTP sul client: tutta la
comunicazione di gioco avviene sulla stessa connessione WebSocket.

### 3.2 Formato messaggio `register` (Client → Server)

```json
{
  "type": "register",
  "name": "IronSerpent",
  "version": "2.1.0",
  "author": "Team Nexus",
  "build": {
    "generator": 20,
    "hull": 25,
    "shields": 15,
    "cannon": 18,
    "propulsion": 12,
    "radar": 10
  }
}
```

| Campo     | Tipo   | Obbligatorio | Note |
|-----------|--------|--------------|------|
| `type`    | string | sì           | Deve essere `"register"` |
| `name`    | string | sì           | Nome del mecha |
| `version` | string | sì           | Versione del bot |
| `author`  | string | sì           | Autore / team |
| `build`   | object | sì           | Sei componenti interi, somma = 100 |

Ogni attributo di `build` deve essere un intero ≥ 5 e ≤ 70.

### 3.3 Validazione Server

Il server esegue le seguenti verifiche in ordine. Al primo errore invia un
messaggio `error` e rifiuta la registrazione.

- Presenza di tutti i campi obbligatori (`name`, `version`, `author`, `build`)
- Ogni attributo di `build` è un intero ≥ 5 e ≤ 70
- La somma degli attributi di `build` è esattamente 100
- Il nome del mecha è **unico nella sessione corrente**
- Una sola registrazione per connessione WebSocket

### 3.4 Risposta `registered` (Server → Client)

```json
{
  "type": "registered",
  "client_id": "abc123-...",
  "status": "waiting",
  "message": "In lobby, waiting for opponent",
  "match_id": null
}
```

Se la partita parte immediatamente (due client in lobby e connessi):

```json
{
  "type": "registered",
  "client_id": "abc123-...",
  "status": "in_match",
  "message": "Match started",
  "match_id": "254de4a2-..."
}
```

### 3.5 Risposta `error` (Server → Client)

```json
{
  "type": "error",
  "error": "build.hull must be >= 5",
  "field": "build.hull"
}
```

### 3.6 Lobby e avvio automatico

Dopo una registrazione valida il client entra in **lobby** e attende un
avversario. Quando **due client** sono in lobby **e entrambi hanno una
connessione WebSocket attiva**, il server:

1. Avvia automaticamente la partita
2. Assegna le posizioni iniziali
3. Invia `match_started` a entrambi
4. Inizia il turno 1 inviando `action_request` al primo giocatore nell'ordine
   stabilito

Non è necessaria alcuna azione aggiuntiva da parte dei client.

---

## 4. Campo di Battaglia

- Griglia discreta **100×100** celle (coordinate da `[0,0]` a `[99,99]`)
- Il campo ha confini fisici: non è possibile uscire dalla griglia
- Due veicoli non possono occupare la stessa cella
- Le posizioni di partenza sono assegnate dal server (casuali, con distanza
  Manhattan minima configurabile, default **20** celle)

---

## 5. Struttura del Turno

La partita si svolge a turni numerati progressivamente (`turn` = 1, 2, 3, …).
In ogni turno il server contatta i client **nell'ordine stabilito all'inizio
della partita** (ordine casuale, fisso per tutta la partita).

Ogni client, quando è il proprio momento:

1. Riceve `action_request` con lo stato aggiornato del proprio veicolo
2. Risponde con un messaggio `action` entro il timeout configurato
3. Riceve `result` a fine turno (dopo che entrambi hanno agito, se la partita
   continua)

**Ogni client esegue esattamente una azione per turno** (MOVE, FIRE, SCAN o
IDLE).

### 5.1 Azioni disponibili

| Azione | Costo energia | Parametri | Effetto |
|--------|---------------|-----------|---------|
| **MOVE** | `energy` (≤ punti propulsione) | `dx`, `dy` | Sposta il veicolo. `\|dx\| + \|dy\| ≤ energy` |
| **FIRE** | `energy` (≤ punti cannone) | `target_x`, `target_y` | Colpo istantaneo. Danno = `energy` se a segno |
| **SCAN** | `energy` (≤ punti radar, > 0) | `scan_x`, `scan_y` | Area scan: raggio = energia investita; rivela posizione esatta se il nemico è nel raggio |
| **IDLE** | 0 | — | Nessuna azione. L'energia non spesa va persa |

---

## 6. Sistema Energetico

### 6.1 Produzione

All'**inizio di ogni turno** (prima della richiesta di azione) il generatore
eroga energia pari ai propri punti build. L'energia non utilizzata entro la
fine del turno **va persa** (non si accumula).

### 6.2 Rigenerazione scudi (inizio turno)

Prima della richiesta di azione, se gli scudi sono sotto il massimo **e**
l'energia disponibile è ≥ 1:

- Gli scudi aumentano di **1** punto
- L'energia disponibile diminuisce di **1**

Se l'energia è 0 dopo la produzione, gli scudi non si rigenerano quel turno.

### 6.3 Utilizzo in azione

In ogni turno il client sceglie **una sola azione** e, se applicabile, quanta
energia investirvi (campo `energy`):

- L'energia assegnata all'azione non può superare i punti build del componente
  corrispondente
- L'energia assegnata non può superare l'energia disponibile quel turno
- Se l'energia richiesta supera quella disponibile, il server usa il minimo tra richiesta e disponibile (solo per azioni non-IDLE)

*Esempio: veicolo con Generatore 20, Cannone 15. In un turno può eseguire FIRE
con `energy: 15` oppure MOVE con `energy: 10`, ma non entrambe.*

---

## 7. Movimento

L'azione **MOVE** consuma `energy` ≤ punti propulsione. Il veicolo si sposta
di `dx` celle sull'asse X e `dy` celle sull'asse Y, con il vincolo:

**`|dx| + |dy| ≤ energy`**

- Il veicolo può muoversi in qualsiasi direzione (non ha un orientamento fisso)
- Il movimento deve restare entro i confini `[0,99] × [0,99]`
- Se la cella di destinazione è occupata dall'avversario, il movimento viene
  annullato (il veicolo rimane fermo ma l'energia è consumata)

---

## 8. Combattimento

### 8.1 Sparo

L'azione **FIRE** designa una cella bersaglio (`target_x`, `target_y`) e
investe `energy` ≤ punti cannone. Il colpo è istantaneo.

- Se la cella bersaglio coincide con la posizione dell'avversario: **COLPO A
  SEGNO**
- Altrimenti: **MANCATO**. L'energia è consumata comunque

### 8.2 Feedback del colpo

Dopo ogni FIRE il veicolo sparante riceve un feedback immediato (incluso in
`action_request` del turno successivo come `last_fire_feedback`, e nel
`result` del turno corrente):

- `hit`: `true` / `false` — se il colpo è andato a segno
- `distance`: distanza Manhattan tra la cella sparata e la posizione reale
  dell'avversario
- `turn`: numero del turno in cui è avvenuto il colpo

### 8.3 Applicazione del danno

Il danno di un colpo a segno è pari all'`energy` investita nel FIRE. Il danno
viene assorbito nell'ordine:

**Scudi → Corazza**

- Prima si sottrae dai punti scudo correnti
- L'eccesso intacca la corazza
- Quando la corazza raggiunge **0** il veicolo è distrutto: la partita termina
  (salvo distruzione simultanea nello stesso turno)
- La corazza **non si rigenera** mai

---

## 9. Scudi

- Valore massimo degli scudi = punti build investiti in Scudi
- Gli scudi si rigenerano automaticamente di **1** punto per turno (inizio
  turno, vedi §6.2)
- La rigenerazione consuma **1** punto di energia
- Gli scudi non possono superare il loro valore massimo

---

## 10. Radar

### 10.1 Funzionamento

L'azione **SCAN** è attiva: il radar non funziona passivamente. Il programma
deve sceglierla come azione del turno, investire `energy` > 0 (con
`energy` ≤ punti radar) e indicare il **centro dell'area** (`scan_x`,
`scan_y`).

- **Raggio di scansione** = `energy` investita nel turno (distanza Manhattan)
- L'area coperta è tutte le celle la cui distanza Manhattan da
  (`scan_x`, `scan_y`) è ≤ raggio
- Se la posizione reale dell'avversario è nell'area: `found: true` con
  coordinate esatte `x`, `y`
- Se l'avversario è fuori dall'area: `found: false` (nessuna posizione rivelata)
- Senza SCAN il veicolo non conosce la posizione dell'avversario (eccetto il
  feedback dei colpi)

### 10.2 Risultato (`last_scan`)

Dopo uno SCAN, il veicolo riceve `last_scan` nel turno successivo (e nel
`result` del turno corrente come `scan_result`):

**Avversario trovato**

```json
{
  "found": true,
  "x": 60,
  "y": 44,
  "scan_x": 55,
  "scan_y": 40,
  "radius": 8,
  "turn": 41
}
```

**Avversario non trovato**

```json
{
  "found": false,
  "scan_x": 55,
  "scan_y": 40,
  "radius": 8,
  "turn": 41
}
```

---

## 11. Condizioni di fine partita

| Esito | Condizione |
|-------|------------|
| **VITTORIA** | La corazza dell'avversario raggiunge 0 |
| **PAREGGIO** | Entrambi i veicoli distrutti nello stesso turno (es. colpi in sequenza nello stesso turno) |
| **TIMEOUT / ABBANDONO** | Un client non risponde entro il tempo limite → perde per abbandono |
| **DISCONNESSIONE** | Un client chiude la WebSocket durante la partita → l'avversario vince per abbandono |
| **TURNO MASSIMO** | Superato il numero massimo di turni (default **500**) → vince chi ha più corazza; pareggio in caso di parità |
| **ADMIN** | Un operatore forza la fine via `POST /match/:id/end` → esito **DRAW** |

---

## 12. Architettura di sistema

### 12.1 Ruoli

| Componente | Ruolo |
|--------------|-------|
| **Server Node.js** | Lobby, simulazione, turni, fisica, WebSocket di gioco, REST di monitoraggio |
| **Client (bot / GUI)** | Si connette via WebSocket, registra il mecha, risponde alle `action_request` |
| **Console di monitoraggio** | Qualsiasi client HTTP che consuma gli endpoint REST in lettura o esegue azioni admin |

### 12.2 Flusso di una partita

1. Il client apre `ws://host:port/ws` e invia `register`
2. Il server valida e mette il client in lobby
3. Quando due client sono in lobby e connessi, il server avvia la partita
4. Il server invia `match_started` a entrambi
5. Per ogni turno, per ogni client nell'ordine stabilito:
   - invia `action_request`
   - attende messaggio `action` entro il timeout
   - applica l'azione (o forfeit se timeout)
6. A fine turno invia `result` a entrambi
7. A partita conclusa invia `gameover` a entrambi

### 12.3 Protocollo WebSocket (gioco)

Endpoint: **`ws://<host>:<port>/ws`**

Tutti i messaggi sono JSON con campo `type`.

#### Client → Server

| `type` | Quando | Payload principale |
|--------|--------|-------------------|
| `register` | Alla connessione | `name`, `version`, `author`, `build` |
| `action` | Risposta a `action_request` | `turn`, `action`, parametri azione |

#### Server → Client

| `type` | Quando | Payload principale |
|--------|--------|-------------------|
| `registered` | Dopo registrazione OK | `client_id`, `status`, `match_id` |
| `error` | Errore validazione / protocollo | `error`, `field` (opzionale) |
| `match_started` | Inizio partita | `match_id` |
| `action_request` | Tocca al client agire | `turn`, `vehicle`, `last_scan`, `last_fire_feedback`, `timeout_ms` |
| `result` | Fine turno | `turn`, `vehicle`, `your_action`, `opponent_action`, `damage_taken` |
| `gameover` | Fine partita | `match_id`, `outcome` (WIN/LOSE/DRAW), `reason`, `turn`, `vehicle` |

### 12.4 Endpoint REST (monitoraggio)

Gli endpoint di monitoraggio sono esposti dal server per osservazione e
amministrazione. Quelli di **lettura** sono pubblici; le azioni admin
richiedono header `Authorization: Bearer <adminToken>` (o token raw).

| Endpoint | Metodo | Auth | Scopo |
|----------|--------|------|-------|
| `GET /status` | GET | — | Stato generale: uptime, lobby, partite attive, client connessi |
| `GET /client/:id` | GET | — | Stato client: nome, status, match_id, connected |
| `GET /match/:id` | GET | — | Snapshot partita: turno, posizioni, HP, scudi |
| `GET /match/:id/history` | GET | — | Log turno per turno (partita in corso o ultima conclusa in memoria) |
| `POST /match/:id/end` | POST | Admin | Forza fine partita con esito **DRAW** |
| `DELETE /client/:id` | DELETE | Admin | Rimuove client da lobby; se in partita → abbandono (WIN avversario) |

---

## 13. Formato JSON

### 13.1 Stato veicolo (in `action_request`)

```json
{
  "type": "action_request",
  "turn": 42,
  "timeout_ms": 180000,
  "vehicle": {
    "x": 34,
    "y": 17,
    "hull": 55,
    "hull_max": 60,
    "shields": 8,
    "shields_max": 20,
    "energy": 25,
    "build": {
      "generator": 25,
      "hull": 60,
      "shields": 20,
      "cannon": 15,
      "propulsion": 10,
      "radar": 20
    }
  },
  "last_scan": {
    "found": true,
    "x": 60,
    "y": 44,
    "scan_x": 55,
    "scan_y": 40,
    "radius": 8,
    "turn": 41
  },
  "last_fire_feedback": { "hit": false, "distance": 12, "turn": 41 }
}
```

`last_scan` e `last_fire_feedback` possono essere `null`.

### 13.2 Azione (Client → Server)

Il messaggio deve includere `type: "action"` e il `turn` corrispondente alla
richiesta pendente.

**MOVE**

```json
{
  "type": "action",
  "turn": 42,
  "action": "MOVE",
  "energy": 8,
  "dx": 3,
  "dy": -5
}
```

**FIRE**

```json
{
  "type": "action",
  "turn": 42,
  "action": "FIRE",
  "energy": 15,
  "target_x": 60,
  "target_y": 44
}
```

**SCAN**

```json
{
  "type": "action",
  "turn": 42,
  "action": "SCAN",
  "energy": 8,
  "scan_x": 55,
  "scan_y": 40
}
```

Il campo `energy` definisce sia il costo sia il **raggio** dell'area scansionata.

**IDLE**

```json
{
  "type": "action",
  "turn": 42,
  "action": "IDLE"
}
```

### 13.3 Risultato turno (`result`)

```json
{
  "type": "result",
  "turn": 42,
  "vehicle": { "...": "stato aggiornato" },
  "your_action": {
    "energy_spent": 8,
    "moved": true,
    "damage_dealt": 0,
    "fire_feedback": null,
    "scan_result": null
  },
  "opponent_action": { "action": "FIRE" },
  "damage_taken": 0
}
```

### 13.4 Fine partita (`gameover`)

```json
{
  "type": "gameover",
  "match_id": "254de4a2-...",
  "outcome": "WIN",
  "reason": "destruction",
  "turn": 15,
  "vehicle": { "hull": 12, "shields": 3 }
}
```

Valori di `outcome`: `WIN`, `LOSE`, `DRAW`.

Valori comuni di `reason`: `destruction`, `timeout`, `forfeit`, `max_turns`,
`simultaneous_destruction`, `admin_end`.

---

## 14. Interfaccia MCP per LLM

Il layer MCP è implementato nel progetto **`MechaMind_mdc`** (Python): espone
registrazione, attesa turno e invio azioni come tool MCP, usando lo stesso
protocollo WebSocket descritto in questo documento.

Vedi [MechaMind_mdc/README.md](../MechaMind_mdc/README.md). Versione inglese
delle regole: [MechaMind_Rules_v1.md](./MechaMind_Rules_v1.md) §14.

---

## 15. Configurazione server

Parametri in `config/default.json`, sovrascrivibili via variabili d'ambiente:

| Parametro | Default | Env | Descrizione |
|-----------|---------|-----|-------------|
| `port` | `3000` | `PORT` | Porta HTTP + WebSocket |
| `gridSize` | `100` | — | Dimensione griglia |
| `turnTimeoutMs` | `180000` (3 min) | `TURN_TIMEOUT_MS` | Timeout risposta azione |
| `maxTurns` | `500` | `MAX_TURNS` | Turni massimi per partita |
| `minStartDistance` | `20` | — | Distanza Manhattan minima tra spawn |
| `adminToken` | `admin-secret` | `ADMIN_TOKEN` | Token azioni admin |
| `logLevel` | `info` | `LOG_LEVEL` | Livello log (`debug`, `info`, `warn`, `error`) |

Avvio:

```bash
npm start
# oppure, es. 5 minuti per turno:
TURN_TIMEOUT_MS=300000 npm start
```

---

## 16. Note di implementazione

- Il server valida tutte le azioni: un'azione **non valida** (energia
  insufficiente, coordinate fuori griglia, tipo sconosciuto, ecc.) viene
  trattata come **IDLE** senza penalità aggiuntive
- Se il client **non risponde** entro `timeout_ms`, perde la partita per
  **abbandono** (non viene convertito in IDLE)
- L'ordine dei turni viene sorteggiato all'inizio e rimane fisso per tutta la
  partita
- Lo stato dell'avversario **non è mai esposto** direttamente: l'unica
  informazione ottenibile è tramite SCAN e feedback dei colpi
- La partita parte solo quando **entrambi** i client in lobby hanno WebSocket
  attiva (evita race condition all'avvio)
- Lo storico partite (`GET /match/:id/history`) è mantenuto **in memoria**;
  non c'è persistenza su database

---

## Appendice A — Migrazione da v1.0 (HTTP callback)

La versione originale del regolamento (docx v1.0) prevedeva:

- `POST /register`, `POST /action`, `POST /result`, `POST /gameover` sul **client**
- Campo obbligatorio `callback_url` con health-check HTTP
- Timeout default **5 secondi**

La implementazione corrente sostituisce il flusso callback con **WebSocket
bidirezionale** e REST solo per monitoraggio. Le regole di gioco (build,
movimento, danno, radar, scudi) restano invariate.
