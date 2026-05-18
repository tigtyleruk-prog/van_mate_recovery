import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/van_mate_app_shell.dart';
import '../services/auth_service.dart';
import 'auth_choice_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        return const VanMateAppShell();
      },
    );
  }
}
