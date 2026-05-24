import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_action.dart';
import '../models/mecha_build.dart';
import '../models/vehicle_state.dart';
import '../services/mechamind_api.dart';
import '../services/websocket_client.dart';

enum PilotPhase { setup, lobby, battle, finished }

class GameController extends ChangeNotifier {
  GameController();

  final MechaMindWebSocket _socket = MechaMindWebSocket();
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  String serverUrl = 'http://127.0.0.1:3000';
  String mechaName = 'HumanPilot';
  String author = 'Player';
  MechaBuild build = MechaBuild();

  PilotPhase phase = PilotPhase.setup;
  String? clientId;
  String? matchId;
  String? errorMessage;

  ActionRequest? pendingAction;
  VehicleState? currentVehicle;
  Map<String, dynamic>? lastResult;
  Map<String, dynamic>? gameOver;
  Map<String, dynamic>? matchSnapshot;
  Map<String, dynamic>? lastScan;
  Map<String, dynamic>? lastFireFeedback;

  /// MOVE | FIRE | SCAN | IDLE — drives grid highlighting.
  String selectedAction = 'SCAN';

  int? scanTargetX;
  int? scanTargetY;
  int scanPreviewRadius = 1;
  int? fireTargetX;
  int? fireTargetY;

  Timer? _pollTimer;
  Completer<GameAction>? _actionCompleter;
  int? matchTurn;
  DateTime? actionDeadline;

  bool get isRegistered => clientId != null;
  bool get awaitingAction => pendingAction != null;
  bool get isInMatch => matchId != null && phase == PilotPhase.battle;

  int get radarMax =>
      pendingAction?.vehicle.build['radar'] ??
      currentVehicle?.build['radar'] ??
      build.radar;

  /// Scan overlay for the tactical map.
  ({int? cx, int? cy, int? radius, bool preview}) get scanOverlay {
    if (awaitingAction && selectedAction == 'SCAN') {
      return (
        cx: scanTargetX,
        cy: scanTargetY,
        radius: scanPreviewRadius,
        preview: true,
      );
    }
    if (lastScan != null) {
      return (
        cx: (lastScan!['scan_x'] as num?)?.toInt(),
        cy: (lastScan!['scan_y'] as num?)?.toInt(),
        radius: (lastScan!['radius'] as num?)?.toInt(),
        preview: false,
      );
    }
    return (cx: null, cy: null, radius: null, preview: false);
  }

  void updateBuild(MechaBuild newBuild) {
    build = newBuild;
    notifyListeners();
  }

  void setSelectedAction(String action) {
    if (selectedAction == action) return;
    selectedAction = action;
    if (action == 'SCAN') {
      setScanPreviewRadius(scanPreviewRadius.clamp(1, radarMax));
    }
    notifyListeners();
  }

