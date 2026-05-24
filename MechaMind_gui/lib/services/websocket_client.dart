import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/mecha_build.dart';

typedef MessageHandler = void Function(Map<String, dynamic> message);

class MechaMindWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect(String serverUrl) async {
    await disconnect();
    final uri = _toWebSocketUri(serverUrl);
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      (raw) {
        final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
        _messageController.add(decoded);
      },
      onError: (Object error) {
        _messageController.addError(error);
      },
      onDone: () {
        _messageController.add({'type': '_disconnected'});
      },
    );
    await _channel!.ready;
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  void register({
    required String name,
    required String version,
    required String author,
    required MechaBuild build,
  }) {
    _send({
      'type': 'register',
      'name': name,
      'version': version,
      'author': author,
      'build': build.toJson(),
    });
  }

  void sendAction(int turn, Map<String, dynamic> action) {
    _send({
      'type': 'action',
      'turn': turn,
      ...action,
    });
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  Uri _toWebSocketUri(String serverUrl) {
    final httpUri = Uri.parse(serverUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(
      scheme: wsScheme,
      path: '/ws',
      query: null,
      fragment: null,
    );
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}

class MechaMindSocketException implements Exception {
  MechaMindSocketException(this.message, {this.field});

  final String message;
  final String? field;

  @override
  String toString() =>
      field != null ? '$field: $message' : message;
}

Future<Map<String, dynamic>> waitForMessageType(
  Stream<Map<String, dynamic>> stream,
  String type, {
  Duration timeout = const Duration(seconds: 10),
}) {
  return stream
      .firstWhere((m) => m['type'] == type)
      .timeout(timeout);
}
