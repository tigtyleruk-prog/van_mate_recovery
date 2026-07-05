import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_choice_page.dart';
import '../auth/display_name_page.dart';
import '../features/van_mate/pages/van_premium_page.dart';
import '../features/van_mate/pages/van_community_review_page.dart';
import '../features/van_mate/services/van_community_admin_service.dart';
import '../features/van_mate/services/van_navigation_service.dart';
import '../features/van_mate/services/van_premium_service.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  static const String routeName = '/profile';

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _promptedDisplayNameForUid;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    unawaited(VanMatePremiumService.instance.ensureLoaded());
    unawaited(VanMateNavigationService.instance.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: VanMateAuthService.instance.userChanges(),
      initialData: VanMateAuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isGuest = user?.isAnonymous ?? true;
        final email = user?.email?.trim();
        final uid = user?.uid;
        final displayName = user?.displayName?.trim();
        final hasDisplayName = displayName?.isNotEmpty == true;
        final theme = Theme.of(context);

        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.16),
                            child: Text(
                              'V',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Log in to manage your profile',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are not signed in right now.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => _openAuthChoice(context),
                          child: const Text('Log in or create account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (!isGuest && !hasDisplayName) {
          _scheduleDisplayNamePrompt(user);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.16,
                          ),
                          child: Text(
                            _profileAvatarLabel(
                              displayName: displayName,
                              email: email,
                              isGuest: isGuest,
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hasDisplayName
                            ? displayName!
                            : (isGuest ? 'Guest profile' : 'Add your name'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _profileSubtitle(
                          isGuest: isGuest,
                          email: email,
                          hasDisplayName: hasDisplayName,
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Display name',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasDisplayName
                                  ? displayName!
                                  : 'No display name set yet.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => _openDisplayNameEditor(
                                user,
                                autoPrompt: false,
                              ),
                              child: Text(
                                hasDisplayName
                                    ? 'Edit display name'
                                    : 'Set display name',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: VanMateNavigationService.instance,
                        builder: (context, _) {
                          final navigationService =
                              VanMateNavigationService.instance;
                          final preferredApp =
                              navigationService.preferredNavigationApp;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Preferred navigation app',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose which app opens when you tap Navigate.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child:
                                        DropdownButton<
                                          VanPreferredNavigationApp
                                        >(
                                          value: preferredApp,
                                          isExpanded: true,
                                          dropdownColor: const Color(
                                            0xFF14243C,
                                          ),
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Colors.white70,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          items: VanPreferredNavigationApp
                                              .values
                                              .map(
                                                (app) =>
                                                    DropdownMenuItem<
                                                      VanPreferredNavigationApp
                                                    >(
                                                      value: app,
                                                      child: Text(app.label),
                                                    ),
                                              )
                                              .toList(growable: false),
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }

                                            unawaited(
                                              navigationService
                                                  .setPreferredNavigationApp(
                                                    value,
                                                  ),
                                            );
                                          },
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  navigationService
                                      .describePreferredNavigationApp(
                                        preferredApp,
                                      ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (uid != null && uid.isNotEmpty)
                        StreamBuilder<bool>(
                          stream: VanCommunityAdminService.instance
                              .watchIsAdmin(uid),
                          initialData: false,
                          builder: (context, adminSnapshot) {
                            if (adminSnapshot.data != true) {
                              return const SizedBox.shrink();
                            }

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_user_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Admin Review',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Review community submissions before they become public.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.4,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const VanCommunityReviewPage(),
                                        ),
                                      );
                                    },
                                    child: const Text('Open Admin Review'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (uid != null && uid.isNotEmpty)
                        const SizedBox(height: 12),
                      _DetailCard(
                        label: 'Account type',
                        value: isGuest ? 'Guest account' : 'Email account',
                      ),
                      const SizedBox(height: 12),
                      _DetailCard(
                        label: 'Email address',
                        value: email?.isNotEmpty == true
                            ? email!
                            : 'Not available',
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: VanMatePremiumService.instance,
                        builder: (context, _) {
                          final premiumService = VanMatePremiumService.instance;
                          final premiumEnabled = premiumService.isPremium;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Van Mate Premium',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                      ),
                                    ),
                                    _ProfileStatusPill(
                                      label: premiumEnabled
                                          ? 'Premium'
                                          : 'Free',
                                      accent: premiumEnabled
                                          ? const Color(0xFF58D0A4)
                                          : const Color(0xFF7EA2FF),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Keep subscription and Premium controls here. Scan Drop OCR, Google road preview, Route Templates, Smart Auto Plan, and test toggles all sit behind this card.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        premiumEnabled
                                            ? 'Premium active'
                                            : 'Premium off',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                      ),
                                    ),
                                    Switch(
                                      value: premiumEnabled,
                                      onChanged: (value) async {
                                        await premiumService.setPremiumEnabled(
                                          value,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  premiumEnabled
                                      ? 'Premium is enabled locally for testing.'
                                      : 'Premium is off. Toggle it here to test Premium flows.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const VanPremiumPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('Open Premium'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            title: Text(
                              'Account details',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'UID and technical details',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            children: [
                              _DetailCard(
                                label: 'User UID',
                                value: uid ?? 'Not available',
                                monospace: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isGuest) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.10,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: Text(
                            'Guest accounts are temporary. Create an account or log in to keep your van data across reinstalls and devices.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const UpgradeGuestAccountPage(),
                              ),
                            );
                          },
                          child: const Text('Upgrade guest account'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _openAuthChoice(context),
                          child: const Text('Log in or create account'),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _isSigningOut ? null : _signOut,
                          child: _isSigningOut
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign out'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAuthChoice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/profile-auth-choice'),
        builder: (_) => const AuthChoicePage(returnToProfile: true),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await VanMateAuthService.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthChoicePage()),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _scheduleDisplayNamePrompt(User user) {
    final uid = user.uid;
    if (_promptedDisplayNameForUid == uid) {
      return;
    }

    _promptedDisplayNameForUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _openDisplayNameEditor(user, autoPrompt: true);
    });
  }

  Future<void> _openDisplayNameEditor(
    User user, {
    required bool autoPrompt,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DisplayNamePage(
          title: autoPrompt ? 'What should we call you?' : 'Edit display name',
          helperText: autoPrompt
              ? 'Pick a display name so your Profile feels more personal.'
              : 'Change the name shown on Profile and anywhere Van Mate uses your account.',
          submitLabel: autoPrompt ? 'Save name' : 'Save changes',
          initialDisplayName: user.displayName,
          allowSkip: autoPrompt,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Display name saved.')));
    }
  }

  String _profileSubtitle({
    required bool isGuest,
    required String? email,
    required bool hasDisplayName,
  }) {
    if (isGuest) {
      return 'You are using a guest account right now.';
    }

    if (hasDisplayName && email?.isNotEmpty == true) {
      return 'Signed in with $email.';
    }

    if (hasDisplayName) {
      return 'You are signed in with a full account.';
    }

    if (email?.isNotEmpty == true) {
      return 'Signed in with $email. Add a display name to make it feel more personal.';
    }

    return 'You are signed in with a full account.';
  }

  String _profileAvatarLabel({
    required String? displayName,
    required String? email,
    required bool isGuest,
  }) {
    final name = displayName?.trim();
    if (name?.isNotEmpty == true) {
      return name!.substring(0, 1).toUpperCase();
    }

    final trimmedEmail = email?.trim() ?? '';
    if (trimmedEmail.isNotEmpty) {
      return trimmedEmail.substring(0, 1).toUpperCase();
    }

    return isGuest ? 'G' : 'V';
  }
}

class _DetailCard extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _DetailCard({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
              fontFamily: monospace ? 'monospace' : null,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatusPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _ProfileStatusPill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class UpgradeGuestAccountPage extends StatefulWidget {
  const UpgradeGuestAccountPage({super.key});

  @override
  State<UpgradeGuestAccountPage> createState() =>
      _UpgradeGuestAccountPageState();
}

class _UpgradeGuestAccountPageState extends State<UpgradeGuestAccountPage> {
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

    try {
      final result = await VanMateAuthService.instance.linkGuestToEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (result.user == null) {
        setState(() {
          _submitError = 'Upgrade failed. Please try again.';
        });
        return;
      }

      Navigator.of(context).pop();
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
        _submitError = 'Upgrade failed. Please try again in a moment.';
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
    final isGuest =
        VanMateAuthService.instance.currentUser?.isAnonymous ?? false;
    final canUpgrade = isGuest && !_isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade guest account')),
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
                        Icons.upgrade_outlined,
                        size: 54,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Turn this guest session into a permanent account',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your existing Firebase user will be linked to email and password, so your Van Mate data stays attached to the same identity.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (!isGuest) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.10,
                            ),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.24,
                              ),
                            ),
                          ),
                          child: Text(
                            'This upgrade flow is only available to guest accounts.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        enabled: canUpgrade,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        enabled: canUpgrade,
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
                          if (canUpgrade) {
                            _submit();
                          }
                        },
                        enabled: canUpgrade,
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
                        onPressed: canUpgrade ? _submit : null,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create permanent account'),
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

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'That email is already linked to another account. Try logging in instead.';
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'requires-recent-login':
        return 'Please sign in again and try the upgrade once more.';
      case 'no-current-user':
        return 'No guest account is available to upgrade right now.';
      case 'not-anonymous':
        return 'This account has already been upgraded.';
      case 'operation-not-allowed':
        return 'Email and password linking is not enabled right now.';
      default:
        return error.message ?? 'Upgrade failed. Please try again.';
    }
  }
}
