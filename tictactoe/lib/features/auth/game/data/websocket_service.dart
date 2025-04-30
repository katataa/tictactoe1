import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:tictactoe/core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef MessageHandler = void Function(Map<String, dynamic>);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  late WebSocketChannel _channel;
  MessageHandler? onMessage;
  String? _gameId;
  Timer? _heartbeatTimer;
  bool _connected = false;
  String? _username;
String? _playerId;


  Future<void> connect(String username) async {
  if (_connected) return;

  _username = username;
  _channel = WebSocketChannel.connect(Uri.parse(kWebSocketUrl));
  final prefs = await SharedPreferences.getInstance();
  _playerId = prefs.getString('player_id');

  _channel.stream.listen(
    (data) {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      if (onMessage != null) onMessage!(msg);
      if (msg['type'] == 'set_id') {
        _playerId = msg['id'] as String;
        prefs.setString('player_id', _playerId!);
      }
    },
    onDone: disconnect,
    onError: (_) => disconnect(),
  );

  _connected = true;

  _channel.sink.add(jsonEncode({
    'type': 'set_username',
    'username': _username,
    'playerId': _playerId,
  }));

  _heartbeatTimer = Timer.periodic(
    const Duration(seconds: 25),
    (_) => _channel.sink.add(jsonEncode({'type': 'ping'})),
  );
}

Future<void> reconnectToLobby(String username) async {
  if (_connected) {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 300));
  }
  await connect(username);
}

  bool get isConnected => _connected;

  void sendInvite(String to, int timeControl) {
    _channel.sink.add(jsonEncode({
      'type': 'invite',
      'to': to,
      'timeControl': timeControl,
    }));
  }
  

  void cancelInvite() {
    _channel.sink.add(jsonEncode({'type': 'cancel_invite'}));
  }

  void acceptInvite(String from, int timeControl) {
    _channel.sink.add(jsonEncode({
      'type': 'accept_invite',
      'from': from,
      'timeControl': timeControl,
    }));
  }

  void sendSetUsername() {
  // ignore: unnecessary_null_comparison
  if (_channel != null && _username != null) {
    _channel.sink.add(jsonEncode({
      'type': 'set_username',
      'username': _username,
      'playerId': _playerId,
    }));
  }
}


  void joinGame(String gameId, String symbol) {
    _gameId = gameId;
    _channel.sink.add(jsonEncode({
      'type': 'join_game',
      'gameId': gameId,
    }));
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
  void leaveGame() {
  if (_gameId != null) {
    _channel.sink.add(jsonEncode({
      'type': 'leave_game',
      'gameId': _gameId,
    }));
    _gameId = null;
  }
}


  void disconnect() {
    if (!_connected) return;
    _heartbeatTimer?.cancel();
    _connected = false;
    _channel.sink.close();
  }
}

