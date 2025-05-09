import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/websocket_service.dart';
import 'game_board_screen.dart';
import 'bot_game_screen.dart';
import '../../../../core/encryption_helper.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({Key? key}) : super(key: key);

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
  int selectedTimeControl = 5;
  final _searchController = TextEditingController();
  bool _loadingSearch = false;
  String _decryptedUsername = '';
  String _decryptedEmail = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final data = doc.data();
    if (data != null) {
      final decryptedUsername = await EncryptionHelper.decrypt(data['username']);
      final decryptedEmail = await EncryptionHelper.decrypt(data['email']);
      setState(() {
        avatar = data['avatar'] ?? avatar;
        wins = data['wins'] ?? wins;
        losses = data['losses'] ?? losses;
        _decryptedUsername = decryptedUsername;
        _decryptedEmail = decryptedEmail;
      });

      await _ws.reconnectToLobby(decryptedUsername);
      _ws.onMessage = _handleWsMessage;
    }
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'user_list':
        final list = List<String>.from(msg['users']);
        list.remove(_decryptedUsername);
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
          opponent: msg['opponent'],
          symbol: msg['symbol'],
          gameId: msg['gameId'],
          timeControl: msg['timeControl'] ?? selectedTimeControl,
        );
        break;
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => allUsers.clear());
      return;
    }

    setState(() => _loadingSearch = true);
    try {
      final userQuery = FirebaseFirestore.instance
          .collection('users')
          .where('searchUsername', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('searchUsername', isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff');

      final emailQuery = FirebaseFirestore.instance
          .collection('users')
          .where('searchEmail', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('searchEmail', isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff');

      final results = await Future.wait([userQuery.get(), emailQuery.get()]);

      final all = <String, Map<String, String>>{};

      for (var doc in [...results[0].docs, ...results[1].docs]) {
  try {
    final decryptedUsername = await EncryptionHelper.decrypt(doc['username']);
    final decryptedEmail = await EncryptionHelper.decrypt(doc['email']);
    all[doc.id] = {'username': decryptedUsername, 'email': decryptedEmail};
  } catch (e) {
    debugPrint('Decryption failed for user: $e');
  }
}

      setState(() => allUsers = all.values.toList());
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => allUsers.clear());
    } finally {
      setState(() => _loadingSearch = false);
    }
  }

  void _launchGame({
    required String opponent,
    required String symbol,
    required String gameId,
    required int timeControl,
  }) {
    setState(() {
      invitedUser = null;
      inviteFrom = null;
      inviteTimeControl = null;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameBoardScreen(
          username: _decryptedUsername,
          opponent: opponent,
          symbol: symbol,
          gameId: gameId,
          socket: _ws,
          timeControl: Duration(minutes: timeControl),
        ),
      ),
    ).then((_) async {
      _loadProfile();
    });
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
    _ws.cancelInvite();
    setState(() => invitedUser = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite cancelled.")),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearch = _searchController.text.isNotEmpty;
    final list = isSearch
        ? allUsers.map((u) => u['username']!).toList()
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
              title: Text(_decryptedUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$_decryptedEmail\nWins: $wins | Losses: $losses'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Time Control:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: selectedTimeControl,
                  items: [5, 10, 15].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                  onChanged: (m) => setState(() => selectedTimeControl = m!),
                ),
              ],
            ),
          ),
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
  final online = onlineUsers.contains(user.toLowerCase());

  return ListTile(
    leading: Icon(Icons.circle, color: online ? Colors.green : Colors.grey, size: 12),
    title: Text(user),
    subtitle: isSearch
        ? Text(allUsers.firstWhere((u) => u['username'] == user)['email'] ?? '')
        : null,
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
