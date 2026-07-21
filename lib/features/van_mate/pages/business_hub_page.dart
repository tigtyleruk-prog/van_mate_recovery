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
import 'driver_customer_reply_mock_page.dart';

class VanIncomingJobsAttention {
  const VanIncomingJobsAttention({
    required this.actionTokens,
    required this.newIncomingRequestCount,
    required this.readyForCalendarCount,
  });

  final Set<String> actionTokens;
  final int newIncomingRequestCount;
  final int readyForCalendarCount;

  int get count => actionTokens.length;
  bool get hasAttention => count > 0;

  String get label {
    if (!hasAttention) {
      return '';
    }
    if (newIncomingRequestCount > 0) {
      return '$newIncomingRequestCount new';
    }
    if (readyForCalendarCount > 0) {
      return 'Ready for Calendar';
    }
    return 'Action needed';
  }
}

String incomingJobsAttentionToken(DriverCustomerReplyMockData job) {
  final changedAt =
      job.updatedAt ??
      job.quoteRespondedAt ??
      job.quoteAcceptedAt ??
      job.replyReceivedAt ??
      job.requestSubmittedAt;
  return [
    job.jobId.trim(),
    job.status.trim().toLowerCase(),
    job.requestStatus.trim().toLowerCase(),
    job.quoteStatus.trim().toLowerCase(),
    job.schedulingStatus.trim().toLowerCase(),
    changedAt?.toIso8601String() ?? '',
  ].join('|');
}

