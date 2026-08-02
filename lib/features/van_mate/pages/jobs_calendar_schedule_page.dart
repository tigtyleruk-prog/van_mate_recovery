// ignore_for_file: unused_field, unused_element

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_calendar_job_presentation.dart';
import '../helpers/van_completed_job_status_pills.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_customer_journey_theme.dart';
import '../helpers/van_job_navigation.dart';
import '../helpers/van_job_request_state.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_customer_journey.dart';
import 'create_invoice_page.dart';
import 'driver_customer_reply_mock_page.dart';
import 'create_job_request_flow.dart';
import 'job_detail_page.dart';
import 'van_invoice_preview_page.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_calendar_compact_action_card.dart';
import '../widgets/van_pre_order_calendar_entry.dart';

class JobsCalendarSchedulePage extends StatefulWidget {
  const JobsCalendarSchedulePage({super.key});

  @override
  State<JobsCalendarSchedulePage> createState() =>
      _JobsCalendarSchedulePageState();
}

class _JobsCalendarSchedulePageState extends State<JobsCalendarSchedulePage>
    with WidgetsBindingObserver {
  static const int _defaultScheduleStartHour = 6;
  static const int _defaultScheduleEndHour = 22;
  static const int _fullScheduleStartHour = 0;
  static const int _fullScheduleEndHour = 23;

  late DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  late DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _pageBuildCount = 0;
  int _driverStateChangeCount = 0;
  int _calendarMapBuildCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[CalendarSchedulePage] initState');
    WidgetsBinding.instance.addObserver(this);
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[CalendarSchedulePage] postFrame refresh start');
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(
          forceServer: true,
          debugOrigin: 'calendar_schedule_page.initState',
        ),
      );
    });
  }

  @override
  void dispose() {
    debugPrint('[CalendarSchedulePage] dispose');
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[CalendarSchedulePage] lifecycle state=$state');
    if (state == AppLifecycleState.resumed) {
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(
          forceServer: true,
          debugOrigin: 'calendar_schedule_page.resumed',
        ),
      );
    }
  }

  void _handleDriverStateChanged() {
    if (!mounted) {
      return;
    }

    _driverStateChangeCount += 1;
    debugPrint(
      '[CalendarSchedulePage] driverStateChanged count=$_driverStateChangeCount '
      'mounted=$mounted selectedDate=${_selectedDate.toIso8601String()} '
      'watchers=${DriverReplyMockState.instance.activeRequestWatchCount} '
      'requests=${DriverReplyMockState.instance.jobRequestCount} '
      'isHydrating=${DriverReplyMockState.instance.isHydratingCloudForDebug}',
    );
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    setState(() {});
    final notice = DriverReplyMockState.instance
        .takeRecentRequestRefreshNotice();
    if (notice != null && notice.isNotEmpty && isCurrentRoute) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice), behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<_ScheduleDayData> get _realDays => _buildRealDays();

  List<_ScheduleDayData> _buildRealDays() {
    final jobsByDate = _calendarJobsByDate();
    final today = DateUtils.dateOnly(DateTime.now());
    final dates = <DateTime>{...jobsByDate.keys, today}.toList()
      ..sort((a, b) {
        final aIsToday = DateUtils.isSameDay(a, today);
        final bIsToday = DateUtils.isSameDay(b, today);
        if (aIsToday && !bIsToday) {
          return -1;
        }
        if (!aIsToday && bIsToday) {
          return 1;
        }

        final aIsFuture = a.isAfter(today);
        final bIsFuture = b.isAfter(today);
        if (aIsFuture != bIsFuture) {
          return aIsFuture ? -1 : 1;
        }

        if (aIsFuture && bIsFuture) {
          return a.compareTo(b);
        }

        return b.compareTo(a);
      });

    return dates
        .map((date) {
          final jobs =
              jobsByDate[date] ?? const <DriverCustomerReplyMockData>[];
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
        })
        .toList(growable: false);
  }

  _ScheduleJobData _buildScheduleJobData(
    DriverCustomerReplyMockData job, {
    bool closeSheetOnDeleted = false,
  }) {
    final debugSource = DriverReplyMockState.instance.debugSourceForJob(
      job.jobId,
    );
    final status = _scheduleJobStatusForJob(job);
    final savedInvoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );
    final locationLabel = buildVanJobLocationSummary(
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
    final exactPinLabel = job.exactPinShared
        ? 'Exact pin shared'
        : job.requiresAnyExactPin
        ? 'Exact pin missing'
        : 'Exact pin not requested';
    final statusPills = buildVanCompletedJobStatusPills(job);
    final request = DriverReplyMockState.instance.requestForJob(job.jobId);
    final actionState = deriveVanJobActionState(job, request: request);
    final shouldSetAgreedTime = actionState.canSetAgreedTime;
    final shouldAddToCalendar =
        actionState.canAddToCalendar && _canAddAcceptedQuoteToCalendar(job);
    final showAcceptedQuoteAction =
        actionState.isQuoteAccepted &&
        (shouldSetAgreedTime || shouldAddToCalendar);

    final actions = job.isCompleted
        ? <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'View job',
              enabled: true,
              icon: Icons.open_in_new_rounded,
              accent: const Color(0xFF4A7DFF),
              onTap: () =>
                  _openJobFor(job, closeSheetOnDeleted: closeSheetOnDeleted),
            ),
            _ScheduleActionData(
              label: savedInvoice == null ? 'Create invoice' : 'View invoice',
              enabled: true,
              icon: Icons.receipt_long_outlined,
              accent: savedInvoice == null ? null : const Color(0xFF4A7DFF),
              onTap: savedInvoice == null
                  ? () => _createInvoiceFor(job)
                  : () => _viewInvoiceFor(job),
            ),
            if (!job.isDraft && (job.isReplyReceived || job.exactPinShared))
              _ScheduleActionData(
                label: 'View reply',
                enabled: true,
                icon: Icons.question_answer,
                accent: const Color(0xFF4A7DFF),
                onTap: () => _openReplyFor(job),
              ),
            if (job.hasQuote)
              _ScheduleActionData(
                label:
                    'View ${job.customerJourney.copy.requestNoun.toLowerCase()}',
                enabled: true,
                icon: job.customerJourney.journeyTheme.icon,
                accent: job.customerJourney.journeyTheme.accent,
                onTap: () => _createQuoteFor(job),
              )
            else if (!job.hasCustomerRequestAttached)
              _ScheduleActionData(
                label: job.customerJourney.copy.businessAction,
                enabled: true,
                icon: job.customerJourney.journeyTheme.icon,
                accent: job.customerJourney.journeyTheme.accent,
                onTap: () => _createQuoteFor(job),
              ),
          ]
        : <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'Open Job',
              enabled: true,
              icon: Icons.open_in_new_rounded,
              accent: const Color(0xFF4A7DFF),
              onTap: () =>
                  _openJobFor(job, closeSheetOnDeleted: closeSheetOnDeleted),
            ),
            if (actionState.canNavigate)
              _ScheduleActionData(
                label: 'Navigate',
                enabled: true,
                icon: Icons.navigation,
                onTap: () => _navigateFor(job),
              ),
            if (actionState.canCallCustomer)
              _ScheduleActionData(
                label: 'Call customer',
                enabled: true,
                icon: Icons.phone,
                accent: const Color(0xFF4A7DFF),
                onTap: () => _callCustomerFor(job),
              ),
            if (actionState.canTextCustomer)
              _ScheduleActionData(
                label: 'Text customer',
                enabled: true,
                icon: Icons.sms_outlined,
                accent: const Color(0xFF4A7DFF),
                onTap: () => _textCustomerFor(job),
              ),
            if (actionState.canCreateQuote)
              _ScheduleActionData(
                label: job.customerJourney.copy.businessAction,
                enabled: true,
                icon: job.customerJourney.journeyTheme.icon,
                accent: job.customerJourney.journeyTheme.accent,
                onTap: () => _createQuoteFor(job),
              )
            else if (actionState.canViewQuote)
              _ScheduleActionData(
                label:
                    'View ${job.customerJourney.copy.requestNoun.toLowerCase()}',
                enabled: true,
                icon: job.customerJourney.journeyTheme.icon,
                accent: job.customerJourney.journeyTheme.accent,
                onTap: () => _createQuoteFor(job),
              ),
            if (showAcceptedQuoteAction)
              _ScheduleActionData(
                label: shouldSetAgreedTime
                    ? 'Set agreed time'
                    : 'Add to calendar',
                enabled: true,
                icon: shouldSetAgreedTime
                    ? Icons.schedule_outlined
                    : Icons.check_circle,
                onTap: () => _openJobFor(job),
              ),
          ];

    return _ScheduleJobData(
      title: job.customerName,
      subtitle: vanCalendarDisplayJobTitle(job),
      locationLabel: locationLabel,
      exactPinLabel: exactPinLabel,
      timeLabel: _jobTimeTextForSchedule(job),
      statusLabel: job.statusLabel,
      status: status,
      accent: vanCalendarAccentForJob(job),
      body: _scheduleBodyText(job),
      statusPills: statusPills,
      actions: actions,
      job: job,
      debugSource: debugSource,
      debugDocId: job.jobId,
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
      case _ScheduleJobStatus.quoteAccepted:
        return const Color(0xFF58D0A4);
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
    if (job.isQuoteAccepted && !job.isConfirmed) {
      return _ScheduleJobStatus.quoteAccepted;
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
    if (job.requiresAnyExactPin && !job.exactPinShared) {
      return _ScheduleJobStatus.awaitingPin;
    }
    return _ScheduleJobStatus.pending;
  }

  String _scheduleDayLabel(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.isSameDay(date, today)) {
      return 'Today';
    }
    return _formatScheduleDate(date);
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
    final statusText = job.isCompleted
        ? 'Job completed.'
        : job.isQuoteDeclined
        ? 'Quote declined. Review, resend, or delete when ready.'
        : job.isQuoteAccepted && !job.isConfirmed
        ? (shouldPromptSetAgreedTimeForJob(
                job,
                request: DriverReplyMockState.instance.requestForJob(job.jobId),
              )
              ? 'Quote accepted. A time still needs arranging before it can be added to your calendar.'
              : _isAwaitingRequiredExactPin(job)
              ? 'Quote accepted. The exact pickup or drop-off pin still needs to be shared before it can be added to your calendar.'
              : 'Quote accepted. Add it to your calendar when you\'re ready.')
        : job.isConfirmed
        ? 'Confirmed and ready to go.'
        : job.isQuoteSent
        ? 'Quote sent. Waiting for customer reply.'
        : job.isReplyReceived
        ? 'Customer reply received.'
        : 'Awaiting customer reply.';
    final pinText = job.exactPinShared
        ? 'Exact pin shared.'
        : job.requiresAnyExactPin
        ? 'Exact pin still missing.'
        : 'No exact pin requested.';
    final dropOffPickupTiming = vanCalendarDropOffPickupTimingText(job);
    return dropOffPickupTiming.isEmpty
        ? '$statusText\n$pinText'
        : '$statusText\n$dropOffPickupTiming\n$pinText';
  }

  bool _hasCustomerReply(DriverCustomerReplyMockData job) {
    final request = DriverReplyMockState.instance.requestForJob(job.jobId);
    return job.hasCustomerReply || request?.hasCustomerReply == true;
  }

  bool _canCallCustomer(DriverCustomerReplyMockData job) {
    return sanitizeVanCustomerPhoneNumber(job.phoneNumber).isNotEmpty;
  }

  bool _isAwaitingRequiredExactPin(DriverCustomerReplyMockData job) {
    return job.isQuoteAccepted && job.requiresAnyExactPin && !job.exactPinSaved;
  }

  bool _canAddAcceptedQuoteToCalendar(DriverCustomerReplyMockData job) {
    final request = DriverReplyMockState.instance.requestForJob(job.jobId);
    if (!shouldPromptAddToCalendarForJob(job, request: request) ||
        _isAwaitingRequiredExactPin(job)) {
      return false;
    }
    return effectiveAgreedSchedulingTimeForJob(job, request: request) != null;
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
              accent: Color(0xFF4A7DFF),
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
            _ScheduleActionData(
              label: 'View Request',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
            _ScheduleActionData(label: 'Resend', enabled: true),
          ],
        ),
        const _ScheduleJobData(
          title: 'Courier supplies drop',
          timeLabel: '14:00',
          statusLabel: 'Completed',
          status: _ScheduleJobStatus.completed,
          accent: Color(0xFF58D0A4),
          body: 'Notes and pin already saved.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'View Notes',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'View Request',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'Open Job',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
          title: 'Courier drop-off',
          timeLabel: '10:00',
          statusLabel: 'Completed',
          status: _ScheduleJobStatus.completed,
          accent: Color(0xFF58D0A4),
          body: 'Finished and ready to review later.',
          actions: <_ScheduleActionData>[
            _ScheduleActionData(
              label: 'View Notes',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'Open Job',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'View Request',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'View Request',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'View Notes',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'Open Job',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
            _ScheduleActionData(
              label: 'View Request',
              enabled: true,
              accent: Color(0xFF4A7DFF),
            ),
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
        unawaited(
          openDriverCustomerReplyMockPage(
            context,
            jobId:
                DriverReplyMockState.instance
                    .realReplyForJob(job.jobId)
                    ?.jobId ??
                job.jobId,
          ),
        );
        return;
      case 'Create quote':
        unawaited(openVanQuoteWorkflowForJob(context, job));
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

  Future<void> _markReadyFor(DriverCustomerReplyMockData job) async {
    if (!_canAddAcceptedQuoteToCalendar(job)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAwaitingRequiredExactPin(job)
                ? 'Wait for the exact pickup or drop-off pin before adding this job to the calendar.'
                : 'Set an exact agreed time before adding this job to the calendar.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final scheduledAt = effectiveAgreedSchedulingTimeForJob(
      job,
      request: DriverReplyMockState.instance.requestForJob(job.jobId),
    );
    if (scheduledAt == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set an exact agreed time before adding this job to the calendar.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final pastScheduleMessage = validateVanMateScheduledAt(scheduledAt);
    if (pastScheduleMessage != null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pastScheduleMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    debugPrintSynchronously(
      'CONFIRM_SCHEDULE_TAPPED path=jobs_calendar_schedule.actions jobId=${job.jobId} '
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    } on VanPastScheduleException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!persisted) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save this job to Calendar. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
        debugOrigin: 'calendar_schedule_page.confirm_schedule',
      );
    } catch (error, stackTrace) {
      debugPrint('[CONFIRM_SCHEDULE_REFRESH_ERROR] error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!mounted) {
      return;
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Job added to calendar.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Future<VanJobActionResult?> _openJobFor(
    DriverCustomerReplyMockData job, {
    bool closeSheetOnDeleted = false,
  }) async {
    final result = await openDriverJobDetailMockPage(
      context,
      reply: DriverReplyMockState.instance.realReplyForJob(job.jobId) ?? job,
      completed: job.isCompleted,
      openedFromCalendar: true,
    );
    if (mounted) {
      setState(() {});
    }
    if (!mounted) {
      return result;
    }

    if (result == VanJobActionResult.deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (closeSheetOnDeleted) {
        Navigator.of(context).maybePop();
      }
    } else if (result == VanJobActionResult.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job marked completed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result == VanJobActionResult.updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return result;
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

  Map<DateTime, List<DriverCustomerReplyMockData>> _calendarJobsByDate() {
    _calendarMapBuildCount += 1;
    final storedJobsByDate = DriverReplyMockState.instance.bookedJobsByDate();
    final jobsByDate = <DateTime, List<DriverCustomerReplyMockData>>{
      for (final entry in storedJobsByDate.entries)
        entry.key: entry.value.toList(growable: true),
    };
    final projectedJobs = <String, DriverCustomerReplyMockData>{};
    for (final jobs in storedJobsByDate.values) {
      for (final job in jobs) {
        projectedJobs[job.jobId] = job;
      }
    }
    for (final job in projectedJobs.values) {
      for (final action in vanCalendarActionProjections(job)) {
        final date = DateUtils.dateOnly(action.start);
        final jobs = jobsByDate.putIfAbsent(
          date,
          () => <DriverCustomerReplyMockData>[],
        );
        if (!jobs.any((candidate) => candidate.jobId == job.jobId)) {
          jobs.add(job);
        }
      }
    }
    debugPrint(
      '[CalendarSchedulePage] calendarJobsByDate build=$_calendarMapBuildCount '
      'days=${jobsByDate.length} watchers=${DriverReplyMockState.instance.activeRequestWatchCount} '
      'requests=${DriverReplyMockState.instance.jobRequestCount} '
      'isHydrating=${DriverReplyMockState.instance.isHydratingCloudForDebug}',
    );
    return jobsByDate;
  }

  DateTime _jobSortDate(DriverCustomerReplyMockData job) {
    return job.scheduledAtOrParsed ??
        job.updatedAt ??
        job.completedAt ??
        job.quoteSentAt ??
        job.quoteSavedAt ??
        job.replyReceivedAt ??
        job.requestSentAt ??
        job.draftSavedAt ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<DriverCustomerReplyMockData> _calendarJobsForDate(
    DateTime date, {
    Map<DateTime, List<DriverCustomerReplyMockData>>? jobsByDate,
  }) {
    final jobs =
        (jobsByDate ?? _calendarJobsByDate())[DateUtils.dateOnly(date)] ??
        const <DriverCustomerReplyMockData>[];
    return jobs.toList(growable: false);
  }

  List<_ScheduleJobData> _selectedDayScheduleJobs() {
    final jobs = _calendarJobsForDate(_selectedDate).toList(growable: true);
    jobs.sort((a, b) {
      final aCompleted = a.isCompleted;
      final bCompleted = b.isCompleted;
      if (aCompleted != bCompleted) {
        return aCompleted ? 1 : -1;
      }
      return _jobSortDate(b).compareTo(_jobSortDate(a));
    });
    return jobs.map(_buildScheduleJobData).toList(growable: false);
  }

  DateTime _monthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  List<DateTime> _monthGridDates(DateTime month) {
    final monthStart = _monthStart(month);
    final gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday - DateTime.monday),
    );
    return List<DateTime>.generate(42, (index) {
      return DateUtils.dateOnly(gridStart.add(Duration(days: index)));
    });
  }

  String _monthTitle(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _calendarSelectedTitle(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(date);
    if (DateUtils.isSameDay(selected, today)) {
      return 'Today';
    }
    return _formatScheduleDate(selected);
  }

  String _calendarSelectedSubtitle(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(date);
    if (DateUtils.isSameDay(selected, today)) {
      return _formatScheduleDate(selected);
    }
    return '';
  }

  List<int> _dayScheduleHoursForEntries(
    List<_DayScheduleEntry> entries, {
    bool showAllOvernightHours = false,
  }) {
    final minHour = entries.isEmpty
        ? _defaultScheduleStartHour
        : entries
              .map((entry) => entry.displayStartHour)
              .reduce((value, element) => value < element ? value : element);
    final maxHour = entries.isEmpty
        ? _defaultScheduleEndHour
        : entries
              .map((entry) => entry.displayEndHour)
              .reduce((value, element) => value > element ? value : element);

    final startHour = showAllOvernightHours
        ? _fullScheduleStartHour
        : (minHour < _defaultScheduleStartHour
              ? minHour
              : _defaultScheduleStartHour);
    final endHour = showAllOvernightHours
        ? _fullScheduleEndHour
        : (maxHour > _defaultScheduleEndHour
              ? maxHour
              : _defaultScheduleEndHour);

    return List<int>.generate(
      (endHour - startHour) + 1,
      (index) => startHour + index,
    );
  }

  List<_DayScheduleEntry> _dayScheduleEntriesForJobs(
    List<DriverCustomerReplyMockData> jobs, {
    required DateTime selectedDate,
  }) {
    final entries = jobs
        .expand(
          (job) =>
              _buildDayScheduleEntriesForJob(job, selectedDate: selectedDate),
        )
        .toList(growable: true);
    entries.sort((a, b) => a.start.compareTo(b.start));
    return entries;
  }

  List<_DayScheduleEntry> _buildDayScheduleEntriesForJob(
    DriverCustomerReplyMockData job, {
    required DateTime selectedDate,
  }) {
    final actions = vanCalendarActionProjections(job);
    if (actions.isEmpty) {
      final entry = _buildDayScheduleEntry(job, selectedDate: selectedDate);
      return entry == null
          ? const <_DayScheduleEntry>[]
          : <_DayScheduleEntry>[entry];
    }
    return actions
        .where((action) => DateUtils.isSameDay(action.start, selectedDate))
        .map(
          (action) => _buildDayScheduleEntry(
            job,
            selectedDate: selectedDate,
            action: action,
          ),
        )
        .whereType<_DayScheduleEntry>()
        .toList(growable: false);
  }

  List<_DayScheduleEntry> _dayScheduleEntriesForDate(
    DateTime date, {
    Map<DateTime, List<DriverCustomerReplyMockData>>? jobsByDate,
  }) {
    final jobs = _calendarJobsForDate(date, jobsByDate: jobsByDate);
    return _dayScheduleEntriesForJobs(
      jobs,
      selectedDate: DateUtils.dateOnly(date),
    );
  }

  _DayScheduleEntry? _buildDayScheduleEntry(
    DriverCustomerReplyMockData job, {
    required DateTime selectedDate,
    VanCalendarActionProjection? action,
  }) {
    try {
      final slot = job.bookedCalendarSlot;
      final scheduledAt =
          action?.start ??
          slot?.start ??
          job.scheduledAtOrParsed ??
          _fallbackTimelineDateTime(job, selectedDate);
      final durationMinutes = _sanitizedTimelineDurationMinutes(
        action == null
            ? slot?.durationMinutes ??
                  job.effectiveCalendarDurationMinutes ??
                  60
            : 60,
      );
      final status = _scheduleJobStatusForJob(job);
      final startHour = _safeTimelineHour(scheduledAt.hour);
      final startMinute = _safeTimelineMinute(scheduledAt.minute);
      final endHour = action == null
          ? _timelineEndHour(
              start: scheduledAt,
              durationMinutes: durationMinutes,
            )
          : startHour;
      final heightFactor = _sanitizedTimelineHeightFactor(
        action == null ? _durationHeightFactor(durationMinutes) : 1.5,
      );
      final computedCardHeight = _timelineCardHeight(heightFactor);
      final topOffsetFraction = _timelineTopOffsetFraction(startMinute);
      _logTimelineEntryComputed(
        selectedDate: selectedDate,
        hourSlot: startHour,
        job: job,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        topOffsetFraction: topOffsetFraction,
        computedCardHeight: computedCardHeight,
        fallbackPlacement: slot == null,
      );
      return _DayScheduleEntry(
        job: job,
        start: scheduledAt,
        durationMinutes: durationMinutes,
        startLabel: _timelineStartLabel(job, scheduledAt),
        durationLabel: action == null || action.showBookingDuration
            ? _formatDurationLabel(durationMinutes, start: scheduledAt)
            : '',
        actionLabel: action?.label ?? '',
        actionIcon: action?.icon,
        actionAddress: action?.address ?? '',
        statusLabel: _timelineStatusLabel(job),
        status: status,
        accent: vanCalendarAccentForJob(job),
        customerName: _safeTimelineCustomerName(job),
        jobTitle: action == null
            ? vanCalendarDisplayJobTitle(job)
            : _safeDaySheetTitle(job),
        heightFactor: heightFactor,
        displayStartHour: startHour,
        displayEndHour: endHour,
        startMinute: startMinute,
        topOffsetFraction: topOffsetFraction,
        computedCardHeight: computedCardHeight,
        usedFallbackPlacement: slot == null,
      );
    } catch (_) {
      final fallbackAt =
          job.bookedCalendarSlot?.start ??
          job.scheduledAtOrParsed ??
          _fallbackTimelineDateTime(job, selectedDate);
      final fallbackStatus = _scheduleJobStatusForJob(job);
      final fallbackHour = _safeTimelineHour(fallbackAt.hour);
      final fallbackMinute = _safeTimelineMinute(fallbackAt.minute);
      final fallbackHeightFactor = _sanitizedTimelineHeightFactor(1.0);
      final fallbackCardHeight = _timelineCardHeight(fallbackHeightFactor);
      final fallbackTopOffset = _timelineTopOffsetFraction(fallbackMinute);
      _logTimelineEntryComputed(
        selectedDate: selectedDate,
        hourSlot: fallbackHour,
        job: job,
        scheduledAt: fallbackAt,
        durationMinutes: 60,
        topOffsetFraction: fallbackTopOffset,
        computedCardHeight: fallbackCardHeight,
        fallbackPlacement: true,
      );
      return _DayScheduleEntry(
        job: job,
        start: fallbackAt,
        durationMinutes: 60,
        startLabel: _timelineFallbackDateTimeLabel(job, fallbackAt),
        durationLabel: _formatDurationLabel(60, start: fallbackAt),
        actionLabel: '',
        statusLabel: 'Scheduled',
        status: fallbackStatus,
        accent: vanCalendarAccentForJob(job),
        customerName: _safeTimelineCustomerName(job),
        jobTitle: vanCalendarDisplayJobTitle(job),
        heightFactor: fallbackHeightFactor,
        displayStartHour: fallbackHour,
        displayEndHour: fallbackHour,
        startMinute: fallbackMinute,
        topOffsetFraction: fallbackTopOffset,
        computedCardHeight: fallbackCardHeight,
        usedFallbackPlacement: true,
      );
    }
  }

  String _formatDurationLabel(int? minutes, {required DateTime start}) {
    if (minutes == null || minutes <= 0) {
      return '';
    }
    final end = start.add(Duration(minutes: minutes));
    final crossesMidnight = !DateUtils.isSameDay(start, end);
    if (crossesMidnight) {
      return '${_formatTimelineTime(start)} - ${_formatTimelineTime(end)} overnight';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    }
    return '${minutes}m';
  }

  double _durationHeightFactor(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return 1.0;
    }
    return (minutes / 60).clamp(1.0, 3.0);
  }

  double _sanitizedTimelineHeightFactor(double value) {
    if (!value.isFinite || value <= 0) {
      return 1.0;
    }
    return value.clamp(1.0, 3.0).toDouble();
  }

  double _timelineCardHeight(double heightFactor) {
    final height = 68.0 * _sanitizedTimelineHeightFactor(heightFactor);
    if (!height.isFinite || height <= 0) {
      return 68.0;
    }
    return height.clamp(68.0, 204.0).toDouble();
  }

  int? _sanitizedTimelineDurationMinutes(int? minutes) {
    if (minutes == null) {
      return null;
    }
    if (minutes <= 0) {
      return null;
    }
    return minutes.clamp(15, 24 * 60).toInt();
  }

  int _safeTimelineHour(int hour) {
    return hour.clamp(_fullScheduleStartHour, _fullScheduleEndHour).toInt();
  }

  DateTime _fallbackTimelineDateTime(
    DriverCustomerReplyMockData job,
    DateTime selectedDate,
  ) {
    final parsedTime = _tryParseTimelineTime(job.scheduledStartTime);
    final baseDate = DateUtils.dateOnly(selectedDate);
    if (parsedTime == null) {
      return baseDate.add(const Duration(hours: 9));
    }
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  TimeOfDay? _tryParseTimelineTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _safeTimelineMinute(int minute) {
    return minute.clamp(0, 59).toInt();
  }

  double _timelineTopOffsetFraction(int minute) {
    final safeMinute = _safeTimelineMinute(minute);
    final fraction = safeMinute / 60.0;
    if (!fraction.isFinite || fraction < 0) {
      return 0.0;
    }
    return fraction.clamp(0.0, 0.98).toDouble();
  }

  int _timelineEndHour({
    required DateTime start,
    required int? durationMinutes,
  }) {
    if (durationMinutes == null) {
      return _safeTimelineHour(start.hour);
    }
    final end = start.add(Duration(minutes: durationMinutes));
    if (!DateUtils.isSameDay(start, end)) {
      return _fullScheduleEndHour;
    }
    if (end.minute == 0 && end.hour > start.hour) {
      return _safeTimelineHour(end.hour - 1);
    }
    return _safeTimelineHour(end.hour);
  }

  String _safeTimelineCustomerName(DriverCustomerReplyMockData job) {
    final customerName = job.customerName.trim();
    if (customerName.isNotEmpty) {
      return customerName;
    }
    final jobTitle = job.jobTitle.trim();
    if (jobTitle.isNotEmpty) {
      return jobTitle;
    }
    return 'Booked job';
  }

  String _safeTimelineJobTitle(DriverCustomerReplyMockData job) {
    final jobTitle = job.jobTitle.trim();
    if (jobTitle.isNotEmpty) {
      return jobTitle;
    }
    final customerName = job.customerName.trim();
    if (customerName.isNotEmpty) {
      return customerName;
    }
    return 'Booked job';
  }

  String _timelineStartLabel(
    DriverCustomerReplyMockData job,
    DateTime scheduledAt,
  ) {
    final text = _jobTimeTextForSchedule(job).trim();
    if (text.isNotEmpty && text != 'Time not set') {
      return text;
    }
    return _formatTimelineTime(scheduledAt);
  }

  String _timelineFallbackDateTimeLabel(
    DriverCustomerReplyMockData job,
    DateTime scheduledAt,
  ) {
    final dateLabel = job.jobDateLabel.trim().isNotEmpty
        ? job.jobDateLabel.trim()
        : _formatScheduleDate(DateUtils.dateOnly(scheduledAt));
    final timeLabel = job.jobTimeLabel.trim().isNotEmpty
        ? job.jobTimeLabel.trim()
        : _formatTimelineTime(scheduledAt);
    return '$dateLabel $timeLabel'.trim();
  }

  String _formatTimelineTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _timelineStatusLabel(DriverCustomerReplyMockData job) {
    if (job.isCompleted) {
      return 'Completed';
    }
    if (job.isConfirmed) {
      return 'Confirmed';
    }
    return 'Scheduled';
  }

  String _hourSlotLabel(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  void _logTimelineEntryComputed({
    required DateTime selectedDate,
    required int hourSlot,
    required DriverCustomerReplyMockData job,
    required DateTime scheduledAt,
    required int? durationMinutes,
    required double topOffsetFraction,
    required double computedCardHeight,
    required bool fallbackPlacement,
  }) {
    assert(() {
      debugPrint(
        '[TimelineEntryComputed] selectedDate=${DateUtils.dateOnly(selectedDate).toIso8601String()} '
        'hourSlot=${_hourSlotLabel(hourSlot)} '
        'jobDocId=${job.jobId} '
        'scheduledStartTime=${job.scheduledStartTime} '
        'scheduledAt=${scheduledAt.toIso8601String()} '
        'duration=${durationMinutes ?? '(none)'} '
        'topFraction=${topOffsetFraction.toStringAsFixed(3)} '
        'height=${computedCardHeight.toStringAsFixed(1)} '
        'fallbackPlacement=$fallbackPlacement',
      );
      return true;
    }());
  }

  void _logTimelineSlotRender({
    required DateTime selectedDate,
    required int hourSlot,
    required List<_DayScheduleEntry> entries,
  }) {
    assert(() {
      debugPrint(
        '[TimelineSlotRender] selectedDate=${DateUtils.dateOnly(selectedDate).toIso8601String()} '
        'hourSlot=${_hourSlotLabel(hourSlot)} '
        'entries=${entries.length}',
      );
      return true;
    }());
  }

  void _logTimelineCardRender({
    required DateTime selectedDate,
    required int hourSlot,
    required _DayScheduleEntry entry,
  }) {
    assert(() {
      debugPrint(
        '[TimelineCardRender] selectedDate=${DateUtils.dateOnly(selectedDate).toIso8601String()} '
        'hourSlot=${_hourSlotLabel(hourSlot)} '
        'jobDocId=${entry.job.jobId} '
        'scheduledStartTime=${entry.job.scheduledStartTime} '
        'duration=${entry.durationMinutes ?? '(none)'} '
        'topFraction=${entry.topOffsetFraction.toStringAsFixed(3)} '
        'height=${entry.computedCardHeight.toStringAsFixed(1)} '
        'fallbackPlacement=${entry.usedFallbackPlacement}',
      );
      return true;
    }());
  }

  List<_DaySheetJobCardData> _buildSafeDaySheetCards(
    List<DriverCustomerReplyMockData> jobs, {
    required DateTime selectedDate,
  }) {
    final cards = jobs
        .expand((job) {
          final projectedActions = vanCalendarActionProjections(job);
          if (projectedActions.isEmpty) {
            return <_DaySheetJobCardData>[
              _buildSafeDaySheetCard(job, selectedDate: selectedDate),
            ];
          }
          return projectedActions
              .where(
                (action) => DateUtils.isSameDay(action.start, selectedDate),
              )
              .map(
                (action) => _buildSafeDaySheetCard(
                  job,
                  selectedDate: selectedDate,
                  action: action,
                ),
              );
        })
        .toList(growable: false);
    cards.sort((a, b) {
      final hourCompare = a.displayHour.compareTo(b.displayHour);
      if (hourCompare != 0) {
        return hourCompare;
      }
      final minuteCompare = a.displayMinute.compareTo(b.displayMinute);
      if (minuteCompare != 0) {
        return minuteCompare;
      }
      return a.job.jobId.compareTo(b.job.jobId);
    });
    return cards;
  }

  _DaySheetJobCardData _buildSafeDaySheetCard(
    DriverCustomerReplyMockData job, {
    required DateTime selectedDate,
    VanCalendarActionProjection? action,
  }) {
    try {
      final selectedDay = DateUtils.dateOnly(selectedDate);
      final slot = job.bookedCalendarSlot;
      final resolvedStart = slot?.start ?? job.scheduledAtOrParsed;
      final fallbackStart = _fallbackTimelineDateTime(job, selectedDay);
      final displayStart = action?.start ?? resolvedStart ?? fallbackStart;
      final hasParsedTime =
          action != null ||
          resolvedStart != null ||
          _tryParseTimelineTime(job.scheduledStartTime) != null;
      final displayHour = _safeTimelineHour(displayStart.hour);
      final displayMinute = _safeTimelineMinute(displayStart.minute);
      final rawDurationMinutes = action == null
          ? _sanitizedTimelineDurationMinutes(
              job.effectiveCalendarDurationMinutes,
            )
          : null;
      final placementDurationMinutes = action == null
          ? _sanitizedTimelineDurationMinutes(
                  slot?.durationMinutes ?? job.effectiveCalendarDurationMinutes,
                ) ??
                60
          : action.visualOccupancyMinutes;
      final timeLabel = hasParsedTime
          ? _formatTimelineTime(displayStart)
          : 'Time not set';
      final title = _safeDaySheetTitle(job);
      final customer = _safeDaySheetCustomer(job);
      final projectedAddress = action?.address.trim() ?? '';
      final address = projectedAddress.isNotEmpty
          ? projectedAddress
          : _safeDaySheetAddress(job);
      final status = _scheduleJobStatusForJob(job);
      final occupiedUntilLabel = _daySheetOccupiedUntilLabelForRange(
        displayStart,
        placementDurationMinutes,
      );
      final statusPills = buildVanCompletedJobStatusPills(job);
      final card = _DaySheetJobCardData(
        job: job,
        displayStart: displayStart,
        displayHour: displayHour,
        displayMinute: displayMinute,
        timeLabel: timeLabel,
        title: title,
        customer: customer,
        durationLabel: rawDurationMinutes == null
            ? ''
            : _formatDurationLabel(rawDurationMinutes, start: displayStart),
        actionLabel: action?.label ?? '',
        actionIcon: action?.icon,
        addressLabel: address,
        statusLabel: _timelineStatusLabel(job),
        status: status,
        accent: vanCalendarAccentForJob(job),
        statusPills: statusPills,
        placementDurationMinutes: placementDurationMinutes,
        occupiedUntilLabel: occupiedUntilLabel,
        usedFallbackTime: !hasParsedTime,
      );
      _logDaySheetCardPrepared(selectedDate: selectedDay, card: card);
      return card;
    } catch (error, stackTrace) {
      final selectedDay = DateUtils.dateOnly(selectedDate);
      final fallbackStart = selectedDay.add(
        const Duration(hours: _defaultScheduleStartHour),
      );
      debugPrint(
        '[DaySheetCardParseError] selectedDate=${selectedDay.toIso8601String()} '
        'jobDocId=${job.jobId} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      final status = _scheduleJobStatusForJob(job);
      final occupiedUntilLabel = _daySheetOccupiedUntilLabelForRange(
        fallbackStart,
        60,
      );
      final fallbackCard = _DaySheetJobCardData(
        job: job,
        displayStart: fallbackStart,
        displayHour: _defaultScheduleStartHour,
        displayMinute: 0,
        timeLabel: 'Time not set',
        title: _safeDaySheetTitle(job),
        customer: _safeDaySheetCustomer(job),
        durationLabel: '',
        actionLabel: '',
        addressLabel: _safeDaySheetAddress(job),
        statusLabel: _timelineStatusLabel(job),
        status: status,
        accent: vanCalendarAccentForJob(job),
        statusPills: buildVanCompletedJobStatusPills(job),
        placementDurationMinutes: 60,
        occupiedUntilLabel: occupiedUntilLabel,
        usedFallbackTime: true,
      );
      _logDaySheetCardPrepared(selectedDate: selectedDay, card: fallbackCard);
      return fallbackCard;
    }
  }

  List<int> _daySheetHourSlotsForCards(
    List<_DaySheetJobCardData> cards, {
    bool showAllOvernightHours = false,
  }) {
    final minHour = cards.isEmpty
        ? _defaultScheduleStartHour
        : cards
              .map((card) => card.displayHour)
              .reduce((value, element) => value < element ? value : element);
    final maxHour = cards.isEmpty
        ? _defaultScheduleEndHour
        : cards
              .map(_daySheetCardEndDisplayHour)
              .reduce((value, element) => value > element ? value : element);
    final startHour = showAllOvernightHours
        ? _fullScheduleStartHour
        : (minHour < _defaultScheduleStartHour
              ? minHour
              : _defaultScheduleStartHour);
    final endHour = showAllOvernightHours
        ? _fullScheduleEndHour
        : (maxHour > _defaultScheduleEndHour
              ? maxHour
              : _defaultScheduleEndHour);
    return List<int>.generate(
      (endHour - startHour) + 1,
      (index) => startHour + index,
    );
  }

  int _daySheetCardEndDisplayHour(_DaySheetJobCardData card) {
    return _timelineEndHour(
      start: card.displayStart,
      durationMinutes: card.placementDurationMinutes,
    );
  }

  bool _daySheetCardOccupiesHour(_DaySheetJobCardData card, int hourSlot) {
    final endHour = _daySheetCardEndDisplayHour(card);
    return hourSlot >= card.displayHour && hourSlot <= endHour;
  }

  String _daySheetOccupiedUntilLabel(_DaySheetJobCardData card) {
    return _daySheetOccupiedUntilLabelForRange(
      card.displayStart,
      card.placementDurationMinutes,
    );
  }

  String _daySheetOccupiedUntilLabelForRange(
    DateTime start,
    int durationMinutes,
  ) {
    final end = start.add(Duration(minutes: durationMinutes));
    if (!DateUtils.isSameDay(start, end)) {
      return 'Occupied overnight';
    }
    return 'Occupied until ${_formatTimelineTime(end)}';
  }

  String _safeDaySheetTitle(DriverCustomerReplyMockData job) {
    final title = job.jobTitle.trim();
    return title.isNotEmpty ? title : 'Job';
  }

  String _safeDaySheetCustomer(DriverCustomerReplyMockData job) {
    final customer = job.customerName.trim();
    return customer.isNotEmpty ? customer : 'Customer';
  }

  String _safeDaySheetAddress(DriverCustomerReplyMockData job) {
    final parts = <String>[
      job.address.trim(),
      job.postcode.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return parts.join(' - ');
  }

  void _logDaySheetCardPrepared({
    required DateTime selectedDate,
    required _DaySheetJobCardData card,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[DaySheetCardPrepared] selectedDate=${selectedDate.toIso8601String()} '
      'hourSlot=${_hourSlotLabel(card.displayHour)} '
      'jobDocId=${card.job.jobId} '
      'scheduledStartTime=${card.job.scheduledStartTime} '
      'duration=${card.job.estimatedDurationMinutes ?? '(missing)'} '
      'position=in-hour '
      'height=auto '
      'timeLabel=${card.timeLabel} '
      'fallbackTime=${card.usedFallbackTime}',
    );
  }

  void _logDaySheetHourRender({
    required DateTime selectedDate,
    required int hourSlot,
    required List<_DaySheetJobCardData> cards,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[DaySheetHourRender] selectedDate=${selectedDate.toIso8601String()} '
      'hourSlot=${_hourSlotLabel(hourSlot)} '
      'entries=${cards.length}',
    );
  }

  void _logDaySheetCardRender({
    required DateTime selectedDate,
    required int hourSlot,
    required _DaySheetJobCardData card,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[DaySheetCardRender] selectedDate=${selectedDate.toIso8601String()} '
      'hourSlot=${_hourSlotLabel(hourSlot)} '
      'jobDocId=${card.job.jobId} '
      'scheduledStartTime=${card.job.scheduledStartTime} '
      'duration=${card.job.estimatedDurationMinutes ?? '(missing)'} '
      'position=in-hour '
      'height=auto '
      'timeLabel=${card.timeLabel} '
      'fallbackTime=${card.usedFallbackTime}',
    );
  }

  void _setCalendarMonth(DateTime month) {
    setState(() {
      _focusedMonth = _monthStart(month);
    });
  }

  void _selectCalendarDate(DateTime date) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
      _focusedMonth = _monthStart(date);
    });
  }

  Future<void> _openDateJobsSheet(
    DateTime date, {
    List<DriverCustomerReplyMockData>? bookedJobs,
  }) async {
    final selectedDate = DateUtils.dateOnly(date);
    final selectedDayJobs = (bookedJobs ?? _calendarJobsForDate(selectedDate))
        .toList(growable: false);
    debugPrint(
      '[CalendarDaySheet] open selectedDate=${selectedDate.toIso8601String()} '
      'jobs=${selectedDayJobs.length} watchers=${DriverReplyMockState.instance.activeRequestWatchCount} '
      'requests=${DriverReplyMockState.instance.jobRequestCount} '
      'isHydrating=${DriverReplyMockState.instance.isHydratingCloudForDebug}',
    );
    final dayCards = _buildSafeDaySheetCards(
      selectedDayJobs,
      selectedDate: selectedDate,
    );
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var modalBuildCount = 0;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              minChildSize: 0.42,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                debugPrint(
                  '[CalendarDaySheet] draggableSheetBuild selectedDate=${selectedDate.toIso8601String()} '
                  'watchers=${DriverReplyMockState.instance.activeRequestWatchCount} '
                  'requests=${DriverReplyMockState.instance.jobRequestCount} '
                  'isHydrating=${DriverReplyMockState.instance.isHydratingCloudForDebug}',
                );
                var showAllOvernightHours = false;
                return StatefulBuilder(
                  builder: (context, setSheetState) {
                    modalBuildCount += 1;
                    final slotHours = _daySheetHourSlotsForCards(
                      dayCards,
                      showAllOvernightHours: showAllOvernightHours,
                    );
                    debugPrint(
                      '[CalendarDaySheet] statefulBuild count=$modalBuildCount '
                      'selectedDate=${selectedDate.toIso8601String()} '
                      'slotHours=${slotHours.length} jobs=${selectedDayJobs.length} '
                      'watchers=${DriverReplyMockState.instance.activeRequestWatchCount} '
                      'requests=${DriverReplyMockState.instance.jobRequestCount} '
                      'isHydrating=${DriverReplyMockState.instance.isHydratingCloudForDebug}',
                    );

                    return _GlassPanel(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jobs for ${_calendarSelectedTitle(selectedDate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    if (_calendarSelectedSubtitle(
                                      selectedDate,
                                    ).trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _calendarSelectedSubtitle(selectedDate),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.66,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                                color: Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: selectedDayJobs.isEmpty
                                ? const _ScheduleEmptyJobsCard()
                                : ListView.separated(
                                    controller: scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: slotHours.length,
                                    separatorBuilder: (context, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final hour = slotHours[index];
                                      final slotCards = dayCards
                                          .where(
                                            (card) => card.displayHour == hour,
                                          )
                                          .toList(growable: false);
                                      final occupiedCards = dayCards
                                          .where(
                                            (card) =>
                                                card.displayHour != hour &&
                                                _daySheetCardOccupiesHour(
                                                  card,
                                                  hour,
                                                ),
                                          )
                                          .toList(growable: false);
                                      _logDaySheetHourRender(
                                        selectedDate: selectedDate,
                                        hourSlot: hour,
                                        cards: <_DaySheetJobCardData>[
                                          ...slotCards,
                                          ...occupiedCards,
                                        ],
                                      );
                                      for (final card in slotCards) {
                                        _logDaySheetCardRender(
                                          selectedDate: selectedDate,
                                          hourSlot: hour,
                                          card: card,
                                        );
                                      }
                                      return _DaySheetHourRow(
                                        hourLabel: _hourSlotLabel(hour),
                                        cards: slotCards,
                                        occupiedCards: occupiedCards,
                                        onOpenJob: (job) async {
                                          await _openJobFor(
                                            job,
                                            closeSheetOnDeleted: true,
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                          if (!showAllOvernightHours) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: () {
                                  setSheetState(() {
                                    showAllOvernightHours = true;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: 0.84,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Show overnight hours'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
    debugPrint(
      '[CalendarDaySheet] closed selectedDate=${selectedDate.toIso8601String()}',
    );
  }

  void _moveCalendarMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + offset,
        1,
      );
      _selectedDate = DateUtils.dateOnly(
        DateTime(_focusedMonth.year, _focusedMonth.month, 1),
      );
    });
  }

  Widget _buildCalendarMonthPanel(BuildContext context) {
    final month = _monthStart(_focusedMonth);
    final days = _monthGridDates(month);
    final calendarJobsByDate = _calendarJobsByDate();

    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _monthTitle(month),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _moveCalendarMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton(
                    onPressed: () {
                      final today = DateUtils.dateOnly(DateTime.now());
                      _setCalendarMonth(today);
                      _selectCalendarDate(today);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Today'),
                  ),
                  IconButton(
                    onPressed: () => _moveCalendarMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(child: _CalendarWeekdayLabel(label: 'Mon')),
                  Expanded(child: _CalendarWeekdayLabel(label: 'Tue')),
                  Expanded(child: _CalendarWeekdayLabel(label: 'Wed')),
                  Expanded(child: _CalendarWeekdayLabel(label: 'Thu')),
                  Expanded(child: _CalendarWeekdayLabel(label: 'Fri')),
                  Expanded(child: _CalendarWeekdayLabel(label: 'Sat')),
                  Expanded(child: _CalendarWeekdayLabel(label: 'Sun')),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, gridConstraints) {
                    final rowHeight =
                        ((gridConstraints.maxHeight - (4.0 * 5)) / 6)
                            .clamp(0.0, double.infinity)
                            .toDouble();

                    return GridView.builder(
                      shrinkWrap: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: days.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        mainAxisExtent: rowHeight,
                      ),
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final jobs =
                            calendarJobsByDate[day] ??
                            const <DriverCustomerReplyMockData>[];
                        final inMonth =
                            day.month == month.month && day.year == month.year;
                        final selected = DateUtils.isSameDay(
                          day,
                          _selectedDate,
                        );
                        final today = DateUtils.isSameDay(day, DateTime.now());
                        final state = jobs.isEmpty
                            ? _ScheduleDayState.empty
                            : _scheduleStateForJobs(jobs);
                        final accent = today
                            ? const Color(0xFF4A7DFF)
                            : _scheduleAccentForState(state);

                        return _CalendarMonthDayCell(
                          dayNumber: day.day.toString(),
                          jobCount: jobs.length,
                          selected: selected,
                          today: today,
                          inMonth: inMonth,
                          accent: accent,
                          onTap: () {
                            _selectCalendarDate(day);
                            unawaited(
                              _openDateJobsSheet(day, bookedJobs: jobs),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _pageBuildCount += 1;
    debugPrint(
      '[CalendarSchedulePage] build count=$_pageBuildCount '
      'selectedDate=${_selectedDate.toIso8601String()} '
      'watchers=${DriverReplyMockState.instance.activeRequestWatchCount} '
      'requests=${DriverReplyMockState.instance.jobRequestCount} '
      'isHydrating=${DriverReplyMockState.instance.isHydratingCloudForDebug}',
    );
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScheduleBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Calendar',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _buildCalendarMonthPanel(context)),
                    ],
                  ),
                ),
              ),
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
    return VanBackBusinessHubButtons(onBack: onTap);
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

class _CalendarWeekdayLabel extends StatelessWidget {
  const _CalendarWeekdayLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 10.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarMonthDayCell extends StatelessWidget {
  const _CalendarMonthDayCell({
    required this.dayNumber,
    required this.jobCount,
    required this.selected,
    required this.today,
    required this.inMonth,
    required this.accent,
    required this.onTap,
  });

  final String dayNumber;
  final int jobCount;
  final bool selected;
  final bool today;
  final bool inMonth;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = selected || today;
    final background = highlight
        ? accent.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: inMonth ? 0.10 : 0.06);
    final borderColor = highlight
        ? accent.withValues(alpha: 0.40)
        : Colors.white.withValues(alpha: inMonth ? 0.12 : 0.07);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: background,
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: inMonth ? 1 : 0.62),
                  fontSize: 13.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (jobCount > 0)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: accent.withValues(alpha: 0.18),
                      border: Border.all(color: accent.withValues(alpha: 0.26)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        jobCount > 3 ? '3+' : '$jobCount',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontSize: 8.4,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
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
              if (isToday) ...[
                Text(
                  day.dateLabel,
                  style: TextStyle(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: muted ? 0.52 : 0.74),
                  ),
                ),
              ],
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
            'No jobs for this day.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select another date to review its jobs.',
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

class _DayScheduleHourRow extends StatelessWidget {
  const _DayScheduleHourRow({
    required this.hourLabel,
    required this.entries,
    required this.onOpenJob,
  });

  final String hourLabel;
  final List<_DayScheduleEntry> entries;
  final ValueChanged<DriverCustomerReplyMockData> onOpenJob;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              hourLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: entries.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Free',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.32),
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < entries.length; index++) ...[
                        _DayScheduleJobCard(
                          key: ValueKey<String>(
                            '${entries[index].job.jobId}:${entries[index].actionLabel}:${entries[index].start.toIso8601String()}',
                          ),
                          entry: entries[index],
                          onTap: () => onOpenJob(entries[index].job),
                        ),
                        if (index < entries.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _DayScheduleJobCard extends StatelessWidget {
  const _DayScheduleJobCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final _DayScheduleEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (entry.job.customerJourney == VanCustomerJourneyType.preOrder) {
      return VanPreOrderCalendarEntry(
        key: ValueKey<String>(
          'pre-order:${entry.job.jobId}:${entry.start.toIso8601String()}',
        ),
        timeLabel: entry.startLabel,
        customerName: entry.customerName,
        accent: entry.accent,
        onOpen: onTap,
      );
    }
    final cardHeight = entry.computedCardHeight;
    final isProjectedAction = entry.actionLabel.isNotEmpty;
    if (isProjectedAction) {
      return VanCalendarCompactActionCard(
        key: ValueKey<String>(
          '${entry.job.jobId}:${entry.actionLabel}:${entry.start.toIso8601String()}',
        ),
        cardId:
            '${entry.job.jobId}-${entry.actionLabel}-${entry.start.millisecondsSinceEpoch}',
        actionLabel: entry.actionLabel,
        actionIcon: entry.actionIcon,
        customerName: entry.customerName,
        accent: entry.accent,
        timeChip: _DayScheduleMetaChip(
          icon: Icons.schedule_rounded,
          label: entry.startLabel,
        ),
        statusChip: _ScheduleMiniChip(
          label: entry.statusLabel,
          accent: entry.accent,
          highlight: true,
          compact: true,
        ),
        expandedChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.jobTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (entry.job.hasServiceHandover)
              Text(
                entry.job.handoverSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            if (entry.actionAddress.trim().isNotEmpty)
              Text(
                entry.actionAddress.trim(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            if (entry.job.phoneNumber.trim().isNotEmpty)
              Text(
                entry.job.phoneNumber.trim(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            Text(
              'Parent job: ${entry.job.jobId}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
        onOpen: onTap,
      );
    }
    final showsMinutePlacementLabel =
        !isProjectedAction &&
        (entry.startMinute != 0 || entry.usedFallbackPlacement);
    final placementLabel = '${entry.startLabel} • ${entry.jobTitle}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: Container(
            constraints: BoxConstraints(minHeight: cardHeight),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  entry.accent.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: entry.accent.withValues(alpha: 0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: entry.accent,
                  ),
                  child: const SizedBox(width: 4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isProjectedAction) ...[
                                  Text(
                                    entry.actionLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: entry.accent,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Text(
                                  entry.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isProjectedAction
                                      ? entry.jobTitle
                                      : showsMinutePlacementLabel
                                      ? placementLabel
                                      : entry.jobTitle,
                                  maxLines: showsMinutePlacementLabel ? 3 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        height: 1.3,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ScheduleMiniChip(
                            label: entry.statusLabel,
                            accent: entry.accent,
                            highlight: true,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isProjectedAction || !showsMinutePlacementLabel)
                            _DayScheduleMetaChip(
                              icon: Icons.schedule_rounded,
                              label: entry.startLabel,
                            ),
                          if (entry.durationLabel.isNotEmpty)
                            _DayScheduleMetaChip(
                              icon: Icons.timelapse_outlined,
                              label: entry.durationLabel,
                            ),
                        ],
                      ),
                    ],
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

class _DayScheduleMetaChip extends StatelessWidget {
  const _DayScheduleMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.09),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.84)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 11.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySheetHourRow extends StatelessWidget {
  const _DaySheetHourRow({
    required this.hourLabel,
    required this.cards,
    required this.occupiedCards,
    required this.onOpenJob,
  });

  final String hourLabel;
  final List<_DaySheetJobCardData> cards;
  final List<_DaySheetJobCardData> occupiedCards;
  final ValueChanged<DriverCustomerReplyMockData> onOpenJob;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              hourLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: cards.isEmpty && occupiedCards.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Free',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.32),
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        _DaySheetJobCard(
                          key: ValueKey<String>(
                            '${cards[index].job.jobId}:${cards[index].actionLabel}:${cards[index].displayStart.toIso8601String()}',
                          ),
                          card: cards[index],
                          onTap: () => onOpenJob(cards[index].job),
                        ),
                        if (index < cards.length - 1) const SizedBox(height: 8),
                      ],
                      if (cards.isNotEmpty && occupiedCards.isNotEmpty)
                        const SizedBox(height: 8),
                      for (
                        var index = 0;
                        index < occupiedCards.length;
                        index++
                      ) ...[
                        _DaySheetOccupiedCard(card: occupiedCards[index]),
                        if (index < occupiedCards.length - 1)
                          const SizedBox(height: 6),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _DaySheetJobCard extends StatelessWidget {
  const _DaySheetJobCard({super.key, required this.card, required this.onTap});

  final _DaySheetJobCardData card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (card.job.customerJourney == VanCustomerJourneyType.preOrder) {
      return VanPreOrderCalendarEntry(
        key: ValueKey<String>(
          'pre-order:${card.job.jobId}:${card.displayStart.toIso8601String()}',
        ),
        timeLabel: card.timeLabel,
        customerName: card.customer,
        accent: card.accent,
        onOpen: onTap,
      );
    }
    if (card.actionLabel.isNotEmpty) {
      return VanCalendarCompactActionCard(
        key: ValueKey<String>(
          '${card.job.jobId}:${card.actionLabel}:${card.displayStart.toIso8601String()}',
        ),
        cardId:
            '${card.job.jobId}-${card.actionLabel}-${card.displayStart.millisecondsSinceEpoch}',
        actionLabel: card.actionLabel,
        actionIcon: card.actionIcon,
        customerName: card.customer,
        accent: card.accent,
        timeChip: _DayScheduleMetaChip(
          icon: Icons.schedule_rounded,
          label: card.timeLabel,
        ),
        statusChip: _ScheduleMiniChip(
          label: card.statusLabel,
          accent: card.accent,
          highlight: true,
          compact: true,
        ),
        expandedChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.84),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (card.job.hasServiceHandover)
              Text(
                card.job.handoverSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            if (card.addressLabel.trim().isNotEmpty)
              Text(
                card.addressLabel.trim(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            if (card.job.phoneNumber.trim().isNotEmpty)
              Text(
                card.job.phoneNumber.trim(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            Text(
              'Parent job: ${card.job.jobId}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            if (card.statusPills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final pill in card.statusPills)
                    _ScheduleMiniChip(
                      label: pill.label,
                      accent: pill.color,
                      highlight: pill.filled || pill.label == 'Paid',
                      compact: true,
                    ),
                ],
              ),
            ],
          ],
        ),
        onOpen: onTap,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  card.accent.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: card.accent.withValues(alpha: 0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: card.accent,
                    ),
                    child: const SizedBox(width: 4, height: 52),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (card.actionLabel.isNotEmpty) ...[
                        Text(
                          card.actionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: card.accent,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        card.customer,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DayScheduleMetaChip(
                            icon: Icons.schedule_rounded,
                            label: card.timeLabel,
                          ),
                          if (card.durationLabel.isNotEmpty)
                            _DayScheduleMetaChip(
                              icon: Icons.timelapse_outlined,
                              label: card.durationLabel,
                            ),
                          if (card.statusPills.isEmpty)
                            _ScheduleMiniChip(
                              label: card.statusLabel,
                              accent: card.accent,
                              highlight: true,
                              compact: true,
                            )
                          else
                            for (final pill in card.statusPills)
                              _ScheduleMiniChip(
                                label: pill.label,
                                accent: pill.color,
                                highlight: pill.filled || pill.label == 'Paid',
                                compact: true,
                              ),
                        ],
                      ),
                    ],
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

class _DaySheetOccupiedCard extends StatelessWidget {
  const _DaySheetOccupiedCard({required this.card});

  final _DaySheetJobCardData card;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        card.title.trim().isEmpty ||
            card.title.trim().toLowerCase() ==
                card.customer.trim().toLowerCase()
        ? card.customer
        : '${card.customer} • ${card.title}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.block_rounded,
            size: 15,
            color: Colors.white.withValues(alpha: 0.52),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Occupied',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.56),
                    height: 1.22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (card.statusPills.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final pill in card.statusPills)
                        _ScheduleMiniChip(
                          label: pill.label,
                          accent: pill.color,
                          highlight: pill.filled || pill.label == 'Paid',
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ],
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
                        if (job.statusPills.isEmpty)
                          _ScheduleMiniChip(
                            label: _jobStatusLabel(job.status),
                            accent: job.accent,
                            highlight: true,
                          ),
                      ],
                    ),
                    if (job.statusPills.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final pill in job.statusPills)
                            _ScheduleMiniChip(
                              label: pill.label,
                              accent: pill.color,
                              highlight: pill.filled || pill.label == 'Paid',
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                    if (job.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        job.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                    if (job.locationLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.68),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              job.locationLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.70),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (job.statusPills.isEmpty) ...[
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
                      if (job.exactPinLabel.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ScheduleMiniChip(
                          label: job.exactPinLabel,
                          accent: job.exactPinLabel == 'Exact pin shared'
                              ? const Color(0xFF58D0A4)
                              : const Color(0xFFFFC38C),
                          highlight: job.exactPinLabel == 'Exact pin shared',
                          compact: true,
                        ),
                      ],
                    ],
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
          Text(
            'source: ${job.debugSource.trim().isEmpty ? 'mock' : job.debugSource}  docId: ${job.debugDocId.trim().isEmpty ? '(none)' : job.debugDocId}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
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
    final actionAccent = action.accent ?? accent;
    final primaryNavigate = enabled && action.label == 'Navigate';
    final fillColor = primaryNavigate
        ? const Color(0xFF4A7DFF)
        : Colors.white.withValues(alpha: enabled ? 0.08 : 0.04);
    final borderColor = primaryNavigate
        ? const Color(0xFF4A7DFF)
        : enabled
        ? actionAccent.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.08);
    final contentColor = Colors.white.withValues(alpha: enabled ? 1 : 0.42);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: fillColor,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (action.icon != null) ...[
                Icon(
                  action.icon,
                  size: 16,
                  color: primaryNavigate
                      ? Colors.white
                      : Colors.white.withValues(alpha: enabled ? 0.92 : 0.42),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w800,
                  color: contentColor,
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
    this.subtitle = '',
    this.locationLabel = '',
    this.exactPinLabel = '',
    required this.timeLabel,
    required this.statusLabel,
    required this.status,
    required this.accent,
    required this.body,
    this.statusPills = const <VanCompletedJobStatusPillData>[],
    required this.actions,
    this.job,
    this.debugSource = '',
    this.debugDocId = '',
  });

  final String title;
  final String subtitle;
  final String locationLabel;
  final String exactPinLabel;
  final String timeLabel;
  final String statusLabel;
  final _ScheduleJobStatus status;
  final Color accent;
  final String body;
  final List<VanCompletedJobStatusPillData> statusPills;
  final List<_ScheduleActionData> actions;
  final DriverCustomerReplyMockData? job;
  final String debugSource;
  final String debugDocId;
}

class _DayScheduleEntry {
  const _DayScheduleEntry({
    required this.job,
    required this.start,
    required this.durationMinutes,
    required this.startLabel,
    required this.durationLabel,
    required this.actionLabel,
    this.actionIcon,
    this.actionAddress = '',
    required this.statusLabel,
    required this.status,
    required this.accent,
    required this.customerName,
    required this.jobTitle,
    required this.heightFactor,
    required this.displayStartHour,
    required this.displayEndHour,
    required this.startMinute,
    required this.topOffsetFraction,
    required this.computedCardHeight,
    required this.usedFallbackPlacement,
  });

  final DriverCustomerReplyMockData job;
  final DateTime start;
  final int? durationMinutes;
  final String startLabel;
  final String durationLabel;
  final String actionLabel;
  final IconData? actionIcon;
  final String actionAddress;
  final String statusLabel;
  final _ScheduleJobStatus status;
  final Color accent;
  final String customerName;
  final String jobTitle;
  final double heightFactor;
  final int displayStartHour;
  final int displayEndHour;
  final int startMinute;
  final double topOffsetFraction;
  final double computedCardHeight;
  final bool usedFallbackPlacement;
}

class _DaySheetJobCardData {
  const _DaySheetJobCardData({
    required this.job,
    required this.displayStart,
    required this.displayHour,
    required this.displayMinute,
    required this.timeLabel,
    required this.title,
    required this.customer,
    required this.durationLabel,
    required this.actionLabel,
    this.actionIcon,
    required this.addressLabel,
    required this.statusLabel,
    required this.status,
    required this.accent,
    this.statusPills = const <VanCompletedJobStatusPillData>[],
    required this.placementDurationMinutes,
    required this.occupiedUntilLabel,
    required this.usedFallbackTime,
  });

  final DriverCustomerReplyMockData job;
  final DateTime displayStart;
  final int displayHour;
  final int displayMinute;
  final String timeLabel;
  final String title;
  final String customer;
  final String durationLabel;
  final String actionLabel;
  final IconData? actionIcon;
  final String addressLabel;
  final String statusLabel;
  final _ScheduleJobStatus status;
  final Color accent;
  final List<VanCompletedJobStatusPillData> statusPills;
  final int placementDurationMinutes;
  final String occupiedUntilLabel;
  final bool usedFallbackTime;
}

class _ScheduleActionData {
  const _ScheduleActionData({
    required this.label,
    required this.enabled,
    this.icon,
    this.accent,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;
}

enum _ScheduleDayState { today, pending, ready, completed, empty, mixed }

enum _ScheduleJobStatus {
  pending,
  awaitingReply,
  quoteAccepted,
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
    case _ScheduleJobStatus.quoteAccepted:
      return 'Quote accepted';
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
    case _ScheduleJobStatus.quoteAccepted:
      return Icons.request_quote_outlined;
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
