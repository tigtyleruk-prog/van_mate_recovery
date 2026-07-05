import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/van_mate_app_shell.dart';
import '../pages/profile_page.dart';
import '../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final bool returnToProfile;

  const LoginPage({super.key, this.returnToProfile = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    var usedGuestLinkFallback = false;

    try {
      final currentUser = VanMateAuthService.instance.currentUser;
      if (currentUser?.isAnonymous == true) {
        try {
          await VanMateAuthService.instance.linkGuestToEmailPassword(
            email,
            password,
          );
        } on FirebaseAuthException catch (error) {
          if (error.code == 'credential-already-in-use' ||
              error.code == 'email-already-in-use') {
            usedGuestLinkFallback = true;
            await VanMateAuthService.instance.signInWithEmailPassword(
              email,
              password,
            );
          } else {
            rethrow;
          }
        }
      } else {
        await VanMateAuthService.instance.signInWithEmailPassword(
          email,
          password,
        );
      }

      await VanMateAuthService.instance.waitForCurrentUserReady(
        requireNonAnonymous: true,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            usedGuestLinkFallback
                ? 'Signed in to your existing account. Guest data is still on the guest account.'
                : 'Signed in successfully.',
          ),
        ),
      );
      _goToSignedInDestination();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitError = _friendlyAuthError(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitError = 'Log in failed. Please try again in a moment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _goToSignedInDestination() {
    if (widget.returnToProfile) {
      Navigator.of(
        context,
      ).popUntil((route) => route.settings.name == ProfilePage.routeName);
      return;
    }

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/van-mate-shell'),
        builder: (_) => const VanMateAppShell(),
      ),
      (route) => false,
    );
  }

  void _goToRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegisterPage(returnToProfile: widget.returnToProfile),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _PasswordResetDialog(initialEmail: _emailController.text.trim()),
    );

    if (!mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'If an account exists for that email, a reset link has been sent.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRect(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 160,
                              maxHeight: 76,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: 0.92,
                              child: Stack(
                                alignment: Alignment.topCenter,
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 24,
                                    right: 24,
                                    bottom: 0,
                                    child: Container(
                                      height: 11,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF0B1220,
                                            ).withValues(alpha: 0.52),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
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
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to sync your Trade Mate data across devices.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        enabled: !isBusy,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) {
                          if (!isBusy) {
                            _submit();
                          }
                        },
                        enabled: !isBusy,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: _validatePassword,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isBusy ? null : _forgotPassword,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_submitError != null) ...[
                        Text(
                          _submitError!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: isBusy ? null : _submit,
                        child: isBusy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Log in'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: isBusy ? null : _goToRegister,
                        child: const Text('Need an account? Create one'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordResetDialog extends StatefulWidget {
  final String initialEmail;

  const _PasswordResetDialog({required this.initialEmail});

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final email = _emailController.text.trim();

    try {
      await VanMateAuthService.instance.sendPasswordResetEmail(email);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(email);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.code == 'user-not-found') {
        Navigator.of(context).pop(email);
        return;
      }

      setState(() {
        _errorText = _friendlyResetError(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText =
            'We could not send the reset link right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSubmitting;

    return AlertDialog(
      backgroundColor: const Color(0xFF0F1623),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Reset password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Enter your email and we’ll send you a reset link.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enabled: !isBusy,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!isBusy) {
                    _sendResetLink();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                ),
                validator: _validateEmail,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isBusy ? null : _sendResetLink,
          child: isBusy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send reset link'),
        ),
      ],
    );
  }
}

String _friendlyResetError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'operation-not-allowed':
      return 'Password reset is not enabled right now.';
    default:
      return 'We could not send the reset link right now. Please try again.';
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Please enter your email address.';
  }

  if (!email.contains('@') || !email.contains('.')) {
    return 'Please enter a valid email address.';
  }

  return null;
}

String? _validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Please enter your password.';
  }

  return null;
}

String _friendlyAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'That email address does not look valid.';
    case 'user-not-found':
      return 'No account was found for that email address.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'That email or password is incorrect.';
    case 'user-disabled':
      return 'This account has been disabled. Please contact support.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'operation-not-allowed':
      return 'Email and password sign-in is not enabled right now.';
    default:
      return error.message ?? 'Log in failed. Please try again.';
  }
}
