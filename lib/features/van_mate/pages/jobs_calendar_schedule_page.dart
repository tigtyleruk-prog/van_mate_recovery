// ignore_for_file: unused_field

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_job_navigation.dart';
import 'create_invoice_page.dart';
import 'driver_customer_reply_mock_page.dart';
import 'create_job_request_flow.dart';
import 'job_detail_page.dart';
import 'van_invoice_preview_page.dart';

class JobsCalendarSchedulePage extends StatefulWidget {
  const JobsCalendarSchedulePage({super.key});

  @override
  State<JobsCalendarSchedulePage> createState() =>
      _JobsCalendarSchedulePageState();
}

class _JobsCalendarSchedulePageState extends State<JobsCalendarSchedulePage> {
  late DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  List<_ScheduleDayData> get _realDays => _buildRealDays();

  _ScheduleDayData get _selectedRealDay {
    final days = _realDays;
    if (days.isEmpty) {
      return _ScheduleDayData(
        label: 'Today',
        dateLabel: _formatScheduleDate(DateTime.now()),
        jobCount: 0,
        accent: const Color(0xFF9AA3B2),
        state: _ScheduleDayState.empty,
        jobs: const <_ScheduleJobData>[],
        date: DateUtils.dateOnly(DateTime.now()),
      );
    }

    for (final day in days) {
      if (DateUtils.isSameDay(day.date, _selectedDate)) {
        return day;
      }
    }

    return days.first;
  }

  List<_ScheduleDayData> _buildRealDays() {
    final jobsByDate = <DateTime, List<DriverCustomerReplyMockData>>{};
    for (final job in DriverReplyMockState.instance.jobs) {
      final scheduledAt = job.scheduledAtOrParsed;
      if (scheduledAt == null || job.status == 'draft' || job.isCancelled) {
        continue;
      }
      final day = DateUtils.dateOnly(scheduledAt);
      jobsByDate
          .putIfAbsent(day, () => <DriverCustomerReplyMockData>[])
          .add(job);
    }

    final today = DateUtils.dateOnly(DateTime.now());
    return List<_ScheduleDayData>.generate(7, (index) {
      final date = today.add(Duration(days: index));
      final jobs = jobsByDate[date] ?? const <DriverCustomerReplyMockData>[];
      final state = DateUtils.isSameDay(date, today)
          ? _ScheduleDayState.today
          : _scheduleStateForJobs(jobs);
      return _ScheduleDayData(
        label: _scheduleDayLabel(date),
        dateLabel: _formatScheduleDate(date),
        jobCount: jobs.length,
        accent: _scheduleAccentForState(state),
        state: state,
        jobs: jobs.map(_buildScheduleJobData).toList(growable: false),
        date: date,
      );
    });
  }

  _ScheduleJobData _buildScheduleJobData(DriverCustomerReplyMockData job) {
    final status = _scheduleJobStatusForJob(job);
    final savedInvoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );

