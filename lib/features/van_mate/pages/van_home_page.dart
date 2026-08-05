import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../helpers/van_text_formatters.dart';
import '../services/van_first_use_help_service.dart';
import '../widgets/van_first_use_help_dialog.dart';
import 'driver_customer_reply_mock_page.dart';

class VanHomePage extends StatefulWidget {
  final bool isLoading;
  final String? loadError;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenIncomingJobs;
  final VoidCallback onOpenPayments;

  const VanHomePage({
    super.key,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
    required this.onOpenCalendar,
    required this.onOpenIncomingJobs,
    required this.onOpenPayments,
  });

  @override
  State<VanHomePage> createState() => _VanHomePageState();
}

class _VanHomePageState extends State<VanHomePage> {
  bool _checkedIntro = false;
  bool _introVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowHomeIntro());
    });
  }

  Future<void> _maybeShowHomeIntro() async {
    if (_checkedIntro || _introVisible || !mounted) {
      return;
    }
    _checkedIntro = true;

    final helpService = VanMateFirstUseHelpService.instance;
    await helpService.ensureLoaded();
    if (!mounted) {
      return;
    }
    final hasSeenIntro = await helpService.hasSeen(
      VanMateFirstUseHelpKeys.seenHomeIntro,
    );
    if (!mounted || hasSeenIntro) {
      return;
    }

    _introVisible = true;
    try {
      await showVanMateFirstUseHelpDialog(
        context,
        storageKey: VanMateFirstUseHelpKeys.seenHomeIntro,
        title: 'Welcome to Business Mate',
        body:
            'Home gives you a quick view of what needs attention today.\n\n'
            'Use Calendar to plan work, Business Hub to run the business, and Routing to complete the day.',
      );
    } finally {
      _introVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DriverReplyMockState.instance,
      builder: (context, _) {
        final overview = _BusinessOverview.fromState(
          DriverReplyMockState.instance,
        );
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('home_tab'),
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 48
                      ? constraints.maxHeight - 48
                      : 0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BusinessDeskHero(overview: overview),
                        if (widget.loadError != null) ...[
                          const SizedBox(height: 16),
                          _ErrorCard(
                            message: widget.loadError!,
                            onRetry: widget.onRetry,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BusinessDeskHero extends StatelessWidget {
  const _BusinessDeskHero({required this.overview});

  final _BusinessOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0A1930),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 1.27, child: const _BusinessDeskArtwork()),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.09)),
            const SizedBox(height: 8),
            _LiveOverviewRow(overview: overview),
          ],
        ),
      ),
    );
  }
}

class _BusinessDeskArtwork extends StatefulWidget {
  const _BusinessDeskArtwork();

  @override
  State<_BusinessDeskArtwork> createState() => _BusinessDeskArtworkState();
}