VanIncomingJobsAttention buildVanIncomingJobsAttention(
  Iterable<DriverCustomerReplyMockData> jobs, {
  Set<String> viewedTokens = const <String>{},
}) {
  final actionTokens = <String>{};
  var newIncomingRequestCount = 0;
  var readyForCalendarCount = 0;

  for (final job in jobs) {
    if (job.isHiddenFromNormalLists ||
        job.isCompletedJob ||
        job.isCancelled ||
        job.isScheduledInCalendarState) {
      continue;
    }
    final needsAttention =
        job.hasRequest ||
        job.hasCustomerReply ||
        job.isQuoteAwaitingCustomerResponse ||
        job.isQuoteAccepted ||
        job.isQuoteDeclined;
    if (!needsAttention) {
      continue;
    }
    final token = incomingJobsAttentionToken(job);
    if (viewedTokens.contains(token)) {
      continue;
    }
    actionTokens.add(token);
    if (job.hasRequest && !job.hasQuote) {
      newIncomingRequestCount += 1;
    }
    if (job.shouldPromptAddToCalendar || job.isReadyToAddToCalendar) {
      readyForCalendarCount += 1;
    }
  }

  return VanIncomingJobsAttention(
    actionTokens: Set<String>.unmodifiable(actionTokens),
    newIncomingRequestCount: newIncomingRequestCount,
    readyForCalendarCount: readyForCalendarCount,
  );
}

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
  final DriverReplyMockState _driverState = DriverReplyMockState.instance;

  List<VanBusinessProfileSummary> _profiles =
      const <VanBusinessProfileSummary>[];
  VanBusinessProfileSummary? _activeProfile;
  bool _loadingProfiles = true;
  final Set<String> _viewedIncomingActionTokens = <String>{};

  @override
  void initState() {
    super.initState();
    _profileScopeStorage.addListener(_handleProfilesChanged);
    _driverState.addListener(_handleIncomingJobsChanged);
    unawaited(_loadProfiles());
    unawaited(_refreshIncomingJobs());
  }

  @override
  void dispose() {
    _profileScopeStorage.removeListener(_handleProfilesChanged);
    _driverState.removeListener(_handleIncomingJobsChanged);
    super.dispose();
  }

  void _handleProfilesChanged() {
    _viewedIncomingActionTokens.clear();
    unawaited(_loadProfiles(showLoader: false));
    unawaited(_refreshIncomingJobs());
  }

  void _handleIncomingJobsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshIncomingJobs() async {
    try {
      await _driverState.loadFromStorage();
      await _driverState.refreshJobsFromCloud(forceServer: true);
    } catch (error) {
      debugPrint(
        '[BusinessHub] incoming jobs attention refresh failed: $error',
      );
    }
  }

  VanIncomingJobsAttention get _incomingJobsAttention =>
      buildVanIncomingJobsAttention(
        _driverState.pendingJobs,
        viewedTokens: _viewedIncomingActionTokens,
      );

  void _markIncomingJobsViewed() {
    _viewedIncomingActionTokens.addAll(_incomingJobsAttention.actionTokens);
  }

  Future<void> _openIncomingJobs() async {
    _markIncomingJobsViewed();
    if (mounted) {
      setState(() {});
    }
    await openVanIncomingRequestsPage(context);
    if (!mounted) {
      return;
    }
    _markIncomingJobsViewed();
    setState(() {});
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

  Future<void> _editActiveBusiness() async {
    final result = await openVanBusinessProfilePage(context);
    if (!mounted) {
      return;
    }
    await _loadProfiles(showLoader: false);
    if (!mounted) {
      return;
    }
    if (result?.businessDeleted == true) {
      final activeName = _activeProfile?.name.trim() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activeName.isEmpty
                ? 'Business deleted.'
                : 'Business deleted. Switched to $activeName.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    final incomingJobsAttention = _incomingJobsAttention;

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
                  onEdit: _editActiveBusiness,
                ),
                const SizedBox(height: 12),
                _BusinessHubSectionCard(
                  title: 'Work & Bookings',
                  subtitle:
                      'Manage your profile, services, booking link and customer jobs.',
                  incomingJobsAttention: incomingJobsAttention,
                  onOpenBusinessProfile: () => unawaited(_editActiveBusiness()),
                  onOpenIncomingJobs: () => unawaited(_openIncomingJobs()),
                  items: const <_BusinessHubActionItem>[
                    _BusinessHubActionItem(
                      title: 'Business Profile',
                      icon: Icons.badge_outlined,
                    ),
                    _BusinessHubActionItem(
                      title: 'Services',
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
    required this.onEdit,
  });

  final List<VanBusinessProfileSummary> profiles;
  final VanBusinessProfileSummary? activeProfile;
  final bool loading;
  final ValueChanged<String> onSwitch;
  final VoidCallback onAdd;
  final VoidCallback onEdit;

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
                tooltip: 'Edit business',
                onPressed: loading ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profiles.length > 1
                ? 'Tap a business to switch. Use the pencil to edit the active business.'
                : 'Use the pencil to edit this business or manage deletion safely.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 12.2,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
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
  final VanIncomingJobsAttention? incomingJobsAttention;
  final VoidCallback? onOpenBusinessProfile;
  final VoidCallback? onOpenIncomingJobs;

  const _BusinessHubSectionCard({
    required this.title,
    required this.subtitle,
    required this.items,
    this.incomingJobsAttention,
    this.onOpenBusinessProfile,
    this.onOpenIncomingJobs,
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
                    attention: item.title == 'Incoming Jobs'
                        ? incomingJobsAttention
                        : null,
                    onTap: () {
                      if (item.title == 'Business Profile') {
                        onOpenBusinessProfile?.call();
                        return;
                      }

                      if (item.title == 'Services') {
                        unawaited(openVanJobTypesServicesPage(context));
                        return;
                      }

                      if (item.title == 'Booking Link') {
                        unawaited(openVanBookingLinkPage(context));
                        return;
                      }

                      if (item.title == 'Incoming Jobs') {
                        onOpenIncomingJobs?.call();
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
  final VanIncomingJobsAttention? attention;

  const _BusinessHubActionTile({
    required this.item,
    required this.onTap,
    this.attention,
  });

  @override
  Widget build(BuildContext context) {
    final hasAttention = attention?.hasAttention ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: hasAttention
                ? const Color(0xFF4A7DFF).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: hasAttention
                  ? const Color(0xFF85A8FF).withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: hasAttention
                ? <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF4A7DFF).withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
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
              if (hasAttention) ...[
                const SizedBox(width: 8),
                _IncomingJobsAttentionBadge(label: attention!.label),
              ],
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

class _IncomingJobsAttentionBadge extends StatelessWidget {
  const _IncomingJobsAttentionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.4,
            fontWeight: FontWeight.w900,
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
