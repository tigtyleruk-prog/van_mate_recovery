import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_completed_job_status_pills.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_quote_decline.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_invoice_draft.dart';
import 'driver_customer_reply_mock_page.dart';
import 'job_detail_page.dart';
import 'van_invoice_preview_page.dart';

Future<void> openVanCompletedJobsPage(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VanCompletedJobsPage()));
}

enum _CustomerHistoryTab { completed, cancelled, declinedQuotes, blocked }

class VanCompletedJobsPage extends StatefulWidget {
  const VanCompletedJobsPage({super.key});

  @override
  State<VanCompletedJobsPage> createState() => _VanCompletedJobsPageState();
}

class _VanCompletedJobsPageState extends State<VanCompletedJobsPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _CustomerHistoryTab _selectedTab = _CustomerHistoryTab.completed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(forceServer: true),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<_CompletedCustomerHistoryGroup> get _completedCustomerGroups {
    final state = DriverReplyMockState.instance;
    final grouped = <String, _CompletedCustomerHistoryGroupBuilder>{};

    for (final job in state.completedJobs) {
      final key = _completedCustomerGroupKey(job);
      final builder = grouped.putIfAbsent(
        key,
        () => _CompletedCustomerHistoryGroupBuilder(groupKey: key),
      );
      builder.addJob(
        job,
        invoice: state.invoiceForJob(job.invoiceHistoryKey),
        blockedRecord: state.blockedCustomerForPhone(job.phoneNumber),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final groups =
        grouped.values
            .map((builder) => builder.build())
            .where((group) => query.isEmpty || group.searchText.contains(query))
            .toList(growable: false)
          ..sort((a, b) => b.lastCompletedAt.compareTo(a.lastCompletedAt));
    return groups;
  }

  List<DriverCustomerReplyMockData> get _declinedQuotes {
    final jobs = <DriverCustomerReplyMockData>[
      for (final job in DriverReplyMockState.instance.debugAllLoadedJobs())
        if (!job.deleted) ...[
          if (job.quoteHistory.isNotEmpty)
            ...job.quoteHistory
                .where((entry) => entry.isDeclined)
                .map(
                  (entry) => job.copyWith(
                    quoteResponseId: entry.quoteResponseId,
                    quoteResponseToken: entry.quoteResponseToken,
                    quoteResponseLink: entry.quoteResponseLink,
                    quoteAmount: entry.quoteAmount,
                    quoteJobDescription: entry.quoteJobDescription,
                    quoteNotes: entry.quoteNotes,
                    quotePaymentInstructions: entry.quotePaymentInstructions,
                    quoteMessage: entry.quoteMessage,
                    quoteExtras: entry.quoteExtras,
                    proposedDate: entry.proposedDate,
                    proposedStartTime: entry.proposedStartTime,
                    proposedAppointmentNote: entry.proposedAppointmentNote,
                    estimatedDurationMinutes: entry.estimatedDurationMinutes,
                    quoteStatus: entry.quoteStatus,
                    quoteResponseStatus: entry.quoteResponseStatus,
                    quoteTimingChoice: entry.quoteTimingChoice,
                    quoteAccepted: entry.quoteAccepted,
                    quoteDeclined: entry.quoteDeclined,
                    quoteSentAt: entry.quoteSentAt,
                    quoteOpenedAt: entry.quoteOpenedAt,
                    quoteAcceptedAt: entry.quoteAcceptedAt,
                    quoteDeclinedAt: entry.quoteDeclinedAt,
                    quoteRespondedAt: entry.quoteRespondedAt,
                    declineReasonCode: entry.declineReasonCode,
                    declineReasonLabel: entry.declineReasonLabel,
                    declineReasonText: entry.declineReasonText,
                  ),
                ),
          if (job.isQuoteDeclined && !job.hasDeclinedQuoteHistory) job,
        ],
    ];
    final query = _searchQuery.trim().toLowerCase();
    final filteredJobs = query.isEmpty
        ? jobs
        : jobs.where(_matchesDeclinedSearch).toList(growable: false);
    filteredJobs.sort((a, b) => _declinedAtFor(b).compareTo(_declinedAtFor(a)));
    return filteredJobs;
  }

  List<DriverCustomerReplyMockData> get _cancelledJobs {
    final jobs = DriverReplyMockState.instance.cancelledJobs.toList(
      growable: false,
    );
    final query = _searchQuery.trim().toLowerCase();
    final filteredJobs = query.isEmpty
        ? jobs
        : jobs.where(_matchesCancelledSearch).toList(growable: false);
    filteredJobs.sort(
      (a, b) => _cancelledAtFor(b).compareTo(_cancelledAtFor(a)),
    );
    return filteredJobs;
  }

  List<VanBlockedCustomerRecord> get _blockedCustomers {
    final records = DriverReplyMockState.instance.blockedCustomers;
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return records;
    }
    return records
        .where((record) {
          final haystack = <String>[
            record.customerName,
            record.phoneNumber,
            record.address,
            record.reason,
            record.note,
          ].join('\n').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  bool _matchesDeclinedSearch(DriverCustomerReplyMockData job) {
    final haystack = <String>[
      job.customerName,
      job.jobTitle,
      job.address,
      job.postcode,
      job.phoneNumber,
      formatCurrency(job.quoteAmount ?? 0),
      _declinedReason(job),
    ].join('\n').toLowerCase();
    return haystack.contains(_searchQuery.trim().toLowerCase());
  }

  bool _matchesCancelledSearch(DriverCustomerReplyMockData job) {
    final haystack = <String>[
      job.customerName,
      job.jobTitle,
      job.address,
      job.postcode,
      job.phoneNumber,
      job.scheduledDate,
      job.scheduledStartTime,
      formatCurrency(job.quoteAmount ?? 0),
      job.additionalNotes,
    ].join('\n').toLowerCase();
    return haystack.contains(_searchQuery.trim().toLowerCase());
  }

  DateTime _completedAtFor(DriverCustomerReplyMockData job) {
    return job.completedAt ??
        job.updatedAt ??
        job.scheduledAtOrParsed ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _declinedAtFor(DriverCustomerReplyMockData job) {
    return job.quoteDeclinedAt ??
        job.quoteRespondedAt ??
        job.updatedAt ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _cancelledAtFor(DriverCustomerReplyMockData job) {
    return job.cancelledAt ??
        job.updatedAt ??
        job.scheduledAtOrParsed ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _completedLabel(DriverCustomerReplyMockData job) {
    final completedAt = _completedAtFor(job);
    return '${formatDate(completedAt)} at ${TimeOfDay.fromDateTime(completedAt).format(context)}';
  }

  String _declinedLabel(DriverCustomerReplyMockData job) {
    final declinedAt = _declinedAtFor(job);
    return '${formatDate(declinedAt)} at ${TimeOfDay.fromDateTime(declinedAt).format(context)}';
  }

  String _cancelledLabel(DriverCustomerReplyMockData job) {
    final cancelledAt = _cancelledAtFor(job);
    return '${formatDate(cancelledAt)} at ${TimeOfDay.fromDateTime(cancelledAt).format(context)}';
  }

  String _scheduledLabel(DriverCustomerReplyMockData job) {
    final scheduledAt = job.scheduledAtOrParsed;
    if (scheduledAt == null) {
      final date = job.scheduledDate.trim();
      final time = job.scheduledStartTime.trim();
      if (date.isEmpty && time.isEmpty) {
        return 'No scheduled time saved';
      }
      if (date.isEmpty) {
        return time;
      }
      if (time.isEmpty) {
        return date;
      }
      return '$date at $time';
    }
    return '${formatDate(scheduledAt)} at ${TimeOfDay.fromDateTime(scheduledAt).format(context)}';
  }

  String _exactPinStatusLabel(DriverCustomerReplyMockData job) {
    if (job.exactPinSaved) {
      return 'Exact pin received';
    }
    if (job.requiresAnyExactPin) {
      return 'Awaiting exact pin';
    }
    return 'Exact pin not required';
  }

  String _blockedLabel(VanBlockedCustomerRecord record) {
    return '${formatDate(record.blockedAt)} at ${TimeOfDay.fromDateTime(record.blockedAt).format(context)}';
  }

  String _addressLabel(DriverCustomerReplyMockData job) {
    final address = job.address.trim();
    final postcode = job.postcode.trim();
    if (address.isEmpty && postcode.isEmpty) {
      return 'No address saved';
    }
    if (address.isEmpty) {
      return postcode;
    }
    if (postcode.isEmpty) {
      return address;
    }
    if (address.toLowerCase().contains(postcode.toLowerCase())) {
      return address;
    }
    return '$address, $postcode';
  }

  String _declinedReason(DriverCustomerReplyMockData job) {
    final summary = buildVanQuoteDeclineSummary(
      reasonLabel: job.declineReasonLabel,
      reasonCode: job.declineReasonCode,
      note: job.declineNote,
      reasonText: job.declineReasonText,
    );
    final formatted = formatVanQuoteDeclineText(summary);
    if (formatted != null) {
      return formatted;
    }
    if (!summary.hasAny) {
      final quoteNotes = job.quoteNotes.trim();
      if (quoteNotes.isNotEmpty) {
        return quoteNotes;
      }
      final extraNotes = job.additionalNotes.trim();
      if (extraNotes.isNotEmpty) {
        return extraNotes;
      }
      return 'Decline reason not saved on this older test.';
    }
    return 'Decline reason not saved on this older test.';
  }

  String _completedCustomerGroupKey(DriverCustomerReplyMockData job) {
    final normalizedPhone = normalizeVanCustomerPhoneNumberForMatch(
      job.phoneNumber,
    );
    if (normalizedPhone.isNotEmpty) {
      return 'phone:$normalizedPhone';
    }

    final requestId = job.requestId?.trim() ?? '';
    if (requestId.isNotEmpty) {
      return 'request:$requestId';
    }
    return 'job:${job.jobId.trim()}';
  }

  Future<void> _openCompletedJob(DriverCustomerReplyMockData job) async {
    final result = await openDriverJobDetailMockPage(
      context,
      reply: DriverReplyMockState.instance.realReplyForJob(job.jobId) ?? job,
      completed: true,
      historyMode: true,
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    if (result == VanJobActionResult.deleted) {
      _showSnack('Job deleted.');
    } else if (result == VanJobActionResult.updated) {
      _showSnack('Job updated.');
    }
  }

  Future<void> _openInvoice(VanInvoiceDraft invoice) async {
    final updated = await openVanInvoicePreviewPage(context, invoice);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {});
  }

  Future<void> _openCompletedCustomerGroup(
    _CompletedCustomerHistoryGroup group,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CompletedCustomerHistoryDetailPage(
          group: group,
          onOpenJob: _openCompletedJob,
          onOpenInvoice: _openInvoice,
          completedLabelFor: _completedLabel,
          addressLabelFor: _addressLabel,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openDeclinedQuote(DriverCustomerReplyMockData job) async {
    final liveJob = DriverReplyMockState.instance.realReplyForJob(job.jobId);
    final replyToOpen =
        liveJob != null &&
            liveJob.quoteResponseId.trim() == job.quoteResponseId.trim()
        ? liveJob
        : job;
    final result = await openDriverJobDetailMockPage(
      context,
      reply: replyToOpen,
      completed: false,
      historyMode: true,
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    if (result == VanJobActionResult.deleted) {
      _showSnack('Quote deleted.');
    } else if (result == VanJobActionResult.updated) {
      _showSnack('Quote updated.');
    }
  }

  Future<void> _reviseDeclinedQuote(DriverCustomerReplyMockData job) async {
    await openDriverQuoteMockPage(context, job);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _callCustomer(DriverCustomerReplyMockData job) async {
    final phone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    if (phone.isEmpty) {
      _showSnack('No phone number saved.');
      return;
    }
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || opened) {
      return;
    }
    _showSnack('Could not open the phone app.');
  }

  Future<void> _textCustomer(DriverCustomerReplyMockData job) async {
    final phone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    if (phone.isEmpty) {
      _showSnack('No phone number saved.');
      return;
    }
    final opened = await launchUrl(
      Uri(scheme: 'sms', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || opened) {
      return;
    }
    _showSnack('Could not open Messages.');
  }

  Future<void> _openCancelledJob(DriverCustomerReplyMockData job) async {
    final result = await openDriverJobDetailMockPage(
      context,
      reply: DriverReplyMockState.instance.jobById(job.jobId) ?? job,
      completed: false,
      historyMode: true,
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    if (result == VanJobActionResult.deleted) {
      _showSnack('Job deleted.');
    } else if (result == VanJobActionResult.updated) {
      _showSnack('Job updated.');
    } else if (result == VanJobActionResult.cancelled) {
      _showSnack('Job cancelled.');
    }
  }

  Future<void> _unblockCustomer(VanBlockedCustomerRecord record) async {
    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unblock this customer?'),
        content: Text(
          'This will remove the blocked warning for future requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (shouldUnblock != true) {
      return;
    }
    final unblocked = DriverReplyMockState.instance.unblockCustomerByPhone(
      record.normalizedPhone,
    );
    if (unblocked) {
      _showSnack('Customer unblocked.');
    }
  }

  Future<void> _viewBlockedCustomerDetails(
    VanBlockedCustomerRecord record,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF142031),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          record.customerName.trim().isEmpty
              ? 'Blocked customer'
              : record.customerName.trim(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryDetailLine(
                label: 'Phone',
                value: record.phoneNumber.trim().isEmpty
                    ? 'No phone saved'
                    : record.phoneNumber.trim(),
              ),
              const SizedBox(height: 8),
              _HistoryDetailLine(
                label: 'Address',
                value: record.address.trim().isEmpty
                    ? 'No address saved'
                    : record.address.trim(),
              ),
              const SizedBox(height: 8),
              _HistoryDetailLine(label: 'Reason', value: record.reason),
              const SizedBox(height: 8),
              _HistoryDetailLine(
                label: 'Blocked',
                value: _blockedLabel(record),
              ),
              if (record.note.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _HistoryDetailLine(label: 'Note', value: record.note.trim()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String get _searchHint {
    switch (_selectedTab) {
      case _CustomerHistoryTab.completed:
        return 'Search name, phone, address or job...';
      case _CustomerHistoryTab.cancelled:
        return 'Search cancelled jobs...';
      case _CustomerHistoryTab.declinedQuotes:
        return 'Search customer or job...';
      case _CustomerHistoryTab.blocked:
        return 'Search customer or job...';
    }
  }

  String get _headerSubtitle {
    return 'Completed jobs, cancelled jobs, declined quotes and blocked customers.';
  }

  String get _sectionTitle {
    switch (_selectedTab) {
      case _CustomerHistoryTab.completed:
        return 'Completed customers';
      case _CustomerHistoryTab.cancelled:
        return 'Cancelled jobs';
      case _CustomerHistoryTab.declinedQuotes:
        return 'Declined quotes';
      case _CustomerHistoryTab.blocked:
        return 'Blocked customers';
    }
  }

  Widget _buildFilterSelector() {
    return _HistoryGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sectionTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_selectedTab != _CustomerHistoryTab.completed)
                _HistoryFilterChip(
                  label: 'Completed jobs',
                  icon: Icons.check_circle_outline,
                  selected: false,
                  onTap: () {
                    setState(() {
                      _selectedTab = _CustomerHistoryTab.completed;
                    });
                  },
                ),
              _HistoryFilterChip(
                label: 'Cancelled jobs',
                icon: Icons.cancel_outlined,
                selected: _selectedTab == _CustomerHistoryTab.cancelled,
                onTap: () {
                  setState(() {
                    _selectedTab = _CustomerHistoryTab.cancelled;
                  });
                },
              ),
              _HistoryFilterChip(
                label: 'Declined quotes',
                icon: Icons.request_quote_outlined,
                selected: _selectedTab == _CustomerHistoryTab.declinedQuotes,
                onTap: () {
                  setState(() {
                    _selectedTab = _CustomerHistoryTab.declinedQuotes;
                  });
                },
              ),
              _HistoryFilterChip(
                label: 'Blocked customers',
                icon: Icons.block_outlined,
                selected: _selectedTab == _CustomerHistoryTab.blocked,
                onTap: () {
                  setState(() {
                    _selectedTab = _CustomerHistoryTab.blocked;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return _HistoryGlassCard(
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: _searchHint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.72),
          ),
          suffixIcon: _searchQuery.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: Color(0xFF4A7DFF), width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = switch (_selectedTab) {
      _CustomerHistoryTab.completed =>
        _searchQuery.trim().isEmpty
            ? 'Completed jobs will appear here after you finish work from the calendar.'
            : 'Try a different search term for completed customer history.',
      _CustomerHistoryTab.cancelled =>
        _searchQuery.trim().isEmpty
            ? 'No cancelled jobs yet.'
            : 'Try a different search term for cancelled jobs.',
      _CustomerHistoryTab.declinedQuotes =>
        _searchQuery.trim().isEmpty
            ? 'Declined quotes will appear here when a customer turns down a quote or you mark it as lost.'
            : 'Try a different search term for declined quotes.',
      _CustomerHistoryTab.blocked =>
        _searchQuery.trim().isEmpty
            ? 'Blocked customers will appear here after you block them from history or request details.'
            : 'Try a different search term for blocked customers.',
    };

    return _HistoryGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No matching history found.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBodyItems() {
    switch (_selectedTab) {
      case _CustomerHistoryTab.completed:
        if (_completedCustomerGroups.isEmpty) {
          return <Widget>[_buildEmptyState()];
        }
        return [
          for (
            var index = 0;
            index < _completedCustomerGroups.length;
            index++
          ) ...[
            _CompletedCustomerGroupCard(
              group: _completedCustomerGroups[index],
              onOpenGroup: () =>
                  _openCompletedCustomerGroup(_completedCustomerGroups[index]),
            ),
            if (index < _completedCustomerGroups.length - 1)
              const SizedBox(height: 12),
          ],
        ];
      case _CustomerHistoryTab.cancelled:
        if (_cancelledJobs.isEmpty) {
          return <Widget>[_buildEmptyState()];
        }
        return [
          for (var index = 0; index < _cancelledJobs.length; index++) ...[
            _CancelledJobItemCard(
              job: _cancelledJobs[index],
              cancelledLabel: _cancelledLabel(_cancelledJobs[index]),
              scheduledLabel: _scheduledLabel(_cancelledJobs[index]),
              addressLabel: _addressLabel(_cancelledJobs[index]),
              exactPinStatus: _exactPinStatusLabel(_cancelledJobs[index]),
              onOpenJob: () => _openCancelledJob(_cancelledJobs[index]),
            ),
            if (index < _cancelledJobs.length - 1) const SizedBox(height: 12),
          ],
        ];
      case _CustomerHistoryTab.declinedQuotes:
        if (_declinedQuotes.isEmpty) {
          return <Widget>[_buildEmptyState()];
        }
        return [
          for (var index = 0; index < _declinedQuotes.length; index++) ...[
            _DeclinedQuoteItemCard(
              job: _declinedQuotes[index],
              declinedLabel: _declinedLabel(_declinedQuotes[index]),
              reasonLabel: _declinedReason(_declinedQuotes[index]),
              onOpenQuote: () => _openDeclinedQuote(_declinedQuotes[index]),
              onReviseQuote: () => _reviseDeclinedQuote(_declinedQuotes[index]),
              onCallCustomer: () => _callCustomer(_declinedQuotes[index]),
              onTextCustomer: () => _textCustomer(_declinedQuotes[index]),
            ),
            if (index < _declinedQuotes.length - 1) const SizedBox(height: 12),
          ],
        ];
      case _CustomerHistoryTab.blocked:
        if (_blockedCustomers.isEmpty) {
          return <Widget>[_buildEmptyState()];
        }
        return [
          for (var index = 0; index < _blockedCustomers.length; index++) ...[
            _BlockedCustomerItemCard(
              record: _blockedCustomers[index],
              onViewDetails: () =>
                  _viewBlockedCustomerDetails(_blockedCustomers[index]),
              blockedLabel: _blockedLabel(_blockedCustomers[index]),
              onUnblock: () => _unblockCustomer(_blockedCustomers[index]),
            ),
            if (index < _blockedCustomers.length - 1)
              const SizedBox(height: 12),
          ],
        ];
    }
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
        title: const Text('Customer History'),
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
                _HistoryGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _headerSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontSize: 13.2,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildFilterSelector(),
                const SizedBox(height: 12),
                _buildSearchCard(),
                const SizedBox(height: 12),
                ..._buildBodyItems(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryGlassCard extends StatelessWidget {
  const _HistoryGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CompletedJobItemCard extends StatelessWidget {
  const _CompletedJobItemCard({
    required this.job,
    required this.completedLabel,
    required this.addressLabel,
    required this.invoice,
    required this.onOpenJob,
  });

  final DriverCustomerReplyMockData job;
  final String completedLabel;
  final String addressLabel;
  final VanInvoiceDraft? invoice;
  final VoidCallback onOpenJob;

  @override
  Widget build(BuildContext context) {
    final phone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    final invoiceNumber = invoice?.invoiceNumber.trim() ?? '';
    final invoiceSummary = invoice == null
        ? ''
        : invoice!.isPaid
        ? invoiceNumber.isEmpty
              ? 'Invoice: Paid'
              : 'Invoice: $invoiceNumber · Paid'
        : invoiceNumber.isEmpty
        ? 'Invoice: Awaiting payment'
        : 'Invoice: $invoiceNumber · Awaiting payment';

    return _HistoryGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.customerName.trim().isEmpty ? 'Customer' : job.customerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.jobTitle.trim().isEmpty ? 'Completed job' : job.jobTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _HistoryDetailLine(label: 'Completed', value: completedLabel),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Address', value: addressLabel),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(label: 'Phone', value: phone),
          ],
          if (invoiceSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(label: 'Invoice', value: invoiceSummary),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: buildVanCompletedJobStatusPills(job)
                .map(
                  (pill) => _HistoryChip(
                    label: pill.label,
                    icon: pill.icon,
                    color: pill.color,
                    filled: pill.filled,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _HistoryActionButton(
              label: 'View job',
              icon: Icons.open_in_new_rounded,
              filled: true,
              color: const Color(0xFF4A7DFF),
              onPressed: onOpenJob,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedCustomerGroupCard extends StatelessWidget {
  const _CompletedCustomerGroupCard({
    required this.group,
    required this.onOpenGroup,
  });

  final _CompletedCustomerHistoryGroup group;
  final VoidCallback onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final subtitle = group.customerSummaryLabel;

    return _HistoryGlassCard(
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
                    Text(
                      group.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.blockedRecord != null)
                const _HistoryChip(
                  label: 'Blocked',
                  icon: Icons.block_outlined,
                  color: Color(0xFFD24C4C),
                  filled: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (group.displayPhone.isNotEmpty) ...[
            _HistoryDetailLine(label: 'Phone', value: group.displayPhone),
            const SizedBox(height: 8),
          ],
          _HistoryDetailLine(
            label: 'Completed jobs',
            value: '${group.completedJobsCount}',
          ),
          const SizedBox(height: 8),
          _HistoryDetailLine(
            label: 'Last job',
            value: formatDate(group.lastCompletedAt),
          ),
          if (group.primaryAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(label: 'Address', value: group.primaryAddress),
          ],
          if (group.totalValue > 0) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(
              label: group.hasAnyInvoice
                  ? 'Total invoiced/quoted'
                  : 'Total quoted',
              value: formatCurrency(group.totalValue),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HistoryChip(
                label: group.completedJobsCount == 1
                    ? '1 job'
                    : '${group.completedJobsCount} jobs',
                icon: Icons.history_rounded,
                color: const Color(0xFF4A7DFF),
              ),
              if (group.unpaidInvoiceCount > 0)
                _HistoryChip(
                  label: group.unpaidInvoiceCount == 1
                      ? '1 unpaid invoice'
                      : '${group.unpaidInvoiceCount} unpaid invoices',
                  icon: Icons.hourglass_bottom,
                  color: const Color(0xFFFFC38C),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _HistoryActionButton(
              label: 'View customer',
              icon: Icons.open_in_new_rounded,
              filled: true,
              color: const Color(0xFF4A7DFF),
              onPressed: onOpenGroup,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeclinedQuoteItemCard extends StatelessWidget {
  const _DeclinedQuoteItemCard({
    required this.job,
    required this.declinedLabel,
    required this.reasonLabel,
    required this.onOpenQuote,
    required this.onReviseQuote,
    required this.onCallCustomer,
    required this.onTextCustomer,
  });

  final DriverCustomerReplyMockData job;
  final String declinedLabel;
  final String reasonLabel;
  final VoidCallback onOpenQuote;
  final VoidCallback onReviseQuote;
  final VoidCallback onCallCustomer;
  final VoidCallback onTextCustomer;

  @override
  Widget build(BuildContext context) {
    final phone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    final amount = job.quoteAmount == null
        ? 'No quote amount saved'
        : formatCurrency(job.quoteAmount!);

    return _HistoryGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HistoryChip(
            label: 'Quote declined',
            icon: Icons.request_quote_outlined,
            color: Color(0xFFFF8F7A),
            filled: true,
          ),
          const SizedBox(height: 12),
          Text(
            job.customerName.trim().isEmpty ? 'Customer' : job.customerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.jobTitle.trim().isEmpty ? 'Quote' : job.jobTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _HistoryDetailLine(label: 'Quote amount', value: amount),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Declined', value: declinedLabel),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Reason', value: reasonLabel),
          const SizedBox(height: 8),
          const _HistoryDetailLine(
            label: 'Next step',
            value: 'Revise quote, follow up, or delete.',
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(label: 'Phone', value: phone),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HistoryActionButton(
                label: 'View quote',
                icon: Icons.open_in_new_rounded,
                filled: true,
                color: const Color(0xFF4A7DFF),
                onPressed: onOpenQuote,
              ),
              _HistoryActionButton(
                label: 'Revise & resend quote',
                icon: Icons.refresh_rounded,
                filled: true,
                color: const Color(0xFF58D0A4),
                onPressed: onReviseQuote,
              ),
              _HistoryActionButton(
                label: 'Call customer',
                icon: Icons.call_outlined,
                color: const Color(0xFF4A7DFF),
                onPressed: onCallCustomer,
              ),
              _HistoryActionButton(
                label: 'Text customer',
                icon: Icons.sms_outlined,
                color: const Color(0xFF4A7DFF),
                onPressed: onTextCustomer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelledJobItemCard extends StatelessWidget {
  const _CancelledJobItemCard({
    required this.job,
    required this.cancelledLabel,
    required this.scheduledLabel,
    required this.addressLabel,
    required this.exactPinStatus,
    required this.onOpenJob,
  });

  final DriverCustomerReplyMockData job;
  final String cancelledLabel;
  final String scheduledLabel;
  final String addressLabel;
  final String exactPinStatus;
  final VoidCallback onOpenJob;

  @override
  Widget build(BuildContext context) {
    final phone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    final amount = job.quoteAmount == null
        ? 'No quote amount saved'
        : formatCurrency(job.quoteAmount!);

    return _HistoryGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HistoryChip(
            label: 'Cancelled job',
            icon: Icons.cancel_outlined,
            color: Color(0xFFFFC38C),
            filled: true,
          ),
          const SizedBox(height: 12),
          Text(
            job.customerName.trim().isEmpty ? 'Customer' : job.customerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.jobTitle.trim().isEmpty ? 'Cancelled job' : job.jobTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _HistoryDetailLine(label: 'Cancelled', value: cancelledLabel),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Scheduled for', value: scheduledLabel),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Address', value: addressLabel),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Exact pin', value: exactPinStatus),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Quote', value: amount),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(label: 'Phone', value: phone),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _HistoryActionButton(
              label: 'View job',
              icon: Icons.open_in_new_rounded,
              filled: true,
              color: const Color(0xFF4A7DFF),
              onPressed: onOpenJob,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedCustomerItemCard extends StatelessWidget {
  const _BlockedCustomerItemCard({
    required this.record,
    required this.onViewDetails,
    required this.blockedLabel,
    required this.onUnblock,
  });

  final VanBlockedCustomerRecord record;
  final VoidCallback onViewDetails;
  final String blockedLabel;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final displayName = record.customerName.trim().isEmpty
        ? 'Customer'
        : record.customerName.trim();
    final displayPhone = record.phoneNumber.trim().isEmpty
        ? 'No phone saved'
        : record.phoneNumber.trim();
    final displayAddress = record.address.trim().isEmpty
        ? 'No address saved'
        : record.address.trim();
    final displayNote = record.note.trim();

    return _HistoryGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HistoryChip(
            label: 'Blocked',
            icon: Icons.block_outlined,
            color: Color(0xFFD24C4C),
            filled: true,
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _HistoryDetailLine(label: 'Phone', value: displayPhone),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Address', value: displayAddress),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Reason', value: record.reason),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Date blocked', value: blockedLabel),
          if (displayNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(label: 'Note', value: displayNote),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HistoryActionButton(
                  label: 'View details',
                  icon: Icons.open_in_new_rounded,
                  color: const Color(0xFF4A7DFF),
                  onPressed: onViewDetails,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HistoryActionButton(
                  label: 'Unblock',
                  icon: Icons.lock_open_rounded,
                  color: const Color(0xFF58D0A4),
                  onPressed: onUnblock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedCustomerHistoryDetailPage extends StatelessWidget {
  const _CompletedCustomerHistoryDetailPage({
    required this.group,
    required this.onOpenJob,
    required this.onOpenInvoice,
    required this.completedLabelFor,
    required this.addressLabelFor,
  });

  final _CompletedCustomerHistoryGroup group;
  final Future<void> Function(DriverCustomerReplyMockData job) onOpenJob;
  final Future<void> Function(VanInvoiceDraft invoice) onOpenInvoice;
  final String Function(DriverCustomerReplyMockData job) completedLabelFor;
  final String Function(DriverCustomerReplyMockData job) addressLabelFor;

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
        title: const Text('Customer History'),
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
                _HistoryGlassCard(
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
                                Text(
                                  group.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  group.displayPhone.isEmpty
                                      ? 'Completed customer history'
                                      : group.displayPhone,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (group.blockedRecord != null)
                            const _HistoryChip(
                              label: 'Blocked',
                              icon: Icons.block_outlined,
                              color: Color(0xFFD24C4C),
                              filled: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _HistoryDetailLine(
                        label: 'Completed jobs',
                        value: '${group.completedJobsCount}',
                      ),
                      const SizedBox(height: 8),
                      _HistoryDetailLine(
                        label: 'Last job',
                        value: formatDate(group.lastCompletedAt),
                      ),
                      if (group.primaryAddress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _HistoryDetailLine(
                          label: 'Address',
                          value: group.primaryAddress,
                        ),
                      ],
                      if (group.totalValue > 0) ...[
                        const SizedBox(height: 8),
                        _HistoryDetailLine(
                          label: group.hasAnyInvoice
                              ? 'Total invoiced/quoted'
                              : 'Total quoted',
                          value: formatCurrency(group.totalValue),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < group.jobs.length; index++) ...[
                  _CompletedCustomerHistoryJobCard(
                    job: group.jobs[index],
                    invoice: group.invoiceForJob(group.jobs[index]),
                    completedLabel: completedLabelFor(group.jobs[index]),
                    addressLabel: addressLabelFor(group.jobs[index]),
                    onOpenJob: () => onOpenJob(group.jobs[index]),
                    onOpenInvoice:
                        group.invoiceForJob(group.jobs[index]) == null
                        ? null
                        : () => onOpenInvoice(
                            group.invoiceForJob(group.jobs[index])!,
                          ),
                  ),
                  if (index < group.jobs.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedCustomerHistoryJobCard extends StatelessWidget {
  const _CompletedCustomerHistoryJobCard({
    required this.job,
    required this.invoice,
    required this.completedLabel,
    required this.addressLabel,
    required this.onOpenJob,
    this.onOpenInvoice,
  });

  final DriverCustomerReplyMockData job;
  final VanInvoiceDraft? invoice;
  final String completedLabel;
  final String addressLabel;
  final VoidCallback onOpenJob;
  final VoidCallback? onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    final amount = invoice != null
        ? formatCurrency(invoice!.totalDue)
        : job.quoteAmount != null
        ? formatCurrency(job.quoteAmount!)
        : '';
    final invoiceStatus = invoice == null
        ? ''
        : invoice!.isPaid
        ? 'Paid'
        : 'Awaiting payment';

    return _HistoryGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.jobTitle.trim().isEmpty ? 'Completed job' : job.jobTitle.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _HistoryDetailLine(label: 'Completed', value: completedLabel),
          const SizedBox(height: 8),
          _HistoryDetailLine(label: 'Address', value: addressLabel),
          if (amount.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(
              label: invoice != null ? 'Invoice amount' : 'Quote amount',
              value: amount,
            ),
          ],
          if (invoiceStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HistoryDetailLine(label: 'Invoice status', value: invoiceStatus),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: buildVanCompletedJobStatusPills(job)
                .map(
                  (pill) => _HistoryChip(
                    label: pill.label,
                    icon: pill.icon,
                    color: pill.color,
                    filled: pill.filled,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HistoryActionButton(
                  label: 'View job',
                  icon: Icons.open_in_new_rounded,
                  color: const Color(0xFF4A7DFF),
                  filled: true,
                  onPressed: onOpenJob,
                ),
              ),
              if (onOpenInvoice != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _HistoryActionButton(
                    label: 'View invoice',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF4A7DFF),
                    onPressed: onOpenInvoice!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedCustomerHistoryGroup {
  const _CompletedCustomerHistoryGroup({
    required this.groupKey,
    required this.displayName,
    required this.displayPhone,
    required this.primaryAddress,
    required this.latestJobTitle,
    required this.lastCompletedAt,
    required this.jobs,
    required this.invoicesByJobKey,
    required this.totalValue,
    required this.unpaidInvoiceCount,
    required this.hasAnyInvoice,
    required this.searchText,
    this.blockedRecord,
  });

  final String groupKey;
  final String displayName;
  final String displayPhone;
  final String primaryAddress;
  final String latestJobTitle;
  final DateTime lastCompletedAt;
  final List<DriverCustomerReplyMockData> jobs;
  final Map<String, VanInvoiceDraft> invoicesByJobKey;
  final double totalValue;
  final int unpaidInvoiceCount;
  final bool hasAnyInvoice;
  final String searchText;
  final VanBlockedCustomerRecord? blockedRecord;

  int get completedJobsCount => jobs.length;

  String get completedJobsLabel =>
      completedJobsCount == 1 ? '1 job' : '$completedJobsCount jobs';

  String get customerSummaryLabel {
    if (latestJobTitle.isEmpty) {
      return completedJobsLabel;
    }
    return '$completedJobsLabel \u2022 Last: $latestJobTitle';
  }

  VanInvoiceDraft? invoiceForJob(DriverCustomerReplyMockData job) {
    return invoicesByJobKey[job.invoiceHistoryKey];
  }
}

class _CompletedCustomerHistoryGroupBuilder {
  _CompletedCustomerHistoryGroupBuilder({required this.groupKey});

  final String groupKey;
  final List<DriverCustomerReplyMockData> _jobs =
      <DriverCustomerReplyMockData>[];
  final Map<String, VanInvoiceDraft> _invoicesByJobKey =
      <String, VanInvoiceDraft>{};
  VanBlockedCustomerRecord? _blockedRecord;

  void addJob(
    DriverCustomerReplyMockData job, {
    required VanInvoiceDraft? invoice,
    required VanBlockedCustomerRecord? blockedRecord,
  }) {
    if (!_jobs.any((existing) => existing.jobId == job.jobId)) {
      _jobs.add(job);
    }
    if (invoice != null) {
      _invoicesByJobKey[job.invoiceHistoryKey] = invoice;
    }
    _blockedRecord ??= blockedRecord;
  }

  _CompletedCustomerHistoryGroup build() {
    _jobs.sort((a, b) => _jobDate(b).compareTo(_jobDate(a)));
    final latest = _jobs.first;
    final displayName = _jobs
        .map((job) => sanitizeVanText(job.customerName).trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => 'Customer');
    final displayPhone = _jobs
        .map((job) => sanitizeVanText(job.phoneNumber).trim())
        .firstWhere(
          (phone) => phone.isNotEmpty,
          orElse: () => _phoneFromGroupKey(groupKey),
        );
    final primaryAddress = _jobs
        .map((job) => _addressForJob(job))
        .firstWhere((address) => address.isNotEmpty, orElse: () => '');
    final latestJobTitle = _jobs
        .map((job) => sanitizeVanText(job.jobTitle).trim())
        .firstWhere((title) => title.isNotEmpty, orElse: () => '');
    final totalValue = _jobs.fold<double>(0, (sum, job) {
      final invoice = _invoicesByJobKey[job.invoiceHistoryKey];
      if (invoice != null) {
        return sum + invoice.totalDue;
      }
      return sum + (job.quoteAmount ?? 0);
    });
    final unpaidInvoiceCount = _invoicesByJobKey.values
        .where((invoice) => invoice.isUnpaid)
        .length;
    final searchBuffer = StringBuffer()
      ..writeln(displayName.toLowerCase())
      ..writeln(displayPhone.toLowerCase())
      ..writeln(primaryAddress.toLowerCase())
      ..writeln(latestJobTitle.toLowerCase());
    for (final job in _jobs) {
      searchBuffer.writeln(job.customerName.toLowerCase());
      searchBuffer.writeln(job.phoneNumber.toLowerCase());
      searchBuffer.writeln(
        normalizeVanCustomerPhoneNumberForMatch(job.phoneNumber).toLowerCase(),
      );
      searchBuffer.writeln(job.jobTitle.toLowerCase());
      searchBuffer.writeln(job.address.toLowerCase());
      searchBuffer.writeln(job.postcode.toLowerCase());
    }
    for (final invoice in _invoicesByJobKey.values) {
      searchBuffer.writeln(invoice.invoiceNumber.toLowerCase());
      searchBuffer.writeln(invoice.jobReference.toLowerCase());
    }

    return _CompletedCustomerHistoryGroup(
      groupKey: groupKey,
      displayName: displayName,
      displayPhone: displayPhone,
      primaryAddress: primaryAddress,
      latestJobTitle: latestJobTitle,
      lastCompletedAt: _jobDate(latest),
      jobs: List<DriverCustomerReplyMockData>.unmodifiable(_jobs),
      invoicesByJobKey: Map<String, VanInvoiceDraft>.unmodifiable(
        _invoicesByJobKey,
      ),
      totalValue: totalValue,
      unpaidInvoiceCount: unpaidInvoiceCount,
      hasAnyInvoice: _invoicesByJobKey.isNotEmpty,
      searchText: searchBuffer.toString(),
      blockedRecord: _blockedRecord,
    );
  }

  DateTime _jobDate(DriverCustomerReplyMockData job) {
    return job.completedAt ??
        job.updatedAt ??
        job.scheduledAtOrParsed ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _addressForJob(DriverCustomerReplyMockData job) {
    final address = sanitizeVanText(job.address).trim();
    final postcode = sanitizeVanText(job.postcode).trim();
    if (address.isEmpty) {
      return postcode;
    }
    if (postcode.isEmpty ||
        address.toLowerCase().contains(postcode.toLowerCase())) {
      return address;
    }
    return '$address, $postcode';
  }

  static String _phoneFromGroupKey(String groupKey) {
    if (!groupKey.startsWith('phone:')) {
      return '';
    }
    return groupKey.substring('phone:'.length);
  }
}

class _HistoryDetailLine extends StatelessWidget {
  const _HistoryDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
      softWrap: true,
    );
  }
}

class _HistoryActionButton extends StatelessWidget {
  const _HistoryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.42)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled
            ? color.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF4A7DFF)
        : Colors.white.withValues(alpha: 0.14);
    final backgroundColor = selected
        ? const Color(0xFF4A7DFF).withValues(alpha: 0.24)
        : Colors.white.withValues(alpha: 0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: backgroundColor,
            border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
