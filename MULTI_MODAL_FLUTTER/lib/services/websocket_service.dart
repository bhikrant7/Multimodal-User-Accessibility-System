import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/connection_status.dart';

class WebSocketService {
  WebSocketService({required this.url})
    : connectionStatus = ValueNotifier(ConnectionStatus.disconnected),
      _messageController = StreamController<Map<String, dynamic>>.broadcast();

  final String url;
  final ValueNotifier<ConnectionStatus> connectionStatus;
  final StreamController<Map<String, dynamic>> _messageController;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _manualDisconnect = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect() async {
    if (_disposed ||
        connectionStatus.value == ConnectionStatus.connected ||
        connectionStatus.value == ConnectionStatus.connecting) {
      return;
    }

    _manualDisconnect = false;
    connectionStatus.value = ConnectionStatus.connecting;

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      await channel.ready;
      if (_disposed || _manualDisconnect || _channel != channel) {
        await channel.sink.close(status.normalClosure);
        return;
      }

      connectionStatus.value = ConnectionStatus.connected;
      _subscription = channel.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('WebSocket connection failed: $error');
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) {
        _messageController.add(decoded);
      }
    } catch (_) {
      debugPrint('Received non-JSON websocket payload: $message');
    }
  }

  void _handleDisconnect() {
    if (_disposed || _manualDisconnect) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    connectionStatus.value = ConnectionStatus.reconnecting;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), connect);
  }

  void send(Map<String, dynamic> payload) {
    if (connectionStatus.value == ConnectionStatus.connected) {
      _channel?.sink.add(jsonEncode(payload));
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close(status.normalClosure);
    _channel = null;
    connectionStatus.value = ConnectionStatus.disconnected;
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messageController.close();
    connectionStatus.dispose();
  }
}
