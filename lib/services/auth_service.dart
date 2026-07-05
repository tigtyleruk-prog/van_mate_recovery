import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class VanMateAuthService {
  VanMateAuthService._({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  static final VanMateAuthService instance = VanMateAuthService._();

  final FirebaseAuth _auth;

  Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }

  Future<UserCredential> signUpWithEmailPassword(
    String email,
    String password,
  ) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<User?> waitForCurrentUserReady({
    Duration timeout = const Duration(seconds: 5),
    bool requireNonAnonymous = false,
  }) async {
    var user = _auth.currentUser;

    final hasReadyUser =
        user != null && (!requireNonAnonymous || user.isAnonymous == false);
    if (!hasReadyUser) {
      try {
        user = await _auth
            .authStateChanges()
            .firstWhere(
              (candidate) =>
                  candidate != null &&
                  (!requireNonAnonymous || candidate.isAnonymous == false),
            )
            .timeout(timeout);
      } on TimeoutException {
        user = _auth.currentUser;
      }
    }

    if (user != null) {
      try {
        await user.reload();
      } catch (_) {
        // If reload fails, keep the authenticated user we already have.
      }
      user = _auth.currentUser ?? user;
    }

    return user;
  }

  Future<User?> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    final trimmedName = displayName.trim();

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user is available right now.',
      );
    }

    if (trimmedName.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-display-name',
        message: 'Please enter a display name.',
      );
    }

    await user.updateDisplayName(trimmedName);
    await user.reload();
    return _auth.currentUser ?? user;
  }

  Future<UserCredential> linkGuestToEmailPassword(
    String email,
    String password,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user is available to upgrade.',
      );
    }

    if (!user.isAnonymous) {
      throw FirebaseAuthException(
        code: 'not-anonymous',
        message: 'Only guest accounts can be upgraded from this flow.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    return user.linkWithCredential(credential);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;
}
