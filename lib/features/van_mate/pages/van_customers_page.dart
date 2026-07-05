import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_invoice_history_entry.dart';
import 'driver_customer_reply_mock_page.dart';
import 'job_detail_page.dart';
import 'van_invoice_preview_page.dart';

Future<void> openVanCustomersPage(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VanCustomersPage()));
}

class VanCustomersPage extends StatefulWidget {
  const VanCustomersPage({super.key});

  @override
  State<VanCustomersPage> createState() => _VanCustomersPageState();
}

class _VanCustomersPageState extends State<VanCustomersPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverReplyMockState.instance.addListener(_handleStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(forceServer: true),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    DriverReplyMockState.instance.removeListener(_handleStateChanged);
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

  void _handleStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  List<_CustomerSummary> get _customers {
    final state = DriverReplyMockState.instance;
    final byKey = <String, _CustomerSummaryBuilder>{};

    for (final job in state.jobs) {
      final key = _customerKey(
        name: job.customerName,
        phone: job.phoneNumber,
        address: job.address,
      );
      if (key.isEmpty) {
        continue;
      }
      final builder = byKey.putIfAbsent(
        key,
        () => _CustomerSummaryBuilder(
          customerKey: key,
          displayName: _displayCustomerName(job.customerName),
          phone: sanitizeVanCustomerPhoneNumber(job.phoneNumber),
          seedAddress: _joinedAddress(job.address, job.postcode),
        ),
      );
      builder.addJob(job);
    }

    for (final entry in state.savedInvoiceHistory) {
      final key = _customerKey(
        name: entry.draft.customerName,
        phone: entry.draft.customerPhone,
        address: entry.draft.billingAddress,
      );
      if (key.isEmpty) {
        continue;
      }
      final builder = byKey.putIfAbsent(
        key,
        () => _CustomerSummaryBuilder(
          customerKey: key,
          displayName: _displayCustomerName(entry.draft.customerName),
          phone: sanitizeVanCustomerPhoneNumber(entry.draft.customerPhone),
          seedAddress: sanitizeVanText(entry.draft.billingAddress).trim(),
        ),
      );
      builder.addInvoice(entry);
    }

    final query = _searchQuery.trim().toLowerCase();
    final summaries =
        byKey.values
            .map((builder) => builder.build())
            .where((summary) {
              if (query.isEmpty) {
                return true;
              }
              return summary.searchText.contains(query);
            })
            .toList(growable: false)
          ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return summaries;
  }

  String _customerKey({
    required String name,
    required String phone,
    required String address,
  }) {
    final normalizedPhone = normalizeVanCustomerPhoneNumberForMatch(phone);
    if (normalizedPhone.isNotEmpty) {
      return normalizedPhone;
    }
    final normalizedName = sanitizeVanText(name).trim().toLowerCase();
    final normalizedAddress = sanitizeVanText(address).trim().toLowerCase();
    if (normalizedName.isEmpty && normalizedAddress.isEmpty) {
      return '';
    }
    return '$normalizedName|$normalizedAddress';
  }

  String _displayCustomerName(String value) {
    final cleaned = sanitizeVanText(value).trim();
    return cleaned.isEmpty ? 'Customer' : cleaned;
  }

  String _joinedAddress(String address, String postcode) {
    final parts = <String>[
      sanitizeVanText(address).trim(),
      sanitizeVanText(postcode).trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final customers = _customers;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Customers'),
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
                _CustomersGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Find previous customers, jobs and invoices.',
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
                _CustomersGlassCard(
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
                      hintText: 'Search name, phone, address or job title',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
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
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        borderSide: BorderSide(
                          color: Color(0xFF4A7DFF),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (customers.isEmpty)
                  _CustomersGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No customers yet.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customers will appear here when you create jobs, quotes or invoices.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.74),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (var index = 0; index < customers.length; index++) ...[
                    _CustomersDirectoryCard(
                      summary: customers[index],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                _CustomerDetailPage(summary: customers[index]),
                          ),
                        );
                      },
                    ),
                    if (index < customers.length - 1)
                      const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetailPage extends StatefulWidget {
  const _CustomerDetailPage({required this.summary});

  final _CustomerSummary summary;

  @override
  State<_CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<_CustomerDetailPage> {
  @override
  void initState() {
    super.initState();
    DriverReplyMockState.instance.addListener(_handleStateChanged);
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

  _CustomerSummary get _summary {
    final state = DriverReplyMockState.instance;
    final jobs = state.jobs
        .where((job) {
          return _customerKeyForJob(job) == widget.summary.customerKey;
        })
        .toList(growable: false);
    final invoices = state.savedInvoiceHistory
        .where((entry) {
          return _customerKeyForInvoice(entry) == widget.summary.customerKey;
        })
        .toList(growable: false);

    if (jobs.isEmpty && invoices.isEmpty) {
      return widget.summary;
    }

    final builder = _CustomerSummaryBuilder(
      customerKey: widget.summary.customerKey,
      displayName: widget.summary.displayName,
      phone: widget.summary.phone,
      seedAddress: widget.summary.primaryAddress,
    );
    for (final job in jobs) {
      builder.addJob(job);
    }
    for (final invoice in invoices) {
      builder.addInvoice(invoice);
    }
    return builder.build();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openJob(DriverCustomerReplyMockData job) async {
    final result = await openDriverJobDetailMockPage(
      context,
      reply: DriverReplyMockState.instance.realReplyForJob(job.jobId) ?? job,
      completed: job.isCompleted,
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

  Future<void> _openInvoice(VanInvoiceHistoryEntry entry) async {
    final updated = await openVanInvoicePreviewPage(context, entry.draft);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {});
  }

  Future<void> _markPaid(VanInvoiceHistoryEntry entry) async {
    final jobKey = entry.jobKey.trim();
    if (jobKey.isEmpty) {
      _showSnack('Save the invoice first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark invoice as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final updated = DriverReplyMockState.instance.markInvoicePaidForJob(jobKey);
    if (updated == null) {
      _showSnack('Could not update invoice status.');
      return;
    }

    _showSnack('Invoice marked as paid.');
    setState(() {});
  }

  Future<void> _callCustomer() async {
    await launchCustomerPhone(context, _summary.phone);
  }

  Future<void> _copyPhone() async {
    final phone = _summary.phone.trim();
    if (phone.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) {
      return;
    }
    _showSnack('Phone number copied.');
  }

  Future<void> _openInMaps() async {
    final address = _summary.primaryAddress.trim();
    if (address.isEmpty) {
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || launched) {
      return;
    }
    _showSnack('Could not open Google Maps right now.');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final summary = _summary;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(summary.displayName),
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
                _CustomersGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (summary.phone.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          summary.phone,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (summary.primaryAddress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          summary.primaryAddress,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (summary.phone.isNotEmpty)
                            _CustomerActionButton(
                              label: 'Call customer',
                              icon: Icons.phone,
                              onTap: _callCustomer,
                            ),
                          if (summary.phone.isNotEmpty)
                            _CustomerActionButton(
                              label: 'Copy phone',
                              icon: Icons.copy_rounded,
                              onTap: _copyPhone,
                            ),
                          if (summary.primaryAddress.isNotEmpty)
                            _CustomerActionButton(
                              label: 'Open in Maps',
                              icon: Icons.map_outlined,
                              onTap: _openInMaps,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CustomerSectionCard(
                  title: 'Job history',
                  child: summary.jobs.isEmpty
                      ? const _CustomerEmptyText(text: 'No jobs yet.')
                      : Column(
                          children: [
                            for (var i = 0; i < summary.jobs.length; i++) ...[
                              _CustomerJobHistoryCard(
                                job: summary.jobs[i],
                                onViewJob: () => _openJob(summary.jobs[i]),
                              ),
                              if (i < summary.jobs.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                _CustomerSectionCard(
                  title: 'Invoice history',
                  child: summary.invoices.isEmpty
                      ? const _CustomerEmptyText(text: 'No invoices yet.')
                      : Column(
                          children: [
                            for (
                              var i = 0;
                              i < summary.invoices.length;
                              i++
                            ) ...[
                              _CustomerInvoiceHistoryCard(
                                entry: summary.invoices[i],
                                onViewInvoice: () =>
                                    _openInvoice(summary.invoices[i]),
                                onMarkPaid: summary.invoices[i].draft.isPaid
                                    ? null
                                    : () => _markPaid(summary.invoices[i]),
                              ),
                              if (i < summary.invoices.length - 1)
                                const SizedBox(height: 10),
                            ],
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

class _CustomersGlassCard extends StatelessWidget {
  const _CustomersGlassCard({required this.child});

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

class _CustomersDirectoryCard extends StatelessWidget {
  const _CustomersDirectoryCard({required this.summary, required this.onTap});

  final _CustomerSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CustomersGlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (summary.phone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  summary.phone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (summary.primaryAddress.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  summary.primaryAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                summary.jobsSummaryLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (summary.invoices.isEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'No invoices yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CustomerChip(
                    label: summary.statusSummaryLabel,
                    color: summary.statusSummaryColor,
                    icon: summary.statusSummaryIcon,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerSectionCard extends StatelessWidget {
  const _CustomerSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _CustomersGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CustomerJobHistoryCard extends StatelessWidget {
  const _CustomerJobHistoryCard({required this.job, required this.onViewJob});

  final DriverCustomerReplyMockData job;
  final VoidCallback onViewJob;

  @override
  Widget build(BuildContext context) {
    final invoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );
    final statusLabel = job.isCompleted
        ? 'Completed'
        : job.isCancelled
        ? 'Cancelled'
        : job.isConfirmed
        ? 'Scheduled'
        : job.statusLabel;
    final invoiceStatus = invoice == null
        ? 'Not invoiced'
        : invoice.isPaid
        ? 'Paid'
        : 'Invoiced';
    final jobDate =
        job.completedAt ??
        job.scheduledAtOrParsed ??
        job.updatedAt ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.jobTitle.trim().isEmpty ? 'Job' : job.jobTitle.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatDate(jobDate),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CustomerChip(
                label: statusLabel,
                color: const Color(0xFF58D0A4),
                icon: Icons.work_outline,
              ),
              _CustomerChip(
                label: invoiceStatus,
                color: invoice?.isPaid == true
                    ? const Color(0xFF58D0A4)
                    : invoice == null
                    ? const Color(0xFFFFC38C)
                    : const Color(0xFF4A7DFF),
                icon: invoice?.isPaid == true
                    ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onViewJob,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Text('View job'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerInvoiceHistoryCard extends StatelessWidget {
  const _CustomerInvoiceHistoryCard({
    required this.entry,
    required this.onViewInvoice,
    required this.onMarkPaid,
  });

  final VanInvoiceHistoryEntry entry;
  final VoidCallback onViewInvoice;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final invoice = entry.draft;
    final invoiceNumber = sanitizeVanText(invoice.invoiceNumber).trim();
    final invoiceDate = _parseInvoiceDateLabel(invoice.invoiceDate);
    final paidDate = invoice.isPaid && invoice.paidAt != null
        ? formatDate(invoice.paidAt!)
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoiceNumber.isEmpty ? 'Invoice' : invoiceNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatCurrency(invoice.totalDue),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CustomerChip(
                label: invoice.isPaid ? 'Paid' : 'Awaiting payment',
                color: invoice.isPaid
                    ? const Color(0xFF58D0A4)
                    : const Color(0xFFFFC38C),
                icon: invoice.isPaid
                    ? Icons.payments_outlined
                    : Icons.hourglass_bottom,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Invoice date: $invoiceDate',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (invoice.isPaid && paidDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Paid date: $paidDate',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: onViewInvoice,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Text('View invoice'),
              ),
              if (onMarkPaid != null)
                FilledButton(
                  onPressed: onMarkPaid,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A7DFF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mark paid'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerActionButton extends StatelessWidget {
  const _CustomerActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _CustomerEmptyText extends StatelessWidget {
  const _CustomerEmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.74),
        height: 1.45,
      ),
    );
  }
}

class _CustomerChip extends StatelessWidget {
  const _CustomerChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSummary {
  const _CustomerSummary({
    required this.customerKey,
    required this.displayName,
    required this.phone,
    required this.primaryAddress,
    required this.jobs,
    required this.invoices,
    required this.awaitingPaymentAmount,
    required this.lastActivity,
    required this.searchText,
  });

  final String customerKey;
  final String displayName;
  final String phone;
  final String primaryAddress;
  final List<DriverCustomerReplyMockData> jobs;
  final List<VanInvoiceHistoryEntry> invoices;
  final double awaitingPaymentAmount;
  final DateTime lastActivity;
  final String searchText;

  int get completedJobsCount => jobs.where((job) => job.isCompleted).length;

  String get jobsSummaryLabel {
    if (jobs.isEmpty) {
      return 'No jobs yet';
    }
    if (completedJobsCount == jobs.length) {
      return completedJobsCount == 1
          ? '1 completed job'
          : '$completedJobsCount completed jobs';
    }
    return jobs.length == 1 ? '1 job' : '${jobs.length} jobs';
  }

  Color get statusSummaryColor {
    if (awaitingPaymentAmount > 0) {
      return const Color(0xFFFFC38C);
    }
    if (invoices.any((invoice) => invoice.draft.isPaid)) {
      return const Color(0xFF58D0A4);
    }
    return const Color(0xFF4A7DFF);
  }

  IconData get statusSummaryIcon {
    if (awaitingPaymentAmount > 0) {
      return Icons.hourglass_bottom;
    }
    if (invoices.any((invoice) => invoice.draft.isPaid)) {
      return Icons.payments_outlined;
    }
    return Icons.people_alt_outlined;
  }

  String get statusSummaryLabel {
    if (awaitingPaymentAmount > 0) {
      return 'Awaiting payment ${formatCurrency(awaitingPaymentAmount)}';
    }
    if (invoices.any((invoice) => invoice.draft.isPaid)) {
      return 'Paid';
    }
    return jobs.length == 1 ? '1 job' : '${jobs.length} jobs';
  }
}

class _CustomerSummaryBuilder {
  _CustomerSummaryBuilder({
    required this.customerKey,
    required this.displayName,
    required this.phone,
    required this.seedAddress,
  });

  final String customerKey;
  final String displayName;
  final String phone;
  final String seedAddress;
  final List<DriverCustomerReplyMockData> jobs =
      <DriverCustomerReplyMockData>[];
  final List<VanInvoiceHistoryEntry> invoices = <VanInvoiceHistoryEntry>[];

  void addJob(DriverCustomerReplyMockData job) {
    if (!jobs.any((existing) => existing.jobId == job.jobId)) {
      jobs.add(job);
    }
  }

  void addInvoice(VanInvoiceHistoryEntry entry) {
    final nextKey = _invoiceEntryKey(entry);
    if (!invoices.any((existing) => _invoiceEntryKey(existing) == nextKey)) {
      invoices.add(entry);
    }
  }

  _CustomerSummary build() {
    jobs.sort((a, b) => _jobDate(b).compareTo(_jobDate(a)));
    invoices.sort((a, b) => b.savedAt.compareTo(a.savedAt));

    final primaryAddress = jobs
        .map((job) => _joinedAddress(job.address, job.postcode))
        .firstWhere((value) => value.isNotEmpty, orElse: () => seedAddress)
        .trim();
    final awaitingPaymentAmount = invoices
        .where((entry) => entry.draft.isUnpaid)
        .fold<double>(0, (sum, entry) => sum + entry.draft.totalDue);
    final searchBuffer = StringBuffer()
      ..writeln(displayName.toLowerCase())
      ..writeln(phone.toLowerCase())
      ..writeln(primaryAddress.toLowerCase());
    for (final job in jobs) {
      searchBuffer.writeln(job.jobTitle.toLowerCase());
      searchBuffer.writeln(job.address.toLowerCase());
      searchBuffer.writeln(job.phoneNumber.toLowerCase());
    }
    for (final invoice in invoices) {
      searchBuffer.writeln(invoice.draft.jobReference.toLowerCase());
    }

    final latestJobAt = jobs.isEmpty ? null : _jobDate(jobs.first);
    final latestInvoiceAt = invoices.isEmpty ? null : invoices.first.savedAt;
    final lastActivityCandidates = <DateTime>[?latestJobAt, ?latestInvoiceAt];

    return _CustomerSummary(
      customerKey: customerKey,
      displayName: displayName,
      phone: phone,
      primaryAddress: primaryAddress,
      jobs: jobs,
      invoices: invoices,
      awaitingPaymentAmount: awaitingPaymentAmount,
      lastActivity: lastActivityCandidates.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : lastActivityCandidates.reduce(
              (latest, value) => value.isAfter(latest) ? value : latest,
            ),
      searchText: searchBuffer.toString(),
    );
  }

  DateTime _jobDate(DriverCustomerReplyMockData job) {
    return job.completedAt ??
        job.scheduledAtOrParsed ??
        job.updatedAt ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _joinedAddress(String address, String postcode) {
    final parts = <String>[
      sanitizeVanText(address).trim(),
      sanitizeVanText(postcode).trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return parts.join(', ');
  }

  String _invoiceEntryKey(VanInvoiceHistoryEntry entry) {
    final invoiceNumber = sanitizeVanText(entry.draft.invoiceNumber).trim();
    final jobKey = entry.jobKey.trim();
    if (jobKey.isNotEmpty || invoiceNumber.isNotEmpty) {
      return '$jobKey|$invoiceNumber';
    }
    return '${entry.savedAt.toIso8601String()}|${entry.draft.customerName}|${entry.draft.totalDue}';
  }
}

String _parseInvoiceDateLabel(String value) {
  final cleaned = sanitizeVanText(value).trim();
  return cleaned.isEmpty ? '--' : cleaned;
}

String _customerKeyForJob(DriverCustomerReplyMockData job) {
  final normalizedPhone = normalizeVanCustomerPhoneNumberForMatch(
    job.phoneNumber,
  );
  if (normalizedPhone.isNotEmpty) {
    return normalizedPhone;
  }
  final normalizedName = sanitizeVanText(job.customerName).trim().toLowerCase();
  final normalizedAddress = sanitizeVanText(job.address).trim().toLowerCase();
  if (normalizedName.isEmpty && normalizedAddress.isEmpty) {
    return '';
  }
  return '$normalizedName|$normalizedAddress';
}

String _customerKeyForInvoice(VanInvoiceHistoryEntry entry) {
  final normalizedPhone = normalizeVanCustomerPhoneNumberForMatch(
    entry.draft.customerPhone,
  );
  if (normalizedPhone.isNotEmpty) {
    return normalizedPhone;
  }
  final normalizedName = sanitizeVanText(
    entry.draft.customerName,
  ).trim().toLowerCase();
  final normalizedAddress = sanitizeVanText(
    entry.draft.billingAddress,
  ).trim().toLowerCase();
  if (normalizedName.isEmpty && normalizedAddress.isEmpty) {
    return '';
  }
  return '$normalizedName|$normalizedAddress';
}
