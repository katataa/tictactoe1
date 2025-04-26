import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  String selectedAvatar = 'avatar1.png';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      if (data != null) {
        _usernameController.text = data['username'] ?? '';
        selectedAvatar = data['avatar'] ?? 'avatar1.png';
        setState(() {});
      }
    }
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'username': _usernameController.text.trim(),
      'avatar': selectedAvatar,
    });

    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarOptions = [
      'avatar1.png',
      'avatar2.png',
      'avatar3.png',
      'avatar4.png',
      'avatar5.png',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Choose Your Avatar', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: avatarOptions.map((avatar) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedAvatar = avatar),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedAvatar == avatar ? Colors.blue : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: Image.asset('assets/avatars/$avatar', width: 80, height: 80),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saveProfile,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}
