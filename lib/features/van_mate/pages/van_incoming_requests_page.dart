import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_block_customer_dialog.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_job_request_state.dart';
import '../helpers/van_quote_decline.dart';
import '../helpers/van_quote_ui_status.dart';
import '../helpers/van_status_tone.dart';
import '../models/van_job_request_record.dart';
import 'driver_customer_reply_mock_page.dart';
import 'job_detail_page.dart';
import '../widgets/van_back_business_hub_buttons.dart';

Future<void> openVanIncomingRequestsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const VanIncomingRequestsPage()),
  );
}

List<DriverCustomerReplyMockData> sortIncomingJobsForDisplay(
  Iterable<DriverCustomerReplyMockData> jobs, {
  required VanJobRequestRecord? Function(String jobId) requestForJob,
}) {
  final sortedJobs = jobs.toList(growable: false);
  final requestCache = <String, VanJobRequestRecord?>{};

  VanJobRequestRecord? requestFor(DriverCustomerReplyMockData job) {
    return requestCache.putIfAbsent(job.jobId, () => requestForJob(job.jobId));
  }

  DateTime createdAtFor(DriverCustomerReplyMockData job) {
    final request = requestFor(job);
    return request?.createdAt ??
        job.requestCreatedAt ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String stableIdFor(DriverCustomerReplyMockData job) {
    final request = requestFor(job);
    final requestId = request?.requestId.trim() ?? '';
    if (requestId.isNotEmpty) {
      return requestId;
    }
    final jobRequestId = job.requestId?.trim() ?? '';
    if (jobRequestId.isNotEmpty) {
      return jobRequestId;
    }
    return job.jobId.trim();
  }

  sortedJobs.sort((a, b) {
    final createdComparison = createdAtFor(b).compareTo(createdAtFor(a));
    if (createdComparison != 0) {
      return createdComparison;
    }

    final stableIdComparison = stableIdFor(a).compareTo(stableIdFor(b));
    if (stableIdComparison != 0) {
      return stableIdComparison;
    }

    return a.jobId.compareTo(b.jobId);
  });

  return sortedJobs;
}

String incomingJobStableKey(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  final requestId = request?.requestId.trim() ?? '';
  if (requestId.isNotEmpty) {
    return 'incoming-$requestId';
  }
  final jobRequestId = job.requestId?.trim() ?? '';
  if (jobRequestId.isNotEmpty) {
    return 'incoming-$jobRequestId';
  }
  return 'incoming-${job.jobId}';
}

class IncomingJobTimingDisplay {
  const IncomingJobTimingDisplay({required this.label, required this.value});

  final String label;
  final String value;
}

IncomingJobTimingDisplay buildIncomingJobTimingDisplay(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  final confirmedDateTime = job.agreedDateTime ?? job.scheduledAtOrParsed;
  final shouldShowConfirmedAppointment =
      job.isQuoteAccepted &&
      confirmedDateTime != null &&
      !job.isAwaitingAgreedTime &&
      (job.hasAgreedSchedulingTime || job.isScheduledInCalendarState);
  if (shouldShowConfirmedAppointment) {
    return IncomingJobTimingDisplay(
      label: 'Confirmed appointment',
      value:
          '${_formatIncomingJobDate(confirmedDateTime)} • ${_formatIncomingJobTime(confirmedDateTime)}',
    );
  }

  final preferredDate = request?.preferredDate ?? job.preferredDate;
  final preferredWindowValue =
      request?.preferredTimeWindow.trim().isNotEmpty == true
      ? request!.preferredTimeWindow.trim().toLowerCase()
      : job.preferredTimeWindow.trim().toLowerCase();
  final preferredWindow = _preferredWindowLabel(preferredWindowValue);
  final isFlexible =
      (request?.preferredIsFlexible ?? false) || job.preferredIsFlexible;
  final preferredParts = <String>[];
  if (preferredDate != null) {
    preferredParts.add(_formatIncomingJobDate(preferredDate));
  }
  if (preferredWindow.isNotEmpty) {
    preferredParts.add(preferredWindow);
  }
  if (isFlexible) {
    preferredParts.add('Flexible');
  }
  return IncomingJobTimingDisplay(
    label: 'Preferred date/time',
    value: preferredParts.join(' • '),
  );
}

String _formatIncomingJobDate(DateTime date) {
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

String _formatIncomingJobTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _preferredWindowLabel(String value) {
  switch (value) {
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

bool vanIncomingJobIsBookingLinkRequest(VanJobRequestRecord? request) {
  final source = request?.source.trim().toLowerCase() ?? '';
  if (source == 'booking_link') {
    return true;
  }
  final notes = request?.additionalNotes.toLowerCase() ?? '';
  return notes.contains('source: booking link');
}

bool vanIncomingJobHasGenuineCustomerReplyForStatus(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  if (job.isQuoteAccepted ||
      job.isQuoteDeclined ||
      job.quoteRespondedAt != null) {
    return true;
  }

  final timingChoice = job.quoteTimingChoice.trim().toLowerCase();
  if (timingChoice == 'arrange_another_time' ||
      timingChoice == 'accepted_proposed_time') {
    return true;
  }

  return !vanIncomingJobIsBookingLinkRequest(request) && job.hasCustomerReply;
}

VanQuoteUiStatus deriveVanIncomingJobDisplayQuoteUiStatus(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  final status = job.quoteUiStatus;
  if (!vanIncomingJobIsBookingLinkRequest(request) ||
      job.hasQuote ||
      vanIncomingJobHasGenuineCustomerReplyForStatus(job, request: request) ||
      status.primaryChipLabel != 'Request received' ||
      status.secondaryChipLabel != 'Reply received') {
    return status;
  }

  return const VanQuoteUiStatus(
    primaryChipLabel: 'Request received',
    secondaryChipLabel: 'Request received',
    statusLabel: 'Request received',
    summary: 'Request received.',
    nextActionText: 'Open to review details and send a quote.',
  );
}

class VanIncomingRequestsPage extends StatefulWidget {
  const VanIncomingRequestsPage({super.key});

  @override
  State<VanIncomingRequestsPage> createState() =>
      _VanIncomingRequestsPageState();
}

class _VanIncomingRequestsPageState extends State<VanIncomingRequestsPage> {
  static const Duration _loadTimeout = Duration(seconds: 12);

  bool _loading = true;
  String? _errorMessage;
  final Set<String> _deletingRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    debugPrint('[IncomingRequestsPage] opened');
    DriverReplyMockState.instance.addListener(_handleStateChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    DriverReplyMockState.instance.removeListener(_handleStateChanged);
    super.dispose();
  }

  void _handleStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    debugPrint('[IncomingRequestsPage] load start');
    try {
      await DriverReplyMockState.instance.loadFromStorage().timeout(
        _loadTimeout,
      );
      final cachedCount = DriverReplyMockState.instance.pendingJobs.length;
      final deletedKeysCount = DriverReplyMockState.instance
          .debugDeletedRequestKeyCount();
      debugPrint(
        '[IncomingRequestsPage] local data loaded count=$cachedCount deletedKeysCount=$deletedKeysCount',
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = null;
        });
      }

      final ownerUid = DriverReplyMockState.instance
          .currentUidForDebug()
          .trim();
      debugPrint(
        '[IncomingRequestsPage] refresh query uid=${ownerUid.isEmpty ? '(none)' : ownerUid} paths=users/$ownerUid/van_jobs, public_job_requests(ownerUid=$ownerUid)',
      );

      await DriverReplyMockState.instance
          .refreshJobsFromCloud(forceServer: true)
          .timeout(_loadTimeout);
      final loadedCount = DriverReplyMockState.instance.pendingJobs.length;
      debugPrint(
        '[IncomingRequestsPage] cloud refresh loaded count=$loadedCount',
      );
      for (final job in DriverReplyMockState.instance.pendingJobs) {
        final request = DriverReplyMockState.instance.requestForJob(job.jobId);
        final source = request?.source.trim().isNotEmpty == true
            ? request!.source.trim()
            : 'manual_or_old_request';
        debugPrint(
          '[IncomingRequestsPage] request jobId=${job.jobId} source=$source',
        );
      }
    } catch (error) {
      debugPrint('[IncomingRequestsPage] load error error=$error');
      if (!mounted) {
        return;
      }
      final hasUsableRequests =
          DriverReplyMockState.instance.pendingJobs.isNotEmpty;
      setState(() {
        _errorMessage = hasUsableRequests
            ? null
            : 'Could not load Incoming Jobs right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      debugPrint('[IncomingRequestsPage] load complete loading=$_loading');
    }
  }

  Future<void> _retryLoad() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = null;
    });
    await _load();
  }

  Future<void> _openRequestDetails(DriverCustomerReplyMockData job) async {
    final request = DriverReplyMockState.instance.requestForJob(job.jobId);
    final baseReply =
        DriverReplyMockState.instance.realReplyForJob(job.jobId) ?? job;
    debugPrint(
      '[IncomingRequestsPage] open details jobId=${job.jobId} requestId=${request?.requestId ?? '(none)'} preferredDate=${request?.preferredDate?.toIso8601String() ?? baseReply.preferredDate?.toIso8601String() ?? '(none)'} preferredTimeWindow=${request?.preferredTimeWindow.isNotEmpty == true ? request!.preferredTimeWindow : (baseReply.preferredTimeWindow.isEmpty ? '(none)' : baseReply.preferredTimeWindow)} preferredIsFlexible=${request?.preferredIsFlexible ?? baseReply.preferredIsFlexible} preferredTimingNote=${request?.preferredTimingNote.trim().isNotEmpty == true ? request!.preferredTimingNote.trim() : (baseReply.preferredTimingNote.trim().isEmpty ? '(none)' : baseReply.preferredTimingNote.trim())}',
    );
    final enrichedReply = request == null
        ? baseReply
        : baseReply.copyWith(
            preferredDate: request.preferredDate,
            preferredTimeWindow: request.preferredTimeWindow,
            preferredIsFlexible: request.preferredIsFlexible,
            preferredTimingNote: request.preferredTimingNote,
            additionalNotes: request.additionalNotes,
          );
    await openDriverJobDetailMockPage(
      context,
      reply: enrichedReply,
      completed: false,
    );
  }

  Future<void> _reviseQuote(DriverCustomerReplyMockData job) async {
    await openVanQuoteWorkflowForJob(context, job);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _callCustomer(DriverCustomerReplyMockData job) async {
    final phone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    if (phone.isEmpty) {
      return;
    }
    await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _textCustomer(DriverCustomerReplyMockData job) async {
    final phone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    if (phone.isEmpty) {
      return;
    }
    await launchUrl(
      Uri(scheme: 'sms', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _confirmDeleteRequest(
    DriverCustomerReplyMockData job,
    VanJobRequestRecord? request,
  ) async {
    final state = DriverReplyMockState.instance;
    final requestId =
        (request?.requestId.trim().isNotEmpty == true
                ? request!.requestId.trim()
                : (job.requestId?.trim() ?? ''))
            .trim();
    final deleteKey = state.stableDeleteKeyForJob(job, request: request);
    final source = request?.source.trim().isNotEmpty == true
        ? request!.source.trim()
        : 'legacy_local';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete request?'),
        content: const Text(
          'This will permanently remove this request from Van Mate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD24C4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deletingRequestIds.add(deleteKey);
    });
    debugPrint(
      '[IncomingRequestsPage] delete tapped title=${job.jobTitle.trim().isNotEmpty ? job.jobTitle.trim() : '(none)'} customer=${job.customerName.trim().isNotEmpty ? job.customerName.trim() : '(none)'} source=$source requestId=${requestId.isEmpty ? '(none)' : requestId} linkedJobId=${request?.linkedJobId.trim().isNotEmpty == true ? request!.linkedJobId.trim() : job.jobId} legacyKey=$deleteKey',
    );

    final result = await state.deleteIncomingRequest(
      requestId: requestId,
      localJobId: job.jobId,
      source: source,
    );

    if (mounted) {
      setState(() {
        _deletingRequestIds.remove(deleteKey);
      });
    }

    if (!mounted) {
      return;
    }

    switch (result.status) {
      case IncomingRequestDeleteStatus.deleted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case IncomingRequestDeleteStatus.removedFromDeviceOnly:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Removed from this device. Could not remove from cloud.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case IncomingRequestDeleteStatus.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove request.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
    }

    if (result.status != IncomingRequestDeleteStatus.failed) {
      unawaited(_load());
    }
  }

  Future<void> _confirmBlockCustomer(
    DriverCustomerReplyMockData job,
    VanJobRequestRecord? request,
  ) async {
    final result = await showVanBlockCustomerDialog(context);
    if (result == null || !mounted) {
      return;
    }
    final blocked = DriverReplyMockState.instance.blockCustomerForJob(
      job: job,
      request: request,
      reason: result.reason,
      note: result.note,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          blocked
              ? 'Customer blocked.'
              : 'No phone number saved for this customer.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _unblockCustomer(DriverCustomerReplyMockData job) async {
    final blockedRecord = DriverReplyMockState.instance.blockedCustomerForJob(
      job,
    );
    if (blockedRecord == null) {
      return;
    }
    final unblocked = DriverReplyMockState.instance.unblockCustomerByPhone(
      blockedRecord.normalizedPhone,
    );
    if (!mounted || !unblocked) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Customer unblocked.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _deleteKeyFor(
    DriverCustomerReplyMockData job,
    VanJobRequestRecord? request,
  ) {
    return DriverReplyMockState.instance.stableDeleteKeyForJob(
      job,
      request: request,
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = sortIncomingJobsForDisplay(
      DriverReplyMockState.instance.pendingJobs,
      requestForJob: DriverReplyMockState.instance.requestForJob,
    );
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final showErrorCard = _errorMessage != null && jobs.isEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Incoming Jobs'),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        bottomInset + 24,
                      ),
                      children: [
                        if (showErrorCard) ...[
                          _IncomingErrorCard(
                            message: _errorMessage!,
                            onRetry: _retryLoad,
                          ),
                        ],
                        if (showErrorCard || jobs.isNotEmpty)
                          const SizedBox(height: 12),
                        if (jobs.isEmpty)
                          const _IncomingEmptyCard()
                        else
                          for (var i = 0; i < jobs.length; i++) ...[
                            () {
                              final job = jobs[i];
                              final request = DriverReplyMockState.instance
                                  .requestForJob(job.jobId);
                              final deleteKey = _deleteKeyFor(job, request);

                              return _IncomingRequestCard(
                                key: ValueKey(
                                  incomingJobStableKey(job, request: request),
                                ),
                                job: job,
                                request: request,
                                deleting: _deletingRequestIds.contains(
                                  deleteKey,
                                ),
                                onViewDetails: () => _openRequestDetails(job),
                                onReviseQuote: () => _reviseQuote(job),
                                onCallCustomer: () => _callCustomer(job),
                                onTextCustomer: () => _textCustomer(job),
                                onBlock: () =>
                                    _confirmBlockCustomer(job, request),
                                onUnblock: () => _unblockCustomer(job),
                                onDelete: () =>
                                    _confirmDeleteRequest(job, request),
                              );
                            }(),
                            if (i < jobs.length - 1) const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _IncomingEmptyCard extends StatelessWidget {
  const _IncomingEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const _IncomingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No incoming jobs yet.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingErrorCard extends StatelessWidget {
  const _IncomingErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _IncomingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load requests',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _IncomingRequestAction {
  viewDetails,
  blockCustomer,
  unblockCustomer,
  deleteRequest,
}

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    super.key,
    required this.job,
    required this.request,
    required this.deleting,
    required this.onViewDetails,
    required this.onReviseQuote,
    required this.onCallCustomer,
    required this.onTextCustomer,
    required this.onBlock,
    required this.onUnblock,
    required this.onDelete,
  });

  final DriverCustomerReplyMockData job;
  final VanJobRequestRecord? request;
  final bool deleting;
  final VoidCallback onViewDetails;
  final VoidCallback onReviseQuote;
  final VoidCallback onCallCustomer;
  final VoidCallback onTextCustomer;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onDelete;

  String _sourceLabel() {
    if (_isPreviewTest()) {
      return 'Preview';
    }
    final source = request?.source.trim().toLowerCase() ?? '';
    if (source == 'booking_link') {
      return 'Booking Link';
    }
    if (source == 'manual' ||
        source == 'new_job' ||
        source == 'create_job' ||
        source == 'newjob') {
      return 'Manual';
    }
    final notes = request?.additionalNotes.toLowerCase() ?? '';
    if (notes.contains('source: booking link')) {
      return 'Booking Link';
    }
    return 'Old request';
  }

  bool _isPreviewTest() {
    if (request?.isPreview == true) {
      return true;
    }
    final source = request?.source.trim().toLowerCase() ?? '';
    return source == 'preview';
  }

  String _serviceName() {
    final selectedServiceName = request?.selectedServiceName.trim() ?? '';
    if (selectedServiceName.isNotEmpty) {
      return selectedServiceName;
    }
    final requestTitle = request?.publicJobTitle.trim() ?? '';
    if (requestTitle.isNotEmpty) {
      return requestTitle;
    }
    final jobTitle = job.jobTitle.trim();
    return jobTitle.isEmpty ? 'Service request' : jobTitle;
  }

  String _postcode() {
    final requestPostcode = request?.customerPostcode.trim() ?? '';
    if (requestPostcode.isNotEmpty) {
      return requestPostcode;
    }
    return job.postcode.trim();
  }

  bool _addressAlreadyContainsPostcode({
    required String address,
    required String postcode,
  }) {
    final normalizedAddress = address.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final normalizedPostcode = postcode.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (normalizedAddress.isEmpty || normalizedPostcode.isEmpty) {
      return false;
    }
    return normalizedAddress.contains(normalizedPostcode);
  }

  VanQuoteUiStatus _displayQuoteUiStatus() {
    return deriveVanIncomingJobDisplayQuoteUiStatus(job, request: request);
  }

  String _statusChipLabel() {
    return _displayQuoteUiStatus().primaryChipLabel;
  }

  Color _statusChipColor() {
    if (job.isQuoteDeclined) {
      return vanStatusToneColor(VanStatusTone.danger);
    }
    if (job.isConfirmed || job.isQuoteAccepted) {
      return vanStatusToneColor(VanStatusTone.positive);
    }
    if (_isQuoteAwaitingResponse()) {
      return vanStatusToneColor(VanStatusTone.warning);
    }
    return vanStatusToneColor(VanStatusTone.positive);
  }

  String _nextActionText({required bool blocked}) {
    if (blocked) {
      return 'Blocked customer match. Review before responding.';
    }
    return _displayQuoteUiStatus().nextActionText;
  }

  @override
  Widget build(BuildContext context) {
    final address = request?.publicAddressSummary.trim().isNotEmpty == true
        ? request!.publicAddressSummary.trim()
        : job.address.trim();
    final phone = request?.publicPhoneNumber.trim().isNotEmpty == true
        ? request!.publicPhoneNumber.trim()
        : job.phoneNumber.trim();
    final customerName = request?.publicCustomerName.trim().isNotEmpty == true
        ? request!.publicCustomerName.trim()
        : (job.customerName.trim().isNotEmpty
              ? job.customerName.trim()
              : 'No customer name');
    final postcode = _postcode();
    final locationPending =
        request?.locationPending == true || job.locationPending;
    final requiresExactPinAfterQuoteAccepted =
        request?.requiresExactPinAfterQuoteAccepted == true ||
        job.requiresExactPinAfterQuoteAccepted;
    final normalizedPostcode =
        _addressAlreadyContainsPostcode(address: address, postcode: postcode)
        ? ''
        : postcode;
    final locationSummary = buildVanJobLocationSummary(
      address: address,
      postcode: normalizedPostcode,
      locationPending: locationPending,
      requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
      hasExactPin: job.exactPinSaved,
    );
    final showLocationPendingNote = vanJobLocationIsPending(
      locationPending: locationPending,
      requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
      hasExactPin: job.exactPinSaved,
      address: address,
      postcode: postcode,
    );
    final timingDisplay = buildIncomingJobTimingDisplay(job, request: request);
    final blockedRecord = DriverReplyMockState.instance.blockedCustomerForJob(
      job,
      request: request,
    );
    final actionState = deriveVanJobActionState(
      job,
      request: request,
      phoneNumberOverride: phone,
    );
    final showStandardActions =
        !job.isQuoteDeclined &&
        (actionState.canCreateQuote ||
            actionState.canViewQuote ||
            actionState.canCallCustomer ||
            actionState.canTextCustomer);
    final displayStatus = _displayQuoteUiStatus();

    return _IncomingGlassCard(
      child: InkWell(
        onTap: deleting ? null : onViewDetails,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _IncomingChip(
                          label: _sourceLabel(),
                          color: vanStatusToneColor(VanStatusTone.neutral),
                        ),
                        _IncomingChip(
                          label: _statusChipLabel(),
                          color: _statusChipColor(),
                        ),
                        if (displayStatus.secondaryChipLabel !=
                            displayStatus.primaryChipLabel)
                          _IncomingChip(
                            label: displayStatus.secondaryChipLabel,
                            color:
                                displayStatus.secondaryChipLabel ==
                                        'Awaiting quote response' ||
                                    displayStatus.secondaryChipLabel ==
                                        'Time needs arranging' ||
                                    displayStatus.secondaryChipLabel ==
                                        'Awaiting exact pin'
                                ? vanStatusToneColor(VanStatusTone.primary)
                                : vanStatusToneColor(VanStatusTone.positive),
                          ),
                        if (displayStatus.showExactPinReceivedChip)
                          _IncomingChip(
                            label: displayStatus.exactPinChipLabel,
                            color: vanStatusToneColor(VanStatusTone.positive),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_IncomingRequestAction>(
                    enabled: !deleting,
                    tooltip: 'Request actions',
                    color: const Color(0xFF13233A),
                    surfaceTintColor: Colors.transparent,
                    icon: deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white70,
                          ),
                    onSelected: (value) {
                      switch (value) {
                        case _IncomingRequestAction.viewDetails:
                          onViewDetails();
                          break;
                        case _IncomingRequestAction.blockCustomer:
                          onBlock();
                          break;
                        case _IncomingRequestAction.unblockCustomer:
                          onUnblock();
                          break;
                        case _IncomingRequestAction.deleteRequest:
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<_IncomingRequestAction>(
                        value: _IncomingRequestAction.viewDetails,
                        child: Text('View details'),
                      ),
                      PopupMenuItem<_IncomingRequestAction>(
                        value: blockedRecord == null
                            ? _IncomingRequestAction.blockCustomer
                            : _IncomingRequestAction.unblockCustomer,
                        child: Text(
                          blockedRecord == null
                              ? 'Block customer'
                              : 'Unblock customer',
                        ),
                      ),
                      const PopupMenuItem<_IncomingRequestAction>(
                        value: _IncomingRequestAction.deleteRequest,
                        child: Text('Delete request'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _serviceName(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                customerName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                locationSummary,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (showLocationPendingNote) ...[
                const SizedBox(height: 4),
                Text(
                  'Exact pin will be requested after quote acceptance.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              if (blockedRecord != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Blocked customer match',
                  style: TextStyle(
                    color: vanStatusToneColor(VanStatusTone.danger),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _nextActionText(blocked: blockedRecord != null),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showStandardActions) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (actionState.canCreateQuote)
                      _IncomingActionButton(
                        label: 'Create quote',
                        icon: Icons.request_quote_outlined,
                        filled: true,
                        onPressed: onReviseQuote,
                      )
                    else if (actionState.canViewQuote)
                      _IncomingActionButton(
                        label: 'View quote',
                        icon: Icons.request_quote_outlined,
                        onPressed: onReviseQuote,
                      ),
                    if (actionState.canCallCustomer)
                      _IncomingActionButton(
                        label: 'Call customer',
                        icon: Icons.call_outlined,
                        onPressed: onCallCustomer,
                      ),
                    if (actionState.canTextCustomer)
                      _IncomingActionButton(
                        label: 'Text customer',
                        icon: Icons.sms_outlined,
                        onPressed: onTextCustomer,
                      ),
                  ],
                ),
              ],
              if (job.isQuoteDeclined) ...[
                const SizedBox(height: 10),
                Text(
                  _declineReasonPreview(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Next step: revise quote, follow up, or delete.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _IncomingActionButton(
                      label: 'Revise & resend quote',
                      icon: Icons.refresh_rounded,
                      filled: true,
                      onPressed: onReviseQuote,
                    ),
                    _IncomingActionButton(
                      label: 'Call customer',
                      icon: Icons.call_outlined,
                      onPressed: onCallCustomer,
                    ),
                    _IncomingActionButton(
                      label: 'Text customer',
                      icon: Icons.sms_outlined,
                      onPressed: onTextCustomer,
                    ),
                  ],
                ),
              ],
              if (timingDisplay.value.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              timingDisplay.label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w800,
                                fontSize: 12.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timingDisplay.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _declineReasonPreview() {
    final summary = buildVanQuoteDeclineSummary(
      reasonLabel: job.declineReasonLabel,
      reasonCode: job.declineReasonCode,
      note: job.declineNote,
      reasonText: job.declineReasonText,
    );
    return formatVanQuoteDeclineText(
          summary,
          emptyFallback: 'Decline reason not saved on this older test.',
        ) ??
        'Decline reason not saved on this older test.';
  }

  bool _isQuoteAwaitingResponse() {
    return job.isQuoteAwaitingCustomerResponse;
  }
}

class _IncomingActionButton extends StatelessWidget {
  const _IncomingActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled ? const Color(0xFF58D0A4) : Colors.white;
    final borderColor = filled
        ? const Color(0xFF58D0A4)
        : Colors.white.withValues(alpha: 0.16);
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: borderColor),
            ),
          );
  }
}

class _IncomingChip extends StatelessWidget {
  const _IncomingChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.4,
        ),
      ),
    );
  }
}

class _IncomingGlassCard extends StatelessWidget {
  const _IncomingGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
          ),
          child: child,
        ),
      ),
    );
  }
}
