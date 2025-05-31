import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_board_screen.dart';
import 'bot_game_screen.dart';
import '../../../../core/encryption_helper.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({Key? key}) : super(key: key);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final StreamSubscription<DocumentSnapshot> _profileSub;
  late StreamSubscription<QuerySnapshot> _usersSub;
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
  StreamSubscription<QuerySnapshot>? _inviteSub;
  String? _currentInviteId;
  StreamSubscription<DocumentSnapshot>? _roomSub;
  String? _inviteInProgressUser;
  String? _inviteInProgressInviteId;
  String? _inviteInProgressRoomId;
  final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    print('[LOBBY INIT] LobbyScreen initState called');
    print('[USER DEBUG] My UID: [36m${FirebaseAuth.instance.currentUser?.uid}[0m');
    _loadProfile();
    _listenToUsers();
    _listenToInvites();
  }

void _loadProfile() {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;

  _profileSub = FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots().listen((doc) async {
    final data = doc.data();
    if (data != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(u.uid);

      if (!data.containsKey('wins')) {
        await userRef.update({'wins': 0});
      }
      if (!data.containsKey('losses')) {
        await userRef.update({'losses': 0});
      }

      final plainUsername = data['searchUsername'] ?? '[No username]';
      final decryptedEmail = data['searchEmail'] ?? '';

      if (mounted) {
        setState(() {
          avatar = data['avatar'] ?? avatar;
          wins = data['wins'] ?? wins;
          losses = data['losses'] ?? losses;
          _decryptedUsername = plainUsername;
          _decryptedEmail = decryptedEmail;
        });
      }
    }
  });
}

