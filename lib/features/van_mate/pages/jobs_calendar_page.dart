// ignore_for_file: unused_element

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_job_navigation.dart';
import 'driver_customer_reply_mock_page.dart';
import 'create_invoice_page.dart';
import 'create_job_request_flow.dart';
import 'job_detail_page.dart';
import 'jobs_calendar_schedule_page.dart';
import 'van_invoice_history_page.dart';
import 'van_job_reports_page.dart';
import 'van_invoice_preview_page.dart';

class JobsCalendarPage extends StatefulWidget {
  const JobsCalendarPage({super.key});

  @override
  State<JobsCalendarPage> createState() => _JobsCalendarPageState();
}

class _JobsCalendarPageState extends State<JobsCalendarPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshCloudRequests());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCloudRequests());
    }
  }

  Future<void> _refreshCloudRequests() async {
    try {
      await DriverReplyMockState.instance.loadJobRequestsFromCloud();
      if (mounted) {
        setState(() {});
        final notice =
            DriverReplyMockState.instance.takeRecentRequestRefreshNotice();
        if (notice != null && notice.isNotEmpty) {
          _showSnack(notice);
        }
      }
    } catch (error) {
      debugPrint('Job request refresh failed: $error');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _clearLocalTestData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF142031),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Clear all local Van Mate test data?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This will remove local jobs, customer replies, quotes, invoices, reports and local workflow drafts from this device only.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear test data'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await DriverReplyMockState.instance.clearAllLocalJobData();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnack('Local test data cleared.');
  }

  Future<void> _openReply() async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    await openDriverCustomerReplyMockPage(context, jobId: job.jobId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _createQuote() async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    await openDriverQuoteMockPage(context, job);
    if (mounted) {
      setState(() {});
    }
  }

  void _markConfirmed() {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    if (job.isConfirmed) {
      return;
    }

    DriverReplyMockState.instance.setJobConfirmed(true, jobId: job.jobId);
    DriverReplyMockState.instance.setJobReady(true, jobId: job.jobId);
    setState(() {});
    _showSnack('Customer marked as confirmed.');
  }

  void _markReady() {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    DriverReplyMockState.instance.setJobReady(true, jobId: job.jobId);
    setState(() {});
    _showSnack('Job marked ready');
  }

  void _navigate() {
    _showSnack('Navigation mock opened');
  }

  Future<void> _openJob({required bool completed}) async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    final finished = await openDriverJobDetailMockPage(
      context,
      reply: job,
      completed: completed,
    );

    if (mounted) {
      setState(() {});
    }

    if (finished == true) {
      _showSnack('Job marked completed.');
    }
  }

  Future<void> _createInvoice() async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    await openCreateInvoiceMockPage(context, job);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _viewInvoice() async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    final savedInvoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );
    if (savedInvoice == null) {
      _showSnack('No saved invoice found.');
      return;
    }

    final updated = await openVanInvoicePreviewPage(context, savedInvoice);
    if (!mounted || updated == null) {
      return;
    }

    setState(() {});
  }

  DriverCustomerReplyMockData get _primaryJob {
    final state = DriverReplyMockState.instance;
    final todayJobs = state.todayJobs;
    if (todayJobs.isNotEmpty) {
      return todayJobs.first;
    }
    final upcomingJobs = state.upcomingJobs;
    if (upcomingJobs.isNotEmpty) {
      return upcomingJobs.first;
    }
    final allJobs = state.jobs;
    if (allJobs.isNotEmpty) {
      return allJobs.first;
    }
    return driverCustomerReplySample;
  }

  String _jobTimeText(DriverCustomerReplyMockData job) {
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

  String _jobDateText(DriverCustomerReplyMockData job) {
    final scheduledAt = job.scheduledAtOrParsed;
    if (scheduledAt == null) {
      return 'Date not set';
    }

    final now = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(scheduledAt);
    if (DateUtils.isSameDay(date, now)) {
      return 'Today';
    }

    if (DateUtils.isSameDay(date, now.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }

    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  String _jobBodyText(DriverCustomerReplyMockData job) {
    final address = job.address.trim();
    final postcode = job.postcode.trim();
    final pieces = <String>[];
    if (address.isNotEmpty) {
      pieces.add(address);
    }
    if (postcode.isNotEmpty) {
      pieces.add(postcode);
    }

    final location = pieces.isEmpty
        ? 'No address added yet.'
        : pieces.join(' • ');
    final timeText = _jobTimeText(job);
    final dateText = _jobDateText(job);
    return '$dateText • $timeText\n$location';
  }

  List<_JobsStatusChip> _jobChips(DriverCustomerReplyMockData job) {
    final exactPinLabel = job.isRequestExactPinReceived
        ? 'Exact pin received'
        : job.exactPinShared
        ? 'Exact pin saved'
        : 'Exact pin missing';
    final exactPinColor = job.exactPinShared
        ? const Color(0xFF58D0A4)
        : const Color(0xFFFFC38C);
    final requestColor = job.isRequestCancelled || job.isRequestExpired
        ? const Color(0xFFFFC38C)
        : job.isRequestExactPinReceived || job.isRequestSubmitted
        ? const Color(0xFF58D0A4)
        : const Color(0xFF4A7DFF);
    final requestIcon = job.isRequestCancelled
        ? Icons.cancel
        : job.isRequestExpired
        ? Icons.schedule
        : job.isRequestExactPinReceived
        ? Icons.location_on
        : job.isRequestSubmitted
        ? Icons.check_circle
        : Icons.pending_actions;

    final chips = <_JobsStatusChip>[
      _JobsStatusChip(
        label: job.statusLabel,
        color: const Color(0xFF58D0A4),
        icon: job.isCompleted
            ? Icons.check_circle
            : job.isConfirmed
            ? Icons.verified
            : job.isQuoteSent
            ? Icons.request_quote_outlined
            : Icons.pending_actions,
        filled: true,
      ),
      _JobsStatusChip(
        label: exactPinLabel,
        color: exactPinColor,
        icon: Icons.location_on,
      ),
      if (job.scheduledAtOrParsed != null)
        _JobsStatusChip(
          label: _jobDateText(job),
          color: const Color(0xFFB48CFF),
          icon: Icons.schedule,
        ),
    ];

    if (job.hasRequest && job.requestStatusLabel != 'Not sent') {
      chips.insert(
        1,
        _JobsStatusChip(
          label: job.requestStatusLabel,
          color: requestColor,
          icon: requestIcon,
          filled: job.isRequestSubmitted || job.isRequestExactPinReceived,
        ),
      );
    }

    return chips;
  }

  List<_JobsInlineActionButton> _jobActions(
    DriverCustomerReplyMockData job, {
    bool completed = false,
  }) {
    final isCompletedJob = completed || job.isCompletedJob;
    final actions = <_JobsInlineActionButton>[
      _JobsInlineActionButton(
        label: isCompletedJob ? 'View job' : 'Open Job',
        onTap: () => _openJobFor(job, completed: isCompletedJob),
      ),
    ];

    if (isCompletedJob) {
      if (_hasCustomerReply(job)) {
        actions.add(
          _JobsInlineActionButton(
            label: 'View reply',
            icon: Icons.question_answer,
            onTap: () => _openReplyFor(job),
          ),
        );
      }

      if (_hasQuote(job)) {
        actions.add(
          _JobsInlineActionButton(
            label: 'View quote',
            icon: Icons.request_quote_outlined,
            onTap: () => _createQuoteFor(job),
          ),
        );
      }

      final savedInvoice = DriverReplyMockState.instance.invoiceForJob(
        job.invoiceHistoryKey,
      );
      actions.add(
        _JobsInlineActionButton(
          label: savedInvoice == null ? 'Create invoice' : 'View invoice',
          icon: Icons.receipt_long_outlined,
          onTap: savedInvoice == null
              ? () => _createInvoiceFor(job)
              : () => _viewInvoiceFor(job),
        ),
      );
    } else {
      actions.add(
        _JobsInlineActionButton(
          label: 'Navigate',
          icon: Icons.navigation,
          onTap: () => _navigateFor(job),
        ),
      );

      if (!job.isDraft) {
        actions.add(
          _JobsInlineActionButton(
            label: 'View reply',
            icon: Icons.question_answer,
            onTap: () => _openReplyFor(job),
          ),
        );
      }

      actions.add(
        _JobsInlineActionButton(
          label: job.isQuoteSent || job.isConfirmed
              ? 'View quote'
              : 'Create quote',
          icon: Icons.request_quote_outlined,
          onTap: () => _createQuoteFor(job),
        ),
      );
    }

    return actions;
  }

  bool _hasCustomerReply(DriverCustomerReplyMockData job) {
    return job.isReplyReceived ||
        job.replyReceivedAt != null ||
        job.exactPinShared ||
        job.checklistResponses.isNotEmpty ||
        job.customQuestionResponses.isNotEmpty ||
        job.additionalNotes.trim().isNotEmpty;
  }

  bool _hasQuote(DriverCustomerReplyMockData job) {
    return job.quoteAmount != null || job.isQuoteSent || job.isConfirmed;
  }

  Widget _buildJobListSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<DriverCustomerReplyMockData> jobs,
    required String emptyTitle,
    required String emptyMessage,
    bool completed = false,
  }) {
    final theme = Theme.of(context);

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JobsSectionHeader(icon: icon, title: title),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emptyTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  emptyMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    height: 1.45,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                for (var index = 0; index < jobs.length; index++) ...[
                  _JobsMockJobCard(
                    accent: jobs[index].isCompleted
                        ? const Color(0xFF58D0A4)
                        : jobs[index].isConfirmed
                        ? const Color(0xFF4A7DFF)
                        : jobs[index].isQuoteSent
                        ? const Color(0xFFB48CFF)
                        : const Color(0xFFFFC38C),
                    icon: jobs[index].isCompleted
                        ? Icons.check_circle
                        : jobs[index].isConfirmed
                        ? Icons.verified
                        : jobs[index].isQuoteSent
                        ? Icons.request_quote_outlined
                        : Icons.calendar_month,
                    eyebrow: _jobDateText(jobs[index]),
                    title: jobs[index].customerName,
                    subtitle: jobs[index].jobTitle,
                    body: _jobBodyText(jobs[index]),
                    chips: _jobChips(jobs[index]),
                    actions: _jobActions(jobs[index], completed: completed),
                  ),
                  if (index < jobs.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
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

  Future<void> _openJobFor(
    DriverCustomerReplyMockData job, {
    required bool completed,
  }) async {
    final finished = await openDriverJobDetailMockPage(
      context,
      reply: job,
      completed: completed,
    );
    if (mounted) {
      setState(() {});
    }
    if (finished == true) {
      _showSnack('Job marked completed.');
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
      _showSnack('No saved invoice found.');
      return;
    }

    final updated = await openVanInvoicePreviewPage(context, savedInvoice);
    if (!mounted || updated == null) {
      return;
    }

    setState(() {});
  }

  void _markConfirmedFor(DriverCustomerReplyMockData job) {
    if (job.isConfirmed) {
      return;
    }

    DriverReplyMockState.instance.setJobConfirmed(true, jobId: job.jobId);
    DriverReplyMockState.instance.setJobReady(true, jobId: job.jobId);
    setState(() {});
    _showSnack('Customer marked as confirmed.');
  }

  void _markReadyFor(DriverCustomerReplyMockData job) {
    DriverReplyMockState.instance.setJobReady(true, jobId: job.jobId);
    setState(() {});
    _showSnack('Job marked ready');
  }

  Future<void> _navigateFor(DriverCustomerReplyMockData job) async {
    await openVanJobNavigation(context, job);
  }

  Widget _buildTodayJobsSection(BuildContext context) {
    final jobs = DriverReplyMockState.instance.todayJobs;
    final theme = Theme.of(context);

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _JobsSectionHeader(icon: Icons.today, title: 'Today'),
          const SizedBox(height: 12),
          if (jobs.isEmpty) ...[
            Text(
              'No jobs booked for today.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When jobs exist later, this will show the day\'s work.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
                height: 1.45,
              ),
            ),
          ] else ...[
            for (var index = 0; index < jobs.length; index++) ...[
              _JobsMockJobCard(
                accent: const Color(0xFF4A7DFF),
                icon: Icons.today,
                eyebrow: _jobDateText(jobs[index]),
                title: jobs[index].customerName,
                subtitle: jobs[index].jobTitle,
                body: _jobBodyText(jobs[index]),
                chips: _jobChips(jobs[index]),
                actions: _jobActions(jobs[index]),
              ),
              if (index < jobs.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection(BuildContext context) {
    final jobs = DriverReplyMockState.instance.pendingJobs;
    return _buildJobListSection(
      context,
      title: 'Pending customer requests',
      icon: Icons.pending_actions,
      jobs: jobs,
      emptyTitle: 'No pending customer requests.',
      emptyMessage:
          'Drafts, requests and replies will appear here until the job is confirmed or completed.',
    );
  }

  Widget _buildUpcomingJobsSection(BuildContext context) {
    final jobs = DriverReplyMockState.instance.upcomingJobs;
    return _buildJobListSection(
      context,
      title: 'Upcoming jobs',
      icon: Icons.calendar_month,
      jobs: jobs,
      emptyTitle: 'No upcoming jobs.',
      emptyMessage:
          'Future bookings will appear here once a job has a future scheduled date.',
    );
  }

  Widget _buildCompletedJobsSection(BuildContext context) {
    final jobs = DriverReplyMockState.instance.completedJobs;
    return _buildJobListSection(
      context,
      title: 'Completed jobs',
      icon: Icons.history,
      jobs: jobs,
      emptyTitle: 'No completed jobs yet.',
      emptyMessage:
          'Finished jobs will show here with their saved notes, quote, exact pin and invoice history.',
      completed: true,
    );
  }

  Widget _buildTestingToolsSection(BuildContext context) {
    final theme = Theme.of(context);

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _JobsSectionHeader(
            icon: Icons.bug_report_outlined,
            title: 'Testing / Developer tools',
          ),
          const SizedBox(height: 12),
          Text(
            'Local testing only. This clears jobs, quotes, invoices, reports and workflow drafts from this device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _clearLocalTestData,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear local test data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFB3B3),
                side: BorderSide(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.42),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(BuildContext context) {
    final theme = Theme.of(context);
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;

    if (job.isCompleted || job.isConfirmed) {
      return _JobsGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _JobsSectionHeader(
              icon: Icons.pending_actions,
              title: 'Pending customer requests',
            ),
            const SizedBox(height: 12),
            Text(
              'No pending customer requests.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _JobsSectionHeader(
            icon: Icons.pending_actions,
            title: 'Pending customer requests',
          ),
          const SizedBox(height: 12),
          _JobsMockJobCard(
            accent: job.isRequestCancelled || job.isRequestExpired
                ? const Color(0xFFFFC38C)
                : job.isRequestSubmitted || job.isRequestExactPinReceived
                ? const Color(0xFF58D0A4)
                : const Color(0xFF4A7DFF),
            icon: job.isRequestCancelled
                ? Icons.cancel
                : job.isRequestExpired
                ? Icons.schedule
                : job.isRequestSubmitted || job.isRequestExactPinReceived
                ? Icons.check_circle
                : Icons.mark_email_read_outlined,
            eyebrow: job.requestBadgeLabel,
            title: job.customerName,
            subtitle: job.jobTitle,
            body: job.isRequestExactPinReceived
                ? 'Customer reply received and exact pin is saved.'
                : job.isRequestSubmitted
                ? 'Customer reply received.'
                : job.isRequestPending
                ? 'Waiting for the customer to reply.'
                : job.isRequestCancelled
                ? 'Request cancelled.'
                : job.isRequestExpired
                ? 'Request expired.'
                : 'Request not sent yet.',
            chips: [
              if (job.hasRequest && job.requestBadgeLabel != 'Not sent')
                _JobsStatusChip(
                  label: job.requestBadgeLabel,
                  color: job.isRequestCancelled || job.isRequestExpired
                      ? const Color(0xFFFFC38C)
                      : job.isRequestExactPinReceived || job.isRequestSubmitted
                      ? const Color(0xFF58D0A4)
                      : const Color(0xFF4A7DFF),
                  icon: job.isRequestCancelled
                      ? Icons.cancel
                      : job.isRequestExpired
                      ? Icons.schedule
                      : job.isRequestExactPinReceived
                      ? Icons.location_on
                      : job.isRequestSubmitted
                      ? Icons.check_circle
                      : Icons.pending_actions,
                  filled: job.isRequestSubmitted ||
                      job.isRequestExactPinReceived,
                ),
              _JobsStatusChip(
                label: job.isRequestExactPinReceived
                    ? 'Exact pin received'
                    : job.exactPinShared
                    ? 'Exact pin saved'
                    : 'Exact pin missing',
                color: job.exactPinShared
                    ? const Color(0xFF58D0A4)
                    : const Color(0xFFFFC38C),
                icon: Icons.location_on,
              ),
              _JobsStatusChip(
                label: job.isQuoteSent ? 'Awaiting response' : 'Ready to quote',
                color: const Color(0xFFB48CFF),
                icon: job.isQuoteSent
                    ? Icons.hourglass_bottom
                    : Icons.request_quote_outlined,
                filled: job.isQuoteSent,
              ),
            ],
            actions: _jobActions(job),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingJobsCard(BuildContext context) {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _JobsSectionHeader(
            icon: Icons.calendar_month,
            title: 'Upcoming jobs',
          ),
          const SizedBox(height: 12),
          if (job.isConfirmed && !job.isCompleted) ...[
            _JobsMockJobCard(
              accent: const Color(0xFF58D0A4),
              icon: Icons.check_circle,
              eyebrow: 'Confirmed • Ready to go',
              title: job.customerName,
              subtitle: job.jobTitle,
              body: 'Customer confirmed the quote and exact pin is saved.',
              chips: [
                const _JobsStatusChip(
                  label: 'Confirmed',
                  color: Color(0xFF58D0A4),
                  icon: Icons.check_circle,
                  filled: true,
                ),
                _JobsStatusChip(
                  label: job.exactPinShared
                      ? 'Exact pin saved'
                      : 'Exact pin missing',
                  color: job.exactPinShared
                      ? const Color(0xFF58D0A4)
                      : const Color(0xFFFFC38C),
                  icon: Icons.location_on,
                ),
                const _JobsStatusChip(
                  label: 'Ready to go',
                  color: Color(0xFF58D0A4),
                  icon: Icons.rocket_launch_outlined,
                ),
              ],
              actions: [
                _JobsInlineActionButton(
                  label: 'Open Job',
                  onTap: () => _openJob(completed: false),
                ),
                _JobsInlineActionButton(
                  label: 'View quote',
                  icon: Icons.request_quote_outlined,
                  onTap: _createQuote,
                ),
                _JobsInlineActionButton(
                  label: 'Navigate',
                  icon: Icons.navigation,
                  onTap: _navigate,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _JobsMockJobCard(
            accent: const Color(0xFF58D0A4),
            icon: Icons.calendar_month,
            eyebrow: job.statusLabel,
            title: job.customerName,
            subtitle: job.jobTitle,
            body: 'Customer reply received and exact pin saved.',
            actions: [
              _JobsInlineActionButton(
                label: 'Open Job',
                onTap: () => _openJob(completed: false),
              ),
              _JobsInlineActionButton(
                label: 'Navigate',
                icon: Icons.navigation,
                onTap: _navigate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedJobsCard(BuildContext context) {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    if (!job.isCompleted) {
      return _JobsGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _JobsSectionHeader(
              icon: Icons.history,
              title: 'Completed jobs',
            ),
            const SizedBox(height: 12),
            Text(
              'Finished jobs, notes, pins and invoices will be saved here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final savedInvoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );
    final hasSavedInvoice = savedInvoice != null;
    final isPaid = savedInvoice?.isPaid == true;

    final invoiceChip = hasSavedInvoice
        ? _JobsStatusChip(
            label: isPaid ? 'Invoice paid' : 'Invoice unpaid',
            color: isPaid ? const Color(0xFF58D0A4) : const Color(0xFFFFC56F),
            icon: isPaid ? Icons.check_circle : Icons.hourglass_bottom,
            filled: true,
          )
        : null;

    final bodyText = hasSavedInvoice
        ? (isPaid
              ? 'Invoice paid and sent. Notes, quote and exact pin are saved.'
              : 'Invoice saved and ready to send. Notes, quote and exact pin are saved.')
        : 'Job completed. Notes, quote and exact pin saved.';

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _JobsSectionHeader(
            icon: Icons.history,
            title: 'Completed jobs',
          ),
          const SizedBox(height: 12),
          _JobsMockJobCard(
            accent: const Color(0xFF58D0A4),
            icon: Icons.check_circle,
            eyebrow: 'Completed',
            title: job.customerName,
            subtitle: job.jobTitle,
            body: bodyText,
            chips: [
              const _JobsStatusChip(
                label: 'Completed',
                color: Color(0xFF58D0A4),
                icon: Icons.check_circle,
                filled: true,
              ),
              _JobsStatusChip(
                label: job.isQuoteSent ? 'Quote sent' : 'Quote saved',
                color: const Color(0xFF58D0A4),
                icon: Icons.request_quote_outlined,
              ),
              _JobsStatusChip(
                label: job.exactPinShared
                    ? 'Exact pin saved'
                    : 'Exact pin missing',
                color: job.exactPinShared
                    ? const Color(0xFF58D0A4)
                    : const Color(0xFFFFC38C),
                icon: Icons.location_on,
              ),
              if (invoiceChip != null) ...[invoiceChip],
            ],
            actions: _jobActions(job, completed: true),
          ),
        ],
      ),
    );
  }

  Future<void> _openPastInvoices() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VanInvoiceHistoryPage()),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openReports() async {
    await openVanJobReportsPage(context);
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

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
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 260 + bottomPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _JobsBackButton(
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Jobs',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Customer requests, job notes and calendar.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _JobsGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _JobsSectionHeader(
                                  icon: Icons.playlist_add_check,
                                  title: 'Quick actions',
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final actions = <Widget>[
                                      _JobsGlassActionButton(
                                        icon: Icons.add_task,
                                        label: 'New job',
                                        onTap: () async {
                                          await _openCreateJobRequestSheet(
                                            context,
                                          );
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        },
                                      ),
                                      _JobsGlassActionButton(
                                        icon: Icons.calendar_month,
                                        label: 'Calendar',
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const JobsCalendarSchedulePage(),
                                          ),
                                        ),
                                      ),
                                      _JobsGlassActionButton(
                                        icon: Icons.history,
                                        label: 'Invoices',
                                        onTap: _openPastInvoices,
                                      ),
                                      _JobsGlassActionButton(
                                        icon: Icons.description_outlined,
                                        label: 'Reports',
                                        onTap: _openReports,
                                      ),
                                    ];

                                    return Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: actions
                                          .map(
                                            (action) => SizedBox(
                                              width:
                                                  (constraints.maxWidth - 10) /
                                                  2,
                                              child: action,
                                            ),
                                          )
                                          .toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _JobsGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _JobsSectionHeader(
                                  icon: Icons.today,
                                  title: 'Today',
                                ),
                                const SizedBox(height: 12),
                                if (DriverReplyMockState
                                    .instance
                                    .todayJobs
                                    .isEmpty) ...[
                                  Text(
                                    'No jobs booked for today.',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'When jobs exist later, this will show the day\'s work.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.74,
                                      ),
                                      height: 1.45,
                                    ),
                                  ),
                                ] else ...[
                                  ...List<Widget>.generate(
                                    DriverReplyMockState
                                        .instance
                                        .todayJobs
                                        .length,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            index ==
                                                DriverReplyMockState
                                                        .instance
                                                        .todayJobs
                                                        .length -
                                                    1
                                            ? 0
                                            : 12,
                                      ),
                                      child: _JobsMockJobCard(
                                        accent: const Color(0xFF4A7DFF),
                                        icon: Icons.today,
                                        eyebrow: 'Today',
                                        title: DriverReplyMockState
                                            .instance
                                            .todayJobs[index]
                                            .customerName,
                                        subtitle: DriverReplyMockState
                                            .instance
                                            .todayJobs[index]
                                            .jobTitle,
                                        body: _jobBodyText(
                                          DriverReplyMockState
                                              .instance
                                              .todayJobs[index],
                                        ),
                                        chips: _jobChips(
                                          DriverReplyMockState
                                              .instance
                                              .todayJobs[index],
                                        ),
                                        actions: _jobActions(
                                          DriverReplyMockState
                                              .instance
                                              .todayJobs[index],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPendingRequestsSection(context),
                          const SizedBox(height: 12),
                          _buildUpcomingJobsSection(context),
                          const SizedBox(height: 12),
                          _buildCompletedJobsSection(context),
                          if (kDebugMode) ...[
                            const SizedBox(height: 12),
                            _buildTestingToolsSection(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await _openCreateJobRequestSheet(context);
                            if (mounted) {
                              setState(() {});
                            }
                          },
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

class _JobsBackButton extends StatelessWidget {
  const _JobsBackButton({required this.onTap});

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

class _JobsGlassCard extends StatelessWidget {
  const _JobsGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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

class _JobsSectionHeader extends StatelessWidget {
  const _JobsSectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

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
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _JobsGlassActionButton extends StatelessWidget {
  const _JobsGlassActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.05),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.14 : 0.09),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.48),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: enabled ? 1 : 0.50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobsStatusChip extends StatelessWidget {
  const _JobsStatusChip({
    required this.label,
    required this.color,
    required this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled
            ? color.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsInlineActionButton extends StatelessWidget {
  const _JobsInlineActionButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 136),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? 0.14 : 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: Colors.white.withValues(
                      alpha: enabled ? 0.92 : 0.42,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: enabled ? 1 : 0.42),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobsMockJobCard extends StatelessWidget {
  const _JobsMockJobCard({
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.body,
    this.chips = const <Widget>[],
    required this.actions,
  });

  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String body;
  final List<Widget> chips;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: accent.withValues(alpha: 0.18),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.15,
                        color: accent.withValues(alpha: 0.96),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

Future<void> _openCreateJobRequestSheet(BuildContext context) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const CreateJobRequestPage()));
}
