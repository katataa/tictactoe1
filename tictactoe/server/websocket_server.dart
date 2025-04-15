// Run with: dart websocket_server.dart
import 'dart:convert';
import 'dart:io';

class Player {
  final String id;
  final WebSocket socket;
  String? username;
  String? inGameWith;

  Player(this.id, this.socket);
}

final players = <String, Player>{};

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('✅ WebSocket Server running on ws://${server.address.address}:8080');

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final player = Player(id, socket);
      players[id] = player;

      print('🔌 Player connected: $id');

      socket.listen(
        (data) => handleMessage(player, data),
        onDone: () => handleDisconnect(player),
        onError: (_) => handleDisconnect(player),
      );
    } else {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
    }
  }
}

void handleMessage(Player player, dynamic data) {
  final decoded = jsonDecode(data);
  final type = decoded['type'];

  switch (type) {
    case 'set_username':
      player.username = decoded['username'];
      broadcastOnlineUsers();
      break;

    case 'invite':
      final toUsername = decoded['to'];
      final toPlayer = players.values.firstWhereOrNull(
        (p) => p.username == toUsername,
      );
      if (toPlayer != null) {
        player.inGameWith = toPlayer.id;
        toPlayer.inGameWith = player.id;

        toPlayer.socket.add(jsonEncode({
          'type': 'invite_received',
          'from': player.username,
        }));
      }
      break;

    case 'accept_invite':
      final fromPlayer = players.values.firstWhereOrNull(
        (p) => p.username == decoded['from'],
      );
      if (fromPlayer != null) {
        fromPlayer.socket.add(jsonEncode({
          'type': 'invite_accepted',
          'by': player.username,
        }));
      }
      break;

    case 'move':
      final toId = player.inGameWith;
      final toPlayer = players[toId];
      if (toPlayer != null) {
        toPlayer.socket.add(jsonEncode({
          'type': 'move',
          'cell': decoded['cell'],
          'by': player.username,
        }));
      }
      break;

    default:
      print('⚠️ Unknown message type: $type');
  }
}

void handleDisconnect(Player player) {
  print('❌ Player disconnected: ${player.id}');
  players.remove(player.id);
  broadcastOnlineUsers();
}

void broadcastOnlineUsers() {
  final userList = players.values
      .where((p) => p.username != null)
      .map((p) => p.username)
      .toList();

  for (final p in players.values) {
    p.socket.add(jsonEncode({
      'type': 'user_list',
      'users': userList,
    }));
  }
}

// 👇 Null-safe helper
extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
