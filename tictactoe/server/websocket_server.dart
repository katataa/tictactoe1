// websocket_server.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class Player {
  final String id;
  final WebSocket socket;
  String? username;
  String? inGameWith;
  bool isInGame = false;
  DateTime lastPing = DateTime.now();
  int? pendingInviteTimeControl;

  Player(this.id, this.socket);
}

class GameSession {
  final String playerX;
  final String playerO;
  final int timeControlMinutes;
  List<String> board = List.filled(9, '');
  String currentTurn = 'X';
  bool isGameOver = false;
  String? winner;
  DateTime lastActivity = DateTime.now();

  GameSession({
    required this.playerX,
    required this.playerO,
    required this.timeControlMinutes,
  });
}

final players = <String, Player>{};
final activeGames = <String, GameSession>{};

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('✅ WebSocket Server running on ws://${server.address.address}:8080');

  // Clean up ghost connections
  Timer.periodic(const Duration(seconds: 10), (_) => checkDisconnects());

  await for (HttpRequest req in server) {
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      final socket = await WebSocketTransformer.upgrade(req);
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
      req.response
        ..statusCode = HttpStatus.forbidden
        ..close();
    }
  }
}

void handleMessage(Player player, dynamic data) {
  final msg = jsonDecode(data as String) as Map<String, dynamic>;
  final type = msg['type'] as String? ?? '';

  switch (type) {
    // initial or re-connect handshake
    case 'set_username':
      final requestedId = msg['playerId'] as String?;
      if (requestedId != null && players.containsKey(requestedId)) {
        // re-attach to old socket
        final old = players.remove(requestedId)!;
        player.username = old.username;
        player.inGameWith = old.inGameWith;
        player.isInGame = old.isInGame;
        print('♻️ Player reconnected with ID $requestedId');
      } else {
        player.username = msg['username'] as String?;
      }
      players[player.id] = player;
      // tell client their (new or restored) id
      player.socket.add(jsonEncode({'type': 'set_id', 'id': player.id}));
      broadcastOnlineUsers();
      break;

    // client wants to resume an in-flight game
    case 'check_resume':
      _handleResume(player);
      break;

    // sending an invite (with timeControl)
    case 'invite':
      final to = msg['to'] as String?;
      final tc = msg['timeControl'] as int? ?? 5;
      player.pendingInviteTimeControl = tc;
      final target = players.values
          .firstWhereOrNull((p) => p.username == to);
      if (target != null) {
        player.inGameWith = target.id;
        target.inGameWith = player.id;
        target.socket.add(jsonEncode({
          'type': 'invite_received',
          'from': player.username,
          'timeControl': tc,
        }));
      }
      break;

    // accept invite (includes agreed timeControl)
    case 'accept_invite':
      final fromName = msg['from'] as String?;
      final tc = msg['timeControl'] as int? 
          ?? player.pendingInviteTimeControl 
          ?? 5;
      final inviter = players.values
          .firstWhereOrNull((p) => p.username == fromName);
      if (inviter != null) {
        final gameId = '${inviter.id}-${player.id}';
        final sess = GameSession(
          playerX: inviter.id,
          playerO: player.id,
          timeControlMinutes: tc,
        );
        activeGames[gameId] = sess;
        inviter.isInGame = true;
        player.isInGame = true;

        // notify both clients of game start, including timeControl
        inviter.socket.add(jsonEncode({
          'type': 'game_start',
          'opponent': player.username,
          'symbol': 'X',
          'gameId': gameId,
          'timeControl': tc,
        }));
        player.socket.add(jsonEncode({
          'type': 'game_start',
          'opponent': inviter.username,
          'symbol': 'O',
          'gameId': gameId,
          'timeControl': tc,
        }));
        broadcastOnlineUsers();
      }
      break;

    case 'ping':
      player.lastPing = DateTime.now();
      break;

    case 'move':
      final gameId = msg['gameId'] as String?;
      final cell = msg['cell'] as int?;
      final session = activeGames[gameId];
      if (session == null || session.isGameOver || cell == null) return;

      final sym =
          (session.playerX == player.id) ? 'X' : 'O';
      if (session.currentTurn != sym ||
          session.board[cell] != '') return;

      session.board[cell] = sym;
      session.currentTurn = (sym == 'X') ? 'O' : 'X';
      session.lastActivity = DateTime.now();

      final win = checkWinner(session.board);
      if (win != null) {
        session.isGameOver = true;
        session.winner = win;
      }

      // broadcast updated state
      for (var pid in [session.playerX, session.playerO]) {
        players[pid]?.socket.add(jsonEncode({
          'type': 'move',
          'cell': cell,
          'by': sym,
          'board': session.board,
          'nextTurn': session.currentTurn,
          'winner': session.winner,
        }));
      }
      break;

    case 'restart_request':
      final gameId = msg['gameId'] as String?;
      final session = activeGames[gameId];
      if (session != null) {
        final other = (session.playerX == player.id)
            ? session.playerO
            : session.playerX;
        players[other]?.socket.add(jsonEncode({
          'type': 'restart_prompt',
          'gameId': gameId,
          'expiresAt': DateTime.now()
              .add(const Duration(seconds: 30))
              .toIso8601String(),
        }));
      }
      break;

    case 'restart_accept':
      final gameId = msg['gameId'] as String?;
      final session = activeGames[gameId];
      if (session != null) {
        session.board = List.filled(9, '');
        session.currentTurn = 'X';
        session.isGameOver = false;
        session.winner = null;
        session.lastActivity = DateTime.now();

        for (var pid in [session.playerX, session.playerO]) {
          players[pid]?.socket.add(jsonEncode({
            'type': 'restart_confirmed',
            'board': session.board,
            'gameId': gameId,
            'timeControl': session.timeControlMinutes,
          }));
        }
      }
      break;
  }
}

