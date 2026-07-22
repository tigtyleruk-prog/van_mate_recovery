import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_calendar_job_presentation.dart';
import '../helpers/van_block_customer_dialog.dart';
import '../models/van_invoice_draft.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_job_completion_actions.dart';
import '../helpers/van_job_request_state.dart';
import '../models/van_exact_pin_source.dart';
import '../models/van_customer_journey.dart';
import '../helpers/van_job_navigation.dart';
import '../helpers/van_quote_decline.dart';
import '../helpers/van_quote_ui_status.dart';
import '../helpers/van_status_tone.dart';
import '../models/van_job_request_record.dart';
import '../helpers/van_text_formatters.dart';
import '../services/van_business_profile_storage.dart';
import 'create_invoice_page.dart';
import 'driver_customer_reply_mock_page.dart';
import 'jobs_calendar_page.dart';
import 'van_invoice_preview_page.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_duration_picker_sheet.dart';

enum VanJobActionResult { updated, deleted, completed, cancelled, none }

enum _CompletedJobNextStep { createInvoice, stayHere, backToCalendar }

enum VanJobDetailOpenTarget {
  top,
  quoteSection,
  exactPinSection,
  actionsSection,
  setAgreedTimeFlow,
}

Future<VanJobActionResult?> openDriverJobDetailMockPage(
  BuildContext context, {
  required DriverCustomerReplyMockData reply,
  required bool completed,
  bool historyMode = false,
  bool openedFromCalendar = false,
  VanJobDetailOpenTarget initialTarget = VanJobDetailOpenTarget.top,
}) {
  return Navigator.of(context).push<VanJobActionResult>(
    MaterialPageRoute<VanJobActionResult>(
      builder: (_) => JobDetailPage(
        reply: reply,
        completed: completed,
        historyMode: historyMode,
        openedFromCalendar: openedFromCalendar,
        initialTarget: initialTarget,
      ),
    ),
  );
}

Future<DriverCustomerReplyMockData?> openDriverJobEditDetailsSheet(
  BuildContext context, {
  required DriverCustomerReplyMockData job,
}) {
  return showModalBottomSheet<DriverCustomerReplyMockData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditJobDetailsSheet(job: job),
  );
}

Future<bool> openDriverJobDateTimeChangeFlow(
  BuildContext context, {
  required DriverCustomerReplyMockData job,
}) async {
  final current = job.scheduledAtOrParsed ?? DateTime.now();
  final today = DateUtils.dateOnly(DateTime.now());
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: DateUtils.dateOnly(current).isBefore(today)
        ? today
        : DateUtils.dateOnly(current),
    firstDate: today,
    lastDate: DateTime(2035),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4A7DFF),
            surface: Color(0xFF101826),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF101826),
          ),
        ),
        child: child ?? const SizedBox(),
      );
    },
  );
  if (pickedDate == null || !context.mounted) {
    return false;
  }

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF101826),
          ),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4A7DFF),
            surface: Color(0xFF101826),
          ),
        ),
        child: child ?? const SizedBox(),
      );
    },
  );
  if (pickedTime == null || !context.mounted) {
    return false;
  }

  final scheduledAt = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
  final pastScheduleMessage = validateVanMateScheduledAt(scheduledAt);
  if (pastScheduleMessage != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pastScheduleMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
  final overlap = DriverReplyMockState.instance.findScheduleOverlap(
    ignoringJobId: job.jobId,
    scheduledAt: scheduledAt,
    estimatedDurationMinutes: job.estimatedDurationMinutes ?? 60,
  );
  if (overlap != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DriverReplyMockState.instance.formatScheduleOverlapMessage(overlap),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
  try {
    DriverReplyMockState.instance.updateJobDateTime(
      jobId: job.jobId,
      scheduledAt: scheduledAt,
    );
  } on VanScheduleOverlapException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  } on VanPastScheduleException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
  return true;
}

