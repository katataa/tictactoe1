import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/presentation/verify_email_screen.dart';
import '../game/presentation/lobby_screen.dart';
import '../game/presentation/profile_screen.dart';
import '../game/data/websocket_service.dart';
import '../data/auth_repository.dart';
import '../../../core/encryption_helper.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = '';

  @override
  void initState() {
    super.initState();
    loadUsername();
  }

Future<void> loadUsername() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final plainUsername = snapshot.data()?['searchUsername'];

    if (mounted) {
      setState(() {
        username = plainUsername ?? '[No username]';
      });
    }
  }
}


  void confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              WebSocketService().disconnect();
              final _authRepo = AuthRepository();
await _authRepo.signOut();

              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: confirmSignOut,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Welcome, $username 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (!(user?.emailVerified ?? false))
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
                  );
                },
                child: const Text("Verify Email"),
              )
            else
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LobbyScreen()),
                      );
                    },
                    child: const Text("Go to Lobby"),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    child: const Text("Profile"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
