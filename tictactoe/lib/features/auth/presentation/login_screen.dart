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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        showSnack("Please verify your email before logging in.");
      }
    } catch (e) {
      showSnack(e.toString());
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
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: loading ? null : login, child: const Text('Login')),
            TextButton(
  onPressed: () {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
  },
  child: const Text("Forgot your password?"),
),

          ],
        ),
      ),
    );
  }
}
