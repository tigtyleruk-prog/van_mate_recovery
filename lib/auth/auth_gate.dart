import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/van_mate_app_shell.dart';
import '../features/van_mate/pages/driver_customer_reply_mock_page.dart';
import '../services/auth_service.dart';
import 'auth_choice_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<User?> _authSubscription;
  bool _handledInitialAuthState = false;
  Future<void>? _hydrateFuture;

  @override
  void initState() {
    super.initState();
    _authSubscription = VanMateAuthService.instance.authStateChanges().listen(
      _handleAuthChanged,
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _handleAuthChanged(User? user) {
    if (!_handledInitialAuthState) {
      _handledInitialAuthState = true;
      return;
    }

    if (user == null) {
      if (mounted && _hydrateFuture != null) {
        setState(() {
          _hydrateFuture = null;
        });
      }
      return;
    }

    final future = DriverReplyMockState.instance.hydrateFromCloud();
    if (mounted) {
      setState(() {
        _hydrateFuture = future;
      });
    }
    unawaited(
      future.whenComplete(() {
        if (!mounted) {
          return;
        }
        if (identical(_hydrateFuture, future)) {
          setState(() {
            _hydrateFuture = null;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: VanMateAuthService.instance.authStateChanges(),
      initialData: VanMateAuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthChoicePage();
        }

        if (_hydrateFuture != null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const VanMateAppShell();
      },
    );
  }
}
