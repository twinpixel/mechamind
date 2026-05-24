import 'dart:convert';

import 'package:http/http.dart' as http;

class MechaMindApi {
  MechaMindApi({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<Map<String, dynamic>> getStatus() async {
    final res = await http.get(_uri('/status'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getClient(String clientId) async {
    final res = await http.get(_uri('/client/$clientId'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getMatch(String matchId) async {
    final res = await http.get(_uri('/match/$matchId'));
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
