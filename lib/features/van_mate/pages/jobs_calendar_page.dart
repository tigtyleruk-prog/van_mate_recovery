// ignore_for_file: unused_element

import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_calendar_job_presentation.dart';
import '../helpers/van_completed_job_status_pills.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_customer_journey_theme.dart';
import '../helpers/van_job_completion_actions.dart';
import '../helpers/van_job_navigation.dart';
import '../helpers/van_job_request_state.dart';
import '../helpers/van_status_tone.dart';
import '../models/van_job_request_record.dart';
import '../models/van_customer_journey.dart';
import '../services/van_job_deletion_service.dart';
import 'driver_customer_reply_mock_page.dart';
import 'create_invoice_page.dart';
import 'create_job_request_flow.dart';
import 'job_detail_page.dart';
import 'jobs_calendar_schedule_page.dart';
import 'van_business_profile_page.dart';
import 'van_completed_jobs_page.dart';
import 'van_invoice_history_page.dart';
import 'van_invoice_preview_page.dart';
import 'van_quick_invoice_page.dart';
import '../widgets/van_back_business_hub_buttons.dart';

class JobsCalendarPage extends StatefulWidget {
  const JobsCalendarPage({
    super.key,
    this.jobDeletionService,
    this.refreshOnInit = true,
  });

  final VanJobDeletionService? jobDeletionService;
  final bool refreshOnInit;

  @override
  State<JobsCalendarPage> createState() => _JobsCalendarPageState();
}

const bool kVanMateDeveloperToolsEnabled = true;

bool showVanMateDeveloperTools({bool isDebugMode = kDebugMode}) {
  return isDebugMode && kVanMateDeveloperToolsEnabled;
}

