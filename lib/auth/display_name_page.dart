import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class DisplayNamePage extends StatefulWidget {
  final String title;
  final String helperText;
  final String submitLabel;
  final String? initialDisplayName;
  final bool allowSkip;

  const DisplayNamePage({
    super.key,
    required this.title,
    required this.helperText,
    required this.submitLabel,
    this.initialDisplayName,
    this.allowSkip = false,
  });

  @override
  State<DisplayNamePage> createState() => _DisplayNamePageState();
}

class _DisplayNamePageState extends State<DisplayNamePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialDisplayName ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
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

    try {
      await VanMateAuthService.instance.updateDisplayName(
        _displayNameController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
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
        _submitError = 'Could not save your name right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _skip() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isSubmitting;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                        Icons.badge_outlined,
                        size: 54,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.helperText,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _displayNameController,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.nickname],
                        enabled: !isBusy,
                        autofocus: true,
                        onFieldSubmitted: (_) {
                          if (!isBusy) {
                            _submit();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                        validator: _validateDisplayName,
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
                            : Text(widget.submitLabel),
                      ),
                      if (widget.allowSkip) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isBusy ? null : _skip,
                          child: const Text('Not now'),
                        ),
                      ],
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

String? _validateDisplayName(String? value) {
  final displayName = value?.trim() ?? '';
  if (displayName.isEmpty) {
    return 'Please enter a display name.';
  }

  return null;
}

String _friendlyAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'no-current-user':
      return 'No signed-in user is available right now.';
    case 'invalid-display-name':
      return 'Please enter a display name.';
    default:
      return error.message ?? 'Could not save your name right now.';
  }
}
