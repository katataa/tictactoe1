import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ⬅️ Add this
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app.dart';
import 'features/auth/home/home_screen.dart';
import 'features/auth/presentation/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  final bool verified = user?.emailVerified ?? false;
print("🔥 App initialized, running now...");

  runApp(
    ProviderScope( // ⬅️ Wrap the app
      child: MyApp(
        startScreen: user != null && verified ? const HomeScreen() : const LoginScreen(),
      ),
    ),
  );
}