Future<bool?> confirmDriverJobDelete(
  BuildContext context, {
  required DriverCustomerReplyMockData job,
  bool refreshCloudAfterDelete = true,
}) async {
  debugPrint('DELETE JOB tapped');
  debugPrint(
    'DELETE JOB precheck uid=${DriverReplyMockState.instance.currentUidForDebug()}',
  );
  debugPrint('DELETE JOB jobId=${job.jobId}');
  debugPrint('DELETE JOB firestoreDocId=${job.jobId}');
  debugPrint('DELETE JOB requestId=${job.requestId ?? '(none)'}');

  final hasInvoice =
      DriverReplyMockState.instance.invoiceForJob(job.invoiceHistoryKey) !=
      null;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final contentLines = <String>[
        'This permanently removes the operational job, request, replies, quotes and linked job photos. Any invoice and financial records will be kept.',
      ];

      return AlertDialog(
        backgroundColor: const Color(0xFF142031),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete this job?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          contentLines.join('\n\n'),
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
            child: const Text('Keep job'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete job'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return null;
  }

  if (hasInvoice || job.isCompletedJob) {
    final finalConfirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF142031),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Permanently delete operational job?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This job is completed or invoiced. Its invoice, payments and financial records will remain independently available.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep job'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (finalConfirmation != true || !context.mounted) return null;
  }

  final deleted = await DriverReplyMockState.instance.deleteJob(
    jobId: job.jobId,
    refreshCloud: refreshCloudAfterDelete,
  );
  if (!deleted && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not delete job. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  return deleted;
}

enum _JobDetailOverflowAction {
  editDetails,
  changeDateTime,
  reviseQuote,
  copyQuoteMessage,
  copyQuoteLink,
  resendRequest,
  newRequest,
  cancelRequest,
  blockCustomer,
  unblockCustomer,
  cancelJob,
  deleteJob,
}

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({
    super.key,
    required this.reply,
    required this.completed,
    this.historyMode = false,
    this.openedFromCalendar = false,
    this.initialTarget = VanJobDetailOpenTarget.top,
  });

  final DriverCustomerReplyMockData reply;
  final bool completed;
  final bool historyMode;
  final bool openedFromCalendar;
  final VanJobDetailOpenTarget initialTarget;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with WidgetsBindingObserver {
  bool _completedInSession = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _actionsSectionKey = GlobalKey();
  final GlobalKey _quoteSectionKey = GlobalKey();
  final GlobalKey _customerReplySectionKey = GlobalKey();
  final GlobalKey _customerRequestSectionKey = GlobalKey();
  final GlobalKey _timingSectionKey = GlobalKey();
  bool _handledInitialTarget = false;

  DriverCustomerReplyMockData get reply =>
      resolveVanQuoteWorkflowReply(widget.reply);
  String get _jobId => widget.reply.jobId;
  VanJobRequestRecord? get _requestRecord =>
      DriverReplyMockState.instance.requestForJob(_jobId);
  bool get _isDropOffPickupRequest =>
      (_requestRecord?.requestType.trim().toLowerCase() ??
          reply.requestType.trim().toLowerCase()) ==
      'dropoffpickuprequest';
  DateTime? get _dropOffDateTime =>
      _requestRecord?.dropOffDateTime ?? reply.dropOffDateTime;
  DateTime? get _pickUpDateTime =>
      _requestRecord?.pickUpDateTime ?? reply.pickUpDateTime;
  DateTime? get _effectiveScheduledAt =>
      reply.scheduledAtOrParsed ?? _requestRecord?.scheduledAt;
  String get _normalizedSchedulingStatus =>
      (reply.schedulingStatus.trim().isNotEmpty
              ? reply.schedulingStatus
              : _requestRecord?.schedulingStatus ?? '')
          .trim()
          .toLowerCase();
  String get _normalizedCalendarStatus =>
      (reply.calendarStatus.trim().isNotEmpty
              ? reply.calendarStatus
              : _requestRecord?.calendarStatus ?? '')
          .trim()
          .toLowerCase();
  String get _normalizedQuoteTimingChoice =>
      (reply.quoteTimingChoice.trim().isNotEmpty
              ? reply.quoteTimingChoice
              : _requestRecord?.quoteTimingChoice ?? '')
          .trim()
          .toLowerCase();
  DateTime? get _persistedAgreedDateTime =>
      _dropOffDateTime ??
      reply.agreedDateTime ??
      _requestRecord?.agreedStartAt ??
      _requestRecord?.agreedDateTime;
  bool get _hasPersistedAgreedTime =>
      _persistedAgreedDateTime != null ||
      (_requestRecord?.hasAgreedSchedulingTime ?? false) ||
      ((_normalizedSchedulingStatus == 'agreed_manual' ||
              _normalizedSchedulingStatus == 'time_agreed' ||
              _normalizedQuoteTimingChoice == 'agreed_time_saved') &&
          _persistedAgreedDateTime != null);
  VanQuoteUiStatus get _quoteUiStatus => deriveVanQuoteUiStatus(
    hasRequest: _hasRequest,
    hasReply: _hasCustomerReply(),
    hasQuote: reply.hasQuote,
    hasRequestBeenSent: reply.hasRequestBeenSent,
    isQuoteAccepted: reply.isQuoteAccepted,
    isQuoteDeclined: reply.isQuoteDeclined,
    isConfirmed: reply.isConfirmed,
    isScheduledInCalendar: _isAlreadyInCalendar,
    isQuoteAwaitingCustomerResponse: _isAwaitingQuoteResponse,
    wasQuoteRevised: reply.hasDeclinedQuoteHistory,
    hasAgreedTime: _hasExactSchedulingTime,
    needsAgreedTime:
        reply.isQuoteAccepted &&
        !_hasExactSchedulingTime &&
        !_isAlreadyInCalendar,
    requiresExactPin: reply.requiresAnyExactPin,
    hasExactPin: reply.exactPinSaved,
  );
  VanBlockedCustomerRecord? get _blockedCustomerMatch => DriverReplyMockState
      .instance
      .blockedCustomerForJob(reply, request: _requestRecord);
  bool get _isAwaitingAgreedTime =>
      _quoteUiStatus.statusLabel == 'Time needs arranging';
  bool get _hasManualAgreedTime =>
      (_normalizedSchedulingStatus == 'agreed_manual' ||
          _normalizedSchedulingStatus == 'time_agreed') &&
      _hasCalendarReadyTime;
  bool get _hasAcceptedProposedTime =>
      (reply.acceptedProposedScheduledAt != null ||
          (_normalizedQuoteTimingChoice == 'accepted_proposed_time' &&
              reply.proposedScheduledAt != null)) &&
      !_isAwaitingAgreedTime;
  DateTime? get _acceptedOrProposedScheduledAt => _hasAcceptedProposedTime
      ? (reply.acceptedProposedScheduledAt ?? reply.proposedScheduledAt)
      : null;
  String get _displayCustomerName {
    final requestName = _requestRecord?.publicCustomerName.trim() ?? '';
    if (_isBookingLinkSubmission && requestName.isNotEmpty) {
      return requestName;
    }
    return sanitizeVanText(reply.customerName).trim();
  }

  String get _displayJobTitle {
    if (_isBookingLinkSubmission) {
      final serviceName = _requestRecord?.selectedServiceName.trim() ?? '';
      if (serviceName.isNotEmpty) {
        return serviceName;
      }
      final requestTitle = _requestRecord?.publicJobTitle.trim() ?? '';
      if (requestTitle.isNotEmpty) {
        return requestTitle;
      }
    }
    return sanitizeVanText(reply.jobTitle).trim();
  }

  String get _displayAddress {
    final requestAddress = _requestRecord?.publicAddressSummary.trim() ?? '';
    final address = _isBookingLinkSubmission && requestAddress.isNotEmpty
        ? requestAddress
        : sanitizeVanText(reply.address).trim();
    var postcode = _requestRecord?.customerPostcode.trim().isNotEmpty == true
        ? _requestRecord!.customerPostcode.trim()
        : sanitizeVanText(reply.postcode).trim();
    if (_addressAlreadyIncludesPostcode(address, postcode)) {
      postcode = '';
    }
    final requiresExactPinAfterQuoteAccepted = _requestRecord != null
        ? _requestRecord!.requiresExactPinAfterQuoteAccepted
        : reply.requiresExactPinAfterQuoteAccepted;
    final locationPending = _isDropOffPickupRequest
        ? requiresExactPinAfterQuoteAccepted &&
              (_requestRecord?.locationPending == true || reply.locationPending)
        : _requestRecord?.locationPending == true || reply.locationPending;
    if (_isDropOffPickupRequest &&
        address.isEmpty &&
        postcode.isEmpty &&
        !requiresExactPinAfterQuoteAccepted) {
      return '';
    }
    final summary = buildVanJobLocationSummary(
      address: address,
      postcode: postcode,
      locationPending: locationPending,
      requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
      hasExactPin: reply.exactPinSaved,
      emptyFallback: '',
    );
    if (vanJobLocationIsPending(
      locationPending: locationPending,
      requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
      hasExactPin: reply.exactPinSaved,
      address: address,
      postcode: postcode,
    )) {
      return _isDropOffPickupRequest
          ? '$summary\nAn exact drop-off location pin will be requested after quote acceptance.'
          : '$summary\nExact pin will be requested after quote acceptance.';
    }
    return summary;
  }

  bool _addressAlreadyIncludesPostcode(String address, String postcode) {
    String normalize(String value) =>
        value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final normalizedAddress = normalize(address);
    final normalizedPostcode = normalize(postcode);
    return normalizedAddress.isNotEmpty &&
        normalizedPostcode.isNotEmpty &&
        (normalizedAddress == normalizedPostcode ||
            normalizedAddress.endsWith(normalizedPostcode));
  }

  String get _displayPhone {
    final requestPhone = _requestRecord?.publicPhoneNumber.trim() ?? '';
    if (_isBookingLinkSubmission && requestPhone.isNotEmpty) {
      return requestPhone;
    }
    return sanitizeVanCustomerPhoneNumber(reply.phoneNumber);
  }

  bool get _isScheduledForFutureDate {
    final scheduledAt = _effectiveScheduledAt ?? _acceptedOrProposedScheduledAt;
    if (scheduledAt == null) {
      return false;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(scheduledAt).isAfter(today);
  }

  DateTime? get _preferredDate =>
      _requestRecord?.preferredDate ?? reply.preferredDate;
  String get _preferredTimeWindow {
    final requestWindow =
        _requestRecord?.preferredTimeWindow.trim().toLowerCase() ?? '';
    if (requestWindow.isNotEmpty) {
      return requestWindow;
    }
    return reply.preferredTimeWindow.trim().toLowerCase();
  }

  bool get _preferredIsFlexible =>
      (_requestRecord?.preferredIsFlexible ?? false) ||
      reply.preferredIsFlexible;
  String get _rawPreferredTimingNote {
    final requestNote = _requestRecord?.preferredTimingNote.trim() ?? '';
    if (requestNote.isNotEmpty) {
      return requestNote;
    }
    return reply.preferredTimingNote.trim();
  }

  String get _rawAdditionalCustomerNotes {
    final requestNotes = _requestRecord?.additionalNotes.trim() ?? '';
    if (requestNotes.isNotEmpty) {
      return requestNotes;
    }
    return reply.additionalNotes.trim();
  }

  String _normalizeCustomerNoteForComparison(String value) {
    return sanitizeVanText(
      value,
    ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _looksLikeTimingSpecificNote(String value) {
    final normalized = _normalizeCustomerNoteForComparison(value);
    if (normalized.isEmpty) {
      return false;
    }

    const timingKeywords = <String>[
      'time',
      'timing',
      'morning',
      'afternoon',
      'evening',
      'flexible',
      'availability',
      'available',
      'arrive',
      'arrival',
      'collect',
      'collection',
      'pickup',
      'pick up',
      'pick-up',
      'drop off',
      'drop-off',
      'before ',
      'after ',
      'between ',
      'around ',
      'slot',
      'schedule',
      'scheduled',
      'date',
      'today',
      'tomorrow',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    if (timingKeywords.any(normalized.contains)) {
      return true;
    }

    return RegExp(
      r'\b\d{1,2}(:\d{2})?\s?(am|pm)\b|\b\d{1,2}(:\d{2})\b',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  bool get _shouldTreatPreferredTimingNoteAsGeneralNote {
    final preferredTimingNote = _rawPreferredTimingNote;
    if (preferredTimingNote.isEmpty) {
      return false;
    }

    final explicitAdditionalNotes = _rawAdditionalCustomerNotes;
    final normalizedTimingNote = _normalizeCustomerNoteForComparison(
      preferredTimingNote,
    );
    final normalizedAdditionalNotes = _normalizeCustomerNoteForComparison(
      explicitAdditionalNotes,
    );

    if (normalizedAdditionalNotes.isNotEmpty &&
        normalizedAdditionalNotes == normalizedTimingNote) {
      return true;
    }

    if (_isBookingLinkSubmission && normalizedAdditionalNotes.isEmpty) {
      return true;
    }

    return normalizedAdditionalNotes.isEmpty &&
        !_looksLikeTimingSpecificNote(preferredTimingNote);
  }

  String? get _legacyAdditionalCustomerNotesFromTimingField {
    if (!_shouldTreatPreferredTimingNoteAsGeneralNote) {
      return null;
    }
    final preferredTimingNote = _rawPreferredTimingNote;
    return preferredTimingNote.isEmpty ? null : preferredTimingNote;
  }

  String get _preferredTimingNote {
    if (_shouldTreatPreferredTimingNoteAsGeneralNote) {
      return '';
    }
    return _rawPreferredTimingNote;
  }

  String get _preferredTimingDecision {
    final requestDecision =
        _requestRecord?.preferredTimingDecision.trim() ?? '';
    if (requestDecision.isNotEmpty) {
      return requestDecision;
    }
    return reply.preferredTimingDecision.trim();
  }

  DateTime? get _suggestedDate =>
      _requestRecord?.suggestedDate ?? reply.suggestedDate;
  String get _suggestedTimeWindow {
    final requestWindow =
        _requestRecord?.suggestedTimeWindow.trim().toLowerCase() ?? '';
    if (requestWindow.isNotEmpty) {
      return requestWindow;
    }
    return reply.suggestedTimeWindow.trim().toLowerCase();
  }

  int? get _estimatedDurationMinutes {
    if (_isDropOffPickupRequest) {
      final dropOff = _dropOffDateTime;
      final pickUp = _pickUpDateTime;
      if (dropOff != null && pickUp != null && pickUp.isAfter(dropOff)) {
        return pickUp.difference(dropOff).inMinutes;
      }
    }
    return reply.estimatedDurationMinutes ??
        _requestRecord?.estimatedDurationMinutes;
  }

  bool get _hasPreferredTimingData {
    return _preferredDate != null ||
        _preferredTimeWindow.isNotEmpty ||
        _preferredTimingNote.isNotEmpty ||
        _preferredIsFlexible ||
        _suggestedDate != null ||
        _suggestedTimeWindow.isNotEmpty;
  }

  bool get _showAcceptedCustomerRequestSummary =>
      _isBookingLinkSubmission && (reply.isQuoteAccepted || reply.isConfirmed);

  DateTime? get _confirmedAppointmentAt =>
      _dropOffDateTime ??
      _effectiveScheduledAt ??
      _acceptedOrProposedScheduledAt;

  bool get _hasConfirmedAppointmentData => _isDropOffPickupRequest
      ? _dropOffDateTime != null && _pickUpDateTime != null
      : _confirmedAppointmentAt != null;

  bool get _showConfirmedAppointmentSection =>
      _showAcceptedCustomerRequestSummary && _hasConfirmedAppointmentData;

  bool get _completed => reply.isCompleted || widget.completed;
  bool get _cancelled => reply.isCancelled;
  bool get _isBookingLinkSubmission {
    final request = _requestRecord;
    final source = request?.source.trim().toLowerCase() ?? '';
    return request?.isPreview == true ||
        source == 'booking_link' ||
        source == 'preview';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleInitialOpenTarget());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(forceServer: true),
      );
    });
  }

  void _logPreferredTimingState() {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[IncomingRequestDetail.job] jobId=$_jobId requestId=${_requestRecord?.requestId ?? reply.requestId ?? '(none)'} isBookingLink=$_isBookingLinkSubmission preferredDate=${_preferredDate?.toIso8601String() ?? '(none)'} preferredTimeWindow=${_preferredTimeWindow.isEmpty ? '(none)' : _preferredTimeWindow} preferredIsFlexible=$_preferredIsFlexible preferredTimingNote=${_preferredTimingNote.isEmpty ? '(none)' : _preferredTimingNote} hasPreferredTiming=$_hasPreferredTimingData',
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleInitialOpenTarget() async {
    if (!mounted || _handledInitialTarget) {
      return;
    }
    _handledInitialTarget = true;

    switch (widget.initialTarget) {
      case VanJobDetailOpenTarget.top:
        return;
      case VanJobDetailOpenTarget.quoteSection:
        await _scrollToFirstAvailable(<GlobalKey>[_quoteSectionKey]);
        return;
      case VanJobDetailOpenTarget.exactPinSection:
        await _scrollToFirstAvailable(<GlobalKey>[
          _customerReplySectionKey,
          _customerRequestSectionKey,
          _actionsSectionKey,
        ]);
        return;
      case VanJobDetailOpenTarget.actionsSection:
        await _scrollToFirstAvailable(<GlobalKey>[
          _actionsSectionKey,
          _timingSectionKey,
        ]);
        return;
      case VanJobDetailOpenTarget.setAgreedTimeFlow:
        await _openAddToCalendarFlow(addToCalendar: false);
        return;
    }
  }

  Future<void> _scrollToFirstAvailable(List<GlobalKey> keys) async {
    for (final key in keys) {
      final targetContext = key.currentContext;
      if (targetContext == null) {
        continue;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(forceServer: true),
      );
    }
  }

  void _handleDriverStateChanged() {
    if (!mounted) {
      return;
    }

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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String? _requestLink() {
    final link = reply.requestLink.trim();
    final requestId = reply.requestId?.trim() ?? '';
    if (requestId.isNotEmpty) {
      return resolveVanJobRequestDisplayLink(
        requestId: requestId,
        requestLink: link,
      );
    }

    if (link.isNotEmpty) {
      return link;
    }

    return null;
  }

  bool get _hasRequest => reply.hasRequest;

  VanJobActionState get _actionState => deriveVanJobActionState(
    reply,
    request: _requestRecord,
    phoneNumberOverride: _displayPhone,
  );

  bool get _canCallCustomer => _actionState.canCallCustomer;
  bool get _canShowNavigateAction {
    if (_cancelled || _completed) {
      return false;
    }
    return _actionState.canNavigate &&
        (!_isBookingLinkSubmission ||
            reply.isQuoteAccepted ||
            reply.isConfirmed ||
            _normalizedCalendarStatus == 'scheduled');
  }

  String get _schedulingStateLabel {
    return _quoteUiStatus.statusLabel;
  }

  String get _schedulingStateHint {
    return switch (_quoteUiStatus.statusLabel) {
      'Added to Calendar' => 'This job has already been added to Calendar.',
      'Ready for Calendar' =>
        'The customer accepted the quote and time. This job is ready to be added to your Calendar.',
      'Awaiting exact pin' =>
        'The time is agreed. Wait for the exact pickup or drop-off pin before adding this job to your Calendar.',
      'Time needs arranging' =>
        'The customer accepted the quote, but the proposed time was not confirmed. Agree a time with the customer, then save it before adding this job to your Calendar.',
      'Awaiting quote response' =>
        'The quote has been sent and is waiting for the customer to accept or decline it.',
      _ => _quoteUiStatus.summary,
    };
  }

  bool get _canSendQuoteForRequestFlow =>
      _actionState.canCreateQuote &&
      _actionState.hasCustomerReply &&
      !_actionState.hasRealQuote;
  bool get _shouldShowBottomCreateQuoteButton =>
      _canSendQuoteForRequestFlow && !_isBookingLinkSubmission;
  bool get _canReviseQuote => _actionState.canReviseQuote;
  bool get _hideTimingAndSchedulingForDeclinedQuote =>
      _isBookingLinkSubmission && reply.isQuoteDeclined;

  bool get _canViewQuote => _actionState.canViewQuote;

  bool get _shouldShowPrimaryCompleteJob => shouldShowCalendarDetailCompleteJob(
    isCompleted: _completed,
    isCancelled: _cancelled,
    isScheduled: _isAlreadyInCalendar,
    openedFromCalendar: widget.openedFromCalendar,
  );

  bool get _canAddJobToCalendarAction =>
      !_completed &&
      !_cancelled &&
      !reply.archived &&
      !_isAlreadyInCalendar &&
      reply.isQuoteAccepted &&
      !reply.isDeclined &&
      !_isAwaitingRequiredExactPin &&
      _hasCalendarReadyTime;
  bool get _isAlreadyInCalendar {
    return reply.isConfirmed ||
        _normalizedCalendarStatus == 'scheduled' ||
        _normalizedCalendarStatus == 'completed';
  }

  bool get _hasExactSchedulingTime {
    return reply.hasAgreedSchedulingTime || _hasPersistedAgreedTime;
  }

  bool get _hasTimingNeedsDecisionSignal {
    final request = _requestRecord;
    final requestSchedulingStatus =
        request?.schedulingStatus.trim().toLowerCase() ?? '';
    final requestQuoteTimingChoice =
        request?.quoteTimingChoice.trim().toLowerCase() ?? '';
    final requestTimeStatus = request?.timeStatus.trim().toLowerCase() ?? '';
    final requestTimingStatus =
        request?.timingStatus.trim().toLowerCase() ?? '';
    return reply.isAwaitingAgreedTime ||
        _normalizedSchedulingStatus == 'awaiting_agreed_time' ||
        _normalizedQuoteTimingChoice == 'arrange_another_time' ||
        request?.needsAgreedTime == true ||
        requestSchedulingStatus == 'awaiting_agreed_time' ||
        requestQuoteTimingChoice == 'arrange_another_time' ||
        requestTimeStatus == 'time_not_accepted' ||
        requestTimeStatus == 'not_accepted' ||
        requestTimeStatus == 'needs_decision' ||
        requestTimingStatus == 'time_not_accepted' ||
        requestTimingStatus == 'not_accepted' ||
        requestTimingStatus == 'needs_decision';
  }

  bool get _canSetAgreedTimeAction =>
      _actionState.canSetAgreedTime &&
      !reply.archived &&
      !_isAlreadyInCalendar &&
      !_hasCalendarReadyTime &&
      _hasTimingNeedsDecisionSignal;
  bool get _hasCalendarReadyTime => _hasExactSchedulingTime;
  bool get _hasAcceptedOrConfirmedQuote =>
      reply.isQuoteAccepted || reply.isConfirmed || _isAlreadyInCalendar;
  bool get _needsSchedulingAgreement =>
      reply.isQuoteAccepted &&
      !_hasCalendarReadyTime &&
      !(_normalizedQuoteTimingChoice == 'agreed_time_saved' &&
          _persistedAgreedDateTime != null);
  bool get _isReadyForCalendar =>
      reply.isQuoteAccepted &&
      _hasCalendarReadyTime &&
      !_isAwaitingRequiredExactPin &&
      !_isAlreadyInCalendar;
  bool get _isAwaitingRequiredExactPin =>
      reply.isQuoteAccepted &&
      reply.requiresAnyExactPin &&
      !reply.exactPinSaved;
  bool get _shouldShowSchedulingSection =>
      (_hasRequest || _requestRecord != null || _isBookingLinkSubmission) &&
      !_completed &&
      !_cancelled &&
      (reply.isQuoteSent ||
          reply.isQuoteAccepted ||
          reply.isConfirmed ||
          _isAlreadyInCalendar ||
          _normalizedSchedulingStatus.isNotEmpty);

  bool get _isAwaitingQuoteResponse =>
      reply.isQuoteAwaitingCustomerResponse &&
      !reply.isQuoteAccepted &&
      !reply.isQuoteDeclined &&
      !_isAlreadyInCalendar;

  String get _preferredTimingStatusLabel {
    if (_needsSchedulingAgreement) {
      return 'Proposed time not confirmed';
    }
    if (((_hasAcceptedOrConfirmedQuote || _hasManualAgreedTime) &&
            _hasCalendarReadyTime) ||
        _isAlreadyInCalendar) {
      return _isAlreadyInCalendar ? 'Added to Calendar' : 'Time agreed';
    }
    return switch (_preferredTimingDecision.trim().toLowerCase()) {
      'use_customer_time' => 'Using customer time',
      'suggested_alternative' => 'Alternative suggested',
      _ =>
        _isAwaitingQuoteResponse
            ? 'Awaiting quote acceptance'
            : 'Quote not yet accepted',
    };
  }

  String get _schedulingPrimaryChipLabel {
    return _quoteUiStatus.primaryChipLabel;
  }

  String get _schedulingSecondaryChipLabel {
    return _quoteUiStatus.secondaryChipLabel;
  }

  VanInvoiceDraft? get _savedInvoice =>
      DriverReplyMockState.instance.invoiceForJob(reply.invoiceHistoryKey);
  bool get _hasAcceptedQuoteForInvoice =>
      reply.isQuoteAccepted && reply.hasQuote;
  String get _createInvoiceActionLabel {
    if (_savedInvoice != null) {
      return 'View invoice';
    }
    if (_hasAcceptedQuoteForInvoice) {
      return 'Create invoice from quote';
    }
    return 'Create invoice';
  }

  bool get _canCancelRequest =>
      _hasRequest &&
      reply.isRequestSubmitted &&
      !reply.isRequestCancelled &&
      !reply.isRequestExpired &&
      !reply.isCompleted &&
      !_hasCustomerReply();

  bool _hasCustomerReply() {
    if (reply.hasCustomerReply) {
      return true;
    }

    final request = _requestRecord;
    return request?.hasCustomerReply ?? false;
  }

  bool get _canEditJobDetails => true;
  bool get _canBlockCustomer =>
      _displayPhone.isNotEmpty && _blockedCustomerMatch == null;
  bool get _canUnblockCustomer => _blockedCustomerMatch != null;

  bool get _canChangeJobDateTime => !_completed && !_cancelled;

  bool get _canResendRequest =>
      _hasRequest &&
      reply.isRequestSubmitted &&
      !reply.isRequestCancelled &&
      !reply.isRequestExpired &&
      !_completed &&
      !_cancelled &&
      !_hasCustomerReply();

  bool get _canCreateNewRequest =>
      !_completed &&
      !_cancelled &&
      (!reply.hasRequest || reply.isRequestCancelled || reply.isRequestExpired);

  bool get _canCancelJobAction => !_completed && !_cancelled;
  bool get _shouldHideHistoricalBookingSections => _completed;

  void _popWithCurrentResult() {
    Navigator.of(
      context,
    ).pop(_completedInSession ? VanJobActionResult.completed : null);
  }

  Future<void> _openCalendarQuickLink() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const JobsCalendarPage()));
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Widget _buildCalendarQuickLinkButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCalendarQuickLink,
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
            Icons.calendar_month_outlined,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowMenuButton() {
    final canShowQuoteDivider = _canReviseQuote || _canViewQuote;
    final canShowRequestDivider =
        _canResendRequest || _canCreateNewRequest || _canCancelRequest;
    final canShowDestructiveDivider =
        _canEditJobDetails ||
        _canChangeJobDateTime ||
        canShowQuoteDivider ||
        canShowRequestDivider ||
        _canBlockCustomer ||
        _canUnblockCustomer;

    return PopupMenuButton<_JobDetailOverflowAction>(
      tooltip: 'Job actions',
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF132031),
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      onSelected: (action) {
        switch (action) {
          case _JobDetailOverflowAction.editDetails:
            unawaited(_editJobDetails());
            break;
          case _JobDetailOverflowAction.changeDateTime:
            unawaited(_changeJobDateTime());
            break;
          case _JobDetailOverflowAction.reviseQuote:
            _openQuote();
            break;
          case _JobDetailOverflowAction.copyQuoteMessage:
            Clipboard.setData(ClipboardData(text: _quoteMessageText()));
            _showSnack('Quote message copied.');
            break;
          case _JobDetailOverflowAction.copyQuoteLink:
            _copyQuoteLink();
            break;
          case _JobDetailOverflowAction.resendRequest:
            unawaited(_resendRequest());
            break;
          case _JobDetailOverflowAction.newRequest:
            unawaited(_newRequest());
            break;
          case _JobDetailOverflowAction.cancelRequest:
            unawaited(_cancelRequest());
            break;
          case _JobDetailOverflowAction.blockCustomer:
            unawaited(_blockCustomer());
            break;
          case _JobDetailOverflowAction.unblockCustomer:
            unawaited(_unblockCustomer());
            break;
          case _JobDetailOverflowAction.cancelJob:
            unawaited(_cancelJob());
            break;
          case _JobDetailOverflowAction.deleteJob:
            unawaited(_deleteJob());
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_JobDetailOverflowAction>>[];

        if (_canEditJobDetails) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.editDetails,
              label: 'Edit job details',
              icon: Icons.edit_outlined,
            ),
          );
        }

        if (_canChangeJobDateTime) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.changeDateTime,
              label: 'Change date/time',
              icon: Icons.event_available_outlined,
            ),
          );
        }

        if (canShowQuoteDivider) {
          items.add(const PopupMenuDivider(height: 10));
        }

        if (_canReviseQuote) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.reviseQuote,
              label: 'Revise / resend quote',
              icon: Icons.refresh_rounded,
            ),
          );
        }

        if (_canViewQuote) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.copyQuoteMessage,
              label: 'Copy quote message',
              icon: Icons.copy,
            ),
          );
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.copyQuoteLink,
              label: 'Copy quote link',
              icon: Icons.link,
            ),
          );
        }

        if (canShowRequestDivider) {
          items.add(const PopupMenuDivider(height: 10));
        }

        if (_canResendRequest) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.resendRequest,
              label: 'Resend request',
              icon: Icons.refresh,
            ),
          );
        }

        if (_canCreateNewRequest) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.newRequest,
              label: 'New request',
              icon: Icons.add_task,
            ),
          );
        }

        if (_canCancelRequest) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.cancelRequest,
              label: 'Cancel request',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFFFC38C),
            ),
          );
        }

        if (_canBlockCustomer) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.blockCustomer,
              label: 'Block customer',
              icon: Icons.block_outlined,
              color: vanStatusToneColor(VanStatusTone.danger),
            ),
          );
        }

        if (_canUnblockCustomer) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.unblockCustomer,
              label: 'Unblock customer',
              icon: Icons.lock_open_outlined,
              color: vanStatusToneColor(VanStatusTone.positive),
            ),
          );
        }

        if (canShowDestructiveDivider) {
          items.add(const PopupMenuDivider(height: 10));
        }

        if (_canCancelJobAction) {
          items.add(
            _buildOverflowMenuItem(
              value: _JobDetailOverflowAction.cancelJob,
              label: 'Cancel job',
              icon: Icons.block_outlined,
              color: vanStatusToneColor(VanStatusTone.danger),
            ),
          );
        }

        items.add(
          _buildOverflowMenuItem(
            value: _JobDetailOverflowAction.deleteJob,
            label: 'Delete job',
            icon: Icons.delete_outline,
            color: vanStatusToneColor(VanStatusTone.danger),
            destructive: true,
          ),
        );

        return items;
      },
    );
  }

  PopupMenuItem<_JobDetailOverflowAction> _buildOverflowMenuItem({
    required _JobDetailOverflowAction value,
    required String label,
    required IconData icon,
    Color? color,
    bool destructive = false,
  }) {
    final itemColor = color ?? Colors.white;
    return PopupMenuItem<_JobDetailOverflowAction>(
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

  Widget _buildRequestTools(String customerPhone, String customerEmail) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final buttons = <Widget>[
          if (customerPhone.isNotEmpty)
            _buildActionButton(
              label: 'Text customer',
              icon: Icons.sms_outlined,
              tone: VanStatusTone.primary,
              onTap: () => unawaited(_textCustomerRequest()),
            ),
          if (customerEmail.isNotEmpty)
            _buildActionButton(
              label: 'Email customer',
              icon: Icons.email_outlined,
              tone: VanStatusTone.primary,
              onTap: () => unawaited(_emailCustomerRequest()),
            ),
          _buildActionButton(
            label: 'Copy link',
            icon: Icons.copy,
            tone: VanStatusTone.neutral,
            onTap: () => unawaited(_copyRequestLink()),
          ),
          _buildActionButton(
            label: 'Share link',
            icon: Icons.share,
            tone: VanStatusTone.neutral,
            onTap: () => unawaited(_shareRequestLink()),
          ),
        ];

        if (stacked) {
          return Column(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                buttons[i],
                if (i < buttons.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final button in buttons)
              SizedBox(
                width: constraints.maxWidth < 620 ? constraints.maxWidth : 176,
                child: button,
              ),
          ],
        );
      },
    );
  }

  bool _isPhotoChecklistQuestion(String question) {
    final normalized = question.trim().toLowerCase();
    return normalized == 'photos needed?' ||
        normalized == 'photos' ||
        normalized.contains('photo');
  }

  List<DriverChecklistResponse> _visibleChecklistResponses() {
    return _effectiveChecklistResponses()
        .where((response) {
          final answer = response.answer.trim();
          final note = response.note?.trim() ?? '';
          return !_isPhotoChecklistQuestion(response.question) &&
              (answer.isNotEmpty || note.isNotEmpty);
        })
        .toList(growable: false);
  }

  List<DriverCustomQuestionResponse> _visibleCustomResponses() {
    return _effectiveCustomResponses()
        .where((response) => response.answer.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _copyRequestLink() async {
    final link = _requestLink();
    if (link == null) {
      _showSnack('No request link available.');
      return;
    }

    try {
      await copyRequestLink(link);
      _showSnack('Link copied');
    } catch (_) {
      _showSnack(
        'Copy failed - long press the address bar or open in Chrome/Safari.',
      );
    }
  }

  Future<void> _shareRequestLink() async {
    final link = _requestLink();
    if (link == null) {
      _showSnack('No request link available.');
      return;
    }
    final businessName = await _requestMessageBusinessName();

    final shareText = buildRequestShareMessage(
      link: link,
      customerName: reply.customerName,
      jobTitle: reply.jobTitle,
      businessName: businessName,
      address: reply.address,
      exactPinRequested: reply.requestExactPin,
      exactPinRequestedAfterQuoteAccepted:
          reply.requiresExactPinAfterQuoteAccepted,
    );
    debugPrint('[VanJobRequestShare]\n$shareText');

    final result = await shareRequestMessage(shareText);
    if (result.status == ShareResultStatus.unavailable) {
      _showSnack('Could not open sharing right now.');
    }
  }

  Future<void> _textCustomerRequest() async {
    final link = _requestLink();
    if (link == null) {
      _showSnack('No request link available.');
      return;
    }
    final businessName = await _requestMessageBusinessName();

    final message = buildRequestShareMessage(
      link: link,
      customerName: reply.customerName,
      jobTitle: reply.jobTitle,
      businessName: businessName,
      address: reply.address,
      exactPinRequested: reply.requestExactPin,
      exactPinRequestedAfterQuoteAccepted:
          reply.requiresExactPinAfterQuoteAccepted,
    );
    final launched = await textCustomerRequest(
      phoneNumber: reply.phoneNumber,
      message: message,
    );
    if (!launched) {
      _showSnack('Could not open text message. Use Share link instead.');
      return;
    }

    _showSnack('Text message opened. Send it from your SMS app.');
  }

  Future<void> _emailCustomerRequest() async {
    final link = _requestLink();
    if (link == null) {
      _showSnack('No request link available.');
      return;
    }
    final businessName = await _requestMessageBusinessName();

    final email = reply.customerEmail.trim();
    if (email.isEmpty) {
      final shared = await shareRequestMessage(
        buildRequestShareMessage(
          link: link,
          customerName: reply.customerName,
          jobTitle: reply.jobTitle,
          businessName: businessName,
          address: reply.address,
          exactPinRequested: reply.requestExactPin,
          exactPinRequestedAfterQuoteAccepted:
              reply.requiresExactPinAfterQuoteAccepted,
        ),
      );
      if (shared.status == ShareResultStatus.unavailable) {
        final copied = await copyRequestMessage(
          buildRequestShareMessage(
            link: link,
            customerName: reply.customerName,
            jobTitle: reply.jobTitle,
            businessName: businessName,
            address: reply.address,
            exactPinRequested: reply.requestExactPin,
            exactPinRequestedAfterQuoteAccepted:
                reply.requiresExactPinAfterQuoteAccepted,
          ),
        );
        if (copied) {
          _showSnack('Email not available. Message copied instead.');
          return;
        }
      }
      _showSnack('Email not available. Share sheet opened instead.');
      return;
    }

    final message = buildRequestEmailBody(
      link: link,
      jobTitle: reply.jobTitle,
      address: reply.address,
      exactPinRequested: reply.requestExactPin,
      exactPinRequestedAfterQuoteAccepted:
          reply.requiresExactPinAfterQuoteAccepted,
    );
    final launched = await emailCustomerRequest(
      email: email,
      subject: 'Van Mate job request',
      message: message,
    );
    if (launched) {
      _showSnack('Email opened. Send it from your mail app.');
      return;
    }

    final shared = await shareRequestMessage(message);
    if (shared.status == ShareResultStatus.unavailable) {
      final copied = await copyRequestMessage(message);
      if (copied) {
        _showSnack('Could not open email. Message copied instead.');
        return;
      }
    }
    _showSnack('Email unavailable. Share sheet opened instead.');
  }

  Future<String> _requestMessageBusinessName() async {
    try {
      final profile = await VanBusinessProfileStorage.instance
          .loadCanonicalProfile();
      return sanitizeVanText(profile.businessName).trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _resendRequest() async {
    final previousRequestId = reply.requestId?.trim() ?? '';
    final DriverCustomerReplyMockData updated;
    try {
      updated = await DriverReplyMockState.instance.sendJobRequest(
        reply.toDraft(),
      );
    } on VanPastScheduleException catch (error) {
      _showSnack(error.message);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    final updatedRequestId = updated.requestId?.trim() ?? '';
    final reusedExisting =
        previousRequestId.isNotEmpty && previousRequestId == updatedRequestId;
    _showSnack(
      reusedExisting
          ? 'Existing request reused for ${updated.customerName}.'
          : 'New request created for ${updated.customerName}.',
    );
  }

  Future<void> _newRequest() async {
    final DriverCustomerReplyMockData updated;
    try {
      updated = await DriverReplyMockState.instance.sendJobRequest(
        reply.toDraft(),
        forceNewRequest: true,
      );
    } on VanPastScheduleException catch (error) {
      _showSnack(error.message);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    _showSnack('New request created for ${updated.customerName}.');
  }

  Future<void> _cancelRequest() async {
    if (!_canCancelRequest) {
      _showSnack('This request cannot be cancelled.');
      return;
    }

    await DriverReplyMockState.instance.cancelRequestForJob(jobId: reply.jobId);
    if (!mounted) {
      return;
    }
    setState(() {});
    _showSnack('Request cancelled.');
  }

  String _windowLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'evening':
        return 'Evening';
      case 'anytime':
        return 'Anytime';
      default:
        return '';
    }
  }

  String _preferredTimingSummary() {
    final parts = <String>[];
    if (_preferredDate != null) {
      parts.add(formatDate(_preferredDate!));
    }
    final label = _windowLabel(_preferredTimeWindow);
    if (label.isNotEmpty) {
      parts.add(label);
    }
    if (_preferredIsFlexible) {
      parts.add('Flexible');
    }
    return parts.join(' • ');
  }

  String _durationLabel(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return 'Not set';
    }
    switch (minutes) {
      case 30:
        return '30m';
      case 60:
        return '1h';
      case 120:
        return '2h';
      case 240:
        return 'Half day';
      default:
        return '${minutes}m';
    }
  }

  Future<bool?> _showAddToCalendarConfirmationSheet({
    required DateTime scheduledAt,
    required int selectedDuration,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13233A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _buildKeyboardAwareBottomSheet(
          sheetContext,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add this accepted job to your Calendar?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confirm this appointment.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _buildSmallInfoCard('Date', formatDate(scheduledAt)),
              const SizedBox(height: 10),
              _buildSmallInfoCard(
                'Time',
                TimeOfDay.fromDateTime(scheduledAt).format(sheetContext),
              ),
              const SizedBox(height: 10),
              _buildSmallInfoCard(
                'Estimated duration',
                _durationLabel(selectedDuration),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  debugPrintSynchronously('CONFIRM_SCHEDULE_TAPPED');
                  Navigator.of(sheetContext).pop(true);
                },
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Confirm schedule'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF58D0A4),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAppointmentConflictDialog() async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF142031),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Appointment conflict',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This appointment overlaps with another scheduled job.\n'
            'Please choose a different time before adding it to Calendar.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A7DFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKeyboardAwareBottomSheet(
    BuildContext context, {
    required Widget child,
    double heightFactor = 0.9,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding =
        mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * heightFactor,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmQuoteAcceptedBeforeManualTimeSave() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF142031),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Has the customer accepted this quote?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Only set an agreed time if the customer has accepted the quote.',
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
              child: const Text('No, save time only'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF58D0A4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, quote accepted'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAddToCalendarFlow({bool addToCalendar = true}) async {
    final now = DateTime.now();
    final baseScheduledAt =
        _dropOffDateTime ??
        _effectiveScheduledAt ??
        _acceptedOrProposedScheduledAt;
    var selectedDate = DateUtils.dateOnly(
      baseScheduledAt ?? _preferredDate ?? now,
    );
    var selectedTime = TimeOfDay.fromDateTime(baseScheduledAt ?? now);
    var selectedDuration = _estimatedDurationMinutes ?? 60;

    if (addToCalendar) {
      if (_isAwaitingRequiredExactPin) {
        _showSnack(
          'Wait for the exact pickup or drop-off pin before adding this job to the calendar.',
        );
        return;
      }
      if (!_hasCalendarReadyTime || baseScheduledAt == null) {
        _showSnack(
          'Set an exact agreed time before adding this job to the calendar.',
        );
        return;
      }
      final pastScheduleMessage = validateVanMateScheduledAt(baseScheduledAt);
      if (pastScheduleMessage != null) {
        _showSnack(pastScheduleMessage);
        return;
      }
      final overlap = DriverReplyMockState.instance.findScheduleOverlap(
        ignoringJobId: _jobId,
        scheduledAt: baseScheduledAt,
        estimatedDurationMinutes: selectedDuration,
      );
      if (overlap != null) {
        await _showAppointmentConflictDialog();
        return;
      }
      final confirmed = await _showAddToCalendarConfirmationSheet(
        scheduledAt: baseScheduledAt,
        selectedDuration: selectedDuration,
      );
      if (confirmed != true) {
        return;
      }
      try {
        final persisted = await DriverReplyMockState.instance
            .persistScheduledJob(
              jobId: _jobId,
              scheduledAt: baseScheduledAt,
              estimatedDurationMinutes: selectedDuration,
              schedulingStatus: reply.schedulingStatus.trim().isNotEmpty
                  ? reply.schedulingStatus
                  : 'accepted_time',
            );
        if (!persisted) {
          if (!mounted) {
            return;
          }
          _showSnack('Could not save this job to Calendar. Please try again.');
          return;
        }
      } on VanScheduleOverlapException {
        if (!mounted) {
          return;
        }
        await _showAppointmentConflictDialog();
        return;
      } catch (error, stackTrace) {
        debugPrintSynchronously(
          'CONFIRM_SCHEDULE_FIRESTORE_ERROR error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
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
      return;
    }

    final shouldAskForAcceptanceConfirmation =
        reply.hasQuote && !reply.isQuoteAccepted && !reply.isQuoteDeclined;
    final markQuoteAccepted = shouldAskForAcceptanceConfirmation
        ? await _confirmQuoteAcceptedBeforeManualTimeSave()
        : null;
    if (shouldAskForAcceptanceConfirmation && markQuoteAccepted == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13233A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: sheetContext,
                initialDate: selectedDate.isBefore(DateUtils.dateOnly(now))
                    ? DateUtils.dateOnly(now)
                    : selectedDate,
                firstDate: DateUtils.dateOnly(now),
                lastDate: DateTime(now.year + 3),
              );
              if (picked == null) return;
              setSheetState(() {
                selectedDate = DateUtils.dateOnly(picked);
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: sheetContext,
                initialTime: selectedTime,
              );
              if (picked == null) return;
              setSheetState(() {
                selectedTime = picked;
              });
            }

            Future<void> pickDuration() async {
              final picked = await showVanDurationPickerSheet(
                context: sheetContext,
                initialMinutes: selectedDuration,
                durationLabel: _durationLabel,
                title: 'Choose duration',
              );
              if (picked == null || picked <= 0) return;
              setSheetState(() {
                selectedDuration = picked;
              });
            }

            return _buildKeyboardAwareBottomSheet(
              sheetContext,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set agreed time',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save the exact agreed time before you add this job to the calendar.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(formatDate(selectedDate)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickTime,
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(selectedTime.format(sheetContext)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: pickDuration,
                    icon: const Icon(Icons.timelapse_outlined),
                    label: Text(
                      'Duration: ${_durationLabel(selectedDuration)}',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    icon: const Icon(Icons.schedule_outlined),
                    label: const Text('Save agreed time'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF58D0A4),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final scheduledAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final pastScheduleMessage = validateVanMateScheduledAt(scheduledAt);
    if (pastScheduleMessage != null) {
      _showSnack(pastScheduleMessage);
      return;
    }
    final overlap = DriverReplyMockState.instance.findScheduleOverlap(
      ignoringJobId: _jobId,
      scheduledAt: scheduledAt,
      estimatedDurationMinutes: selectedDuration,
    );
    if (overlap != null) {
      _showSnack(
        DriverReplyMockState.instance.formatScheduleOverlapMessage(overlap),
      );
      return;
    }
    final saved = await DriverReplyMockState.instance.persistAgreedTime(
      jobId: _jobId,
      scheduledAt: scheduledAt,
      estimatedDurationMinutes: selectedDuration,
      schedulingStatus: 'ready_for_calendar',
      markQuoteAccepted: markQuoteAccepted == true,
    );
    if (!saved) {
      if (!mounted) {
        return;
      }
      _showSnack('Could not save the agreed time. Please try again.');
      return;
    }
    try {
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[AGREED_TIME_REFRESH_ERROR] error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    _showSnack('Agreed time saved.');
  }

  String _quoteMessageText() {
    final quoteAmount = formatCurrency(reply.quoteAmount ?? 0);
    final quoteResponseLink = reply.activeQuoteResponseLink;
    final proposedAppointment = _preferredTimingSummary();
    return buildVanQuoteMessage(
      customerName: _displayCustomerName,
      jobTitle: _displayJobTitle,
      quoteAmountText: quoteAmount,
      quoteResponseLink: quoteResponseLink,
      businessName: '',
      proposedAppointmentText: proposedAppointment,
    );
  }

  List<DriverChecklistResponse> _effectiveChecklistResponses() {
    if (reply.checklistResponses.isNotEmpty) {
      return reply.checklistResponses;
    }

    final request = _requestRecord;
    if (request == null) {
      return const <DriverChecklistResponse>[];
    }

    return request.checklistResponses
        .map(
          (response) => DriverChecklistResponse(
            question: response.question,
            answer: response.answer,
            note: response.note,
            icon: Icons.checklist,
          ),
        )
        .toList(growable: false);
  }

  List<DriverCustomQuestionResponse> _effectiveCustomResponses() {
    if (reply.customQuestionResponses.isNotEmpty) {
      return reply.customQuestionResponses;
    }

    final request = _requestRecord;
    if (request == null) {
      return const <DriverCustomQuestionResponse>[];
    }

    return request.customQuestionResponses
        .map(
          (response) => DriverCustomQuestionResponse(
            question: response.question,
            answer: response.answer,
          ),
        )
        .toList(growable: false);
  }

  List<VanJobRequestAnswer> _bookingLinkAnswers() {
    if (!_isBookingLinkSubmission) {
      return const <VanJobRequestAnswer>[];
    }
    return (_requestRecord?.answers ?? const <VanJobRequestAnswer>[])
        .where((answer) => answer.hasAnswer)
        .toList(growable: false);
  }

  String? _replyNotesText() {
    final replyNotes = reply.additionalNotes.trim();
    final requestNotes = _requestRecord?.additionalNotes.trim() ?? '';
    final legacyNotes = _legacyAdditionalCustomerNotesFromTimingField ?? '';

    final preferredNotes = _isBookingLinkSubmission
        ? <String>[
            if (requestNotes.isNotEmpty) requestNotes,
            if (replyNotes.isNotEmpty) replyNotes,
            if (legacyNotes.isNotEmpty) legacyNotes,
          ]
        : <String>[
            if (replyNotes.isNotEmpty) replyNotes,
            if (requestNotes.isNotEmpty) requestNotes,
            if (legacyNotes.isNotEmpty) legacyNotes,
          ];
    if (preferredNotes.isEmpty) {
      return null;
    }

    final selectedNotes = preferredNotes.first;
    if (!_isBookingLinkSubmission) {
      return selectedNotes;
    }

    final cleanedLines = selectedNotes
        .split('\n')
        .map((line) => line.trim())
        .where((line) {
          final normalized = line.toLowerCase();
          if (normalized.startsWith('source:')) {
            return false;
          }
          if (normalized.startsWith('photos')) {
            return false;
          }
          return line.isNotEmpty;
        })
        .toList(growable: false);
    if (cleanedLines.isEmpty) {
      return null;
    }
    return cleanedLines.join('\n');
  }

  String? _declineReasonText() {
    final replySummary = buildVanQuoteDeclineSummary(
      reasonLabel: reply.declineReasonLabel,
      reasonCode: reply.declineReasonCode,
      note: reply.declineNote,
      reasonText: reply.declineReasonText,
    );
    final replyText = formatVanQuoteDeclineText(replySummary);
    if (replyText != null) {
      return replyText;
    }

    final requestRecord = _requestRecord;
    if (requestRecord == null) {
      return null;
    }
    final requestSummary = buildVanQuoteDeclineSummary(
      reasonLabel: requestRecord.declineReasonLabel,
      reasonCode: requestRecord.declineReasonCode,
      note: requestRecord.declineNote,
      reasonText: requestRecord.declineReasonText,
    );
    return formatVanQuoteDeclineText(requestSummary);
  }

  String? _replyExactPinText() {
    if (reply.exactPinSaved &&
        reply.exactPinLatitude != null &&
        reply.exactPinLongitude != null) {
      final coordinates =
          '${reply.exactPinLatitude!.toStringAsFixed(5)}, ${reply.exactPinLongitude!.toStringAsFixed(5)}';
      final source =
          reply.exactPinShareSource?.driverSourceText ??
          (reply.exactPinShareSource != null
              ? reply.exactPinShareSource.toString()
              : 'Customer shared the drop-off location.');
      final note = reply.exactPinNote?.trim() ?? '';
      final parts = <String>[source];
      if (kDebugMode) {
        parts.add(coordinates);
      } else {
        parts.add('Exact pin received.');
      }
      if (note.isNotEmpty) {
        parts.add(note);
      }
      return parts.join('\n');
    }

    final request = _requestRecord;
    if (request != null && request.hasExactPin) {
      final coordinates =
          request.exactPinLat != null && request.exactPinLng != null
          ? '${request.exactPinLat!.toStringAsFixed(5)}, ${request.exactPinLng!.toStringAsFixed(5)}'
          : 'Coordinates not saved yet.';
      final source =
          vanExactPinSourceFromStorage(
            request.exactPinSource,
          )?.driverSourceText ??
          (request.exactPinSource.trim().isNotEmpty
              ? request.exactPinSource.trim()
              : 'Customer shared the drop-off location.');
      final note = request.exactPinNote.trim();
      final parts = <String>[source];
      if (kDebugMode) {
        parts.add(coordinates);
      } else {
        parts.add('Exact pin received.');
      }
      if (note.isNotEmpty) {
        parts.add(note);
      }
      return parts.join('\n');
    }

    return null;
  }

  List<Widget> _buildReplyDetailCards() {
    final cards = <Widget>[];
    final checklistResponses = _visibleChecklistResponses();
    final customResponses = _visibleCustomResponses();
    final bookingAnswers = _bookingLinkAnswers();
    final notesText = _replyNotesText();
    final exactPinText = _replyExactPinText();

    if (_isBookingLinkSubmission) {
      final selectedService = _requestRecord?.selectedServiceName.trim() ?? '';
      if (selectedService.isNotEmpty) {
        cards.add(_buildDetailCard('Selected service', selectedService));
      }
      for (final answer in bookingAnswers) {
        final question = answer.questionText.trim().isEmpty
            ? 'Question'
            : answer.questionText.trim();
        cards.add(_buildDetailCard(question, answer.answerValue.trim()));
      }
      if (exactPinText != null) {
        cards.add(_buildDetailCard('Exact pin', exactPinText));
      }
      if (notesText != null) {
        cards.add(_buildDetailCard('Additional notes', notesText));
      }
      return cards;
    }

    for (final response in checklistResponses) {
      final label = vanJobChecklistDisplayLabel(response.question);
      final value = formatAnswerWithNote(response.answer, response.note);
      cards.add(_buildDetailCard(label, value));
    }

    for (final response in customResponses) {
      final question = sanitizeVanText(response.question).trim();
      final answer = sanitizeVanText(response.answer).trim();
      final value = question.isEmpty ? answer : '$question\nAnswer: $answer';
      cards.add(
        _buildDetailCard(question.isEmpty ? 'Custom' : 'Custom / Other', value),
      );
    }

    if (exactPinText != null) {
      cards.add(_buildDetailCard('Exact pin', exactPinText));
    }

    if (notesText != null) {
      cards.add(_buildDetailCard('Additional notes', notesText));
    }

    return cards;
  }

  Widget _buildCustomerReplyDetailsContent(List<Widget> replyCards) {
    if (replyCards.isEmpty && !_isBookingLinkSubmission) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isBookingLinkSubmission ? 'Customer answers' : 'Customer reply',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (replyCards.isEmpty && _isBookingLinkSubmission)
          Text(
            'No answers submitted.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w600,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final detail in replyCards)
                    SizedBox(width: cardWidth, child: detail),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _openCustomerResponsesDialog(List<Widget> replyCards) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF0E1B2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 640, maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: _buildCustomerReplyDetailsContent(replyCards),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerReplySection(List<Widget> replyCards) {
    if (replyCards.isEmpty && !_isBookingLinkSubmission) {
      return const SizedBox.shrink();
    }

    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'View customer responses',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'View responses',
            icon: Icons.question_answer_outlined,
            tone: VanStatusTone.primary,
            onTap: () => unawaited(_openCustomerResponsesDialog(replyCards)),
          ),
        ],
      ),
    );
  }

  List<String> _bookingLinkPhotoUrls() {
    return (_requestRecord?.photos ?? const <VanJobRequestPhoto>[])
        .where((photo) => photo.hasUrl)
        .map((photo) => photo.url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  String _bookingLinkPhotoStatus() {
    final photoCount = _bookingLinkPhotoUrls().length;
    if (photoCount > 0) {
      return photoCount == 1
          ? '1 photo attached'
          : '$photoCount photos attached';
    }
    final notes = _requestRecord?.additionalNotes.trim() ?? '';
    for (final line in notes.split('\n')) {
      final normalized = line.trim().toLowerCase();
      if (normalized.startsWith('photos requested') &&
          normalized.contains('upload failed')) {
        return 'Photos requested, upload failed';
      }
      if (normalized.startsWith('photos') &&
          !normalized.contains('none attached')) {
        return line.trim();
      }
    }
    return '';
  }

  Future<void> _openPhotosDialog(List<String> urls, {int initialIndex = 0}) {
    if (urls.isEmpty) {
      return Future<void>.value();
    }
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var current = initialIndex.clamp(0, urls.length - 1);
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: const Color(0xFF0E1B2D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 620, maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Photo ${current + 1} of ${urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          urls[current],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.white.withValues(alpha: 0.06),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 28,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                  if (urls.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: current == 0
                                  ? null
                                  : () => setDialogState(() {
                                      current -= 1;
                                    }),
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('Previous'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: current >= urls.length - 1
                                  ? null
                                  : () => setDialogState(() {
                                      current += 1;
                                    }),
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: const Text('Next'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotosSection() {
    final urls = _bookingLinkPhotoUrls();
    final status = _bookingLinkPhotoStatus();
    if (urls.isEmpty && status.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (urls.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) => InkWell(
                onTap: () => _openPhotosDialog(urls, initialIndex: index),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    urls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.white.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferredTimeSection() {
    if (!_hasPreferredTimingData) {
      return const SizedBox.shrink();
    }
    final preferredDateLabel = _preferredDate == null
        ? ''
        : formatDate(_preferredDate!);
    final preferredTimeLabel = _windowLabel(_preferredTimeWindow);
    final flexibleLabel = _preferredIsFlexible ? 'Yes' : 'No';
    final suggestedDate = _suggestedDate;
    final suggestedWindowLabel = _windowLabel(_suggestedTimeWindow);
    final suggestedSummaryParts = <String>[];
    if (suggestedDate != null) {
      suggestedSummaryParts.add(formatDate(suggestedDate));
    }
    if (suggestedWindowLabel.isNotEmpty) {
      suggestedSummaryParts.add(suggestedWindowLabel);
    }
    final suggestedSummary = suggestedSummaryParts.join(' • ');
    final decisionLabel = _preferredTimingStatusLabel;
    final sectionTitle = _showAcceptedCustomerRequestSummary
        ? 'Customer Request'
        : 'Preferred timing';

    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (preferredDateLabel.isNotEmpty)
            _buildSmallInfoCard(
              _showAcceptedCustomerRequestSummary
                  ? 'Requested date'
                  : 'Preferred date',
              preferredDateLabel,
            ),
          if (preferredTimeLabel.isNotEmpty) ...[
            if (preferredDateLabel.isNotEmpty) const SizedBox(height: 10),
            _buildSmallInfoCard(
              _showAcceptedCustomerRequestSummary
                  ? 'Requested time'
                  : 'Preferred time',
              preferredTimeLabel,
            ),
          ],
          if (_preferredDate != null || preferredTimeLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSmallInfoCard('Flexible', flexibleLabel),
          ],
          if (_preferredTimingNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSmallInfoCard(
              _showAcceptedCustomerRequestSummary
                  ? 'Customer note'
                  : 'Customer timing note',
              _preferredTimingNote,
            ),
          ],
          if (suggestedSummary.isNotEmpty &&
              (!_showAcceptedCustomerRequestSummary ||
                  _needsSchedulingAgreement)) ...[
            const SizedBox(height: 10),
            _buildSmallInfoCard('Suggested alternative', suggestedSummary),
          ],
          if (_isBookingLinkSubmission) ...[
            const SizedBox(height: 12),
            _buildSmallInfoCard(
              _showAcceptedCustomerRequestSummary ? 'Timing status' : 'Status',
              decisionLabel,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmedAppointmentSection() {
    final confirmedAt = _confirmedAppointmentAt;
    if (!_showAcceptedCustomerRequestSummary || confirmedAt == null) {
      return const SizedBox.shrink();
    }

    if (_isDropOffPickupRequest) {
      final dropOff = _dropOffDateTime;
      final pickUp = _pickUpDateTime;
      if (dropOff == null || pickUp == null) {
        return const SizedBox.shrink();
      }
      return _buildShellCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirmed Drop-off / Pick-up',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _buildSmallInfoCard(
              'Drop-off',
              formatDateTime(dropOff, TimeOfDay.fromDateTime(dropOff)),
            ),
            const SizedBox(height: 10),
            _buildSmallInfoCard(
              'Pick-up',
              formatDateTime(pickUp, TimeOfDay.fromDateTime(pickUp)),
            ),
          ],
        ),
      );
    }

    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirmed Appointment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _buildSmallInfoCard('Date', formatDate(confirmedAt)),
          const SizedBox(height: 10),
          _buildSmallInfoCard(
            'Time',
            TimeOfDay.fromDateTime(confirmedAt).format(context),
          ),
          const SizedBox(height: 10),
          _buildSmallInfoCard(
            'Duration',
            _durationLabel(_estimatedDurationMinutes),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRequestSection() {
    if (_isBookingLinkSubmission) {
      return const SizedBox.shrink();
    }
    final replyReceived = _hasCustomerReply();
    final customerPhone = sanitizeVanCustomerPhoneNumber(reply.phoneNumber);
    final customerEmail = reply.customerEmail.trim();

    if (replyReceived) {
      return _buildShellCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer request',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  'Customer reply received',
                  color: const Color(0xFF58D0A4),
                  icon: Icons.check_circle,
                  filled: true,
                ),
                if (reply.exactPinSaved)
                  _buildChip(
                    'Exact pin received',
                    color: const Color(0xFF58D0A4),
                    icon: Icons.location_on,
                    filled: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSmallInfoCard('Status', reply.requestStatusSummary),
          ],
        ),
      );
    }

    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                reply.requestBadgeLabel,
                color: reply.isRequestCancelled
                    ? const Color(0xFFFFC38C)
                    : reply.isRequestExpired
                    ? const Color(0xFFFFC38C)
                    : reply.isRequestPending
                    ? const Color(0xFF4A7DFF)
                    : const Color(0xFF58D0A4),
                icon: reply.isRequestCancelled
                    ? Icons.cancel
                    : reply.isRequestExpired
                    ? Icons.schedule
                    : reply.isRequestPending
                    ? Icons.mark_email_read_outlined
                    : reply.isRequestSubmitted || reply.isReplyReceived
                    ? Icons.check_circle
                    : Icons.send_outlined,
                filled: true,
              ),
              if (reply.isRequestPending)
                _buildChip(
                  reply.requestStatusLabel,
                  color: const Color(0xFF4A7DFF),
                  icon: Icons.hourglass_bottom,
                ),
              if (reply.isRequestPending ||
                  reply.isRequestSubmitted ||
                  reply.isReplyReceived)
                _buildChip(
                  reply.isRequestExactPinReceived
                      ? 'Exact pin received'
                      : reply.exactPinSaved
                      ? 'Exact pin received'
                      : reply.requiresAnyExactPin
                      ? 'Exact pin missing'
                      : 'Exact pin not requested',
                  color: reply.isRequestExactPinReceived
                      ? const Color(0xFF58D0A4)
                      : const Color(0xFFFFC38C),
                  icon: Icons.location_on,
                ),
              if (reply.isRequestExpired)
                _buildChip(
                  'Expired',
                  color: const Color(0xFFFFC38C),
                  icon: Icons.schedule,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSmallInfoCard('Status', reply.requestStatusSummary),
          const SizedBox(height: 10),
          _buildSmallInfoCard(
            'Request link',
            _requestLink() ?? 'No request link yet.',
          ),
          const SizedBox(height: 12),
          _buildRequestTools(customerPhone, customerEmail),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final actionWidgets = <Widget>[
                if (!_cancelled && !_completed) ...[
                  if (_canShowNavigateAction)
                    _buildActionButton(
                      label: 'Navigate',
                      icon: Icons.navigation,
                      tone: VanStatusTone.neutral,
                      onTap: () => unawaited(_navigate()),
                    ),
                  if (_canCallCustomer)
                    _buildActionButton(
                      label: 'Call customer',
                      icon: Icons.phone,
                      tone: VanStatusTone.primary,
                      onTap: () => unawaited(_callCustomer()),
                    ),
                  if (_canCallCustomer)
                    _buildActionButton(
                      label: 'Text customer',
                      icon: Icons.sms_outlined,
                      tone: VanStatusTone.primary,
                      onTap: () => unawaited(_textCustomer()),
                    ),
                ],
              ];

              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < actionWidgets.length; i++) ...[
                      actionWidgets[i],
                      if (i < actionWidgets.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final button in actionWidgets)
                    SizedBox(
                      width: constraints.maxWidth < 620
                          ? constraints.maxWidth
                          : 176,
                      child: button,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSection() {
    if (!reply.hasQuote) {
      return const SizedBox.shrink();
    }

    final quoteAmount = reply.quoteAmount;
    final amountLabel = quoteAmount == null
        ? 'Quote saved'
        : formatCurrency(quoteAmount);
    final declineReasonText = _declineReasonText();

    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quote',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            amountLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          if (reply.isQuoteDeclined && declineReasonText != null) ...[
            const SizedBox(height: 14),
            _buildSmallInfoCard('Decline reason', declineReasonText),
          ],
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'View quote',
            icon: Icons.open_in_new,
            tone: VanStatusTone.primary,
            onTap: _openQuote,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingQuoteActionButton() {
    if (!_isBookingLinkSubmission ||
        _completed ||
        _cancelled ||
        !_canSendQuoteForRequestFlow) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _openQuote,
        icon: const Icon(Icons.request_quote_outlined),
        label: Text(widget.reply.customerJourney.copy.businessAction),
        style: FilledButton.styleFrom(
          backgroundColor: vanStatusToneColor(VanStatusTone.primary),
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
    );
  }

  Widget _buildBookingReadyActionButton() {
    if (_isAlreadyInCalendar) {
      return const SizedBox.shrink();
    }
    if (!_canAddJobToCalendarAction ||
        !_hasCalendarReadyTime ||
        _isAwaitingRequiredExactPin) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: () => _openAddToCalendarFlow(addToCalendar: true),
        icon: const Icon(Icons.event_available),
        label: const Text('Add job to Calendar'),
        style: FilledButton.styleFrom(
          backgroundColor: vanStatusToneColor(VanStatusTone.primary),
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
    );
  }

  Widget _buildSetAgreedTimeActionButton() {
    if (!_canSetAgreedTimeAction) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: () => _openAddToCalendarFlow(addToCalendar: false),
        icon: const Icon(Icons.schedule_outlined),
        label: const Text('Set agreed time'),
        style: FilledButton.styleFrom(
          backgroundColor: vanStatusToneColor(VanStatusTone.primary),
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
    );
  }

  Widget _buildSchedulingStatusCard() {
    if (_schedulingStateLabel.isEmpty || !_shouldShowSchedulingSection) {
      return const SizedBox.shrink();
    }

    final primaryLabel = _schedulingPrimaryChipLabel;
    final secondaryLabel = _schedulingSecondaryChipLabel;
    final secondaryColor =
        secondaryLabel == 'Time needs arranging' ||
            secondaryLabel == 'Awaiting quote response' ||
            secondaryLabel == 'Awaiting exact pin' ||
            secondaryLabel == 'Proposed time sent'
        ? const Color(0xFF4A7DFF)
        : const Color(0xFF58D0A4);
    final secondaryIcon = switch (secondaryLabel) {
      'Awaiting quote response' => Icons.mark_email_unread_outlined,
      'Awaiting exact pin' => Icons.location_on_outlined,
      'Time needs arranging' => Icons.schedule_outlined,
      'Proposed time sent' => Icons.schedule_send_outlined,
      'Added to Calendar' => Icons.event_available_outlined,
      'Ready for Calendar' => Icons.event_available_outlined,
      'Time agreed' => Icons.event_available_outlined,
      _ => Icons.event_available_outlined,
    };

    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scheduling',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                primaryLabel,
                color: reply.isQuoteDeclined
                    ? vanStatusToneColor(VanStatusTone.danger)
                    : (reply.isQuoteAccepted || reply.isConfirmed
                          ? const Color(0xFF58D0A4)
                          : const Color(0xFF4A7DFF)),
                icon: reply.isQuoteDeclined
                    ? Icons.cancel_outlined
                    : (reply.isQuoteAccepted || reply.isConfirmed
                          ? Icons.check_circle
                          : Icons.request_quote_outlined),
                filled: true,
              ),
              _buildChip(
                secondaryLabel,
                color: secondaryColor,
                icon: secondaryIcon,
                filled:
                    secondaryLabel != 'Awaiting quote response' &&
                    secondaryLabel != 'Time needs arranging' &&
                    secondaryLabel != 'Proposed time sent',
              ),
              if (_quoteUiStatus.showExactPinReceivedChip)
                _buildChip(
                  _quoteUiStatus.exactPinChipLabel,
                  color: const Color(0xFF58D0A4),
                  icon: Icons.place_outlined,
                  filled: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSmallInfoCard('Status', _schedulingStateLabel),
          if (_schedulingStateHint.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _schedulingStateHint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimingAndSchedulingSection() {
    if (_hideTimingAndSchedulingForDeclinedQuote ||
        _shouldHideHistoricalBookingSections) {
      return const SizedBox.shrink();
    }

    final suppressAcceptedRequestTiming =
        _showAcceptedCustomerRequestSummary && _hasConfirmedAppointmentData;
    final showsPreferredTiming =
        _hasPreferredTimingData && !suppressAcceptedRequestTiming;
    final showsConfirmedAppointment = _showConfirmedAppointmentSection;
    final showsSharedScheduling = _shouldShowSchedulingSection;
    final showsSchedulingStatusCard =
        showsSharedScheduling &&
        !(reply.isQuoteAccepted || _isReadyForCalendar || _isAlreadyInCalendar);
    final showsBookingQuoteAction =
        _isBookingLinkSubmission && _canSendQuoteForRequestFlow;

    if (!showsPreferredTiming &&
        !showsConfirmedAppointment &&
        !showsSharedScheduling &&
        !showsBookingQuoteAction) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showsPreferredTiming) ...[
          _buildPreferredTimeSection(),
          if (showsConfirmedAppointment ||
              showsSchedulingStatusCard ||
              showsBookingQuoteAction)
            const SizedBox(height: 12),
        ],
        if (showsConfirmedAppointment) ...[
          _buildConfirmedAppointmentSection(),
          if (showsSharedScheduling || showsBookingQuoteAction)
            const SizedBox(height: 12),
        ],
        if (showsSharedScheduling) ...[
          if (showsSchedulingStatusCard) ...[
            _buildSchedulingStatusCard(),
            const SizedBox(height: 12),
          ],
          _buildSetAgreedTimeActionButton(),
          if (_canSetAgreedTimeAction) const SizedBox(height: 10),
          _buildBookingReadyActionButton(),
          if ((_canAddJobToCalendarAction &&
                  (_hasCalendarReadyTime || _canSetAgreedTimeAction)) ||
              showsBookingQuoteAction)
            const SizedBox(height: 10),
          if (!_isAlreadyInCalendar) _buildBookingCompletionHint(),
        ],
        if (showsBookingQuoteAction) _buildBookingQuoteActionButton(),
      ],
    );
  }

  Widget _buildBookingCompletionHint() {
    if ((!_hasRequest && _requestRecord == null) || _completed || _cancelled) {
      return const SizedBox.shrink();
    }
    if (!_canViewQuote ||
        reply.isConfirmed ||
        _isAlreadyInCalendar ||
        !reply.isQuoteAccepted) {
      return const SizedBox.shrink();
    }
    if (_isAwaitingAgreedTime) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        reply.isQuoteAccepted
            ? (_isAwaitingRequiredExactPin
                  ? 'Quote accepted. The exact pickup or drop-off pin still needs to be shared before this job can be added to your Calendar.'
                  : (_hasCalendarReadyTime
                        ? 'The customer accepted the quote and time. Add it to your Calendar when you\'re ready.'
                        : 'Set an exact agreed time before adding this job to your Calendar.'))
            : '',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.66),
          fontSize: 12.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openQuote() {
    unawaited(openVanQuoteWorkflowForJob(context, reply));
  }

  Widget _buildBottomCreateQuoteButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        key: const ValueKey('job_detail_bottom_create_quote_button'),
        onPressed: _openQuote,
        icon: const Icon(Icons.request_quote_outlined),
        label: Text(widget.reply.customerJourney.copy.businessAction),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF58D0A4),
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
    );
  }

  void _copyQuoteLink() {
    final link = reply.activeQuoteResponseLink;
    Clipboard.setData(ClipboardData(text: link));
    _showSnack('Quote link copied.');
  }

  Future<void> _createInvoice() async {
    await openCreateInvoiceMockPage(context, reply);
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _openInvoice() async {
    final savedInvoice = _savedInvoice;
    if (savedInvoice == null) {
      return;
    }

    final updated = await openVanInvoicePreviewPage(context, savedInvoice);
    if (!mounted || updated == null) {
      return;
    }

    setState(() {});
  }

  Future<_CompletedJobNextStep?> _showCompletedJobNextStepSheet() {
    return showModalBottomSheet<_CompletedJobNextStep>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(
                                0xFF58D0A4,
                              ).withValues(alpha: 0.18),
                              border: Border.all(
                                color: const Color(
                                  0xFF58D0A4,
                                ).withValues(alpha: 0.32),
                              ),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Job completed',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This job has been moved to Customer History.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(_CompletedJobNextStep.createInvoice),
                          icon: Icon(
                            _savedInvoice == null
                                ? Icons.receipt_long_outlined
                                : Icons.visibility_outlined,
                          ),
                          label: const Text('Create invoice from quote'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF58D0A4),
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(_CompletedJobNextStep.stayHere),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Stay here'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(_CompletedJobNextStep.backToCalendar),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back to Calendar'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.86,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
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

  Future<void> _navigate() async {
    await openVanJobNavigation(context, reply);
  }

  Future<void> _callCustomer() async {
    await launchCustomerPhone(context, _displayPhone);
  }

  Future<void> _textCustomer() async {
    final launched = await textCustomerRequest(
      phoneNumber: _displayPhone,
      message:
          'Hi $_displayCustomerName, thanks for accepting the quote. Let\'s arrange a time that works for your ${_displayJobTitle.toLowerCase()}.',
    );
    if (!mounted) {
      return;
    }
    if (launched) {
      _showSnack('Text message opened. Send it from your SMS app.');
      return;
    }
    _showSnack('Could not open text message.');
  }

  Future<void> _editJobDetails() async {
    final saved = await openDriverJobEditDetailsSheet(context, job: reply);

    if (!mounted || saved == null) {
      return;
    }

    setState(() {});
    _showSnack('Job updated.');
  }

  Future<void> _changeJobDateTime() async {
    final changed = await openDriverJobDateTimeChangeFlow(context, job: reply);
    if (!mounted || !changed) {
      return;
    }

    setState(() {});
    _showSnack('Job time updated.');
  }

  Future<void> _cancelJob() async {
    if (_completed || _cancelled) {
      return;
    }

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
            'Cancel this job?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This will remove it from active work but keep a record.',
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
              child: const Text('Keep job'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC38C),
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancel job'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    DriverReplyMockState.instance.cancelJob(jobId: _jobId);
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnack('Job cancelled.');
  }

  Future<void> _deleteJob() async {
    final deleted = await confirmDriverJobDelete(context, job: reply);
    if (!mounted || deleted != true) {
      return;
    }

    _showSnack('Job deleted.');
    Navigator.of(context).pop(VanJobActionResult.deleted);
  }

  Future<void> _markCompleted() async {
    final completionAction = vanCalendarCompletionActionLabel(reply);
    final scheduledAt = _effectiveScheduledAt ?? _acceptedOrProposedScheduledAt;
    final shouldComplete =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF142031),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                '$completionAction?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Text(
                scheduledAt != null
                    ? 'This job is booked for ${formatDateTime(scheduledAt, TimeOfDay.fromDateTime(scheduledAt))}. Mark it complete?'
                    : 'Mark this job complete now?',
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Text('Cancel'),
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
            );
          },
        ) ??
        false;

    if (!shouldComplete) {
      return;
    }

    _completedInSession = true;
    final completedAt = DateTime.now();
    final persisted = await DriverReplyMockState.instance.persistCompletedJob(
      jobId: _jobId,
      completedAt: completedAt,
    );
    if (!persisted) {
      if (!mounted) {
        return;
      }
      setState(() {
        _completedInSession = false;
      });
      _showSnack('Could not complete this job. Please try again.');
      return;
    }
    try {
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[COMPLETE_JOB_REFRESH_ERROR] error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) {
      return;
    }

    setState(() {});
    final nextStep = await _showCompletedJobNextStepSheet();
    if (!mounted) {
      return;
    }
    switch (nextStep) {
      case _CompletedJobNextStep.createInvoice:
        if (_savedInvoice == null) {
          await _createInvoice();
        } else {
          await _openInvoice();
        }
        break;
      case _CompletedJobNextStep.backToCalendar:
        _popWithCurrentResult();
        break;
      case _CompletedJobNextStep.stayHere:
      case null:
        setState(() {});
        break;
    }
  }

  Widget _buildShellCard({required Widget child}) {
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

  Widget _buildChip(
    String label, {
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
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
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
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

  Widget _buildSmallInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedJobCallout() {
    return _buildShellCard(
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
                  color: const Color(0xFF58D0A4).withValues(alpha: 0.18),
                  border: Border.all(
                    color: const Color(0xFF58D0A4).withValues(alpha: 0.32),
                  ),
                ),
                child: const Icon(Icons.check_circle, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Job completed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This job is now in Customer History. You can create the invoice now or head back to Calendar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final buttons = <Widget>[
                _buildActionButton(
                  label: _createInvoiceActionLabel,
                  icon: _savedInvoice == null
                      ? Icons.receipt_long_outlined
                      : Icons.visibility_outlined,
                  tone: _savedInvoice == null
                      ? VanStatusTone.primary
                      : VanStatusTone.primary,
                  filled: _savedInvoice == null,
                  onTap: _savedInvoice == null ? _createInvoice : _openInvoice,
                ),
                _buildActionButton(
                  label: 'Back to Calendar',
                  icon: Icons.arrow_back_rounded,
                  tone: VanStatusTone.neutral,
                  onTap: _popWithCurrentResult,
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      buttons[i],
                      if (i < buttons.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final button in buttons)
                    SizedBox(
                      width: constraints.maxWidth < 620
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2,
                      child: button,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    bool filled = false,
    VanStatusTone tone = VanStatusTone.neutral,
  }) {
    final primaryNavigate = label == 'Navigate';
    final color = primaryNavigate
        ? const Color(0xFF4A7DFF)
        : tone == VanStatusTone.neutral
        ? Colors.white
        : vanStatusToneColor(tone);
    final contentColor = filled || primaryNavigate ? Colors.white : color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: primaryNavigate
                ? color
                : filled
                ? color.withValues(
                    alpha: tone == VanStatusTone.neutral ? 0.10 : 0.20,
                  )
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: primaryNavigate
                  ? color
                  : color.withValues(
                      alpha: tone == VanStatusTone.neutral ? 0.16 : 0.24,
                    ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: contentColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _blockCustomer() async {
    final result = await showVanBlockCustomerDialog(context);
    if (result == null || !mounted) {
      return;
    }
    final blocked = DriverReplyMockState.instance.blockCustomerForJob(
      job: reply,
      request: _requestRecord,
      reason: result.reason,
      note: result.note,
    );
    if (!mounted) {
      return;
    }
    if (!blocked) {
      _showSnack('No phone number saved for this customer.');
      return;
    }
    _showSnack('Customer blocked.');
    setState(() {});
  }

  Future<void> _unblockCustomer() async {
    final blockedRecord = _blockedCustomerMatch;
    if (blockedRecord == null) {
      return;
    }
    final unblocked = DriverReplyMockState.instance.unblockCustomerByPhone(
      blockedRecord.normalizedPhone,
    );
    if (!mounted) {
      return;
    }
    if (unblocked) {
      _showSnack('Customer unblocked.');
      setState(() {});
    }
  }

  Widget _buildBlockedCustomerWarningCard() {
    final blockedRecord = _blockedCustomerMatch;
    if (blockedRecord == null) {
      return const SizedBox.shrink();
    }
    final note = blockedRecord.note.trim();

    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blocked customer match',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This phone number is marked as blocked.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 10),
          _buildSmallInfoCard('Reason', blockedRecord.reason),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSmallInfoCard('Note', note),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final replyDetailCards = _buildReplyDetailCards();
    final hasReplyDetails = replyDetailCards.isNotEmpty;
    final hasBookingPhotoSection =
        _bookingLinkPhotoUrls().isNotEmpty ||
        _bookingLinkPhotoStatus().isNotEmpty;
    final scheduledAt = _effectiveScheduledAt;
    final scheduledLabel =
        _isDropOffPickupRequest &&
            _dropOffDateTime != null &&
            _pickUpDateTime != null
        ? 'Drop-off ${formatDateTime(_dropOffDateTime!, TimeOfDay.fromDateTime(_dropOffDateTime!))}\n'
              'Pick-up ${formatDateTime(_pickUpDateTime!, TimeOfDay.fromDateTime(_pickUpDateTime!))}'
        : scheduledAt == null
        ? '${sanitizeVanText(reply.jobDateLabel).trim()} at ${sanitizeVanText(reply.jobTimeLabel).trim()}'
        : formatDateTime(scheduledAt, TimeOfDay.fromDateTime(scheduledAt));
    final displayJobTitle = _displayJobTitle.isEmpty
        ? sanitizeVanText(reply.jobTitle).trim()
        : _displayJobTitle;
    final displayCustomerName = _displayCustomerName.isEmpty
        ? sanitizeVanText(reply.customerName).trim()
        : _displayCustomerName;
    final displayAddress = _displayAddress.isEmpty
        ? sanitizeVanText(reply.address).trim()
        : _displayAddress;
    final displayPhone = _displayPhone;
    final isNewJobReplyReviewState =
        !_isBookingLinkSubmission &&
        _hasCustomerReply() &&
        !reply.hasQuote &&
        !reply.isQuoteAccepted &&
        !reply.isConfirmed &&
        !_completed &&
        !_cancelled;
    final pageTitle = reply.isQuoteDeclined
        ? 'Quote declined'
        : isNewJobReplyReviewState
        ? 'Customer reply received'
        : displayJobTitle;
    final timingAndSchedulingSection = _buildTimingAndSchedulingSection();
    final subtitle = _cancelled
        ? 'This job has been cancelled.'
        : reply.isQuoteDeclined
        ? 'Review the declined quote below and send a revised quote if you would like to make another offer.'
        : _isAlreadyInCalendar
        ? 'This job has been added to your calendar.'
        : reply.isQuoteAccepted && !reply.isConfirmed
        ? (_isAwaitingAgreedTime
              ? (_isAwaitingRequiredExactPin
                    ? 'The customer accepted this quote. A time still needs arranging and the exact pickup or drop-off pin still needs sharing before the job can be added to Calendar.'
                    : 'The customer accepted this quote. A time still needs arranging before the job can be added to Calendar.')
              : (_isAwaitingRequiredExactPin
                    ? 'The customer accepted this quote. The exact pickup or drop-off pin still needs sharing before the job can be added to Calendar.'
                    : 'The customer accepted this quote. Add it to your calendar when you\'re ready.'))
        : _hasManualAgreedTime
        ? (_isAwaitingRequiredExactPin
              ? 'An agreed time has been saved. The exact pickup or drop-off pin still needs sharing before the job can be added to Calendar.'
              : 'An agreed time has been saved. Add it to your calendar when you\'re ready.')
        : _completed
        ? 'Job completed. Create the invoice now or head back to Calendar when you are ready.'
        : reply.isConfirmed
        ? (_isBookingLinkSubmission && _isScheduledForFutureDate
              ? 'Scheduled in your calendar.'
              : 'Job ready for work.')
        : isNewJobReplyReviewState
        ? 'Review the customer’s answers before sending a quote.'
        : _hasCustomerReply()
        ? (_isBookingLinkSubmission
              ? 'Booking request received.'
              : 'Customer reply received.')
        : 'Active job record.';
    _logPreferredTimingState();

    return PopScope<VanJobActionResult?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _popWithCurrentResult();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AppTheme.backgroundImage(),
            Container(color: Colors.black.withValues(alpha: 0.34)),
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(16, 14, 16, 140 + bottomPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailBackButton(onTap: _popWithCurrentResult),
                        const SizedBox(height: 18),
                        Text(
                          pageTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.76),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildShellCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: const Color(
                                        0xFF58D0A4,
                                      ).withValues(alpha: 0.18),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF58D0A4,
                                        ).withValues(alpha: 0.32),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayCustomerName,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          scheduledLabel,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.70,
                                                ),
                                                height: 1.35,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCalendarQuickLinkButton(),
                                  const SizedBox(width: 8),
                                  _buildOverflowMenuButton(),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildSmallInfoCard(
                                'Customer',
                                displayCustomerName,
                              ),
                              const SizedBox(height: 10),
                              _buildSmallInfoCard('Job', displayJobTitle),
                              const SizedBox(height: 10),
                              _buildSmallInfoCard('Date/time', scheduledLabel),
                              const SizedBox(height: 10),
                              if (displayAddress.isNotEmpty) ...[
                                _buildSmallInfoCard('Address', displayAddress),
                                const SizedBox(height: 10),
                              ],
                              _buildSmallInfoCard(
                                'Phone',
                                displayPhone.isEmpty
                                    ? 'No phone saved'
                                    : displayPhone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBlockedCustomerWarningCard(),
                        if (_blockedCustomerMatch != null)
                          const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _actionsSectionKey,
                          child: _buildActionsSection(),
                        ),
                        if (hasReplyDetails) ...[
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: _customerReplySectionKey,
                            child: _buildCustomerReplySection(replyDetailCards),
                          ),
                        ],
                        if (hasBookingPhotoSection) ...[
                          const SizedBox(height: 12),
                          _buildPhotosSection(),
                        ],
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _quoteSectionKey,
                          child: _buildQuoteSection(),
                        ),
                        if (_completed &&
                            !_completedInSession &&
                            !widget.historyMode) ...[
                          const SizedBox(height: 12),
                          _buildCompletedJobCallout(),
                        ],
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        if (!_isBookingLinkSubmission &&
                            !_shouldHideHistoricalBookingSections)
                          KeyedSubtree(
                            key: _customerRequestSectionKey,
                            child: _buildCustomerRequestSection(),
                          ),
                        if (_shouldShowBottomCreateQuoteButton) ...[
                          const SizedBox(height: 12),
                          _buildBottomCreateQuoteButton(),
                        ],
                        if (timingAndSchedulingSection is! SizedBox) ...[
                          const SizedBox(height: 12),
                          KeyedSubtree(
                            key: _timingSectionKey,
                            child: timingAndSchedulingSection,
                          ),
                        ],
                        if (_shouldShowPrimaryCompleteJob) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: _markCompleted,
                              icon: const Icon(Icons.task_alt),
                              label: Text(
                                vanCalendarCompletionActionLabel(reply),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
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
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditJobDetailsSheet extends StatefulWidget {
  const _EditJobDetailsSheet({required this.job});

  final DriverCustomerReplyMockData job;

  @override
  State<_EditJobDetailsSheet> createState() => _EditJobDetailsSheetState();
}

class _EditJobDetailsSheetState extends State<_EditJobDetailsSheet> {
  late final TextEditingController _customerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _addressController;
  late final TextEditingController _postcodeController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.job;
    _customerNameController = TextEditingController(text: current.customerName);
    _phoneController = TextEditingController(text: current.phoneNumber);
    _emailController = TextEditingController(text: current.customerEmail);
    _jobTitleController = TextEditingController(text: current.jobTitle);
    _addressController = TextEditingController(text: current.address);
    _postcodeController = TextEditingController(text: current.postcode);
    _notesController = TextEditingController(text: _initialNotesText(current));
    final scheduledAt = current.scheduledAtOrParsed ?? DateTime.now();
    _selectedDate = DateUtils.dateOnly(scheduledAt);
    _selectedTime = TimeOfDay.fromDateTime(scheduledAt);
  }

  String _initialNotesText(DriverCustomerReplyMockData job) {
    final cleanedLines = job.notesMessage
        .split('\n')
        .map((line) => line.trim())
        .where((line) {
          if (line.isEmpty) {
            return false;
          }
          final normalized = line.toLowerCase();
          if (normalized.startsWith('source:')) {
            return false;
          }
          if (normalized.startsWith('photos requested')) {
            return false;
          }
          if (normalized == 'photos' || normalized.startsWith('photos:')) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    return cleanedLines.join('\n');
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _jobTitleController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const monthNames = <String>[
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
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4A7DFF),
              surface: Color(0xFF101826),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF101826),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedDate = DateUtils.dateOnly(picked);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF101826),
            ),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4A7DFF),
              surface: Color(0xFF101826),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedTime = picked;
    });
  }

  Future<void> _saveChanges() async {
    if (_saving) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
    });

    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final pastScheduleMessage = validateVanMateScheduledAt(scheduledAt);
    if (pastScheduleMessage != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pastScheduleMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final updated = DriverReplyMockState.instance.updateJobDetails(
        jobId: widget.job.jobId,
        customerName: _customerNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        customerEmail: _emailController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        address: _addressController.text.trim(),
        postcode: _postcodeController.text.trim(),
        notesMessage: _notesController.text.trim(),
        scheduledAt: scheduledAt,
      );

      if (updated == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _saving = false;
        });
        return;
      }

      await DriverReplyMockState.instance.saveToStorage(syncCloud: false);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } on VanPastScheduleException catch (error) {
      debugPrint('[VanJobDetailEdit] past schedule blocked: ${error.message}');
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on VanScheduleOverlapException catch (error) {
      debugPrint('[VanJobDetailEdit] overlap blocked: ${error.message}');
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      debugPrint('[VanJobDetailEdit] save failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save job details. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: !_saving,
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        labelOpacity: 0.68,
        hintOpacity: 0.50,
        fillColor: Colors.white.withValues(alpha: 0.06),
        focusedBorderWidth: 1.4,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            color: const Color(0xFF0E1520).withValues(alpha: 0.97),
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  topInset > 0 ? 22 : 18,
                  18,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit job details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Update the saved local job without creating a duplicate.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildField(_customerNameController, 'Customer name'),
                    const SizedBox(height: 10),
                    _buildField(_jobTitleController, 'Job title / reference'),
                    const SizedBox(height: 10),
                    _buildField(
                      _phoneController,
                      'Phone',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      _emailController,
                      'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _buildField(_addressController, 'Address'),
                    const SizedBox(height: 10),
                    _buildField(_postcodeController, 'Postcode'),
                    const SizedBox(height: 10),
                    _buildField(
                      _notesController,
                      'Notes',
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: _formatDate(_selectedDate),
                            icon: Icons.event,
                            color: const Color(0xFF4A7DFF),
                            onTap: _saving ? null : _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionButton(
                            label: _formatTime(_selectedTime),
                            icon: Icons.schedule,
                            color: const Color(0xFF4A7DFF),
                            onTap: _saving ? null : _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(null),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _saveChanges,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4A7DFF),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _saving
                                  ? const SizedBox(
                                      key: ValueKey('saving'),
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      key: ValueKey('save'),
                                      'Save changes',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBackButton extends StatelessWidget {
  const _DetailBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VanBackBusinessHubButtons(onBack: onTap);
  }
}
