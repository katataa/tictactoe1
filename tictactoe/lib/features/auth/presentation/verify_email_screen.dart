import 'dart:async'; // 🧠 ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    checkEmailVerified();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.emailVerified ?? false) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

 @override
Widget build(BuildContext context) => Scaffold(
  appBar: AppBar(title: const Text('Verify Email')),
  body: Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('A verification email has been sent to your email.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          const CircularProgressIndicator(),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text("Entered wrong email? Go back"),
          ),
        ],
      ),
    ),
  ),
);

}
