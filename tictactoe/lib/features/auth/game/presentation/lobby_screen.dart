import 'package:flutter/material.dart';
import 'bot_game_screen.dart';
import '../data/websocket_service.dart';
import 'game_board_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String username;
  const LobbyScreen({super.key, required this.username});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final WebSocketService _ws = WebSocketService();
  List<String> users = [];
  String? inviteFrom;

  @override
  void initState() {
    super.initState();
    _ws.connect(widget.username);

    _ws.onMessage = (msg) {
      switch (msg['type']) {
        case 'user_list':
          final List<String> allUsers = List<String>.from(msg['users']);
          allUsers.remove(widget.username); // don't show self
          setState(() => users = allUsers);
          break;
        case 'invite_received':
          setState(() => inviteFrom = msg['from']);
          break;
        case 'game_start':
          final String opponent = msg['opponent'];
          final String gameId = msg['gameId'];
          final String symbol = msg['symbol'];

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameBoardScreen(
                username: widget.username,
                opponent: opponent,
                symbol: symbol,
                gameId: gameId,
                socket: _ws,
              ),
            ),
          );
          break;
      }
    };
  }

  void sendInvite(String to) {
    _ws.sendInvite(to);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invite sent to $to")));
  }

  void acceptInvite() {
    if (inviteFrom != null) {
      _ws.acceptInvite(inviteFrom!);
      setState(() => inviteFrom = null);
    }
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Column(
        children: [
          if (inviteFrom != null)
            AlertDialog(
              title: Text('Game Invite'),
              content: Text('$inviteFrom invited you to play!'),
              actions: [
                TextButton(
                  onPressed: acceptInvite,
                  child: const Text('Accept'),
                ),
              ],
            ),
          const SizedBox(height: 20),
          const Text('Online Players:', style: TextStyle(fontSize: 18)),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, index) {
                return ListTile(
                  title: Text(users[index]),
                  trailing: ElevatedButton(
                    onPressed: () => sendInvite(users[index]),
                    child: const Text('Invite'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BotGameScreen()),
              );
            },
            icon: Icon(Icons.smart_toy),
            label: const Text('Play vs Bot'),
          ),
        ],
      ),
    );
  }
}
