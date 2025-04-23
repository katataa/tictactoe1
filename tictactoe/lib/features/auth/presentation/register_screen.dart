import 'package:flutter/material.dart';
import '../../../core/validators.dart';
import '../../auth/data/auth_repository.dart';

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
      if (!mounted) return;

      showSnack("Check your email for verification!");
      Navigator.pop(context);
    } catch (e) {
      showSnack(e.toString());
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
          children: [
            TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: loading ? null : register, child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}
