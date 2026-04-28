import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diet_cure/core/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //Having problem with the "Stream" method so trying Future method
  Stream<User?> get authStateChanges => _auth.idTokenChanges();

  Future<User?> getCurrentAuthUser() async {
    return _auth.currentUser;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user!.updateDisplayName(displayName);
    await saveUserToFirestore(credential.user!, role, displayName);

    return credential;
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Phone verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> saveUserToFirestore(User user, UserRole role, [String? displayNameOverride,]) async {
    final appUser = AppUser(
      uid: user.uid,
      displayName: displayNameOverride ?? user.displayName ?? '',
      email: user.email,
      photoUrl: user.photoURL ?? '',
      role: role,
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(appUser.toMap());
  }

  Future<AppUser?> getUserFromFirestore(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.data()!, uid);
  }

  Future<void> assignRole(String uid, UserRole role) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'not_authenticated',
        message: 'Not Authenticated',
      );
    }

    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final currentUserRole = UserRole.values.firstWhere(
      (r) => r.name == currentUserDoc['role'],
    );

    if (currentUserRole != UserRole.admin) {
      throw FirebaseAuthException(
        code: 'permission_denied',
        message: 'Only admins can assign roles',
      );
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': role.name,
    });
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return await getUserFromFirestore(user.uid);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
