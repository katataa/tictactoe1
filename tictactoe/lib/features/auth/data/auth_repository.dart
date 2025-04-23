import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<User?> signUp(String email, String password, String username) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await result.user!.sendEmailVerification();

    await _firestore.collection('users').doc(result.user!.uid).set({
      'username': username,
      'email': email,
      'createdAt': Timestamp.now(),
    });

    return result.user;
  }

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  bool isEmailVerified() => _auth.currentUser?.emailVerified ?? false;

  Future<bool> refreshAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
