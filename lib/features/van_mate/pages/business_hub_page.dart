import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../models/van_business_profile.dart';
import '../services/van_business_profile_scope_storage.dart';
import '../services/van_business_profile_storage.dart';
import 'van_expenses_page.dart';
import 'van_payments_earnings_page.dart';
import 'van_business_profile_page.dart';
import 'van_booking_link_page.dart';
import 'van_completed_jobs_page.dart';
import 'van_incoming_requests_page.dart';
import 'van_invoice_history_page.dart';
import 'van_job_types_services_page.dart';
import 'van_quick_invoice_page.dart';
import 'van_job_reports_page.dart';
import 'jobs_calendar_page.dart';

Future<void> openVanBusinessHubPage(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VanBusinessHubPage()));
}

class VanBusinessHubPage extends StatefulWidget {
  const VanBusinessHubPage({super.key});

  @override
  State<VanBusinessHubPage> createState() => _VanBusinessHubPageState();
}

class _VanBusinessHubPageState extends State<VanBusinessHubPage> {
  final VanBusinessProfileScopeStorage _profileScopeStorage =
      VanBusinessProfileScopeStorage.instance;

  List<VanBusinessProfileSummary> _profiles =
      const <VanBusinessProfileSummary>[];
  VanBusinessProfileSummary? _activeProfile;
  bool _loadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _profileScopeStorage.addListener(_handleProfilesChanged);
    unawaited(_loadProfiles());
  }

  @override
  void dispose() {
    _profileScopeStorage.removeListener(_handleProfilesChanged);
    super.dispose();
  }

  void _handleProfilesChanged() {
    unawaited(_loadProfiles(showLoader: false));
  }

  Future<void> _loadProfiles({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loadingProfiles = true;
      });
    }
    final profiles = await _profileScopeStorage.loadProfiles();
    final active = await _profileScopeStorage.activeProfile();
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _activeProfile = active;
      _loadingProfiles = false;
    });
  }

  Future<void> _switchBusiness(String profileId) async {
    await _profileScopeStorage.switchProfile(profileId);
    await _loadProfiles(showLoader: false);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business switched.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addBusiness() async {
    final name = await _showBusinessNameDialog(
      title: 'Add business',
      actionLabel: 'Add',
    );
    final cleanedName = name?.trim() ?? '';
    if (cleanedName.isEmpty) {
      return;
    }

    final profile = await _profileScopeStorage.addProfile(
      cleanedName,
      activate: false,
      notify: false,
    );
    await VanBusinessProfileStorage.instance.save(
      const VanBusinessProfile.defaults().copyWith(businessName: profile.name),
      syncCloud: false,
      scopeIdOverride: profile.id,
    );
    await _waitForDialogDismissalFrame();
    if (!mounted) {
      return;
    }
    await _profileScopeStorage.switchProfile(profile.id);
    if (!mounted) {
      return;
    }
    await _loadProfiles(showLoader: false);
  }

  Future<void> _waitForDialogDismissalFrame() async {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _renameActiveBusiness() async {
    final active = _activeProfile;
    if (active == null) {
      return;
    }
    final name = await _showBusinessNameDialog(
      title: 'Rename business',
      actionLabel: 'Save',
      initialValue: active.name,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await _profileScopeStorage.renameProfile(profileId: active.id, name: name);
    final currentProfile = await VanBusinessProfileStorage.instance.load();
    await VanBusinessProfileStorage.instance.save(
      currentProfile.copyWith(businessName: name.trim()),
      syncCloud: active.id == VanBusinessProfileScopeStorage.defaultBusinessId,
    );
    await _loadProfiles(showLoader: false);
  }

  Future<String?> _showBusinessNameDialog({
    required String title,
    required String actionLabel,
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _BusinessNameDialog(
        title: title,
        actionLabel: actionLabel,
        initialValue: initialValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Business Hub'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _BusinessHubHeaderIconButton(
              icon: Icons.calendar_month_rounded,
              tooltip: 'Open calendar',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JobsCalendarPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
              children: [
                _BusinessHubHeroCard(
                  title: 'Business Hub',
                  subtitle: 'Bookings, payments, invoices and business tools.',
                ),
                const SizedBox(height: 12),
                _BusinessProfileSwitcherCard(
                  profiles: _profiles,
                  activeProfile: _activeProfile,
                  loading: _loadingProfiles,
                  onSwitch: _switchBusiness,
                  onAdd: _addBusiness,
                  onRename: _renameActiveBusiness,
                ),
                const SizedBox(height: 12),
                _BusinessHubSectionCard(
                  title: 'Work & Bookings',
                  subtitle:
                      'Set up your business tools and manage customer work.',
                  items: const <_BusinessHubActionItem>[
                    _BusinessHubActionItem(
                      title: 'Business Profile',
                      icon: Icons.badge_outlined,
                    ),
                    _BusinessHubActionItem(
                      title: 'Job Types / Services',
                      icon: Icons.design_services_outlined,
                    ),
                    _BusinessHubActionItem(
                      title: 'Booking Link',
                      icon: Icons.link_rounded,
                    ),
                    _BusinessHubActionItem(
                      title: 'Incoming Jobs',
                      icon: Icons.inbox_outlined,
                    ),
                    _BusinessHubActionItem(
                      title: 'Customer History',
                      icon: Icons.task_alt_outlined,
                    ),
                    _BusinessHubActionItem(
                      title: 'Quick Invoice',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _BusinessHubSectionCard(
                  title: 'Money & Paperwork',
                  subtitle:
                      'Track invoices, payments, expenses and yearly totals.',
                  items: const <_BusinessHubActionItem>[
                    _BusinessHubActionItem(
                      title: 'Invoices',
                      icon: Icons.receipt_long_outlined,
                    ),
                    _BusinessHubActionItem(
                      title: 'Payments',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _BusinessHubActionItem(
                      title: 'Expenses',
                      icon: Icons.trending_down_rounded,
                    ),
                    _BusinessHubActionItem(
                      title: 'Reports & Export',
                      icon: Icons.file_upload_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessNameDialog extends StatefulWidget {
  const _BusinessNameDialog({
    required this.title,
    required this.actionLabel,
    required this.initialValue,
  });

  final String title;
  final String actionLabel;
  final String initialValue;

  @override
  State<_BusinessNameDialog> createState() => _BusinessNameDialogState();
}

class _BusinessNameDialogState extends State<_BusinessNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final cleaned = _controller.text.trim();
    if (cleaned.isEmpty) {
      setState(() {
        _errorText = 'Enter a business name.';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Business name',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText == null) {
            return;
          }
          setState(() {
            _errorText = null;
          });
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _BusinessHubHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BusinessHubHeroCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return _BusinessHubGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.2,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessProfileSwitcherCard extends StatelessWidget {
  const _BusinessProfileSwitcherCard({
    required this.profiles,
    required this.activeProfile,
    required this.loading,
    required this.onSwitch,
    required this.onAdd,
    required this.onRename,
  });

  final List<VanBusinessProfileSummary> profiles;
  final VanBusinessProfileSummary? activeProfile;
  final bool loading;
  final ValueChanged<String> onSwitch;
  final VoidCallback onAdd;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final active = activeProfile;
    return _BusinessHubGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF4A7DFF).withValues(alpha: 0.18),
                  border: Border.all(
                    color: const Color(0xFF4A7DFF).withValues(alpha: 0.30),
                  ),
                ),
                child: const Icon(Icons.business_center, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading
                          ? 'Loading business...'
                          : active?.name ?? 'Default business',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Current active business',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rename business',
                onPressed: loading ? null : onRename,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final profile in profiles)
                ChoiceChip(
                  selected: profile.id == active?.id,
                  onSelected: loading ? null : (_) => onSwitch(profile.id),
                  label: Text(profile.name),
                  selectedColor: const Color(0xFF4A7DFF),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: profile.id == active?.id
                        ? const Color(0xFF4A7DFF)
                        : Colors.white.withValues(alpha: 0.16),
                  ),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ActionChip(
                onPressed: loading ? null : onAdd,
                avatar: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add another business'),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessHubSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_BusinessHubActionItem> items;

  const _BusinessHubSectionCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _BusinessHubGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.8,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 84,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _BusinessHubActionTile(
                    item: item,
                    onTap: () {
                      if (item.title == 'Business Profile') {
                        unawaited(openVanBusinessProfilePage(context));
                        return;
                      }

                      if (item.title == 'Job Types / Services') {
                        unawaited(openVanJobTypesServicesPage(context));
                        return;
                      }

                      if (item.title == 'Booking Link') {
                        unawaited(openVanBookingLinkPage(context));
                        return;
                      }

                      if (item.title == 'Incoming Jobs') {
                        unawaited(openVanIncomingRequestsPage(context));
                        return;
                      }

                      if (item.title == 'Customer History') {
                        unawaited(openVanCompletedJobsPage(context));
                        return;
                      }

                      if (item.title == 'Invoices') {
                        unawaited(openVanInvoiceHistoryPage(context));
                        return;
                      }

                      if (item.title == 'Quick Invoice') {
                        unawaited(openVanQuickInvoicePage(context));
                        return;
                      }

                      if (item.title == 'Reports & Export') {
                        unawaited(openVanJobReportsPage(context));
                        return;
                      }

                      if (item.title == 'Expenses') {
                        unawaited(openVanExpensesPage(context));
                        return;
                      }

                      if (item.title == 'Payments') {
                        unawaited(openVanPaymentsEarningsPage(context));
                        return;
                      }

                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              VanBusinessHubPlaceholderPage(title: item.title),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BusinessHubActionTile extends StatelessWidget {
  final _BusinessHubActionItem item;
  final VoidCallback onTap;

  const _BusinessHubActionTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: const Color(0xFF4A7DFF).withValues(alpha: 0.16),
                  border: Border.all(
                    color: const Color(0xFF4A7DFF).withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(item.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.48),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VanBusinessHubPlaceholderPage extends StatelessWidget {
  final String title;

  const VanBusinessHubPlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
              children: [
                _BusinessHubGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(
                            0xFF4A7DFF,
                          ).withValues(alpha: 0.16),
                          border: Border.all(
                            color: const Color(
                              0xFF4A7DFF,
                            ).withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Coming soon',
                        style: TextStyle(
                          fontSize: 13.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.74),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This Business Hub tile is a lightweight placeholder for now.',
                        style: TextStyle(
                          fontSize: 13.0,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessHubGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _BusinessHubGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BusinessHubHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BusinessHubHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _BusinessHubActionItem {
  final String title;
  final IconData icon;

  const _BusinessHubActionItem({required this.title, required this.icon});
}
