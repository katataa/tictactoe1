import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  late WebSocketChannel _channel;
  Function(Map<String, dynamic>)? onMessage;

  void connect(String username) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://10.0.2.2:8080'), // 👈 Android emulator — change if needed
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
    _channel.sink.add(jsonEncode({
      'type': 'invite',
      'to': toUsername,
    }));
  }

  void acceptInvite(String fromUsername) {
    _channel.sink.add(jsonEncode({
      'type': 'accept_invite',
      'from': fromUsername,
    }));
  }

  void sendMove(int cell) {
    _channel.sink.add(jsonEncode({
      'type': 'move',
      'cell': cell,
    }));
  }

  void disconnect() {
    _channel.sink.close(status.normalClosure);
  }
}
