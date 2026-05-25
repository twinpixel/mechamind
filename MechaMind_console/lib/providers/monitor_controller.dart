import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/match_models.dart';
import '../services/mechamind_api.dart';

class MonitorController extends ChangeNotifier {
  MonitorController({String baseUrl = 'http://127.0.0.1:3000'})
      : _baseUrl = baseUrl;

  static const defaultBaseUrl = 'http://127.0.0.1:3000';
  static const homePollInterval = Duration(seconds: 2);
  static const matchPollInterval = Duration(seconds: 1);

  String _baseUrl;
  MechaMindApi? _api;
  Timer? _pollTimer;

  ServerStatus? status;
  MatchSnapshot? snapshot;
  List<TurnHistoryEntry> history = [];
  String? selectedMatchId;
  String? error;
  bool loading = false;
  bool polling = false;

  String get baseUrl => _baseUrl;

  MechaMindApi get api => _api ??= MechaMindApi(baseUrl: _baseUrl);

  void setBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == _baseUrl) return;
    _baseUrl = trimmed;
    _api = MechaMindApi(baseUrl: _baseUrl);
    notifyListeners();
  }

  Future<void> connect() async {
    await refreshStatus();
    startHomePolling();
  }

  void startHomePolling() {
    _stopPolling();
    polling = true;
    _pollTimer = Timer.periodic(homePollInterval, (_) => refreshStatus());
    notifyListeners();
  }

  void startMatchPolling(String matchId) {
    selectedMatchId = matchId;
    _stopPolling();
    polling = true;
    _pollTimer = Timer.periodic(matchPollInterval, (_) => refreshMatch());
    notifyListeners();
    refreshMatch();
  }

  void stopPolling() {
    _stopPolling();
    notifyListeners();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    polling = false;
  }

  Future<void> refreshStatus() async {
    try {
      status = await api.getStatus();
      error = null;
      if (selectedMatchId == null &&
          status!.matches.isNotEmpty &&
          status!.matches.any((m) => m.isRunning)) {
        // Keep home screen; user picks match explicitly.
      }
    } on MechaMindApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> refreshMatch() async {
    final matchId = selectedMatchId;
    if (matchId == null) return;

    loading = history.isEmpty;
    notifyListeners();

    try {
      snapshot = await api.getMatch(matchId);
      history = await api.getMatchHistory(matchId);
      error = null;
    } on MechaMindApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearMatchView() {
    selectedMatchId = null;
    snapshot = null;
    history = [];
    startHomePolling();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
