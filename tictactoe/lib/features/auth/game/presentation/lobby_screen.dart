// lib/features/game/presentation/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/websocket_service.dart';
import 'game_board_screen.dart';
import 'bot_game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String username;
  const LobbyScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final WebSocketService _ws = WebSocketService();
  List<Map<String, dynamic>> allUsers = [];
  List<String> onlineUsers = [];
  String avatar = 'avatar1.png';
  int wins = 0, losses = 0;
  String? inviteFrom;
  int? inviteTimeControl;
  String? invitedUser;
  String? ongoingGameId, ongoingOpponent, ongoingSymbol;
  int selectedTimeControl = 5;
  final _searchController = TextEditingController();
  bool _loadingSearch = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _ws.connect(widget.username).then((_) => _ws.sendResumeCheck());
    _ws.onMessage = _handleWsMessage;
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'user_list':
        final list = List<String>.from(msg['users'] as List);
        list.remove(widget.username);
        setState(() => onlineUsers = list);
        break;

      case 'invite_received':
        setState(() {
          inviteFrom = msg['from'] as String?;
          inviteTimeControl = msg['timeControl'] as int? ?? selectedTimeControl;
        });
        break;

      case 'game_start':
        _launchGame(
          opponent: msg['opponent'] as String,
          symbol: msg['symbol'] as String,
          gameId: msg['gameId'] as String,
          board: List<String>.filled(9, ''),    // fresh game
          nextTurn: 'X',
          timeControl: msg['timeControl'] as int? ?? selectedTimeControl,
        );
        break;

      case 'resume_game':
        _launchGame(
          opponent: msg['opponent'] as String,
          symbol: msg['symbol'] as String,
          gameId: msg['gameId'] as String,
          board: List<String>.from(msg['board'] as List),
          nextTurn: msg['nextTurn'] as String,
          timeControl: msg['timeControl'] as int,
        );
        break;
    }
  }

  Future<void> _loadProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final d = doc.data();
    if (d != null) {
      setState(() {
        avatar = d['avatar'] as String? ?? avatar;
        wins = d['wins'] as int? ?? wins;
        losses = d['losses'] as int? ?? losses;
      });
    }
  }

  Future<void> _searchUsers(String q) async {
    if (q.isEmpty) {
      setState(() => allUsers.clear());
      return;
    }
    setState(() => _loadingSearch = true);
    var snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: q)
        .get();
    if (snap.docs.isEmpty) {
      snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: q)
          .get();
    }
    setState(() {
      allUsers = snap.docs
          .map((d) => {
                'username': d.data()['username'] as String? ?? '',
                'email': d.data()['email'] as String? ?? '',
              })
          .toList();
      _loadingSearch = false;
    });
  }

  void _launchGame({
    required String opponent,
    required String symbol,
    required String gameId,
    required List<String> board,
    required String nextTurn,
    required int timeControl,
  }) {
    // clear any pending invites
    setState(() {
      invitedUser = null;
      inviteFrom = null;
      inviteTimeControl = null;
      ongoingGameId = gameId;
      ongoingOpponent = opponent;
      ongoingSymbol = symbol;
      selectedTimeControl = timeControl;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameBoardScreen(
          username: widget.username,
          opponent: opponent,
          symbol: symbol,
          gameId: gameId,
          socket: _ws,
          timeControl: Duration(minutes: timeControl),
        ),
      ),
    ).then((_) => _loadProfile());
  }

  void _sendInvite(String to) {
    if (!_ws.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not connected. Please rejoin lobby.")),
      );
      return;
    }
    _ws.sendInvite(to, selectedTimeControl);
    setState(() => invitedUser = to);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Invite sent to $to (${selectedTimeControl}m)")),
    );
  }

  void _acceptInvite() {
    if (inviteFrom != null && inviteTimeControl != null) {
      _ws.acceptInvite(inviteFrom!, inviteTimeControl!);
      setState(() {
        inviteFrom = null;
        inviteTimeControl = null;
      });
    }
  }

  void _cancelInvite() {
    setState(() => invitedUser = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite cancelled.")),
    );
  }

  void _returnToGame() {
    if (ongoingGameId != null) {
      _ws.sendResumeCheck();
    }
  }

  @override
  void dispose() {
    _ws.disconnect();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final isSearch = _searchController.text.isNotEmpty;
    final list = isSearch
        ? allUsers.map((u) => u['username'] as String).toList()
        : onlineUsers;

    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: AssetImage('assets/avatars/$avatar'),
                radius: 25,
              ),
              title: Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Wins: $wins | Losses: $losses'),
            ),
          ),

          // time control dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Time Control:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: selectedTimeControl,
                  items: [5, 10, 15].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                  onChanged: (m) {
                    if (m != null) setState(() => selectedTimeControl = m);
                  },
                ),
              ],
            ),
          ),

          // return to game
          if (ongoingGameId != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(onPressed: _returnToGame, child: const Text('Return to Game')),
            ),

          // incoming invite dialog
          if (inviteFrom != null)
            AlertDialog(
              title: const Text('Game Invite'),
              content: Text('$inviteFrom wants to play (${inviteTimeControl}m)'),
              actions: [
                TextButton(onPressed: _acceptInvite, child: const Text('Accept')),
                TextButton(onPressed: () => setState(() => inviteFrom = null), child: const Text('Decline')),
              ],
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by username or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _searchUsers(v.trim()),
            ),
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          Expanded(
            child: _loadingSearch
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text('No players found.'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final user = list[i];
                          final online = onlineUsers.contains(user);
                          return ListTile(
                            leading: Icon(Icons.circle, color: online ? Colors.green : Colors.grey, size: 12),
                            title: Text(user),
                            trailing: online
                                ? (invitedUser == user
                                    ? ElevatedButton(
                                        onPressed: _cancelInvite,
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                        child: const Text('Cancel'),
                                      )
                                    : ElevatedButton(
                                        onPressed: () => _sendInvite(user),
                                        child: const Text('Invite'),
                                      ))
                                : const Text('Offline', style: TextStyle(color: Colors.grey)),
                          );
                        },
                      ),
          ),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BotGameScreen())),
            icon: const Icon(Icons.smart_toy),
            label: const Text('Play vs Bot'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