    final actions = job.isCompleted
        ? <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'View job',
              enabled: true,
              icon: Icons.open_in_new_rounded,
              onTap: () => _openJobFor(job),
            ),
            if (job.quoteAmount != null)
              _ScheduleActionData(
                label: 'View quote',
                enabled: true,
                icon: Icons.request_quote_outlined,
                onTap: () => _createQuoteFor(job),
              ),
            _ScheduleActionData(
              label: savedInvoice == null ? 'Create invoice' : 'View invoice',
              enabled: true,
              icon: Icons.receipt_long_outlined,
              onTap: savedInvoice == null
                  ? () => _createInvoiceFor(job)
                  : () => _viewInvoiceFor(job),
            ),
            if (!job.isDraft && (job.isReplyReceived || job.exactPinShared))
              _ScheduleActionData(
                label: 'View reply',
                enabled: true,
                icon: Icons.question_answer,
                onTap: () => _openReplyFor(job),
              ),
          ]
        : <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'Open Job',
              enabled: true,
              icon: Icons.open_in_new_rounded,
              onTap: () => _openJobFor(job),
            ),
            _ScheduleActionData(
              label: 'Navigate',
              enabled: true,
              icon: Icons.navigation,
              onTap: () => _navigateFor(job),
            ),
            _ScheduleActionData(
              label: 'View reply',
              enabled: _hasCustomerReply(job),
              icon: Icons.question_answer,
              onTap: () => _openReplyFor(job),
            ),
            _ScheduleActionData(
              label: job.isQuoteSent || job.isConfirmed || job.isCompleted
                  ? 'View quote'
                  : 'Create quote (job info)',
              enabled: !job.isCompleted,
              icon: Icons.request_quote_outlined,
              onTap: () => _createQuoteFor(job),
            ),
          ];

    return _ScheduleJobData(
      title: job.customerName,
      timeLabel: _jobTimeTextForSchedule(job),
      statusLabel: job.statusLabel,
      status: status,
      accent: _scheduleAccentForStatus(status),
      body: _scheduleBodyText(job),
      actions: actions,
      job: job,
    );
  }

  _ScheduleDayState _scheduleStateForJobs(
    List<DriverCustomerReplyMockData> jobs,
  ) {
    if (jobs.isEmpty) {
      return _ScheduleDayState.empty;
    }
    final hasCompleted = jobs.any((job) => job.isCompleted);
    final hasConfirmed = jobs.any((job) => job.isConfirmed);
    final hasPending = jobs.any((job) => !job.isCompleted && !job.isConfirmed);
    if (hasCompleted && !hasConfirmed && !hasPending) {
      return _ScheduleDayState.completed;
    }
    if (hasConfirmed && !hasPending && !hasCompleted) {
      return _ScheduleDayState.ready;
    }
    if (hasPending && !hasConfirmed && !hasCompleted) {
      return _ScheduleDayState.pending;
    }
    return _ScheduleDayState.mixed;
  }

  Color _scheduleAccentForState(_ScheduleDayState state) {
    switch (state) {
      case _ScheduleDayState.today:
        return const Color(0xFF4A7DFF);
      case _ScheduleDayState.pending:
        return const Color(0xFFFFC38C);
      case _ScheduleDayState.ready:
        return const Color(0xFF58D0A4);
      case _ScheduleDayState.completed:
        return const Color(0xFF58D0A4);
      case _ScheduleDayState.empty:
        return const Color(0xFF9AA3B2);
      case _ScheduleDayState.mixed:
        return const Color(0xFFB48CFF);
    }
  }

  Color _scheduleAccentForStatus(_ScheduleJobStatus status) {
    switch (status) {
      case _ScheduleJobStatus.pending:
        return const Color(0xFFFFC38C);
      case _ScheduleJobStatus.awaitingReply:
        return const Color(0xFFB48CFF);
      case _ScheduleJobStatus.awaitingPin:
        return const Color(0xFFFFC38C);
      case _ScheduleJobStatus.ready:
        return const Color(0xFF58D0A4);
      case _ScheduleJobStatus.completed:
        return const Color(0xFF58D0A4);
    }
  }

  _ScheduleJobStatus _scheduleJobStatusForJob(DriverCustomerReplyMockData job) {
    if (job.isCompleted) {
      return _ScheduleJobStatus.completed;
    }
    if (job.isConfirmed) {
      return _ScheduleJobStatus.ready;
    }
    if (job.isQuoteSent) {
      return _ScheduleJobStatus.awaitingReply;
    }
    if (job.isReplyReceived) {
      return job.exactPinShared
          ? _ScheduleJobStatus.ready
          : _ScheduleJobStatus.awaitingPin;
    }
    if (job.requestExactPin && !job.exactPinShared) {
      return _ScheduleJobStatus.awaitingPin;
    }
    return _ScheduleJobStatus.pending;
  }

  String _scheduleDayLabel(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.isSameDay(date, today)) {
      return 'Today';
    }
    if (DateUtils.isSameDay(date, today.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }

    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }

  String _formatScheduleDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _jobTimeTextForSchedule(DriverCustomerReplyMockData job) {
    final scheduledAt = job.scheduledAtOrParsed;
    if (scheduledAt == null) {
      return job.jobTimeLabel.trim().isNotEmpty
          ? job.jobTimeLabel
          : 'Time not set';
    }

    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _scheduleBodyText(DriverCustomerReplyMockData job) {
    final pieces = <String>[
      job.address.trim(),
      job.postcode.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    final location = pieces.isEmpty
        ? 'No address added yet.'
        : pieces.join(' • ');
    final pinText = job.exactPinShared
        ? 'Exact pin saved.'
        : 'Exact pin missing.';
    return '$location\n$pinText';
  }

  bool _hasCustomerReply(DriverCustomerReplyMockData job) {
    return job.isReplyReceived ||
        job.replyReceivedAt != null ||
        job.exactPinShared ||
        job.checklistResponses.isNotEmpty ||
        job.customQuestionResponses.isNotEmpty ||
        job.additionalNotes.trim().isNotEmpty;
  }

  late final List<_ScheduleDayData> _days = <_ScheduleDayData>[
    _ScheduleDayData(
      label: 'Today',
      dateLabel: '18 May',
      jobCount: 3,
      accent: const Color(0xFF4A7DFF),
      state: _ScheduleDayState.today,
      jobs: <_ScheduleJobData>[
        const _ScheduleJobData(
          title: 'Local job',
          timeLabel: '08:30',
          statusLabel: 'Ready • Exact pin shared',
          status: _ScheduleJobStatus.ready,
          accent: Color(0xFF58D0A4),
          body: 'Customer replied. Ready to quote and head out.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'View reply',
              icon: Icons.question_answer,
              enabled: true,
            ),
            _ScheduleActionData(
              label: 'Create quote',
              icon: Icons.request_quote_outlined,
              enabled: true,
            ),
            _ScheduleActionData(
              label: 'Navigate',
              icon: Icons.navigation,
              enabled: true,
            ),
          ],
        ),
        const _ScheduleJobData(
          title: 'Pharmacy delivery',
          timeLabel: '11:00',
          statusLabel: 'Awaiting customer reply',
          status: _ScheduleJobStatus.awaitingReply,
          accent: Color(0xFFB48CFF),
          body: 'Customer still confirming drop instructions.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Request', enabled: true),
            _ScheduleActionData(label: 'Resend', enabled: true),
          ],
        ),
        const _ScheduleJobData(
          title: 'Trade supplies drop',
          timeLabel: '14:00',
          statusLabel: 'Completed',
          status: _ScheduleJobStatus.completed,
          accent: Color(0xFF58D0A4),
          body: 'Notes and pin already saved.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Notes', enabled: true),
          ],
        ),
      ],
    ),
    _ScheduleDayData(
      label: 'Tue',
      dateLabel: '19 May',
      jobCount: 0,
      accent: const Color(0xFF9AA3B2),
      state: _ScheduleDayState.empty,
      jobs: const <_ScheduleJobData>[],
    ),
    _ScheduleDayData(
      label: 'Wed',
      dateLabel: '20 May',
      jobCount: 2,
      accent: const Color(0xFFB48CFF),
      state: _ScheduleDayState.pending,
      jobs: <_ScheduleJobData>[
        const _ScheduleJobData(
          title: 'Office move quote',
          timeLabel: '09:15',
          statusLabel: 'Awaiting customer reply',
          status: _ScheduleJobStatus.awaitingReply,
          accent: Color(0xFFB48CFF),
          body: 'Quote sent. Waiting for customer approval.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Request', enabled: true),
            _ScheduleActionData(label: 'Resend', enabled: true),
          ],
        ),
        const _ScheduleJobData(
          title: 'Garden waste pick-up',
          timeLabel: '13:45',
          statusLabel: 'Awaiting exact pin',
          status: _ScheduleJobStatus.awaitingPin,
          accent: Color(0xFFFFC38C),
          body: 'Pin missing, so navigation is still locked.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'Navigate',
              icon: Icons.navigation,
              enabled: false,
            ),
            _ScheduleActionData(label: 'Open Job', enabled: true),
          ],
        ),
      ],
    ),
    _ScheduleDayData(
      label: 'Thu',
      dateLabel: '21 May',
      jobCount: 1,
      accent: const Color(0xFF58D0A4),
      state: _ScheduleDayState.completed,
      jobs: <_ScheduleJobData>[
        const _ScheduleJobData(
          title: 'Trade drop-off',
          timeLabel: '10:00',
          statusLabel: 'Completed',
          status: _ScheduleJobStatus.completed,
          accent: Color(0xFF58D0A4),
          body: 'Finished and ready to archive later.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Notes', enabled: true),
          ],
        ),
      ],
    ),
    _ScheduleDayData(
      label: 'Fri',
      dateLabel: '22 May',
      jobCount: 4,
      accent: const Color(0xFF4A7DFF),
      state: _ScheduleDayState.ready,
      jobs: <_ScheduleJobData>[
        const _ScheduleJobData(
          title: 'Appliance delivery',
          timeLabel: '08:00',
          statusLabel: 'Ready to go',
          status: _ScheduleJobStatus.ready,
          accent: Color(0xFF4A7DFF),
          body: 'Customer location confirmed and route planned.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'Navigate',
              icon: Icons.navigation,
              enabled: true,
            ),
            _ScheduleActionData(label: 'Open Job', enabled: true),
          ],
        ),
        const _ScheduleJobData(
          title: 'Collection quote',
          timeLabel: '11:30',
          statusLabel: 'Awaiting customer reply',
          status: _ScheduleJobStatus.awaitingReply,
          accent: Color(0xFFB48CFF),
          body: 'Quote pending customer confirmation.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Request', enabled: true),
            _ScheduleActionData(label: 'Resend', enabled: true),
          ],
        ),
      ],
    ),
    _ScheduleDayData(
      label: 'Sat',
      dateLabel: '23 May',
      jobCount: 1,
      accent: const Color(0xFFFFC38C),
      state: _ScheduleDayState.pending,
      jobs: <_ScheduleJobData>[
        const _ScheduleJobData(
          title: 'Weekend tip run',
          timeLabel: '12:15',
          statusLabel: 'Awaiting exact pin',
          status: _ScheduleJobStatus.awaitingPin,
          accent: Color(0xFFFFC38C),
          body: 'Pin request sent. Navigation is disabled for now.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Request', enabled: true),
            _ScheduleActionData(
              label: 'Navigate',
              icon: Icons.navigation,
              enabled: false,
            ),
          ],
        ),
      ],
    ),
    _ScheduleDayData(
      label: 'Sun',
      dateLabel: '24 May',
      jobCount: 0,
      accent: const Color(0xFF9AA3B2),
      state: _ScheduleDayState.empty,
      jobs: const <_ScheduleJobData>[],
    ),
    _ScheduleDayData(
      label: 'Mon',
      dateLabel: '25 May',
      jobCount: 2,
      accent: const Color(0xFF58D0A4),
      state: _ScheduleDayState.completed,
      jobs: <_ScheduleJobData>[
        const _ScheduleJobData(
          title: 'Store transfer',
          timeLabel: '07:45',
          statusLabel: 'Completed',
          status: _ScheduleJobStatus.completed,
          accent: Color(0xFF58D0A4),
          body: 'Delivery closed out and notes saved.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Notes', enabled: true),
          ],
        ),
        const _ScheduleJobData(
          title: 'Storage pickup',
          timeLabel: '15:10',
          statusLabel: 'Ready to go',
          status: _ScheduleJobStatus.ready,
          accent: Color(0xFF4A7DFF),
          body: 'Pin confirmed and route ready.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'Navigate',
              icon: Icons.navigation,
              enabled: true,
            ),
            _ScheduleActionData(label: 'Open Job', enabled: true),
          ],
        ),
      ],
    ),
    _ScheduleDayData(
      label: 'Tue',
      dateLabel: '26 May',
      jobCount: 1,
      accent: const Color(0xFFB48CFF),
      state: _ScheduleDayState.pending,
      jobs: <_ScheduleJobData>[
        const _ScheduleJobData(
          title: 'Late quote follow-up',
          timeLabel: '10:20',
          statusLabel: 'Awaiting customer reply',
          status: _ScheduleJobStatus.awaitingReply,
          accent: Color(0xFFB48CFF),
          body: 'Quick follow-up before it becomes a job.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(label: 'View Request', enabled: true),
            _ScheduleActionData(label: 'Resend', enabled: true),
          ],
        ),
      ],
    ),
  ];

  void _handleActionTap(String label) {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    switch (label) {
      case 'View reply':
        unawaited(openDriverCustomerReplyMockPage(context, jobId: job.jobId));
        return;
      case 'Create quote':
        unawaited(openDriverQuoteMockPage(context, job));
        return;
      case 'Navigate':
        _showComingSoon(context, 'Navigation mock');
        return;
      case 'Mark ready':
        _showComingSoon(context, 'Mark ready');
        return;
      default:
        _showComingSoon(context, label);
        return;
    }
  }

  Future<void> _openReplyFor(DriverCustomerReplyMockData job) async {
    await openDriverCustomerReplyMockPage(context, jobId: job.jobId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _createQuoteFor(DriverCustomerReplyMockData job) async {
    await openDriverQuoteMockPage(context, job);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _createInvoiceFor(DriverCustomerReplyMockData job) async {
    await openCreateInvoiceMockPage(context, job);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _viewInvoiceFor(DriverCustomerReplyMockData job) async {
    final savedInvoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );
    if (savedInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved invoice found.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updated = await openVanInvoicePreviewPage(context, savedInvoice);
    if (!mounted || updated == null) {
      return;
    }

    setState(() {});
  }

  Future<void> _openJobFor(DriverCustomerReplyMockData job) async {
    final finished = await openDriverJobDetailMockPage(
      context,
      reply: job,
      completed: job.isCompleted,
    );
    if (mounted) {
      setState(() {});
    }
    if (finished == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job marked completed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _navigateFor(DriverCustomerReplyMockData job) async {
    await openVanJobNavigation(context, job);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 128),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ScheduleBackButton(
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Schedule',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upcoming jobs and customer requests.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _GlassPanel(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ScheduleSectionHeader(
                                  icon: Icons.calendar_month,
                                  title: 'This week',
                                  subtitle:
                                      'Tap a day to update the work list.',
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 160,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _realDays.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final day = _realDays[index];
                                      final selected =
                                          day.date != null &&
                                          DateUtils.isSameDay(
                                            day.date!,
                                            _selectedDate,
                                          );
                                      return _ScheduleDayCard(
                                        day: day,
                                        selected: selected,
                                        onTap: () {
                                          setState(() {
                                            _selectedDate =
                                                day.date ?? _selectedDate;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _GlassPanel(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _SelectedDayJobsPanel(
                                key: ValueKey<String>(_selectedRealDay.label),
                                day: _selectedRealDay,
                                onActionTap: _handleActionTap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () => _openCreateJobRequestSheet(context),
                          icon: const Icon(Icons.add_task),
                          label: const Text('Create Job Request'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7DFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _ScheduleBackButton extends StatelessWidget {
  const _ScheduleBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(18),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ScheduleSectionHeader extends StatelessWidget {
  const _ScheduleSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleDayCard extends StatelessWidget {
  const _ScheduleDayCard({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _ScheduleDayData day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day.state == _ScheduleDayState.today;
    final accent = day.accent;
    final muted = day.state == _ScheduleDayState.empty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 114,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: selected ? 0.14 : 0.08),
                Colors.white.withValues(alpha: selected ? 0.06 : 0.04),
              ],
            ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.36)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? accent.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.18),
                blurRadius: selected ? 28 : 18,
                offset: const Offset(0, 12),
              ),
              if (isToday)
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      day.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: muted ? 0.62 : 1),
                      ),
                    ),
                  ),
                  if (isToday)
                    _ScheduleMiniChip(
                      label: 'Today',
                      accent: accent,
                      highlight: true,
                    ),
                ],
              ),
              Text(
                day.dateLabel,
                style: TextStyle(
                  fontSize: 11.6,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: muted ? 0.52 : 0.74),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.jobCount} Jobs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: muted ? 0.54 : 1),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              _ScheduleMiniChip(
                label: _dayStateLabel(day.state),
                accent: accent,
                highlight: selected || isToday,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDayJobsPanel extends StatelessWidget {
  const _SelectedDayJobsPanel({
    super.key,
    required this.day,
    required this.onActionTap,
  });

  final _ScheduleDayData day;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScheduleSectionHeader(
            icon: Icons.list_alt_rounded,
            title: day.label,
            subtitle: day.jobs.isEmpty
                ? 'No jobs booked for this day.'
                : '${day.jobCount} jobs scheduled for this day.',
          ),
          const SizedBox(height: 14),
          if (day.jobs.isEmpty)
            const _ScheduleEmptyJobsCard()
          else
            Column(
              children: [
                for (var index = 0; index < day.jobs.length; index++) ...[
                  _ScheduleJobCard(
                    job: day.jobs[index],
                    onActionTap: onActionTap,
                  ),
                  if (index < day.jobs.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScheduleEmptyJobsCard extends StatelessWidget {
  const _ScheduleEmptyJobsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white70, size: 28),
          const SizedBox(height: 10),
          Text(
            'No jobs booked for this day.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a different day or add a new request when you are ready.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleJobCard extends StatelessWidget {
  const _ScheduleJobCard({required this.job, required this.onActionTap});

  final _ScheduleJobData job;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: job.accent.withValues(alpha: 0.18),
                  border: Border.all(color: job.accent.withValues(alpha: 0.28)),
                ),
                child: Icon(
                  _statusIcon(job.status),
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        _ScheduleMiniChip(
                          label: _jobStatusLabel(job.status),
                          accent: job.accent,
                          highlight: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          job.timeLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          job.statusLabel,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.84),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            job.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 420;

              if (stackButtons) {
                return Column(
                  children: [
                    for (
                      var index = 0;
                      index < job.actions.length;
                      index++
                    ) ...[
                      _ScheduleActionButton(
                        action: job.actions[index],
                        accent: job.accent,
                        onTap:
                            job.actions[index].onTap ??
                            () => onActionTap(job.actions[index].label),
                      ),
                      if (index < job.actions.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              if (job.actions.length == 3) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ScheduleActionButton(
                            action: job.actions[0],
                            accent: job.accent,
                            onTap:
                                job.actions[0].onTap ??
                                () => onActionTap(job.actions[0].label),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ScheduleActionButton(
                            action: job.actions[1],
                            accent: job.accent,
                            onTap:
                                job.actions[1].onTap ??
                                () => onActionTap(job.actions[1].label),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ScheduleActionButton(
                      action: job.actions[2],
                      accent: job.accent,
                      onTap:
                          job.actions[2].onTap ??
                          () => onActionTap(job.actions[2].label),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < job.actions.length; index++) ...[
                    Expanded(
                      child: _ScheduleActionButton(
                        action: job.actions[index],
                        accent: job.accent,
                        onTap:
                            job.actions[index].onTap ??
                            () => onActionTap(job.actions[index].label),
                      ),
                    ),
                    if (index < job.actions.length - 1)
                      const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScheduleActionButton extends StatelessWidget {
  const _ScheduleActionButton({
    required this.action,
    required this.accent,
    required this.onTap,
  });

  final _ScheduleActionData action;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = action.enabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (action.icon != null) ...[
                Icon(
                  action.icon,
                  size: 16,
                  color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.42),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.42),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleMiniChip extends StatelessWidget {
  const _ScheduleMiniChip({
    required this.label,
    required this.accent,
    required this.highlight,
    this.compact = false,
  });

  final String label;
  final Color accent;
  final bool highlight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: highlight ? 0.18 : 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9.8 : 10.8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          color: Colors.white.withValues(alpha: 0.96),
        ),
      ),
    );
  }
}

class _ScheduleDayData {
  const _ScheduleDayData({
    required this.label,
    required this.dateLabel,
    required this.jobCount,
    required this.accent,
    required this.state,
    required this.jobs,
    this.date,
  });

  final String label;
  final String dateLabel;
  final int jobCount;
  final Color accent;
  final _ScheduleDayState state;
  final List<_ScheduleJobData> jobs;
  final DateTime? date;
}

class _ScheduleJobData {
  const _ScheduleJobData({
    required this.title,
    required this.timeLabel,
    required this.statusLabel,
    required this.status,
    required this.accent,
    required this.body,
    required this.actions,
    this.job,
  });

  final String title;
  final String timeLabel;
  final String statusLabel;
  final _ScheduleJobStatus status;
  final Color accent;
  final String body;
  final List<_ScheduleActionData> actions;
  final DriverCustomerReplyMockData? job;
}

class _ScheduleActionData {
  const _ScheduleActionData({
    required this.label,
    required this.enabled,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final IconData? icon;
  final VoidCallback? onTap;
}

enum _ScheduleDayState { today, pending, ready, completed, empty, mixed }

enum _ScheduleJobStatus {
  pending,
  awaitingReply,
  awaitingPin,
  ready,
  completed,
}

String _dayStateLabel(_ScheduleDayState state) {
  switch (state) {
    case _ScheduleDayState.today:
      return 'Today';
    case _ScheduleDayState.pending:
      return 'Pending';
    case _ScheduleDayState.ready:
      return 'Ready';
    case _ScheduleDayState.completed:
      return 'Done';
    case _ScheduleDayState.empty:
      return 'No jobs';
    case _ScheduleDayState.mixed:
      return 'Mixed';
  }
}

String _jobStatusLabel(_ScheduleJobStatus status) {
  switch (status) {
    case _ScheduleJobStatus.pending:
      return 'Pending';
    case _ScheduleJobStatus.awaitingReply:
      return 'Awaiting reply';
    case _ScheduleJobStatus.awaitingPin:
      return 'Awaiting pin';
    case _ScheduleJobStatus.ready:
      return 'Ready';
    case _ScheduleJobStatus.completed:
      return 'Completed';
  }
}

IconData _statusIcon(_ScheduleJobStatus status) {
  switch (status) {
    case _ScheduleJobStatus.pending:
      return Icons.pending_actions;
    case _ScheduleJobStatus.awaitingReply:
      return Icons.mark_email_unread_rounded;
    case _ScheduleJobStatus.awaitingPin:
      return Icons.location_searching_rounded;
    case _ScheduleJobStatus.ready:
      return Icons.playlist_add_check_rounded;
    case _ScheduleJobStatus.completed:
      return Icons.check_circle_rounded;
  }
}

Future<void> _openCreateJobRequestSheet(BuildContext context) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const CreateJobRequestPage()));
}

void _showComingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label tapped.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
