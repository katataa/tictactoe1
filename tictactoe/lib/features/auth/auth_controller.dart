import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);

final authControllerProvider = StateNotifierProvider<AuthController, User?>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<User?> {
  final Ref ref;
  AuthController(this.ref) : super(null);

  Future<void> signIn(String email, String password) async {
    final auth = ref.read(firebaseAuthProvider);
    final result = await auth.signInWithEmailAndPassword(email: email, password: password);
    state = result.user;
  }

  Future<void> register(String email, String password) async {
    final auth = ref.read(firebaseAuthProvider);
    final result = await auth.createUserWithEmailAndPassword(email: email, password: password);
    state = result.user;
    await result.user?.sendEmailVerification();
  }

  Future<void> sendResetLink(String email) async {
    final auth = ref.read(firebaseAuthProvider);
    await auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    final auth = ref.read(firebaseAuthProvider);
    await auth.signOut();
    state = null;
  }
}