class _BusinessDeskArtworkState extends State<_BusinessDeskArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _ambientController,
        builder: (context, _) {
          final phase = _ambientController.value;
          final shimmerProgress = (phase / 0.18).clamp(0.0, 1.0);
          final shimmerOpacity = phase < 0.18
              ? math.sin(shimmerProgress * math.pi) * 0.16
              : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF0A1930)),
              Image.asset(
                'assets/images/Laptop.png',
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
              ),
              Positioned(
                left: constraints.maxWidth * 0.60,
                top: constraints.maxHeight * 0.20,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: shimmerOpacity,
                    child: Transform.scale(
                      scale: 0.72 + shimmerProgress * 0.34,
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: Color(0xFF75A6FF),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: constraints.maxWidth * 0.09,
                top: constraints.maxHeight * 0.33,
                width: constraints.maxWidth * 0.09,
                height: constraints.maxHeight * 0.13,
                child: IgnorePointer(child: _MugSteam(progress: phase)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MugSteam extends StatelessWidget {
  const _MugSteam({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MugSteamPainter(progress));
  }
}

class _MugSteamPainter extends CustomPainter {
  const _MugSteamPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCFE8FF).withValues(alpha: 0.18)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sway = math.sin(progress * math.pi * 2) * size.width * 0.08;

    for (var index = 0; index < 3; index++) {
      final startX = size.width * (0.22 + index * 0.28);
      final path = Path()
        ..moveTo(startX, size.height)
        ..cubicTo(
          startX + sway,
          size.height * 0.7,
          startX - sway,
          size.height * 0.35,
          startX + sway * 0.3,
          0,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MugSteamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LiveOverviewRow extends StatelessWidget {
  const _LiveOverviewRow({required this.overview});

  final _BusinessOverview overview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S OVERVIEW",
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 7),
          FractionallySizedBox(
            widthFactor: 0.34,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: const Color(0xFF4F8DFF).withValues(alpha: 0.68),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F8DFF).withValues(alpha: 0.16),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _OverviewValue(
                icon: Icons.calendar_today_rounded,
                label: 'Today',
                value: '${overview.jobsToday} Jobs',
              ),
              const _OverviewDivider(),
              _OverviewValue(
                icon: Icons.markunread_outlined,
                label: 'New',
                value: '${overview.newRequests}',
              ),
              const _OverviewDivider(),
              _OverviewValue(
                icon: Icons.payments_outlined,
                label: 'Due',
                value: overview.outstandingAmount == 0
                    ? 'Paid'
                    : formatCurrency(overview.outstandingAmount),
              ),
              const _OverviewDivider(),
              _OverviewValue(
                icon: Icons.schedule_rounded,
                label: 'Next Job',
                value: overview.nextJobTimeLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewValue extends StatelessWidget {
  const _OverviewValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF78D8C0)),
          const SizedBox(height: 5),
          SizedBox(
            height: 20,
            child: Center(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.4,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFEAF3FF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewDivider extends StatelessWidget {
  const _OverviewDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.10),
    );
  }
}

enum _OverviewDestination { calendar, incomingJobs, payments }

class _BusinessNotification {
  const _BusinessNotification({required this.badge, required this.destination});

  final String badge;
  final _OverviewDestination destination;
}

class _BusinessOverview {
  const _BusinessOverview({
    required this.jobsToday,
    required this.newRequests,
    required this.quotesAwaiting,
    required this.outstandingAmount,
    required this.nextJob,
  });

  final int jobsToday;
  final int newRequests;
  final int quotesAwaiting;
  final double outstandingAmount;
  final DriverCustomerReplyMockData? nextJob;

  factory _BusinessOverview.fromState(DriverReplyMockState state) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final jobs = state.allJobs;
    final scheduledToday =
        jobs.where((job) {
          final date = _scheduledMoment(job);
          return date != null &&
              DateUtils.isSameDay(date, today) &&
              job.isScheduledInCalendarState &&
              !job.isCompletedJob;
        }).toList()..sort(
          (a, b) => _scheduledMoment(a)!.compareTo(_scheduledMoment(b)!),
        );
    final upcoming = scheduledToday.where((job) {
      final date = _scheduledMoment(job);
      return date != null && !date.isBefore(now);
    }).toList();
    final invoices = state.savedInvoiceHistory;
    final outstandingAmount = invoices
        .where((entry) => entry.draft.isUnpaid)
        .fold<double>(0, (total, entry) => total + entry.draft.totalDue);
    return _BusinessOverview(
      jobsToday: scheduledToday.length,
      newRequests: jobs.where((job) => job.isPendingCustomerRequest).length,
      quotesAwaiting: jobs
          .where((job) => job.isQuoteAwaitingCustomerResponse)
          .length,
      outstandingAmount: outstandingAmount,
      nextJob: upcoming.isEmpty ? null : upcoming.first,
    );
  }

  static DateTime? _scheduledMoment(DriverCustomerReplyMockData job) {
    if (job.scheduledAt != null) {
      return job.scheduledAt;
    }
    if (job.agreedDateTime != null) {
      return job.agreedDateTime;
    }
    return DateTime.tryParse(job.scheduledDate);
  }

  String get nextJobTimeLabel {
    final job = nextJob;
    if (job == null) {
      return 'Clear';
    }
    final time = job.jobTimeLabel.trim().isNotEmpty
        ? job.jobTimeLabel.trim()
        : job.scheduledStartTime.trim();
    return time.isEmpty ? 'Scheduled' : time;
  }

  _BusinessNotification get notification {
    if (newRequests > 0) {
      return _BusinessNotification(
        badge: '$newRequests',
        destination: _OverviewDestination.incomingJobs,
      );
    }
    if (quotesAwaiting > 0) {
      return _BusinessNotification(
        badge: '$quotesAwaiting',
        destination: _OverviewDestination.incomingJobs,
      );
    }
    if (outstandingAmount > 0) {
      return const _BusinessNotification(
        badge: '!',
        destination: _OverviewDestination.payments,
      );
    }
    if (nextJob != null) {
      return const _BusinessNotification(
        badge: '✓',
        destination: _OverviewDestination.calendar,
      );
    }
    return const _BusinessNotification(
      badge: '✓',
      destination: _OverviewDestination.calendar,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync issue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => unawaited(onRetry()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