void _handleResume(Player player) {
  final entry = activeGames.entries.firstWhereOrNull(
    (e) =>
        (e.value.playerX == player.id ||
         e.value.playerO == player.id) &&
        !e.value.isGameOver,
  );
  if (entry != null) {
    final sid = entry.key;
    final s = entry.value;
    final opp = (s.playerX == player.id)
        ? s.playerO
        : s.playerX;
    final sym = (s.playerX == player.id) ? 'X' : 'O';

    player.socket.add(jsonEncode({
      'type': 'resume_game',
      'opponent': players[opp]?.username,
      'symbol': sym,
      'gameId': sid,
      'board': s.board,
      'nextTurn': s.currentTurn,
      'timeControl': s.timeControlMinutes,
    }));
  }
}

void handleDisconnect(Player p) {
  print('❌ Player disconnected: ${p.id}');
  if (p.inGameWith != null) {
    players[p.inGameWith!]?.socket.add(jsonEncode({
      'type': 'player_left',
    }));
  }
  players.remove(p.id);
  broadcastOnlineUsers();
}

void broadcastOnlineUsers() {
  final list = players.values
      .where((p) => p.username != null && !p.isInGame)
      .map((p) => p.username!)
      .toList();
  for (var p in players.values) {
    p.socket.add(jsonEncode({'type': 'user_list', 'users': list}));
  }
}

String? checkWinner(List<String> b) {
  const wins = [
    [0,1,2],[3,4,5],[6,7,8],
    [0,3,6],[1,4,7],[2,5,8],
    [0,4,8],[2,4,6],
  ];
  for (var w in wins) {
    if (b[w[0]] != '' &&
        b[w[0]] == b[w[1]] &&
        b[w[0]] == b[w[2]]) {
      return b[w[0]];
    }
  }
  if (!b.contains('')) return 'draw';
  return null;
}

void checkDisconnects() {
  final now = DateTime.now();
  final stale = players.values
      .where((p) => now.difference(p.lastPing).inSeconds > 60)
      .toList();
  for (var p in stale) handleDisconnect(p);
}

extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
