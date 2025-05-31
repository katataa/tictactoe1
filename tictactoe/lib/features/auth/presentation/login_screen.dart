import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/home/home_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _authRepo = AuthRepository();

  bool loading = false;

  void login() async {
  setState(() => loading = true);
  try {
    final user = await _authRepo.signIn(emailController.text, passwordController.text);
    if (user != null && _authRepo.isEmailVerified()) {
      Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) => const HomeScreen()),
);
    } else {
      showSnack("Please verify your email before logging in.");
    }
  } on FirebaseAuthException catch (e) {
  switch (e.code) {
    case 'user-not-found':
      showSnack("No account found for that email.");
      break;
    case 'wrong-password':
      showSnack("Incorrect password.");
      break;
    case 'invalid-email':
      showSnack("That email address is not valid.");
      break;
    case 'too-many-requests':
      showSnack("Too many attempts. Try again later.");
      break;
    default:
      showSnack("Login failed: ${e.message ?? 'Unknown error'}");
  }
} catch (e) {
  showSnack("Something went wrong. Please check your internet and try again.");
}
 finally {
    setState(() => loading = false);
  }
}


  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : login,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Login'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
              },
              child: const Text("Forgot your password?"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
              },
              child: const Text("Create an account"),
            ),
          ],
        ),
      ),
    );
  }
}
