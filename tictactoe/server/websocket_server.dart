import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:tictactoe/core/constants.dart';


class Player {
  final String id;
  final WebSocket socket;
  String? username;
  String? inGameWith;

  Player(this.id, this.socket);
}

class GameSession {
  String playerX;
  String playerO;
  List<String> board = List.filled(9, '');
  String currentTurn = 'X';
  bool isGameOver = false;
  String? winner;
  DateTime lastActivity = DateTime.now();

  GameSession({required this.playerX, required this.playerO});
}

final players = <String, Player>{};
final activeGames = <String, GameSession>{};

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('✅ WebSocket Server running on ws://${server.address.address}:8080');

  Timer.periodic(Duration(seconds: 10), (_) => checkDisconnects());

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
      request.response..statusCode = HttpStatus.forbidden..close();
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
      final toPlayer = players.values.firstWhereOrNull((p) => p.username == toUsername);
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
      final fromPlayer = players.values.firstWhereOrNull((p) => p.username == decoded['from']);
      if (fromPlayer != null) {
        final gameId = '${fromPlayer.id}-${player.id}';
        final session = GameSession(playerX: fromPlayer.id, playerO: player.id);
        activeGames[gameId] = session;

        fromPlayer.socket.add(jsonEncode({
          'type': 'invite_accepted',
          'by': player.username,
          'gameId': gameId,
        }));

        player.socket.add(jsonEncode({
          'type': 'game_start',
          'opponent': fromPlayer.username,
          'symbol': 'O',
          'gameId': gameId,
        }));

        fromPlayer.socket.add(jsonEncode({
          'type': 'game_start',
          'opponent': player.username,
          'symbol': 'X',
          'gameId': gameId,
        }));
      }
      break;

    case 'move':
      final gameId = decoded['gameId'];
      final cell = decoded['cell'];
      final session = activeGames[gameId];

      if (session == null || session.isGameOver) return;

      final symbol = session.playerX == player.id ? 'X' : 'O';
      if (session.currentTurn != symbol || session.board[cell] != '') return;

      session.board[cell] = symbol;
      session.currentTurn = symbol == 'X' ? 'O' : 'X';
      session.lastActivity = DateTime.now();

      final winner = checkWinner(session.board);
      if (winner != null) {
        session.isGameOver = true;
        session.winner = winner;
      }

      for (var p in [session.playerX, session.playerO]) {
        players[p]?.socket.add(jsonEncode({
          'type': 'move',
          'cell': cell,
          'by': symbol,
          'board': session.board,
          'nextTurn': session.currentTurn,
          'winner': session.winner,
        }));
      }
      break;

    case 'restart_request':
      final gameId = decoded['gameId'];
      final session = activeGames[gameId];
      if (session != null) {
        for (var p in [session.playerX, session.playerO]) {
          players[p]?.socket.add(jsonEncode({
            'type': 'restart_prompt',
            'gameId': gameId,
            'expiresAt': DateTime.now().add(Duration(seconds: 30)).toIso8601String(),
          }));
        }
      }
      break;

    case 'restart_accept':
      final gameId = decoded['gameId'];
      final session = activeGames[gameId];
      if (session != null) {
        session.board = List.filled(9, '');
        session.currentTurn = 'X';
        session.isGameOver = false;
        session.winner = null;

        for (var p in [session.playerX, session.playerO]) {
          players[p]?.socket.add(jsonEncode({
            'type': 'restart_confirmed',
            'board': session.board,
            'gameId': gameId,
          }));
        }
      }
      break;
  }
}

void handleDisconnect(Player player) {
  print('❌ Player disconnected: ${player.id}');
  players.remove(player.id);
  broadcastOnlineUsers();
}

void broadcastOnlineUsers() {
  final userList = players.values.where((p) => p.username != null).map((p) => p.username!).toList();
  for (final p in players.values) {
    p.socket.add(jsonEncode({'type': 'user_list', 'users': userList}));
  }
}

String? checkWinner(List<String> b) {
  final wins = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];
  for (var combo in wins) {
    final a = combo[0], b1 = combo[1], c = combo[2];
    if (b[a] != '' && b[a] == b[b1] && b[a] == b[c]) {
      return b[a];
    }
  }
  if (!b.contains('')) return 'draw';
  return null;
}

void checkDisconnects() {
  final now = DateTime.now();
  activeGames.forEach((id, session) {
    if (!session.isGameOver && now.difference(session.lastActivity).inMinutes >= 2) {
      session.isGameOver = true;
      session.winner = session.currentTurn == 'X' ? 'O' : 'X';

      for (var p in [session.playerX, session.playerO]) {
        players[p]?.socket.add(jsonEncode({
          'type': 'disconnect_timeout',
          'winner': session.winner,
        }));
      }
    }
  });
}

// 🔧 Safe null helper
extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
