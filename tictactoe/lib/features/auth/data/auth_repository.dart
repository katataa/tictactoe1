import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/encryption_helper.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<User?> signUp(String email, String password, String username) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user!.sendEmailVerification();

    return result.user;
  }

 Future<void> saveUser({
  required String uid,
  required String username,
  required String email,
}) async {
  final encryptedUsername = await EncryptionHelper.encrypt(username);
  final encryptedEmail = await EncryptionHelper.encrypt(email);

  await _firestore.collection('users').doc(uid).set({
    'username': encryptedUsername,
    'email': encryptedEmail,
    'searchUsername': username.toLowerCase(),
    'searchEmail': email.toLowerCase(),
    'createdAt': Timestamp.now(),
    'avatar': 'avatar1.png',
    'wins': 0,
    'losses': 0,
  });
}

 Future<User?> signIn(String email, String password) async {
  final result = await _auth.signInWithEmailAndPassword(email: email, password: password);

  await _firestore.collection('users').doc(result.user!.uid).update({
    'isOnline': true,
  });

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
  final uid = _auth.currentUser?.uid;

  if (uid != null) {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': false,
    });
  }

  await _auth.signOut();
}

  User? get currentUser => _auth.currentUser;
}
