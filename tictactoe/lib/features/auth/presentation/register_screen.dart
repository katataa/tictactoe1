import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/validators.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  final _authRepo = AuthRepository();

  bool loading = false;

void register() async {
  final passwordError = validatePassword(passwordController.text);
  if (passwordError != null) {
    showSnack(passwordError);
    return;
  }

  setState(() => loading = true);
  try {
    await _authRepo.signUp(
      emailController.text,
      passwordController.text,
      usernameController.text,
    );

    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    await FirebaseAuth.instance.currentUser?.sendEmailVerification();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'email-already-in-use':
        showSnack("That email is already registered.");
        break;
      case 'invalid-email':
        showSnack("Please enter a valid email address.");
        break;
      case 'weak-password':
        showSnack("Password should be at least 6 characters.");
        break;
      default:
        showSnack("Registration failed: ${e.message}");
    }
  } catch (e) {
    showSnack("Something went wrong during registration.");
  } finally {
    setState(() => loading = false);
  }
}

  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : register,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
