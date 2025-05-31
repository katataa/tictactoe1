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
  String? errorMsg;

void login() async {
  setState(() {
    loading = true;
    errorMsg = null;
  });

  final email = emailController.text.trim();
  final password = passwordController.text.trim();

  try {
    final user = await _authRepo.signIn(email, password);

    if (user != null && _authRepo.isEmailVerified()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      showSnack("Please verify your email before logging in.");
    }
  } on FirebaseAuthException catch (e) {
    String msg;
    switch (e.code) {
      case 'user-not-found':
        msg = "No account found for that email.";
        break;
      case 'wrong-password':
        msg = "Incorrect password.";
        break;
      case 'invalid-email':
        msg = "That email address is not valid.";
        break;
      case 'too-many-requests':
        msg = "Too many attempts. Try again later.";
        break;
      default:
        msg = "Login failed: ${e.message ?? 'Unknown error'}";
    }
    setState(() => errorMsg = msg);
  } catch (e) {
    setState(() => errorMsg = "Something went wrong. Check your internet and try again.");
  } finally {
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
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
