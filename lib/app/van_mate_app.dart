import 'package:flutter/material.dart';

import '../auth/auth_gate.dart';
import 'van_mate_theme.dart';
import 'workspace/van_mate_workspace_scope.dart';

class VanMateApp extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const VanMateApp({super.key, required this.scaffoldMessengerKey});

  @override
  Widget build(BuildContext context) {
    return VanMateWorkspaceScope(
      config: VanMateWorkspaceConfig.personal(),
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Trade Mate',
        theme: VanMateTheme.light(),
        darkTheme: VanMateTheme.dark(),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}