  Future<void> register() async {
    errorMessage = null;
    if (!build.isValid) {
      errorMessage = 'Build must sum to 100 (currently ${build.sum})';
      notifyListeners();
      return;
    }

    try {
      await _socket.connect(serverUrl);
      _socketSub?.cancel();
      _socketSub = _socket.messages.listen(_onSocketMessage);

      _socket.register(
        name: mechaName,
        version: '1.0.0',
        author: author,
        build: build,
      );

      final response = await _socket.messages
          .firstWhere(
            (m) => m['type'] == 'registered' || m['type'] == 'error',
          )
          .timeout(const Duration(seconds: 10));

      if (response['type'] == 'error') {
        throw MechaMindSocketException(
          response['error']?.toString() ?? 'Registration failed',
          field: response['field']?.toString(),
        );
      }

      _applyRegistration(response);
      _startPolling();
      notifyListeners();
    } on MechaMindSocketException catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    } on TimeoutException {
      errorMessage = 'Registration timeout — is the server running?';
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _applyRegistration(Map<String, dynamic> response) {
    clientId = response['client_id'] as String?;
    matchId = response['match_id'] as String? ?? matchId;
    final status = response['status'] as String?;

    if (status == 'in_match' || matchId != null) {
      phase = PilotPhase.battle;
      _pollMatchSnapshot();
    } else if (phase != PilotPhase.battle) {
      phase = PilotPhase.lobby;
    }
  }

  void _enterBattle({String? newMatchId}) {
    if (newMatchId != null) {
      matchId = newMatchId;
    }
    phase = PilotPhase.battle;
    _pollMatchSnapshot();
  }

  void _onSocketMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'error':
        errorMessage = msg['field'] != null
            ? '${msg['field']}: ${msg['error']}'
            : msg['error']?.toString();
        notifyListeners();
      case 'registered':
        _applyRegistration(msg);
        notifyListeners();
      case 'match_started':
        _enterBattle(newMatchId: msg['match_id'] as String?);
        notifyListeners();
      case 'action_request':
        _handleActionRequest(msg);
      case 'result':
        lastResult = msg;
        if (msg['vehicle'] != null) {
          currentVehicle = VehicleState.fromJson(
            msg['vehicle'] as Map<String, dynamic>,
          );
        }
        final yourAction = msg['your_action'] as Map<String, dynamic>?;
        final scanResult = yourAction?['scan_result'] as Map<String, dynamic>?;
        if (scanResult != null) {
          lastScan = {
            ...scanResult,
            'turn': msg['turn'],
            'pending': false,
          };
        }
        if (phase != PilotPhase.battle && matchId != null) {
          phase = PilotPhase.battle;
        }
        notifyListeners();
      case 'gameover':
        gameOver = msg;
        phase = PilotPhase.finished;
        _pollTimer?.cancel();
        notifyListeners();
      case '_disconnected':
        if (phase != PilotPhase.finished) {
          errorMessage = 'Disconnected from server';
          notifyListeners();
        }
    }
  }

  void _handleActionRequest(Map<String, dynamic> state) {
    pendingAction = ActionRequest.fromJson(state);
    currentVehicle = pendingAction!.vehicle;
    if (pendingAction!.lastScan != null) {
      lastScan = {
        ...pendingAction!.lastScan!,
        'pending': false,
      };
    }
    lastFireFeedback = pendingAction!.lastFireFeedback;
    actionDeadline = DateTime.now().add(
      Duration(milliseconds: pendingAction!.timeoutMs),
    );

    final pos = pendingAction!.vehicle;
    scanTargetX = pos.x;
    scanTargetY = pos.y;
    scanPreviewRadius = radarMax.clamp(1, pos.energy);
    selectedAction = 'SCAN';

    if (lastScan != null && lastScan!['found'] == true) {
      scanTargetX = (lastScan!['x'] as num?)?.toInt() ?? scanTargetX;
      scanTargetY = (lastScan!['y'] as num?)?.toInt() ?? scanTargetY;
    }

    phase = PilotPhase.battle;
    _actionCompleter = Completer<GameAction>();
    notifyListeners();
  }

  void submitAction(GameAction action) {
    if (_actionCompleter != null && !_actionCompleter!.isCompleted) {
      _actionCompleter!.complete(action);
    }

    final turn = pendingAction?.turn;
    if (turn != null) {
      _socket.sendAction(turn, action.toJson());

      if (action.type == ActionType.scan) {
        final p = action.payload;
        lastScan = {
          'pending': true,
          'found': false,
          'scan_x': p['scan_x'],
          'scan_y': p['scan_y'],
          'radius': p['energy'],
          'turn': turn,
        };
      }
    }

    pendingAction = null;
    actionDeadline = null;
    _actionCompleter = null;
    notifyListeners();
  }

  void setFireTarget(int x, int y) {
    fireTargetX = x;
    fireTargetY = y;
    selectedAction = 'FIRE';
    notifyListeners();
  }

  void setScanTarget(int x, int y) {
    scanTargetX = x;
    scanTargetY = y;
    selectedAction = 'SCAN';
    notifyListeners();
  }

  void setScanPreviewRadius(int radius) {
    scanPreviewRadius = radius.clamp(1, radarMax);
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (matchId != null) {
        _pollMatchSnapshot();
      } else {
        _pollClientStatus();
      }
    });
    if (matchId != null) {
      _pollMatchSnapshot();
    } else if (clientId != null) {
      _pollClientStatus();
    }
  }

  Future<void> _pollClientStatus() async {
    if (clientId == null) return;
    try {
      final api = MechaMindApi(baseUrl: serverUrl);
      final status = await api.getClient(clientId!);
      final newMatchId = status['match_id'] as String?;
      if (newMatchId != null && newMatchId != matchId) {
        _enterBattle(newMatchId: newMatchId);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _pollMatchSnapshot() async {
    if (matchId == null) return;
    try {
      final api = MechaMindApi(baseUrl: serverUrl);
      matchSnapshot = await api.getMatch(matchId!);
      matchTurn = (matchSnapshot!['turn'] as num?)?.toInt();
      _syncVehicleFromSnapshot();
      notifyListeners();
    } catch (_) {}
  }

  void _syncVehicleFromSnapshot() {
    if (matchSnapshot == null || clientId == null) return;
    final clients = matchSnapshot!['clients'] as List<dynamic>?;
    if (clients == null) return;

    Map<String, dynamic>? me;
    for (final client in clients) {
      if (client is Map && client['client_id'] == clientId) {
        me = Map<String, dynamic>.from(client);
        break;
      }
    }
    if (me == null) return;

    final pos = me['position'] as Map<String, dynamic>? ?? {};
    currentVehicle = VehicleState(
      x: (pos['x'] as num?)?.toInt() ?? 0,
      y: (pos['y'] as num?)?.toInt() ?? 0,
      hull: (me['hull'] as num?)?.toInt() ?? build.hull,
      hullMax: (me['hull_max'] as num?)?.toInt() ?? build.hull,
      shields: (me['shields'] as num?)?.toInt() ?? build.shields,
      shieldsMax: (me['shields_max'] as num?)?.toInt() ?? build.shields,
      energy: pendingAction?.vehicle.energy ?? build.generator,
      build: build.toJson(),
    );
  }

  Future<void> reset() async {
    _pollTimer?.cancel();
    await _socketSub?.cancel();
    await _socket.disconnect();
    clientId = null;
    matchId = null;
    pendingAction = null;
    actionDeadline = null;
    currentVehicle = null;
    lastResult = null;
    gameOver = null;
    matchSnapshot = null;
    matchTurn = null;
    lastScan = null;
    lastFireFeedback = null;
    scanTargetX = null;
    scanTargetY = null;
    fireTargetX = null;
    fireTargetY = null;
    selectedAction = 'SCAN';
    errorMessage = null;
    phase = PilotPhase.setup;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socketSub?.cancel();
    _socket.dispose();
    super.dispose();
  }
}
