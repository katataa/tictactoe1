// lib/features/game/data/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:tictactoe/core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef MessageHandler = void Function(Map<String, dynamic>);

class WebSocketService {
  late WebSocketChannel _channel;
  MessageHandler? onMessage;
  String? _gameId;
  Timer? _heartbeatTimer;

  Future<void> connect(String username) async {
    _channel = WebSocketChannel.connect(Uri.parse(kWebSocketUrl));
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('player_id');

    _channel.stream.listen(
      (data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        if (onMessage != null) onMessage!(msg);
        if (msg['type'] == 'set_id') {
          prefs.setString('player_id', msg['id'] as String);
        }
      },
      onDone: disconnect,
      onError: (_) => disconnect(),
    );

    // initial handshake (register or reconnect)
    _channel.sink.add(jsonEncode({
      'type': 'set_username',
      'username': username,
      'playerId': savedId,
    }));

    // heartbeat
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _channel.sink.add(jsonEncode({'type': 'ping'})),
    );
  }

  bool get isConnected => _channel.closeCode == null;

  void sendInvite(String to, int timeControl) {
    _channel.sink.add(jsonEncode({
      'type': 'invite',
      'to': to,
      'timeControl': timeControl,
    }));
  }

  void acceptInvite(String from, int timeControl) {
    _channel.sink.add(jsonEncode({
      'type': 'accept_invite',
      'from': from,
      'timeControl': timeControl,
    }));
  }

  void sendResumeCheck() {
    _channel.sink.add(jsonEncode({'type': 'check_resume'}));
  }

  void joinGame(String gameId, String symbol) {
    _gameId = gameId;
  }

  void sendMove(int cell) {
    if (_gameId != null) {
      _channel.sink.add(jsonEncode({
        'type': 'move',
        'gameId': _gameId,
        'cell': cell,
      }));
    }
  }

  void requestRestart() {
    if (_gameId != null) {
      _channel.sink.add(jsonEncode({
        'type': 'restart_request',
        'gameId': _gameId,
      }));
    }
  }

  void declineRestart() {
    if (_gameId != null) {
      _channel.sink.add(jsonEncode({
        'type': 'restart_decline',
        'gameId': _gameId,
      }));
    }
  }

  void acceptRestart() {
    if (_gameId != null) {
      _channel.sink.add(jsonEncode({
        'type': 'restart_accept',
        'gameId': _gameId,
      }));
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel.sink.close();
  }
}
