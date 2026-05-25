import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_models.dart';

class MechaMindApi {
  MechaMindApi({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<ServerStatus> getStatus() async {
    final data = await _getJson('/status');
    return ServerStatus.fromJson(data);
  }

  Future<MatchSnapshot> getMatch(String matchId) async {
    final data = await _getJson('/match/$matchId');
    return MatchSnapshot.fromJson(data);
  }

  Future<List<TurnHistoryEntry>> getMatchHistory(String matchId) async {
    final data = await _getJson('/match/$matchId/history');
    final history = data['history'] as List<dynamic>? ?? [];
    return history
        .map((e) => TurnHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final res = await http.get(_uri(path));
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.isEmpty ? '{}' : res.body;
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw MechaMindApiException(
        statusCode: res.statusCode,
        message: data['error']?.toString() ?? 'Request failed',
      );
    }
    return data;
  }
}

class MechaMindApiException implements Exception {
  MechaMindApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'MechaMindApiException($statusCode): $message';
}
