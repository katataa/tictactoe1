import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  List<Map<String, dynamic>> allUsers = [];
  List<String> onlineUsers = [];
  String searchQuery = '';

  String avatar = 'avatar1.png';
  int wins = 0;
  int losses = 0;
  String? inviteFrom;
  String? invitedUser;

  final _searchController = TextEditingController();
  bool _loadingSearch = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    _ws.connect(widget.username);

    _ws.onMessage = (msg) {
      switch (msg['type']) {
        case 'user_list':
          final List<String> users = List<String>.from(msg['users']);
          users.remove(widget.username);
          setState(() => onlineUsers = users);
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

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          avatar = data['avatar'] ?? 'avatar1.png';
          wins = data['wins'] ?? 0;
          losses = data['losses'] ?? 0;
        });
      }
    }
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => allUsers.clear());
      return;
    }

    setState(() => _loadingSearch = true);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: query)
        .get();

    if (snapshot.docs.isEmpty) {
      final emailSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: query)
          .get();

      setState(() {
        allUsers = emailSnapshot.docs.map((doc) => {
          'username': doc.data()['username'] ?? '',
          'email': doc.data()['email'] ?? '',
        }).toList();
      });
    } else {
      setState(() {
        allUsers = snapshot.docs.map((doc) => {
          'username': doc.data()['username'] ?? '',
          'email': doc.data()['email'] ?? '',
        }).toList();
      });
    }

    setState(() => _loadingSearch = false);
  }

  void sendInvite(String to) {
    _ws.sendInvite(to);
    setState(() => invitedUser = to);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Invite sent to $to")),
    );
  }

  void cancelInvite() {
    setState(() => invitedUser = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite cancelled.")),
    );
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingSearchResults = searchQuery.isNotEmpty;

    final usersToShow = showingSearchResults
        ? allUsers.map((u) => u['username'] as String).toList()
        : onlineUsers;

    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // --- My Profile Card ---
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
          const SizedBox(height: 16),
          if (inviteFrom != null)
            AlertDialog(
              title: const Text('Game Invite'),
              content: Text('$inviteFrom invited you to play!'),
              actions: [
                TextButton(
                  onPressed: acceptInvite,
                  child: const Text('Accept'),
                ),
                TextButton(
                  onPressed: () => setState(() => inviteFrom = null),
                  child: const Text('Decline'),
                ),
              ],
            ),
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by username or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => searchQuery = value.trim());
                searchUsers(value.trim());
              },
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
                : usersToShow.isEmpty
                    ? const Center(child: Text('No players found.'))
                    : ListView.builder(
                        itemCount: usersToShow.length,
                        itemBuilder: (_, index) {
                          final username = usersToShow[index];
                          final isOnline = onlineUsers.contains(username);

                          return ListTile(
                            leading: Icon(
                              Icons.circle,
                              color: isOnline ? Colors.green : Colors.grey,
                              size: 12,
                            ),
                            title: Text(username),
                            trailing: isOnline
                                ? invitedUser == username
                                    ? ElevatedButton(
                                        onPressed: cancelInvite,
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                        child: const Text('Cancel'),
                                      )
                                    : ElevatedButton(
                                        onPressed: () => sendInvite(username),
                                        child: const Text('Invite'),
                                      )
                                : const Text('Offline', style: TextStyle(color: Colors.grey)),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BotGameScreen()),
              );
            },
            icon: const Icon(Icons.smart_toy),
            label: const Text('Play vs Bot'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
