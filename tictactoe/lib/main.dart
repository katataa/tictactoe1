import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/auth/home/home_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart'; // ⬅️ ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  final bool verified = user?.emailVerified ?? false;
  print("🔥 App initialized, running now...");

  runApp(
    ProviderScope(
      child: MyApp(
        startScreen: user == null
            ? const LoginScreen()
            : (verified ? const HomeScreen() : const VerifyEmailScreen()),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Join The Fun',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: startScreen,
      routes: {
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}
