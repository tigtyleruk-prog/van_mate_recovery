import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthChoicePage extends StatefulWidget {
  const AuthChoicePage({super.key});

  @override
  State<AuthChoicePage> createState() => _AuthChoicePageState();
}

class _AuthChoicePageState extends State<AuthChoicePage> {
  bool _isSigningInGuest = false;
  String? _guestError;

  Future<void> _continueAsGuest() async {
    if (_isSigningInGuest) {
      return;
    }

    setState(() {
      _isSigningInGuest = true;
      _guestError = null;
    });

    try {
      await VanMateAuthService.instance.signInAnonymously();

      if (!mounted) {
        return;
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.message ?? 'Guest sign-in failed.';
      setState(() {
        _guestError = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      const message = 'Guest sign-in failed. Please try again.';
      setState(() {
        _guestError = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSigningInGuest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSigningInGuest;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRect(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 180,
                          maxHeight: 82,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: 0.92,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 28,
                                right: 28,
                                bottom: 0,
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0B1220,
                                        ).withValues(alpha: 0.52),
                                        blurRadius: 16,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFF3F5F96),
                                        Color(0xFF182337),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.68, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Image.asset(
                                'assets/images/van_mate_van_login.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Van Mate',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to keep your van data in sync, or continue as a guest for now.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: isBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: isBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                    child: const Text('Log in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isBusy ? null : _continueAsGuest,
                    child: isBusy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue as guest'),
                  ),
                  if (_guestError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _guestError!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
