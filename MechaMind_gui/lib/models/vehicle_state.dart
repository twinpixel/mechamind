class VehicleState {
  VehicleState({
    required this.x,
    required this.y,
    required this.hull,
    required this.hullMax,
    required this.shields,
    required this.shieldsMax,
    required this.energy,
    required this.build,
  });

  final int x;
  final int y;
  final int hull;
  final int hullMax;
  final int shields;
  final int shieldsMax;
  final int energy;
  final Map<String, int> build;

  factory VehicleState.fromJson(Map<String, dynamic> json) {
    final buildJson = json['build'] as Map<String, dynamic>? ?? {};
    return VehicleState(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      hull: (json['hull'] as num?)?.toInt() ?? 0,
      hullMax: (json['hull_max'] as num?)?.toInt() ?? 0,
      shields: (json['shields'] as num?)?.toInt() ?? 0,
      shieldsMax: (json['shields_max'] as num?)?.toInt() ?? 0,
      energy: (json['energy'] as num?)?.toInt() ?? 0,
      build: buildJson.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}

class ActionRequest {
  ActionRequest({
    required this.turn,
    required this.vehicle,
    this.lastScan,
    this.lastFireFeedback,
    this.timeoutMs = 180000,
  });

  final int turn;
  final VehicleState vehicle;
  final Map<String, dynamic>? lastScan;
  final Map<String, dynamic>? lastFireFeedback;
  final int timeoutMs;

  factory ActionRequest.fromJson(Map<String, dynamic> json) {
    return ActionRequest(
      turn: (json['turn'] as num?)?.toInt() ?? 0,
      vehicle: VehicleState.fromJson(
        json['vehicle'] as Map<String, dynamic>? ?? {},
      ),
      lastScan: json['last_scan'] as Map<String, dynamic>?,
      lastFireFeedback: json['last_fire_feedback'] as Map<String, dynamic>?,
      timeoutMs: (json['timeout_ms'] as num?)?.toInt() ?? 180000,
    );
  }
}
