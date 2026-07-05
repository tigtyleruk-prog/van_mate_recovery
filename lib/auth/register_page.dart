import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/van_mate_app_shell.dart';
import '../pages/profile_page.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  final bool returnToProfile;

  const RegisterPage({super.key, this.returnToProfile = false});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

    try {
      final currentUser = VanMateAuthService.instance.currentUser;
      if (currentUser?.isAnonymous == true) {
        await VanMateAuthService.instance.linkGuestToEmailPassword(
          email,
          password,
        );
      } else {
        await VanMateAuthService.instance.signUpWithEmailPassword(
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
        const SnackBar(content: Text('Account ready. You are signed in now.')),
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
        _submitError = 'Create account failed. Please try again in a moment.';
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

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(returnToProfile: widget.returnToProfile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                      Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 52,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create your account',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save your van details and keep everything in sync.',
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
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        enabled: !isBusy,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) {
                          if (!isBusy) {
                            _submit();
                          }
                        },
                        enabled: !isBusy,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        validator: _validateConfirmPassword,
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
                            : const Text('Create account'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: isBusy ? null : _goToLogin,
                        child: const Text('Already have an account? Log in'),
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

  String? _validateConfirmPassword(String? value) {
    final confirmPassword = value ?? '';
    if (confirmPassword.isEmpty) {
      return 'Please confirm your password.';
    }

    if (confirmPassword != _passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
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
    return 'Please enter a password.';
  }

  if (password.length < 6) {
    return 'Use at least 6 characters.';
  }

  return null;
}

String _friendlyAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'That email address does not look valid.';
    case 'email-already-in-use':
      return 'That email is already registered. Try logging in instead.';
    case 'weak-password':
      return 'Please choose a stronger password.';
    case 'operation-not-allowed':
      return 'Email and password sign-up is not enabled right now.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    default:
      return error.message ?? 'Create account failed. Please try again.';
  }
}
