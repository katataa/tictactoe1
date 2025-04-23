import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants.dart';


typedef MessageHandler = void Function(Map<String, dynamic>);

class WebSocketService {
  late WebSocketChannel _channel;
  MessageHandler? onMessage;
  String? _gameId;

  void connect(String username) {
    _channel = WebSocketChannel.connect(
      Uri.parse(kWebSocketUrl),
    );

    _channel.stream.listen((data) {
      final decoded = jsonDecode(data);
      if (onMessage != null) onMessage!(decoded);
    });

    _channel.sink.add(jsonEncode({
      'type': 'set_username',
      'username': username,
    }));
  }

  void sendInvite(String toUsername) {
    _channel.sink.add(jsonEncode({'type': 'invite', 'to': toUsername}));
  }

  void acceptInvite(String fromUsername) {
    _channel.sink.add(jsonEncode({'type': 'accept_invite', 'from': fromUsername}));
  }

  void joinGame(String gameId, String symbol) {
    _gameId = gameId;
  }

  void sendMove(int cell) {
    if (_gameId != null) {
      _channel.sink.add(jsonEncode({'type': 'move', 'gameId': _gameId, 'cell': cell}));
    }
  }

  void requestRestart() {
    if (_gameId != null) {
      _channel.sink.add(jsonEncode({'type': 'restart_request', 'gameId': _gameId}));
    }
  }

  void acceptRestart() {
    if (_gameId != null) {
      _channel.sink.add(jsonEncode({'type': 'restart_accept', 'gameId': _gameId}));
    }
  }

  void disconnect() {
    _channel.sink.close();
  }
}