class _JobsCalendarPageState extends State<JobsCalendarPage>
    with WidgetsBindingObserver {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _isRefreshingPendingRequests = false;
  bool _isClearingSavedJobs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    if (widget.refreshOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshCloudRequests(userInitiated: false));
      });
    }
  }

  @override
  void dispose() {
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCloudRequests(userInitiated: false));
    }
  }

  void _handleDriverStateChanged() {
    if (!mounted) {
      return;
    }

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    _debugLogJobsPageSnapshot();
    setState(() {});
    final notice = DriverReplyMockState.instance
        .takeRecentRequestRefreshNotice();
    if (notice != null && notice.isNotEmpty && isCurrentRoute) {
      _showSnack(notice);
    }
  }

  Future<VanPendingRefreshResult> _refreshCloudRequests({
    required bool userInitiated,
  }) async {
    final state = DriverReplyMockState.instance;
    final uid = state.currentUidForDebug();
    debugPrint(
      '[PendingRefresh] started userInitiated=$userInitiated uid=$uid',
    );
    final serverResult = await state.refreshPendingRequestsFromCloud(
      source: Source.server,
    );
    var finalResult = serverResult;
    var serverStatus = serverResult.baseMergeSuccess ? 'success' : 'fail';
    var serverError = serverResult.baseError;
    var fallbackStatus = 'not_run';
    var fallbackError = '(none)';

    if (!serverResult.baseMergeSuccess) {
      debugPrint('[PendingRefreshButton] serverResult=fail error=$serverError');
      final fallbackResult = await state.refreshPendingRequestsFromCloud(
        source: Source.serverAndCache,
      );
      finalResult = fallbackResult;
      fallbackStatus = fallbackResult.baseMergeSuccess ? 'success' : 'fail';
      fallbackError = fallbackResult.baseError?.toString() ?? '(none)';
      if (!fallbackResult.baseMergeSuccess) {
        debugPrint(
          '[PendingRefreshButton] fallbackResult=fail error=$fallbackError',
        );
        if (mounted && userInitiated) {
          _showSnack('Could not refresh requests. Please try again.');
        }
      } else if (mounted && userInitiated) {
        final snack = fallbackResult.visibleCardUpdateFailures > 0
            ? 'Some replies could not be updated. Try again.'
            : 'Requests refreshed.';
        _showSnack(snack);
      }
    } else {
      serverError = '(none)';
      debugPrint('[PendingRefreshButton] serverResult=success error=(none)');
      fallbackStatus = 'success';
      fallbackError = '(none)';
      if (mounted && userInitiated) {
        final snack = serverResult.visibleCardUpdateFailures > 0
            ? 'Some replies could not be updated. Try again.'
            : 'Requests refreshed.';
        _showSnack(snack);
      }
    }

    if (mounted) {
      _debugLogJobsPageSnapshot();
      setState(() {});
    }

    debugPrint(
      '[PendingRefreshButton] serverResult=$serverStatus error=${serverError ?? '(none)'}',
    );
    debugPrint(
      '[PendingRefreshButton] fallbackResult=$fallbackStatus error=$fallbackError',
    );
    debugPrint(
      '[PendingRefreshButton] pendingCount=${finalResult.visiblePending}',
    );
    final snackbar = !finalResult.baseMergeSuccess
        ? 'full_error'
        : finalResult.visibleCardUpdateFailures > 0
        ? 'partial_visible_failure'
        : 'requests_refreshed';
    debugPrint('[PendingRefresh] snackbar=$snackbar');
    debugPrint(
      '[PendingRefreshButton] snackbar=${!userInitiated ? 'none' : (finalResult.baseMergeSuccess ? 'success' : 'error')}',
    );
    return finalResult;
  }

  void _debugLogJobsPageSnapshot() {
    if (!kDebugMode) {
      return;
    }
    final state = DriverReplyMockState.instance;
    final uid = state.currentUidForDebug();
    final allJobs = state.debugAllLoadedJobs();
    final todayJobs = _selectedDayJobs();
    final pendingJobs = state.pendingJobs;
    final completedJobs = _selectedDayCompletedJobs();
    var hiddenCount = 0;
    debugPrint('[JobsPageLoad] uid=$uid');
    debugPrint('[JobsPageLoad] totalCloudJobs=${allJobs.length}');
    debugPrint(
      '[JobsPageLoad] selectedDate=${_selectedDate.toIso8601String()}',
    );
    debugPrint('[JobsPageLoad] visiblePending=${pendingJobs.length}');
    debugPrint('[JobsPageLoad] visibleToday=${todayJobs.length}');
    debugPrint('[JobsPageLoad] visibleCompleted=${completedJobs.length}');

    final todaySet = todayJobs.map((job) => job.jobId).toSet();
    final pendingSet = pendingJobs.map((job) => job.jobId).toSet();
    final completedSet = completedJobs.map((job) => job.jobId).toSet();
    for (final job in allJobs) {
      final decision = state.debugBucketDecisionForJob(job);
      final selectedDateMatch =
          job.scheduledAtOrParsed != null &&
          DateUtils.isSameDay(job.scheduledAtOrParsed, _selectedDate);
      final hasPin =
          job.exactPinSaved ||
          job.exactPinLatitude != null ||
          job.exactPinLongitude != null ||
          job.exactPinShared;
      debugPrint(
        '[JobBucket] jobId=${job.jobId} source=${state.debugSourceForJob(job.jobId)} status=${job.status} requestStatus=${job.requestStatus} quoteStatus=${job.quoteStatus} quoteAccepted=${job.quoteAccepted} ready=${job.isConfirmed} jobReady=${job.isConfirmed} hasReply=${job.hasCustomerReply} hasPin=$hasPin selectedDateMatch=$selectedDateMatch bucket=${decision.bucket.name} customerName=${job.customerName} jobTitle=${job.jobTitle} scheduledAt=${job.scheduledAtOrParsed?.toIso8601String() ?? '(none)'} jobDate=${job.jobDateLabel} requestId=${job.requestId ?? '(none)'} requestLinkExists=${job.requestLink.trim().isNotEmpty} replyReceivedAt=${job.replyReceivedAt?.toIso8601String() ?? '(none)'} checklistResponsesCount=${job.checklistResponses.length} customQuestionResponsesCount=${job.customQuestionResponses.length} quoteSentAt=${job.quoteSentAt?.toIso8601String() ?? '(none)'} archived=${job.archived} deleted=${job.deleted} hiddenReason=${decision.bucket == VanJobBucket.hiddenDeletedOrDraft ? decision.reason : '(none)'}',
      );

      final visibleNow =
          todaySet.contains(job.jobId) ||
          pendingSet.contains(job.jobId) ||
          completedSet.contains(job.jobId);
      if (decision.bucket == VanJobBucket.hiddenDeletedOrDraft) {
        hiddenCount += 1;
        debugPrint(
          '[HiddenJob] jobId=${job.jobId} status=${job.status} requestStatus=${job.requestStatus} requestId=${job.requestId ?? '(none)'} hasReply=${job.hasCustomerReply} checklistCount=${job.checklistResponses.length} reason=${decision.reason}',
        );
      } else if (visibleNow) {
        debugPrint(
          '[VisibleJob] jobId=${job.jobId} bucket=${decision.bucket.name} source=van_jobs',
        );
      }
      if (decision.bucket != VanJobBucket.hiddenDeletedOrDraft &&
          !visibleNow &&
          selectedDateMatch) {
        debugPrint(
          '[JobsBug] real job has bucket but no visible section jobId=${job.jobId}',
        );
      }
    }
    debugPrint('[JobsPageLoad] hiddenCount=$hiddenCount');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _refreshPendingRequestsManually() async {
    if (_isRefreshingPendingRequests) {
      return;
    }
    final state = DriverReplyMockState.instance;
    final uid = state.currentUidForDebug();
    debugPrint('[PendingRefreshButton] tapped uid=$uid');
    debugPrint('[PendingRefreshButton] usingJobsPageReloadPath=true');
    setState(() {
      _isRefreshingPendingRequests = true;
    });
    await _refreshCloudRequests(userInitiated: true);
    if (mounted) {
      setState(() {
        _isRefreshingPendingRequests = false;
      });
    }
  }

  void _setSelectedDate(DateTime date) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
    });
  }

  String _compactDateLabel(DateTime date) {
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

  String _snapshotLabel(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(date);
    if (DateUtils.isSameDay(selected, today)) {
      return 'Today';
    }
    return _compactDateLabel(selected);
  }

  String _snapshotSubtitle(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(date);
    if (DateUtils.isSameDay(selected, today)) {
      return _compactDateLabel(selected);
    }
    return '';
  }

  Future<void> _runDeveloperCleanup({
    required VanMateTestCleanupScope scope,
    required String title,
    required String message,
    required String actionLabel,
    required String successLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF142031),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.4),
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
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final result = await DriverReplyMockState.instance.debugClearTestData(
      scope: scope,
    );
    if (!mounted) {
      return;
    }

    await _refreshCloudRequests(userInitiated: false);
    if (!mounted) {
      return;
    }

    setState(() {});
    if (result.didClearAnything) {
      _showSnack('$successLabel (${result.totalCleared} records).');
    } else {
      _showSnack('No matching test data found.');
    }
  }

  Future<void> _clearTestRequests() async {
    await _runDeveloperCleanup(
      scope: VanMateTestCleanupScope.pendingRequests,
      title: 'Clear test requests?',
      message:
          'This will remove debug/test pending customer requests and clearly test booking-link replies from Firebase and from the pending lists. It will not delete business profile, question packs, quote templates, invoices, or real customer history.',
      actionLabel: 'Clear test requests',
      successLabel: 'Test requests cleared',
    );
  }

  Future<void> _clearAllTestJobs() async {
    await _runDeveloperCleanup(
      scope: VanMateTestCleanupScope.allJobs,
      title: 'Clear all test jobs?',
      message:
          'This will archive clearly marked debug/test jobs, requests, and quote records from Firebase. It will not delete business profile, custom questions, quote templates, app settings, invoices, or real customer history.',
      actionLabel: 'Clear all test jobs',
      successLabel: 'Test jobs cleared',
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

  Future<void> _runDeveloperJobDeletion(
    VanJobDeletionSelection selection,
  ) async {
    if (_isClearingSavedJobs) {
      return;
    }
    setState(() {
      _isClearingSavedJobs = true;
    });
    try {
      final service =
          widget.jobDeletionService ?? VanJobDeletionService.instance;
      final preview = await service.preview(selection: selection);
      if (!mounted) return;
      if (preview.targets.isEmpty) {
        _showSnack('No eligible jobs found for the active business.');
        return;
      }
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF142031),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              selection == VanJobDeletionSelection.testJobs
                  ? 'Delete marked test jobs?'
                  : 'Delete all operational jobs?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jobs ${preview.summary.jobs} · Requests ${preview.summary.requests} · Quote versions ${preview.summary.quoteVersions} · Tokens ${preview.summary.tokens} · Photos ${preview.summary.photos}',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preserved: ${preview.summary.invoicesPreserved} invoices and ${preview.summary.ambiguousPreserved} ambiguous records. All finance and accounting data is kept.',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...preview.targets.map(
                      (target) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          '${target.jobId} · ${target.status}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Type ${preview.confirmationPhrase}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Confirmation',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: controller.text == preview.confirmationPhrase
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                ),
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ),
      );
      final typedPhrase = controller.text;
      controller.dispose();
      if (confirmed != true || !mounted) return;
      final execution = await service.execute(
        preview,
        confirmationPhrase: typedPhrase,
      );
      await DriverReplyMockState.instance.applyConfirmedJobDeletionResults(
        execution.completed,
        refreshCloud: widget.refreshOnInit,
      );
      if (!mounted) return;
      _showSnack(
        'Deleted ${execution.completed.length}; failed ${execution.failed.length}. Invoices and finance were preserved.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('Could not delete jobs safely. Please try again.');
      debugPrint('[DeveloperJobDeletion] failed: $error');
    } finally {
      if (mounted) setState(() => _isClearingSavedJobs = false);
    }
  }

  Future<void> _openReply() async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    final realReply = DriverReplyMockState.instance.realReplyForJob(job.jobId);
    await openDriverCustomerReplyMockPage(
      context,
      jobId: realReply?.jobId ?? job.jobId,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _createQuote() async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    await openVanQuoteWorkflowForJob(context, job);
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

  Future<void> _persistScheduledJobFor(
    DriverCustomerReplyMockData job, {
    required String callbackPath,
  }) async {
    if (!_canAddAcceptedQuoteToCalendar(job)) {
      _showSnack(
        _isAwaitingRequiredExactPin(job)
            ? 'Wait for the exact pickup or drop-off pin before adding this job to the calendar.'
            : 'Set an exact agreed time before adding this job to the calendar.',
      );
      return;
    }
    final scheduledAt = effectiveAgreedSchedulingTimeForJob(
      job,
      request: _requestForJob(job),
    );
    if (scheduledAt == null) {
      _showSnack(
        'Set an exact agreed time before adding this job to the calendar.',
      );
      return;
    }
    debugPrintSynchronously(
      'CONFIRM_SCHEDULE_TAPPED path=$callbackPath jobId=${job.jobId} '
      'source=${DriverReplyMockState.instance.debugSourceForJob(job.jobId)}',
    );
    final bool persisted;
    try {
      persisted = await DriverReplyMockState.instance.persistScheduledJob(
        jobId: job.jobId,
        scheduledAt: scheduledAt,
        estimatedDurationMinutes: job.effectiveCalendarDurationMinutes ?? 60,
        schedulingStatus: job.schedulingStatus.trim().isNotEmpty
            ? job.schedulingStatus
            : 'accepted_time',
      );
    } on VanScheduleOverlapException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message);
      return;
    }
    if (!persisted) {
      if (!mounted) {
        return;
      }
      _showSnack('Could not save this job to Calendar. Please try again.');
      return;
    }
    try {
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[CONFIRM_SCHEDULE_REFRESH_ERROR] error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    _showSnack('Job added to calendar.');
  }

  Future<void> _markReady() async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    await _persistScheduledJobFor(job, callbackPath: 'jobs_calendar.active');
  }

  void _navigate() {
    _showSnack('Navigation mock opened');
  }

  Future<void> _openJob({required bool completed}) async {
    final job =
        DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
    final result = await openDriverJobDetailMockPage(
      context,
      reply: DriverReplyMockState.instance.realReplyForJob(job.jobId) ?? job,
      completed: completed,
      openedFromCalendar: true,
    );

    if (mounted) {
      setState(() {});
    }

    if (result == VanJobActionResult.deleted) {
      _showSnack('Job deleted.');
    } else if (result == VanJobActionResult.completed) {
      _showSnack('Job marked completed.');
    } else if (result == VanJobActionResult.updated) {
      _showSnack('Job updated.');
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
    return _compactDateLabel(date);
  }

  String _jobBodyText(DriverCustomerReplyMockData job) {
    final location = buildVanJobLocationSummary(
      address: job.address,
      postcode: job.postcode,
      locationPending: job.locationPending,
      requiresExactPinAfterQuoteAccepted:
          job.requiresExactPinAfterQuoteAccepted,
      hasExactPin: job.exactPinSaved,
      emptyFallback: job.isDropOffPickupRequest && !job.requiresAnyExactPin
          ? ''
          : 'No address added yet.',
    );
    final timeText = _jobTimeText(job);
    final dateText = _jobDateText(job);
    final dropOffPickupTiming = vanCalendarDropOffPickupTimingText(job);
    if (dropOffPickupTiming.isNotEmpty) {
      return location.trim().isEmpty
          ? dropOffPickupTiming
          : '$dropOffPickupTiming\n$location';
    }
    return '$dateText • $timeText\n$location';
  }

  String _debugSourceFor(DriverCustomerReplyMockData job) {
    return DriverReplyMockState.instance.debugSourceForJob(job.jobId);
  }

  List<_JobsStatusChip> _jobChips(
    DriverCustomerReplyMockData job, {
    bool enableShortcuts = false,
  }) {
    if (job.isCompleted) {
      return buildVanCompletedJobStatusPills(job)
          .map(
            (pill) => _JobsStatusChip(
              label: pill.label,
              color: pill.color,
              icon: pill.icon,
              filled: pill.filled,
            ),
          )
          .toList(growable: false);
    }

    if (_isReplyReceivedAwaitingQuote(job)) {
      return const <_JobsStatusChip>[
        _JobsStatusChip(
          label: 'Reply received',
          color: Color(0xFF58D0A4),
          icon: Icons.mark_email_read_outlined,
          filled: true,
        ),
      ];
    }

    if (_isAcceptedQuoteAwaitingExactPin(job)) {
      return <_JobsStatusChip>[
        _JobsStatusChip(
          label: job.customerJourney.copy.acceptedLabel,
          color: job.customerJourney.journeyTheme.accent,
          icon: job.customerJourney.journeyTheme.icon,
          filled: true,
          onTap: enableShortcuts
              ? () => _openJobFor(
                  job,
                  completed: false,
                  initialTarget: VanJobDetailOpenTarget.quoteSection,
                )
              : null,
        ),
        _JobsStatusChip(
          label: 'Awaiting exact pin',
          color: Color(0xFFFFC38C),
          icon: Icons.location_on,
        ),
      ];
    }

    if (_isAcceptedQuotePendingTimeAgreement(job)) {
      return <_JobsStatusChip>[
        _JobsStatusChip(
          label: job.customerJourney.copy.acceptedLabel,
          color: job.customerJourney.journeyTheme.accent,
          icon: job.customerJourney.journeyTheme.icon,
          filled: true,
          onTap: enableShortcuts
              ? () => _openJobFor(
                  job,
                  completed: false,
                  initialTarget: VanJobDetailOpenTarget.quoteSection,
                )
              : null,
        ),
        _JobsStatusChip(
          label: 'Exact pin received',
          color: vanStatusToneColor(VanStatusTone.positive),
          icon: Icons.location_on,
          onTap: enableShortcuts
              ? () => _openJobFor(
                  job,
                  completed: false,
                  initialTarget: VanJobDetailOpenTarget.exactPinSection,
                )
              : null,
        ),
      ];
    }

    if (_isAcceptedQuoteCalendarReady(job)) {
      return <_JobsStatusChip>[
        _JobsStatusChip(
          label: job.customerJourney.copy.acceptedLabel,
          color: job.customerJourney.journeyTheme.accent,
          icon: job.customerJourney.journeyTheme.icon,
          filled: true,
          onTap: enableShortcuts
              ? () => _openJobFor(
                  job,
                  completed: false,
                  initialTarget: VanJobDetailOpenTarget.quoteSection,
                )
              : null,
        ),
        _JobsStatusChip(
          label: 'Exact pin received',
          color: Color(0xFF58D0A4),
          icon: Icons.location_on,
          onTap: enableShortcuts
              ? () => _openJobFor(
                  job,
                  completed: false,
                  initialTarget: VanJobDetailOpenTarget.exactPinSection,
                )
              : null,
        ),
        _JobsStatusChip(
          label: 'Time agreed',
          color: vanStatusToneColor(VanStatusTone.positive),
          icon: Icons.schedule,
          onTap: enableShortcuts
              ? () => _openJobFor(
                  job,
                  completed: false,
                  initialTarget: VanJobDetailOpenTarget.actionsSection,
                )
              : null,
        ),
      ];
    }

    final exactPinLabel = job.isRequestExactPinReceived
        ? 'Exact pin received'
        : _isAwaitingRequiredExactPin(job)
        ? 'Awaiting exact pin'
        : 'Exact pin not requested';
    final exactPinColor = job.exactPinShared
        ? vanStatusToneColor(VanStatusTone.positive)
        : vanStatusToneColor(VanStatusTone.warning);
    final statusColor = job.isRequestCancelled || job.isRequestExpired
        ? vanStatusToneColor(VanStatusTone.danger)
        : job.isRequestPending
        ? vanStatusToneColor(VanStatusTone.warning)
        : (job.isQuoteSent
              ? vanStatusToneColor(VanStatusTone.warning)
              : vanStatusToneColor(VanStatusTone.positive));
    final statusIcon = job.isCompleted
        ? Icons.check_circle
        : job.isConfirmed
        ? Icons.verified
        : job.isQuoteSent
        ? Icons.request_quote_outlined
        : job.isRequestSubmitted || job.isReplyReceived
        ? Icons.check_circle
        : job.isRequestCancelled
        ? Icons.cancel
        : job.isRequestExpired
        ? Icons.schedule
        : job.isRequestPending
        ? Icons.mark_email_read_outlined
        : Icons.pending_actions;

    final chips = <_JobsStatusChip>[
      _JobsStatusChip(
        label: job.statusLabel,
        color: statusColor,
        icon: statusIcon,
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
          color: vanStatusToneColor(VanStatusTone.neutral),
          icon: Icons.schedule,
        ),
    ];

    if (job.isRequestPending) {
      final showReplyProgressChip =
          !job.isRequestSubmitted && !job.isReplyReceived;
      if (showReplyProgressChip) {
        chips.insert(
          1,
          _JobsStatusChip(
            label: job.requestStatusLabel,
            color: vanStatusToneColor(VanStatusTone.warning),
            icon: Icons.hourglass_bottom,
          ),
        );
      }
    }

    return chips;
  }

  List<_JobsInlineActionButton> _jobActions(
    DriverCustomerReplyMockData job, {
    bool completed = false,
  }) {
    final isCompletedJob = completed || job.isCompletedJob;
    final request = _requestForJob(job);
    final actionState = deriveVanJobActionState(job, request: request);
    final actions = <_JobsInlineActionButton>[];

    if (isCompletedJob) {
      actions.add(
        _JobsInlineActionButton(
          label: 'View job',
          onTap: () => _openJobFor(job, completed: true),
          tone: VanStatusTone.primary,
        ),
      );
      if (actionState.canViewQuote) {
        actions.add(
          _JobsInlineActionButton(
            label: 'View quote',
            icon: Icons.request_quote_outlined,
            onTap: () => _createQuoteFor(job),
            tone: VanStatusTone.primary,
          ),
        );
      } else if (!job.hasCustomerRequestAttached) {
        actions.add(
          _JobsInlineActionButton(
            label: job.customerJourney.copy.businessAction,
            icon: job.customerJourney.journeyTheme.icon,
            onTap: () => _createQuoteFor(job),
            tone: VanStatusTone.primary,
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
          tone: savedInvoice == null
              ? VanStatusTone.primary
              : VanStatusTone.primary,
        ),
      );
    } else {
      if (actionState.canCreateQuote &&
          actionState.hasCustomerReply &&
          !actionState.hasRealQuote) {
        actions.add(
          _JobsInlineActionButton(
            label: job.customerJourney.copy.businessAction,
            icon: job.customerJourney.journeyTheme.icon,
            onTap: () => _createQuoteFor(job),
            tone: VanStatusTone.primary,
          ),
        );
      } else if (actionState.canSetAgreedTime) {
        actions.add(
          _JobsInlineActionButton(
            label: 'Set agreed time',
            icon: Icons.schedule_outlined,
            onTap: () => _openJobFor(
              job,
              completed: false,
              initialTarget: VanJobDetailOpenTarget.setAgreedTimeFlow,
            ),
            tone: VanStatusTone.primary,
          ),
        );
      } else if (actionState.canAddToCalendar) {
        actions.add(
          _JobsInlineActionButton(
            label: 'Add to calendar',
            icon: Icons.check_circle,
            onTap: () => _markReadyFor(job),
            tone: VanStatusTone.primary,
          ),
        );
      } else if (actionState.isAwaitingExactPin) {
        if (actionState.canViewQuote) {
          actions.add(
            _JobsInlineActionButton(
              label: 'View quote',
              icon: Icons.request_quote_outlined,
              onTap: () => _createQuoteFor(job),
              tone: VanStatusTone.primary,
            ),
          );
        } else {
          actions.add(
            _JobsInlineActionButton(
              label: 'Open Job',
              onTap: () => _openJobFor(job, completed: false),
              tone: VanStatusTone.primary,
            ),
          );
        }
      } else {
        actions.add(
          _JobsInlineActionButton(
            label: 'Open Job',
            onTap: () => _openJobFor(job, completed: false),
            tone: VanStatusTone.primary,
          ),
        );
      }
      if (actionState.canAddToCalendar && actionState.canNavigate) {
        actions.add(
          _JobsInlineActionButton(
            label: 'Navigate',
            icon: Icons.navigation,
            onTap: () => _navigateFor(job),
            tone: VanStatusTone.neutral,
          ),
        );
      } else if (!actionState.canSetAgreedTime &&
          !actionState.isAwaitingExactPin &&
          !actionState.canAddToCalendar &&
          actionState.canNavigate) {
        actions.add(
          _JobsInlineActionButton(
            label: 'Navigate',
            icon: Icons.navigation,
            onTap: () => _navigateFor(job),
            tone: VanStatusTone.neutral,
          ),
        );
      }
      if (actionState.canCallCustomer) {
        actions.add(
          _JobsInlineActionButton(
            label: 'Call customer',
            icon: Icons.phone,
            onTap: () => _callCustomerFor(job),
            tone: VanStatusTone.primary,
          ),
        );
      }
      if (actionState.canTextCustomer) {
        actions.add(
          _JobsInlineActionButton(
            label: 'Text customer',
            icon: Icons.sms_outlined,
            onTap: () => _textCustomerFor(job),
            tone: VanStatusTone.primary,
          ),
        );
      }

      if (actionState.hasCustomerReply &&
          !(actionState.canCreateQuote &&
              actionState.hasCustomerReply &&
              !actionState.hasRealQuote) &&
          !actionState.isAwaitingExactPin &&
          !actionState.canSetAgreedTime &&
          !actionState.canAddToCalendar) {
        actions.add(
          _JobsInlineActionButton(
            label: 'View reply',
            icon: Icons.question_answer,
            onTap: () => _openReplyFor(job),
            tone: VanStatusTone.primary,
          ),
        );
      }

      if (actionState.canViewQuote) {
        if (!actionState.isAwaitingExactPin) {
          actions.add(
            _JobsInlineActionButton(
              label: 'View quote',
              icon: Icons.request_quote_outlined,
              onTap: () => _createQuoteFor(job),
              tone: VanStatusTone.primary,
            ),
          );
        }
      } else if (actionState.canCreateQuote &&
          !(actionState.hasCustomerReply && !actionState.hasRealQuote)) {
        actions.add(
          _JobsInlineActionButton(
            label: 'Create quote',
            icon: Icons.request_quote_outlined,
            onTap: () => _createQuoteFor(job),
            tone: VanStatusTone.primary,
          ),
        );
      }

      if (actionState.isQuoteAccepted &&
          !job.isConfirmed &&
          !actionState.isAwaitingExactPin &&
          !actionState.canSetAgreedTime &&
          !actionState.canAddToCalendar) {
        if (actionState.canSetAgreedTime || actionState.canAddToCalendar) {
          actions.add(
            _JobsInlineActionButton(
              label: actionState.canSetAgreedTime
                  ? 'Set agreed time'
                  : 'Add to calendar',
              icon: actionState.canSetAgreedTime
                  ? Icons.schedule_outlined
                  : Icons.check_circle,
              onTap: () => _openJobFor(
                job,
                completed: false,
                initialTarget: actionState.canSetAgreedTime
                    ? VanJobDetailOpenTarget.setAgreedTimeFlow
                    : VanJobDetailOpenTarget.actionsSection,
              ),
              tone: VanStatusTone.primary,
            ),
          );
        }
      }
    }

    return actions;
  }

  bool _hasCustomerReply(DriverCustomerReplyMockData job) {
    final request = DriverReplyMockState.instance.requestForJob(job.jobId);
    return job.hasCustomerReply || request?.hasCustomerReply == true;
  }

  VanJobRequestRecord? _requestForJob(DriverCustomerReplyMockData job) {
    return DriverReplyMockState.instance.requestForJob(job.jobId);
  }

  bool _hasQuote(DriverCustomerReplyMockData job) {
    return job.hasQuote;
  }

  bool _isReplyReceivedAwaitingQuote(DriverCustomerReplyMockData job) {
    return _hasCustomerReply(job) &&
        !job.hasQuote &&
        !job.isQuoteAccepted &&
        !job.isConfirmed;
  }

  bool _isAcceptedQuoteAwaitingExactPin(DriverCustomerReplyMockData job) {
    return job.isQuoteAccepted &&
        !job.isConfirmed &&
        _isAwaitingRequiredExactPin(job);
  }

  bool _isAcceptedQuotePendingTimeAgreement(DriverCustomerReplyMockData job) {
    return shouldPromptSetAgreedTimeForJob(job, request: _requestForJob(job));
  }

  bool _isAcceptedQuoteCalendarReady(DriverCustomerReplyMockData job) {
    return shouldPromptAddToCalendarForJob(job, request: _requestForJob(job)) &&
        _canAddAcceptedQuoteToCalendar(job);
  }

  bool _canCallCustomer(DriverCustomerReplyMockData job) {
    return sanitizeVanCustomerPhoneNumber(job.phoneNumber).isNotEmpty;
  }

  bool _canNavigateFor(DriverCustomerReplyMockData job) {
    return hasUsableNavigationTargetForJob(job, request: _requestForJob(job));
  }

  bool _isAwaitingRequiredExactPin(DriverCustomerReplyMockData job) {
    return job.isQuoteAccepted && job.requiresAnyExactPin && !job.exactPinSaved;
  }

  bool _canAddAcceptedQuoteToCalendar(DriverCustomerReplyMockData job) {
    if (!shouldPromptAddToCalendarForJob(job, request: _requestForJob(job)) ||
        _isAwaitingRequiredExactPin(job)) {
      return false;
    }
    return hasCanonicalAgreedSchedulingTimeForJob(
          job,
          request: _requestForJob(job),
        ) &&
        (effectiveAgreedSchedulingTimeForJob(
              job,
              request: _requestForJob(job),
            ) !=
            null);
  }

  bool _shouldShowCompleteEarlyAction(DriverCustomerReplyMockData job) {
    return shouldShowCompleteEarlyAction(
      isCompleted: job.isCompleted,
      isCancelled: job.isCancelled,
      isScheduled: job.isScheduledInCalendarState,
      scheduledAt: job.scheduledAtOrParsed,
    );
  }

  Future<bool> _confirmCompleteEarly(DriverCustomerReplyMockData job) async {
    final completionAction = vanCalendarCompletionActionLabel(job);
    final scheduledAt = job.scheduledAtOrParsed;
    final scheduledLabel = scheduledAt == null
        ? 'this scheduled time'
        : '${_compactDateLabel(scheduledAt)} at ${TimeOfDay.fromDateTime(scheduledAt).format(context)}';
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF142031),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              '$completionAction early?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              'This job is scheduled for $scheduledLabel. Only complete it now if the work has already been done.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Text('Keep scheduled'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF58D0A4),
                  foregroundColor: Colors.white,
                ),
                child: Text(completionAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _completeJobEarlyFor(DriverCustomerReplyMockData job) async {
    if (!_shouldShowCompleteEarlyAction(job)) {
      return;
    }
    final confirmed = await _confirmCompleteEarly(job);
    if (!confirmed) {
      return;
    }
    final persisted = await DriverReplyMockState.instance.persistCompletedJob(
      jobId: job.jobId,
      completedAt: DateTime.now(),
    );
    if (!persisted) {
      if (!mounted) {
        return;
      }
      _showSnack('Could not complete this job. Please try again.');
      return;
    }
    try {
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[COMPLETE_EARLY_REFRESH_ERROR] error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    _showSnack(vanCalendarCompletionPastTenseLabel(job));
  }

  bool _isBookingLinkPendingRequest(DriverCustomerReplyMockData job) {
    final request = DriverReplyMockState.instance.requestForJob(job.jobId);
    final requestSource = request?.source.trim().toLowerCase() ?? '';
    return request?.isPreview == true ||
        requestSource == 'booking_link' ||
        requestSource == 'preview';
  }

  Widget _buildJobListSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<DriverCustomerReplyMockData> jobs,
    required String emptyTitle,
    String emptyMessage = '',
    bool completed = false,
    bool enableChipShortcuts = false,
  }) {
    final theme = Theme.of(context);

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JobsSectionHeader(icon: icon, title: title, trailing: trailing),
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
                if (emptyMessage.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var index = 0; index < jobs.length; index++) ...[
                  _JobsMockJobCard(
                    accent: completed || jobs[index].isScheduledInCalendarState
                        ? vanCalendarAccentForJob(jobs[index])
                        : jobs[index].isConfirmed
                        ? const Color(0xFF4A7DFF)
                        : jobs[index].isQuoteSent
                        ? const Color(0xFFB48CFF)
                        : const Color(0xFFFFC38C),
                    icon: completed || jobs[index].isScheduledInCalendarState
                        ? vanCalendarIconForJob(jobs[index])
                        : jobs[index].isConfirmed
                        ? Icons.verified
                        : jobs[index].isQuoteSent
                        ? Icons.request_quote_outlined
                        : Icons.calendar_month,
                    eyebrow: _jobDateText(jobs[index]),
                    title: jobs[index].customerName,
                    subtitle:
                        completed || jobs[index].isScheduledInCalendarState
                        ? vanCalendarDisplayJobTitle(jobs[index])
                        : jobs[index].jobTitle,
                    body: _jobBodyText(jobs[index]),
                    debugSource: _debugSourceFor(jobs[index]),
                    debugDocId: jobs[index].jobId,
                    chips: _jobChips(
                      jobs[index],
                      enableShortcuts: enableChipShortcuts,
                    ),
                    actions: _jobActions(jobs[index], completed: completed),
                    onTap: () => _openJobFor(
                      jobs[index],
                      completed: completed || jobs[index].isCompletedJob,
                    ),
                    onEditJob: completed
                        ? null
                        : () => _editJobFor(jobs[index]),
                    onChangeDateTime: completed
                        ? null
                        : () => _changeDateTimeFor(jobs[index]),
                    onCompleteEarly: _shouldShowCompleteEarlyAction(jobs[index])
                        ? () => _completeJobEarlyFor(jobs[index])
                        : null,
                    onDeleteJob: () => _deleteJobFor(jobs[index]),
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
    final linkedJob = DriverReplyMockState.instance.jobById(job.jobId);
    final linkedRequest = DriverReplyMockState.instance.requestForJob(
      job.jobId,
    );
    debugPrint(
      '[VanPendingRender] requestId=${linkedRequest?.requestId ?? '(none)'} linkedJobId=${job.jobId} linkedJobExists=${linkedJob != null} source=${_debugSourceFor(job)}',
    );
    if (linkedJob == null) {
      _showSnack('This request is no longer linked to a job.');
      return;
    }
    final realReply = DriverReplyMockState.instance.realReplyForJob(job.jobId);
    await openDriverCustomerReplyMockPage(
      context,
      jobId: realReply?.jobId ?? job.jobId,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _createQuoteFor(DriverCustomerReplyMockData job) async {
    await openVanQuoteWorkflowForJob(context, job);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openJobFor(
    DriverCustomerReplyMockData job, {
    required bool completed,
    VanJobDetailOpenTarget initialTarget = VanJobDetailOpenTarget.top,
  }) async {
    final result = await openDriverJobDetailMockPage(
      context,
      reply: DriverReplyMockState.instance.realReplyForJob(job.jobId) ?? job,
      completed: completed,
      initialTarget: initialTarget,
      openedFromCalendar: true,
    );
    if (mounted) {
      setState(() {});
    }
    if (result == VanJobActionResult.deleted) {
      _showSnack('Job deleted.');
    } else if (result == VanJobActionResult.completed) {
      _showSnack('Job marked completed.');
    } else if (result == VanJobActionResult.updated) {
      _showSnack('Job updated.');
    }
  }

  Future<void> _editJobFor(DriverCustomerReplyMockData job) async {
    final saved = await openDriverJobEditDetailsSheet(context, job: job);
    if (!mounted || saved == null) {
      return;
    }

    setState(() {});
    _showSnack('Job updated.');
  }

  Future<void> _changeDateTimeFor(DriverCustomerReplyMockData job) async {
    final changed = await openDriverJobDateTimeChangeFlow(context, job: job);
    if (!mounted || !changed) {
      return;
    }

    setState(() {});
    _showSnack('Job time updated.');
  }

  Future<void> _deleteJobFor(DriverCustomerReplyMockData job) async {
    final deleted = await confirmDriverJobDelete(context, job: job);
    if (!mounted || deleted != true) {
      return;
    }

    setState(() {});
    _showSnack('Job deleted.');
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

  Future<void> _markReadyFor(DriverCustomerReplyMockData job) async {
    await _persistScheduledJobFor(job, callbackPath: 'jobs_calendar.list_item');
  }

  Future<void> _navigateFor(DriverCustomerReplyMockData job) async {
    await openVanJobNavigation(context, job);
  }

  Future<void> _callCustomerFor(DriverCustomerReplyMockData job) async {
    await launchCustomerPhone(context, job.phoneNumber);
  }

  Future<void> _textCustomerFor(DriverCustomerReplyMockData job) async {
    final launched = await textCustomerRequest(
      phoneNumber: job.phoneNumber,
      message:
          'Hi ${job.customerName.trim().isNotEmpty ? job.customerName.trim() : 'there'}, just following up about your ${job.jobTitle.trim().isNotEmpty ? job.jobTitle.trim().toLowerCase() : 'job request'}.',
    );
    if (!mounted || launched) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open text message.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _selectedDateLabel(DateTime date) => _snapshotLabel(date);

  String _daySnapshotLabel(DateTime date) {
    return _snapshotLabel(date);
  }

  String _daySnapshotSubtitle(DateTime date) {
    return _snapshotSubtitle(date);
  }

  List<DriverCustomerReplyMockData> _visibleScheduledJobsForDate(
    DateTime date, {
    String? logTag,
  }) {
    final state = DriverReplyMockState.instance;
    return state
        .bookedJobsForDate(date, logTag: logTag)
        .where((job) => !job.isCompleted)
        .toList(growable: false);
  }

  int _daySnapshotCount(DateTime date) {
    return _visibleScheduledJobsForDate(date, logTag: 'Next3Count').length;
  }

  List<_JobsDaySnapshot> _daySnapshots() {
    final today = DateUtils.dateOnly(DateTime.now());
    return List<_JobsDaySnapshot>.generate(7, (index) {
      final date = today.add(Duration(days: index));
      return _JobsDaySnapshot(
        date: date,
        label: _daySnapshotLabel(date),
        subtitle: _daySnapshotSubtitle(date),
        count: _daySnapshotCount(date),
        selected: DateUtils.isSameDay(date, _selectedDate),
      );
    });
  }

  List<DriverCustomerReplyMockData> _selectedDayJobs() {
    return _visibleScheduledJobsForDate(_selectedDate, logTag: 'CalendarCount');
  }

  List<DriverCustomerReplyMockData> _selectedDayCompletedJobs() {
    final state = DriverReplyMockState.instance;
    return state
        .jobsForDate(_selectedDate)
        .where((job) {
          final decision = state.debugBucketDecisionForJob(job);
          return decision.bucket == VanJobBucket.completedJob;
        })
        .toList(growable: false);
  }

  Widget _buildDaySnapshotSelector(BuildContext context) {
    final theme = Theme.of(context);
    final days = _daySnapshots();

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JobsSectionHeader(
            icon: Icons.calendar_month,
            title: 'Next 3 days',
            onIconTap: _openCalendarSchedulePage,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a day to update the work list.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (var index = 0; index < days.length; index++) ...[
                  SizedBox(
                    width: 118,
                    child: _JobsDaySnapshotCard(
                      snapshot: days[index],
                      onTap: () => _setSelectedDate(days[index].date),
                    ),
                  ),
                  if (index < days.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayJobsSection(BuildContext context) {
    final jobs = _selectedDayJobs();
    final theme = Theme.of(context);
    final title = _selectedDateLabel(_selectedDate);

    return _JobsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JobsSectionHeader(icon: Icons.today, title: title),
          const SizedBox(height: 12),
          if (jobs.isEmpty) ...[
            Text(
              'No jobs booked for this day.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open a different day or add a new request when you are ready.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
                height: 1.45,
              ),
            ),
          ] else ...[
            for (var index = 0; index < jobs.length; index++) ...[
              _JobsMockJobCard(
                accent: vanCalendarAccentForJob(jobs[index]),
                icon: vanCalendarIconForJob(jobs[index]),
                eyebrow: _selectedDateLabel(_selectedDate),
                title: jobs[index].customerName,
                subtitle: vanCalendarDisplayJobTitle(jobs[index]),
                body: _jobBodyText(jobs[index]),
                debugSource: _debugSourceFor(jobs[index]),
                debugDocId: jobs[index].jobId,
                chips: _jobChips(jobs[index]),
                actions: _jobActions(jobs[index]),
                onTap: () => _openJobFor(jobs[index], completed: false),
                onEditJob: () => _editJobFor(jobs[index]),
                onChangeDateTime: () => _changeDateTimeFor(jobs[index]),
                onDeleteJob: () => _deleteJobFor(jobs[index]),
              ),
              if (index < jobs.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedJobsSection(BuildContext context) {
    final jobs = _selectedDayCompletedJobs();
    return _buildJobListSection(
      context,
      title: 'Completed jobs',
      icon: Icons.history,
      jobs: jobs,
      emptyTitle: 'No jobs completed for this day.',
      emptyMessage: 'Completed jobs for the selected day will appear here.',
      completed: true,
    );
  }

  Widget _buildPendingRequestsSection(BuildContext context) {
    final jobs = DriverReplyMockState.instance.pendingJobs
        .where((job) => !_isBookingLinkPendingRequest(job))
        .toList(growable: false);
    return _buildJobListSection(
      context,
      title: 'Pending customer requests',
      icon: Icons.pending_actions,
      trailing: IconButton(
        tooltip: 'Refresh requests',
        onPressed: _isRefreshingPendingRequests
            ? null
            : _refreshPendingRequestsManually,
        icon: _isRefreshingPendingRequests
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
        color: Colors.white,
      ),
      jobs: jobs,
      emptyTitle: 'No pending requests',
      enableChipShortcuts: true,
    );
  }

  Widget _buildCustomerHistoryShortcut(BuildContext context) {
    final theme = Theme.of(context);

    return _JobsGlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => unawaited(openVanCompletedJobsPage(context)),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(Icons.history, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed, declined and blocked customers',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.84),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
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
            'Debug-only cleanup for the current account. Business Profile, questions, templates and app configuration are kept.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _isClearingSavedJobs
                  ? null
                  : () => _runDeveloperJobDeletion(
                      VanJobDeletionSelection.testJobs,
                    ),
              icon: _isClearingSavedJobs
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
              label: const Text('Delete marked test jobs'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isClearingSavedJobs
                  ? null
                  : () => _runDeveloperJobDeletion(
                      VanJobDeletionSelection.allOperational,
                    ),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Delete all operational jobs'),
            ),
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
            accent: vanCalendarAccentForJob(job),
            icon: vanCalendarIconForJob(job),
            eyebrow: 'Completed',
            title: job.customerName,
            subtitle: vanCalendarDisplayJobTitle(job),
            body: bodyText,
            debugSource: _debugSourceFor(job),
            debugDocId: job.jobId,
            chips: [
              ...buildVanCompletedJobStatusPills(job).map(
                (pill) => _JobsStatusChip(
                  label: pill.label,
                  color: pill.color,
                  icon: pill.icon,
                  filled: pill.filled,
                ),
              ),
            ],
            actions: _jobActions(job, completed: true),
            onTap: () => _openJobFor(job, completed: true),
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

  Future<void> _openCalendarSchedulePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const JobsCalendarSchedulePage()),
    );
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _openQuickInvoice() async {
    await openVanQuickInvoicePage(context);
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _openBusinessProfile() async {
    await openVanBusinessProfilePage(context);
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
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 120 + bottomPadding),
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
                            'Scheduled jobs, job notes and calendar.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildDaySnapshotSelector(context),
                          const SizedBox(height: 12),
                          _JobsGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _JobsSectionHeader(
                                  icon: Icons.playlist_add_check,
                                  title: 'Quick actions',
                                ),
                                const SizedBox(height: 12),
                                Column(
                                  children: [
                                    _JobsGlassActionButton(
                                      icon: Icons.badge_outlined,
                                      label: 'Business Profile',
                                      onTap: _openBusinessProfile,
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _JobsGlassActionButton(
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
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _JobsGlassActionButton(
                                            icon: Icons.calendar_month,
                                            label: 'Calendar',
                                            onTap: _openCalendarSchedulePage,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _JobsGlassActionButton(
                                            icon: Icons.history,
                                            label: 'Invoices',
                                            onTap: _openPastInvoices,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _JobsGlassActionButton(
                                            icon: Icons.receipt_long_outlined,
                                            label: 'Quick Inv.',
                                            onTap: _openQuickInvoice,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSelectedDayJobsSection(context),
                          const SizedBox(height: 12),
                          _buildPendingRequestsSection(context),
                          const SizedBox(height: 12),
                          _buildCustomerHistoryShortcut(context),
                          if (showVanMateDeveloperTools()) ...[
                            const SizedBox(height: 12),
                            _buildTestingToolsSection(context),
                          ],
                        ],
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
    return VanBackBusinessHubButtons(onBack: onTap);
  }
}

class _JobsDaySnapshot {
  const _JobsDaySnapshot({
    required this.date,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.selected,
  });

  final DateTime date;
  final String label;
  final String subtitle;
  final int count;
  final bool selected;
}

class _JobsDaySnapshotCard extends StatelessWidget {
  const _JobsDaySnapshotCard({required this.snapshot, required this.onTap});

  final _JobsDaySnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = snapshot.selected
        ? const Color(0xFF4A7DFF)
        : const Color(0xFF8AB4FF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: snapshot.selected
                ? const Color(0xFF4A7DFF).withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.10),
            border: Border.all(
              color: accent.withValues(alpha: snapshot.selected ? 0.48 : 0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (snapshot.subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  snapshot.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                snapshot.count == 1 ? '1 job' : '${snapshot.count} jobs',
                style: TextStyle(
                  color: snapshot.selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.84),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
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
  const _JobsSectionHeader({
    required this.icon,
    required this.title,
    this.onIconTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onIconTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onIconTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
          ),
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
        trailing ?? const SizedBox.shrink(),
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
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
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

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}

class _JobsInlineActionButton extends StatelessWidget {
  const _JobsInlineActionButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.tone = VanStatusTone.neutral,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final VanStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final accent = tone == VanStatusTone.neutral
        ? Colors.white
        : vanStatusToneColor(tone);

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
              color: tone == VanStatusTone.neutral
                  ? Colors.white.withValues(alpha: enabled ? 0.08 : 0.04)
                  : accent.withValues(alpha: enabled ? 0.20 : 0.08),
              border: Border.all(
                color: tone == VanStatusTone.neutral
                    ? Colors.white.withValues(alpha: enabled ? 0.14 : 0.08)
                    : accent.withValues(alpha: enabled ? 0.26 : 0.12),
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
    this.onTap,
    this.onEditJob,
    this.onChangeDateTime,
    this.onCompleteEarly,
    this.onDeleteJob,
    this.debugSource = '',
    this.debugDocId = '',
  });

  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String body;
  final List<Widget> chips;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final Future<void> Function()? onEditJob;
  final Future<void> Function()? onChangeDateTime;
  final Future<void> Function()? onCompleteEarly;
  final Future<void> Function()? onDeleteJob;
  final String debugSource;
  final String debugDocId;

  @override
  Widget build(BuildContext context) {
    final hasOverflowActions =
        onEditJob != null ||
        onChangeDateTime != null ||
        onCompleteEarly != null ||
        onDeleteJob != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.black.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                            border: Border.all(
                              color: accent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      eyebrow,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.15,
                                        color: accent.withValues(alpha: 0.96),
                                      ),
                                    ),
                                  ),
                                  if (hasOverflowActions) ...[
                                    const SizedBox(width: 8),
                                    _JobsCardOverflowMenuButton(
                                      onEditJob: onEditJob,
                                      onChangeDateTime: onChangeDateTime,
                                      onCompleteEarly: onCompleteEarly,
                                      onDeleteJob: onDeleteJob,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.76,
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
                    if (showVanMateDeveloperTools() &&
                        (debugSource.trim().isNotEmpty ||
                            debugDocId.trim().isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      Text(
                        'source: ${debugSource.trim().isEmpty ? 'mock' : debugSource}  docId: ${debugDocId.trim().isEmpty ? '(none)' : debugDocId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.50),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(spacing: 10, runSpacing: 10, children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

enum _JobsCardOverflowAction {
  editJob,
  changeDateTime,
  completeEarly,
  deleteJob,
}

class _JobsCardOverflowMenuButton extends StatelessWidget {
  const _JobsCardOverflowMenuButton({
    required this.onEditJob,
    required this.onChangeDateTime,
    required this.onCompleteEarly,
    required this.onDeleteJob,
  });

  final Future<void> Function()? onEditJob;
  final Future<void> Function()? onChangeDateTime;
  final Future<void> Function()? onCompleteEarly;
  final Future<void> Function()? onDeleteJob;

  @override
  Widget build(BuildContext context) {
    final hasAnyAction =
        onEditJob != null ||
        onChangeDateTime != null ||
        onCompleteEarly != null ||
        onDeleteJob != null;
    if (!hasAnyAction) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_JobsCardOverflowAction>(
      tooltip: 'Job actions',
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF132031),
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      onSelected: (action) {
        switch (action) {
          case _JobsCardOverflowAction.editJob:
            if (onEditJob != null) {
              unawaited(onEditJob!());
            }
            break;
          case _JobsCardOverflowAction.changeDateTime:
            if (onChangeDateTime != null) {
              unawaited(onChangeDateTime!());
            }
            break;
          case _JobsCardOverflowAction.completeEarly:
            if (onCompleteEarly != null) {
              unawaited(onCompleteEarly!());
            }
            break;
          case _JobsCardOverflowAction.deleteJob:
            if (onDeleteJob != null) {
              unawaited(onDeleteJob!());
            }
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_JobsCardOverflowAction>>[];
        if (onEditJob != null) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobsCardOverflowAction.editJob,
              label: 'Edit job',
              icon: Icons.edit_outlined,
            ),
          );
        }
        if (onChangeDateTime != null) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobsCardOverflowAction.changeDateTime,
              label: 'Change date/time',
              icon: Icons.event_available_outlined,
            ),
          );
        }
        if (onCompleteEarly != null) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobsCardOverflowAction.completeEarly,
              label: 'Complete early',
              icon: Icons.task_alt_outlined,
            ),
          );
        }
        if (onDeleteJob != null) {
          if (items.isNotEmpty) {
            items.add(const PopupMenuDivider(height: 10));
          }
          items.add(
            _buildOverflowMenuItem(
              value: _JobsCardOverflowAction.deleteJob,
              label: 'Delete job',
              icon: Icons.delete_outline,
              color: const Color(0xFFFF6B6B),
              destructive: true,
            ),
          );
        }
        return items;
      },
    );
  }

  PopupMenuItem<_JobsCardOverflowAction> _buildOverflowMenuItem({
    required _JobsCardOverflowAction value,
    required String label,
    required IconData icon,
    Color? color,
    bool destructive = false,
  }) {
    final itemColor = color ?? Colors.white;
    return PopupMenuItem<_JobsCardOverflowAction>(
      value: value,
      height: 46,
      child: Row(
        children: [
          Icon(icon, size: 18, color: itemColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: itemColor,
              fontWeight: destructive ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
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
