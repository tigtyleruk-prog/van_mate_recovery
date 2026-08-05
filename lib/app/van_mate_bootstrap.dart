import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase_options.dart';
import '../features/van_mate/pages/driver_customer_reply_mock_page.dart';
import '../features/van_mate/services/van_firebase_auth_service.dart';
import '../features/van_mate/services/van_firebase_debug_logging.dart';
import '../features/van_mate/services/van_invoice_reminder_service.dart';
import '../features/van_mate/services/van_pickup_reminder_service.dart';
import '../features/van_mate/services/van_user_cloud_service.dart';
import '../features/van_mate/services/van_premium_service.dart';
import '../features/van_mate/services/van_push_notification_service.dart';
import 'van_mate_app.dart';
import 'van_mate_startup_splash.dart';

final GlobalKey<ScaffoldMessengerState> _rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> runVanMateApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(_VanMateStartupApp(scaffoldMessengerKey: _rootScaffoldMessengerKey));
}

Future<void> _initializeVanMate() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  logVanFirebaseStartup(
    stage: 'firebase initialized',
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    extra:
        'platformProjectId=${DefaultFirebaseOptions.currentPlatform.projectId} '
        'platformAppId=${DefaultFirebaseOptions.currentPlatform.appId}',
  );
  try {
    await DriverReplyMockState.instance.loadFromStorage();
  } catch (error) {
    debugPrint('Trade Mate mock state load failed: $error');
  }
  try {
    logVanFirebaseHydration(stage: 'started', target: 'cloud auth/bootstrap');
    await VanFirebaseAuthService.instance.ensureSignedIn(
      source: 'van_mate.bootstrap',
    );
    final user = FirebaseAuth.instance.currentUser;
    logVanFirebaseAuthState(stage: 'bootstrap current user', user: user);
    if (user != null) {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: user.uid,
        authType: user.isAnonymous ? 'anonymous' : 'authenticated',
        source: 'van_mate.bootstrap',
      );
    }
    logVanFirebaseHydration(stage: 'completed', target: 'cloud auth/bootstrap');
  } catch (error) {
    logVanFirebaseHydration(
      stage: 'failed',
      target: 'cloud auth/bootstrap',
      extra: error.toString(),
    );
    debugPrint('Trade Mate auth bootstrap failed: $error');
  }
  try {
    await DriverReplyMockState.instance.hydrateFromCloud();
  } catch (error) {
    debugPrint('Trade Mate cloud hydrate failed: $error');
  }
  await VanMatePremiumService.instance.ensureLoaded();
  await VanMatePushNotificationService.instance.initialize(
    scaffoldMessengerKey: _rootScaffoldMessengerKey,
  );
  await VanInvoiceReminderService.instance.initialize();
  VanPickupReminderService.instance.initialize();
  await DriverReplyMockState.instance.syncPickupReminders();
  await VanInvoiceReminderService.instance.runReminderCheck(
    invoices: DriverReplyMockState.instance.savedInvoiceHistory,
    onReminderSent: (jobKey, stageDays, sentAt) async {
      DriverReplyMockState.instance.markInvoiceReminderSentForJob(
        jobKey,
        stageDays: stageDays,
        sentAt: sentAt,
      );
    },
  );
}

class _VanMateStartupApp extends StatefulWidget {
  const _VanMateStartupApp({required this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<_VanMateStartupApp> createState() => _VanMateStartupAppState();
}

class _VanMateStartupAppState extends State<_VanMateStartupApp> {
  bool _bootstrapComplete = false;
  bool _splashAnimationComplete = false;
  bool _showApp = false;
  bool _transitionScheduled = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _initializeVanMate();
      if (!mounted) {
        return;
      }
      setState(() => _bootstrapComplete = true);
      _scheduleAppTransition();
    } catch (error) {
      if (mounted) {
        setState(() => _startupError = error);
      }
    }
  }

  void _handleSplashAnimationComplete() {
    if (!mounted || _splashAnimationComplete) {
      return;
    }
    setState(() => _splashAnimationComplete = true);
    _scheduleAppTransition();
  }

  void _scheduleAppTransition() {
    if (!_bootstrapComplete ||
        !_splashAnimationComplete ||
        _transitionScheduled) {
      return;
    }
    _transitionScheduled = true;
    setState(() => _showApp = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _startupError != null
          ? const VanMateStartupErrorApp(
              key: ValueKey('startup_error'),
              message:
                  'Business Mate could not start Firebase. Check the app configuration and relaunch.',
            )
          : _showApp
          ? VanMateApp(
              key: const ValueKey('van_mate_app'),
              scaffoldMessengerKey: widget.scaffoldMessengerKey,
            )
          : MaterialApp(
              key: const ValueKey('startup_splash'),
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.dark,
              home: VanMateStartupSplash(
                onAnimationFinished: _handleSplashAnimationComplete,
              ),
            ),
    );
  }
}

class VanMateStartupErrorApp extends StatelessWidget {
  final String message;

  const VanMateStartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 52,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Trade Mate Startup Failed',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
