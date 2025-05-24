import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_board_screen.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void startGlobalInviteListener() {
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('invites')
        .where('toUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final invite = snapshot.docs.first;
        final data = invite.data();
        showDialog(
          context: globalNavigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Game Invite'),
            content: Text('${data['fromUsername']} wants to play!'),
            actions: [
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('invites').doc(invite.id).update({'status': 'declined'});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(globalNavigatorKey.currentContext!).showSnackBar(
                    SnackBar(content: Text('Declined invite from ${data['fromUsername']}')),
                  );
                },
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final roomId = data['roomId'] as String?;
                  if (roomId != null) {
                    await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
                      'status': 'active',
                      'joined': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid]),
                    });
                    await FirebaseFirestore.instance.collection('invites').doc(invite.id).update({'status': 'accepted'});
                    Navigator.pop(context);
                    // Navigate to game screen
                    globalNavigatorKey.currentState!.push(MaterialPageRoute(
                      builder: (_) => GameBoardScreen(
                        username: FirebaseAuth.instance.currentUser!.displayName ?? '',
                        opponent: data['fromUsername'],
                        opponentEmail: '',
                        symbol: 'O',
                        gameId: roomId,
                        timeControl: Duration(minutes: 5),
                      ),
                    ));
                  }
                },
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      }
    });
  });
} 