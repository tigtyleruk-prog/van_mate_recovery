import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class VanFirebaseAuthService {
  VanFirebaseAuthService._({AuthService? authService})
    : _authService = authService ?? AuthService.instance;

  static final VanFirebaseAuthService instance = VanFirebaseAuthService._();

  final AuthService _authService;

  User? get currentUser => _authService.currentUser;

  String? get currentUid => _authService.currentUid;

  Future<User?> ensureSignedInOrNull({String source = 'van_mate'}) async {
    return _authService.ensureSignedInOrNull(source: source);
  }

  Future<User> ensureSignedIn({String source = 'van_mate'}) async {
    return _authService.ensureSignedIn(source: source);
  }

  Future<String?> ensureCurrentUid({String source = 'van_mate'}) async {
    return _authService.ensureCurrentUid(source: source);
  }

  Stream<User?> authStateChanges() => FirebaseAuth.instance.authStateChanges();
}
