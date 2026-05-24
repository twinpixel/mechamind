enum ActionType { move, fire, scan, idle }

class GameAction {
  const GameAction._(this.type, this.payload);

  final ActionType type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => payload;

  factory GameAction.idle() => const GameAction._(
        ActionType.idle,
        {'action': 'IDLE'},
      );

  factory GameAction.move({
    required int energy,
    required int dx,
    required int dy,
  }) =>
      GameAction._(
        ActionType.move,
        {
          'action': 'MOVE',
          'energy': energy,
          'dx': dx,
          'dy': dy,
        },
      );

  factory GameAction.fire({
    required int energy,
    required int targetX,
    required int targetY,
  }) =>
      GameAction._(
        ActionType.fire,
        {
          'action': 'FIRE',
          'energy': energy,
          'target_x': targetX,
          'target_y': targetY,
        },
      );

  factory GameAction.scan({
    required int energy,
    required int scanX,
    required int scanY,
  }) =>
      GameAction._(
        ActionType.scan,
        {
          'action': 'SCAN',
          'energy': energy,
          'scan_x': scanX,
          'scan_y': scanY,
        },
      );
}
