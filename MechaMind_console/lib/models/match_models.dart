class ServerStatus {
  ServerStatus({
    required this.uptimeMs,
    required this.lobbyCount,
    required this.activeMatches,
    required this.totalMatches,
    required this.registeredClients,
    required this.connectedClients,
    required this.lobby,
    required this.matches,
    this.lastFinishedMatch,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    final lobbyRaw = json['lobby'] as List<dynamic>? ?? [];
    final matchesRaw = json['matches'] as List<dynamic>? ?? [];
    final lastRaw = json['last_finished_match'] as Map<String, dynamic>?;

    return ServerStatus(
      uptimeMs: json['uptime_ms'] as int? ?? 0,
      lobbyCount: json['lobby_count'] as int? ?? 0,
      activeMatches: json['active_matches'] as int? ?? 0,
      totalMatches: json['total_matches'] as int? ?? 0,
      registeredClients: json['registered_clients'] as int? ?? 0,
      connectedClients: json['connected_clients'] as int? ?? 0,
      lobby: lobbyRaw
          .map((e) => LobbyClient.fromJson(e as Map<String, dynamic>))
          .toList(),
      matches: matchesRaw
          .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastFinishedMatch:
          lastRaw != null ? MatchSummary.fromJson(lastRaw) : null,
    );
  }

  final int uptimeMs;
  final int lobbyCount;
  final int activeMatches;
  final int totalMatches;
  final int registeredClients;
  final int connectedClients;
  final List<LobbyClient> lobby;
  final List<MatchSummary> matches;
  final MatchSummary? lastFinishedMatch;

  String get uptimeLabel {
    final totalSec = uptimeMs ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class LobbyClient {
  LobbyClient({required this.clientId, required this.name});

  factory LobbyClient.fromJson(Map<String, dynamic> json) => LobbyClient(
        clientId: json['client_id'] as String,
        name: json['name'] as String,
      );

  final String clientId;
  final String name;
}

class MatchSummary {
  MatchSummary({
    required this.id,
    required this.status,
    required this.turn,
    required this.clients,
    this.winnerId,
    this.endReason,
  });

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'unknown',
        turn: json['turn'] as int? ?? 0,
        clients: (json['clients'] as List<dynamic>? ?? [])
            .map((e) => MatchClientRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        winnerId: json['winner_id'] as String?,
        endReason: json['end_reason'] as String?,
      );

  final String id;
  final String status;
  final int turn;
  final List<MatchClientRef> clients;
  final String? winnerId;
  final String? endReason;

  bool get isRunning => status == 'running';

  String get shortId => id.length > 8 ? '${id.substring(0, 8)}…' : id;

  String get clientNames => clients.map((c) => c.name).join(' vs ');
}

class MatchClientRef {
  MatchClientRef({required this.clientId, required this.name});

  factory MatchClientRef.fromJson(Map<String, dynamic> json) => MatchClientRef(
        clientId: json['client_id'] as String,
        name: json['name'] as String,
      );

  final String clientId;
  final String name;
}

class MatchSnapshot {
  MatchSnapshot({
    required this.id,
    required this.status,
    required this.turn,
    required this.turnOrder,
    required this.clients,
    this.winnerId,
    this.endReason,
  });

  factory MatchSnapshot.fromJson(Map<String, dynamic> json) => MatchSnapshot(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'unknown',
        turn: json['turn'] as int? ?? 0,
        turnOrder: (json['turnOrder'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        clients: (json['clients'] as List<dynamic>? ?? [])
            .map((e) => MechaState.fromJson(e as Map<String, dynamic>))
            .toList(),
        winnerId: json['winner_id'] as String?,
        endReason: json['end_reason'] as String?,
      );

  final String id;
  final String status;
  final int turn;
  final List<String> turnOrder;
  final List<MechaState> clients;
  final String? winnerId;
  final String? endReason;

  bool get isRunning => status == 'running';

  MechaState? mechaById(String clientId) {
    for (final m in clients) {
      if (m.clientId == clientId) return m;
    }
    return null;
  }

  String? nameFor(String clientId) => mechaById(clientId)?.name;
}

class MechaState {
  MechaState({
    required this.clientId,
    required this.name,
    required this.x,
    required this.y,
    required this.hull,
    required this.hullMax,
    required this.shields,
    required this.shieldsMax,
    required this.destroyed,
  });

  factory MechaState.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>? ?? {};
    return MechaState(
      clientId: json['client_id'] as String,
      name: json['name'] as String,
      x: pos['x'] as int? ?? 0,
      y: pos['y'] as int? ?? 0,
      hull: json['hull'] as int? ?? 0,
      hullMax: json['hull_max'] as int? ?? 0,
      shields: json['shields'] as int? ?? 0,
      shieldsMax: json['shields_max'] as int? ?? 0,
      destroyed: json['destroyed'] as bool? ?? false,
    );
  }

  final String clientId;
  final String name;
  final int x;
  final int y;
  final int hull;
  final int hullMax;
  final int shields;
  final int shieldsMax;
  final bool destroyed;

  double get hullRatio => hullMax > 0 ? hull / hullMax : 0;
  double get shieldRatio => shieldsMax > 0 ? shields / shieldsMax : 0;
}

class TurnHistoryEntry {
  TurnHistoryEntry({
    required this.turn,
    required this.actions,
    required this.results,
  });

  factory TurnHistoryEntry.fromJson(Map<String, dynamic> json) {
    final actionsRaw = json['actions'] as Map<String, dynamic>? ?? {};
    final resultsRaw = json['results'] as Map<String, dynamic>? ?? {};

    return TurnHistoryEntry(
      turn: json['turn'] as int? ?? 0,
      actions: actionsRaw.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>?) ?? {}),
      ),
      results: resultsRaw.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>?) ?? {}),
      ),
    );
  }

  final int turn;
  final Map<String, Map<String, dynamic>> actions;
  final Map<String, Map<String, dynamic>> results;

  String describeAction(String clientId) {
    final action = actions[clientId];
    if (action == null) return '—';
    final type = action['action']?.toString() ?? '?';
    switch (type) {
      case 'MOVE':
        return 'MOVE → (${action['x']}, ${action['y']})';
      case 'FIRE':
        return 'FIRE → (${action['x']}, ${action['y']})';
      case 'SCAN':
        return 'SCAN @ (${action['scan_x']}, ${action['scan_y']})';
      case 'IDLE':
        return 'IDLE';
      default:
        return type;
    }
  }

  String describeResult(String clientId) {
    final result = results[clientId];
    if (result == null) return '';
    final parts = <String>[];
    final dmg = result['damage_dealt'];
    if (dmg is num && dmg > 0) parts.add('dmg $dmg');
    final moved = result['moved'];
    if (moved == true) parts.add('moved');
    final energy = result['energy_spent'];
    if (energy is num && energy > 0) parts.add('E−$energy');
    final scan = result['scan_result'] as Map<String, dynamic>?;
    if (scan != null && scan['found'] == true) {
      parts.add('scan hit');
    }
    return parts.isEmpty ? '' : parts.join(' · ');
  }
}
