import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'van_firebase_debug_logging.dart';

class AuthService {
  AuthService._({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static final AuthService instance = AuthService._();
  static const String unavailableMessage =
      'Van Mate could not sign in right now.';

  final FirebaseAuth _auth;
  Future<User>? _ensureSignedInFuture;
  AuthUnavailableException? _cachedEnsureSignedInFailure;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => currentUser?.uid;

  Future<User?> ensureSignedInOrNull({String source = 'unknown'}) async {
    try {
      return await ensureSignedIn(source: source);
    } on AuthUnavailableException catch (_) {
      return null;
    }
  }

  Future<User> ensureSignedIn({String source = 'unknown'}) async {
    final existingUser = _auth.currentUser;

    if (existingUser != null) {
      logVanFirebaseAuthState(
        stage: 'existing user reused source=$source',
        user: existingUser,
      );
      return existingUser;
    }

    final inFlightRequest = _ensureSignedInFuture;
    if (inFlightRequest != null) {
      return inFlightRequest;
    }

    final cachedFailure = _cachedEnsureSignedInFailure;
    if (cachedFailure != null) {
      throw cachedFailure;
    }

    final signInFuture = _signInAnonymously(source);
    _ensureSignedInFuture = signInFuture;

    try {
      return await signInFuture;
    } finally {
      if (identical(_ensureSignedInFuture, signInFuture)) {
        _ensureSignedInFuture = null;
      }
    }
  }

  Future<String?> ensureCurrentUid({String source = 'unknown'}) async {
    final user = await ensureSignedInOrNull(source: source);
    return currentUid ?? user?.uid;
  }

  Future<User> _signInAnonymously(String source) async {
    debugPrint('[VanFirebase][Auth] sign-in start source=$source');
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        final exception = const AuthUnavailableException(unavailableMessage);
        debugPrint(
          '[VanFirebase][Auth] sign-in failed source=$source error=no-user',
        );
        _cachedEnsureSignedInFailure = exception;
        throw exception;
      }

      _cachedEnsureSignedInFailure = null;
      logVanFirebaseAuthState(
        stage: 'anonymous sign-in success source=$source',
        user: user,
      );
      return user;
    } on FirebaseAuthException catch (error) {
      debugPrint(
        '[VanFirebase][Auth] sign-in failed source=$source '
        'code=${error.code} message=${error.message ?? ''}',
      );
      final exception = _mapFirebaseAuthException(error);
      _cachedEnsureSignedInFailure = exception;
      throw exception;
    } catch (_) {
      debugPrint('[VanFirebase][Auth] sign-in failed source=$source error=unknown');
      final exception = const AuthUnavailableException(unavailableMessage);
      _cachedEnsureSignedInFailure = exception;
      throw exception;
    }
  }

  AuthUnavailableException _mapFirebaseAuthException(
    FirebaseAuthException error,
  ) {
    return const AuthUnavailableException(unavailableMessage);
  }
}

class AuthUnavailableException implements Exception {
  final String message;

  const AuthUnavailableException(this.message);

  @override
  String toString() => message;
}