void _listenToUsers() {
  final myUid = FirebaseAuth.instance.currentUser?.uid;

  _usersSub = FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) async {
    final all = <Map<String, dynamic>>[];
    final online = <String>[];

    for (var doc in snapshot.docs) {
      if (doc.id == myUid) continue; // 👈 skip current user's document

      try {
        final data = doc.data();
        if (!data.containsKey('username') || !data.containsKey('email')) continue;

        String decryptedUsername;
        String decryptedEmail;

       decryptedUsername = data['searchUsername'] ?? '[Unknown]';

        decryptedEmail = data['searchEmail'] ?? '';

        all.add({
          'username': decryptedUsername,
          'email': decryptedEmail,
          'isOnline': data['isOnline'] ?? false,
        });

        if (data['isOnline'] == true) online.add(decryptedUsername);
      } catch (e) {
        debugPrint('[USER LOOP ERROR] $e');
      }
    }

    if (mounted) {
      setState(() {
        allUsers = all;
        onlineUsers = online;
      });
    }
  });
}


  void _listenToInvites() {
    print('[INVITE LISTENER] _listenToInvites called');
    final u = FirebaseAuth.instance.currentUser;
    print('[INVITE LISTENER] Current user UID: ${u?.uid}');
    if (u == null) {
      print('[INVITE LISTENER ERROR] No current user');
      return;
    }
    print('[INVITE LISTENER] Listening for invites for UID: ${u.uid}');
    _inviteSub = FirebaseFirestore.instance
        .collection('invites')
        .where('toUid', isEqualTo: u.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      print('[INVITE DEBUG] Invite snapshot docs: ${snapshot.docs.length}');
      if (snapshot.docs.isEmpty) {
        print('[INVITE DEBUG] No pending invites for this user.');
      }
      for (var doc in snapshot.docs) {
        print('[INVITE DEBUG] Invite doc: ${doc.data()}');
      }
      if (snapshot.docs.isNotEmpty) {
        print('[INVITE DEBUG] Invite doc data: ${snapshot.docs.first.data()}');
        final invite = snapshot.docs.first;
        if (_currentInviteId == invite.id) return; // Already handled
        _currentInviteId = invite.id;
        final data = invite.data();
        print('[INVITE RECEIVED] from: \x1b[32m${data['fromUsername']}\x1b[0m, status: ${data['status']}');
        print('[INVITE POPUP] Showing invite dialog for invite: ${invite.id}');
        try {
          _showInviteDialog(invite.id, data['fromUsername'], data['timeControl'] ?? 5);
        } catch (e) {
          print('[INVITE POPUP ERROR] $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invite from ${data['fromUsername']}')), // fallback
            );
          }
        }
      } else {
        _currentInviteId = null;
      }
    }, onError: (e) {
      print('[INVITE LISTENER ERROR] $e');
    });
  }

  void _showInviteDialog(String inviteId, String fromUsername, int timeControl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Game Invite', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('$fromUsername wants to play ($timeControl m)', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _respondToInvite(inviteId, false),
                    child: const Text('Decline'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _respondToInvite(inviteId, true),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _respondToInvite(String inviteId, bool accept) async {
    print('[INVITE RESPONSE] Responding to invite $inviteId, accept: $accept');
    final inviteRef = FirebaseFirestore.instance.collection('invites').doc(inviteId);
    final inviteSnap = await inviteRef.get();
    final data = inviteSnap.data();
    if (data == null) {
      print('[INVITE RESPONSE ERROR] No invite data');
      return;
    }
    final roomId = data['roomId'] as String?;
    if (accept) {
  print('[INVITE ACCEPTED] from: ${data['fromUsername']}');
  if (roomId != null) {
    try {
      // Reset the room to start fresh
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'status': 'active',
        'board': List.filled(9, ''),
        'moveHistory': [],
        'currentTurn': 'X',
        'winner': '',
        'rematchRequest': FieldValue.delete(),
        'joined': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid]),
      });
      print('[ROOM ACTIVATED AND RESET] id: $roomId');

      _listenToRoom(roomId);
    } catch (e) {
      print('[ROOM ACTIVATION ERROR] $e');
    }
  }

  await inviteRef.update({'status': 'accepted'});
  Navigator.pop(context);
}
 else {
      print('[INVITE DECLINED] from: ${data['fromUsername']}');
      if (roomId != null) {
        try {
          await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
            'status': 'cancelled',
          });
          print('[ROOM CANCELLED] id: $roomId');
        } catch (e) {
          print('[ROOM CANCELLATION ERROR] $e');
        }
      }
      await inviteRef.update({'status': 'declined'});
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Declined invite from ${data['fromUsername']}')),
      );
    }
  }

  Future<String> _createRoom(String player1Uid, String player2Uid, String player1Username, String player2Username) async {
    print('[ROOM] Attempting to create room for $player1Username ($player1Uid) and $player2Username ($player2Uid)');
    try {
      final roomRef = await FirebaseFirestore.instance.collection('rooms').add({
        'player1Uid': player1Uid,
        'player2Uid': player2Uid,
        'player1Username': player1Username,
        'player2Username': player2Username,
        'status': 'waiting',
        'joined': [player1Uid],
        'createdAt': FieldValue.serverTimestamp(),
        'board': List.filled(9, ''),
        'currentTurn': 'X',
        'timeControlMinutes': selectedTimeControl,
      });
      print('[ROOM CREATED] id: ${roomRef.id}, players: $player1Username & $player2Username');
      return roomRef.id;
    } catch (e) {
      print('[FIRESTORE ERROR] $e');
      return '';
    }
  }

  Future<void> _sendInviteToUser(Map<String, dynamic> user) async {
    print('[INVITE] Attempting to send invite to user: $user');
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      print('[INVITE ERROR] No current user');
      return;
    }
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final myData = myDoc.data();
    if (myData == null) {
      print('[INVITE ERROR] No user data for current user');
      return;
    }
    final decryptedMyUsername = myData['searchUsername'] ?? '[No username]';
    final toUsername = user['username'];
    final toDoc = await FirebaseFirestore.instance
    .collection('users')
    .where('searchUsername', isEqualTo: toUsername.toLowerCase())
    .limit(1)
    .get();
    if (toDoc.docs.isEmpty) {
      print('[INVITE ERROR] No user found for username: $toUsername');
      return;
    }
    final toUid = toDoc.docs.first.id;
    print('[INVITE SENT] from: $decryptedMyUsername to: $toUsername');
    print('[INVITE DEBUG] Sending invite to toUid: $toUid');

    // Create room immediately
    final roomId = await _createRoom(u.uid, toUid, decryptedMyUsername, toUsername);

    await Future.delayed(const Duration(milliseconds: 300));

    final inviteDoc = await FirebaseFirestore.instance.collection('invites').add({
      'fromUid': u.uid,
      'toUid': toUid,
      'fromUsername': decryptedMyUsername,
      'toUsername': toUsername,
      'status': 'pending',
      'roomId': roomId,
      'timeControl': selectedTimeControl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('[INVITE] Invite document created in Firestore');
    setState(() {
      _inviteInProgressUser = toUsername;
      _inviteInProgressInviteId = inviteDoc.id;
      _inviteInProgressRoomId = roomId;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite sent to $toUsername')),
    );
    // Start listening to the room for this user
    _listenToRoom(roomId);
  }

  Future<void> _cancelInviteInProgress() async {
    print('[INVITE CANCEL] Attempting to cancel invite and room');
    if (_inviteInProgressInviteId != null) {
      try {
        await FirebaseFirestore.instance.collection('invites').doc(_inviteInProgressInviteId).delete();
        print('[INVITE CANCEL] Invite document deleted');
      } catch (e) {
        print('[INVITE CANCEL ERROR] $e');
      }
    }
    if (_inviteInProgressRoomId != null) {
      try {
        await FirebaseFirestore.instance.collection('rooms').doc(_inviteInProgressRoomId).delete();
        print('[INVITE CANCEL] Room document deleted');
      } catch (e) {
        print('[INVITE CANCEL ERROR] $e');
      }
    }
    setState(() {
      _inviteInProgressUser = null;
      _inviteInProgressInviteId = null;
      _inviteInProgressRoomId = null;
    });
  }

  void _listenToRoom(String roomId) {
    print('[ROOM LISTENER] Setting up listener for room: $roomId');
    _roomSub?.cancel();
    _roomSub = FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots().listen((doc) {
      print('[ROOM LISTENER] Room snapshot received');
      if (!doc.exists) {
        print('[ROOM LISTENER] Room document does not exist');
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      print('[ROOM UPDATE] $data');
      final status = data['status'];
      final joined = List<String>.from(data['joined'] ?? []);
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (status == 'active' && joined.contains(myUid)) {
        print('[MATCH START] Room $roomId, joined: $joined');
        // Navigate to game screen
        _goToRoom(roomId, data['player1Username'], data['player2Username']);
      } else if (status == 'ended' || status == 'cancelled') {
        print('[MATCH ENDED] Room $roomId, status: $status');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match ended or cancelled.')),
          );
        }
        _roomSub?.cancel();
      }
    }, onError: (e) {
      print('[ROOM LISTENER ERROR] $e');
    });
  }

void _goToRoom(String roomId, String player1, String player2) async {
  final myUsername = _decryptedUsername;
  final opponent = myUsername == player1 ? player2 : player1;

  final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();
  final data = roomDoc.data();
  if (data == null) return;

  final mySymbol = myUsername == player1 ? 'X' : 'O';
  final opponentUid = myUsername == player1
      ? data['player2Uid']
      : data['player1Uid'];

  print('[USER JOINED ROOM] username: $myUsername, roomId: $roomId, opponentUid: $opponentUid');

final minutes = data['timeControlMinutes'] ?? selectedTimeControl;
final Duration timeControl = Duration(minutes: minutes);

 Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => GameBoardScreen(
      username: myUsername,
      opponent: opponent,
      opponentEmail: '',
      opponentUid: opponentUid,
      symbol: mySymbol,
      gameId: roomId,
      timeControl: timeControl,
    ),
  ),
);

}


  Future<void> _endRoom(String roomId) async {
    print('[ROOM END REQUESTED] id: $roomId');
    await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({'status': 'ended'});
    print('[ROOM ENDED] id: $roomId');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _profileSub.cancel();
    _usersSub.cancel();
    _inviteSub?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {}); // Just to trigger rebuild, filtering is done in build
  }

  Future<void> _showInviteConfirmationDialog(Map<String, dynamic> user) async {
    print('[DIALOG] Showing invite confirmation dialog for user: ${user['username']}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Game Invite'),
        content: Text('Do you want to send a game invite to ${user['username']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
    print('[DIALOG] Invite confirmation result: $confirmed');
    if (confirmed == true) {
      await _sendInviteToUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[LOBBY BUILD] Building LobbyScreen');
    final isSearch = _searchController.text.isNotEmpty;
    final searchQuery = _searchController.text.trim().toLowerCase();
    final currentUserEmail = _decryptedEmail;

final filteredUsers = isSearch
    ? allUsers
        .where((u) =>
            u['email'] != currentUserEmail &&
            (u['username'].toLowerCase().contains(searchQuery) ||
             u['email'].toLowerCase().contains(searchQuery)))
        .toList()
    : allUsers.where((u) => u['email'] != currentUserEmail).toList();

    final list = filteredUsers.map((u) => u['username'] as String).toList();

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by username or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
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
                          final user = filteredUsers[i];
                          final online = user['isOnline'] == true;
                          return ListTile(
                            leading: Icon(Icons.circle, color: online ? Colors.green : Colors.grey, size: 12),
                            title: Text(user['username']),
                            subtitle: Text(user['email']),
                            trailing: _inviteInProgressUser == user['username']
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Invite in Progress...'),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: _cancelInviteInProgress,
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  )
                                : ElevatedButton(
                                    onPressed: () => _showInviteConfirmationDialog(user),
                                    child: const Text('Invite'),
                                  ),
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
