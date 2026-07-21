import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_job_report_pdf_helper.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_business_profile.dart';
import '../models/van_invoice_history_entry.dart';
import '../models/van_job_report.dart';
import '../services/van_business_profile_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import 'driver_customer_reply_mock_page.dart';
import 'van_quick_invoice_page.dart';

Future<void> openVanJobReportsPage(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VanJobReportsPage()));
}

class VanJobReportsPage extends StatefulWidget {
  const VanJobReportsPage({super.key});

  @override
  State<VanJobReportsPage> createState() => _VanJobReportsPageState();
}

class _VanJobReportsPageState extends State<VanJobReportsPage>
    with WidgetsBindingObserver {
  final VanBusinessProfileStorage _storage = VanBusinessProfileStorage.instance;

  VanBusinessProfile _businessProfile = const VanBusinessProfile.defaults();
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverReplyMockState.instance.addListener(_handleStateChanged);
    unawaited(_loadData());
  }

  @override
  void dispose() {
    DriverReplyMockState.instance.removeListener(_handleStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadData());
    }
  }

  void _handleStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadData() async {
    final profile = await _storage.loadCanonicalProfile();
    await DriverReplyMockState.instance.loadInvoicesFromCloud();
    await DriverReplyMockState.instance.refreshJobsFromCloud(forceServer: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _businessProfile = profile;
      _loading = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<VanInvoiceHistoryEntry> get _allInvoices =>
      DriverReplyMockState.instance.savedInvoiceHistory.toList(growable: false);

  List<DriverCustomerReplyMockData> get _completedJobs =>
      DriverReplyMockState.instance.completedJobs.toList(growable: false);

  DateTime? _parseInvoiceDate(String value) {
    final text = sanitizeVanText(value).trim();
    if (text.isEmpty) {
      return null;
    }

    final direct = DateTime.tryParse(text);
    if (direct != null) {
      return direct;
    }

    final slash = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$',
    ).firstMatch(text);
    if (slash != null) {
      final day = int.tryParse(slash.group(1) ?? '');
      final month = int.tryParse(slash.group(2) ?? '');
      final parsedYear = int.tryParse(slash.group(3) ?? '');
      if (day == null || month == null || parsedYear == null) {
        return null;
      }
      final year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
      final built = DateTime(year, month, day);
      if (built.year == year && built.month == month && built.day == day) {
        return built;
      }
    }

    final words = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})$',
    ).firstMatch(text);
    if (words != null) {
      final day = int.tryParse(words.group(1) ?? '');
      final month = _monthNumber(words.group(2) ?? '');
      final year = int.tryParse(words.group(3) ?? '');
      if (day == null || month == null || year == null) {
        return null;
      }
      final built = DateTime(year, month, day);
      if (built.year == year && built.month == month && built.day == day) {
        return built;
      }
    }

    return null;
  }

  int? _monthNumber(String raw) {
    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    return months[raw.trim().toLowerCase()];
  }

  DateTime? _invoiceDateFor(VanInvoiceHistoryEntry entry) {
    return _parseInvoiceDate(entry.draft.invoiceDate) ??
        entry.createdAt ??
        entry.savedAt;
  }

  DateTime? _dueDateFor(VanInvoiceHistoryEntry entry) {
    return _parseInvoiceDate(entry.draft.dueDate);
  }

  DateTime _paidDateFor(VanInvoiceHistoryEntry entry) {
    return entry.draft.paidAt ?? entry.updatedAt ?? entry.savedAt;
  }

  DateTime _completedDateFor(DriverCustomerReplyMockData job) {
    return job.completedAt ??
        job.updatedAt ??
        job.scheduledAtOrParsed ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool _isThisYear(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year;
  }

  double _sumInvoices(Iterable<VanInvoiceHistoryEntry> invoices) {
    return invoices.fold<double>(0, (sum, entry) => sum + entry.draft.totalDue);
  }

  List<VanInvoiceHistoryEntry> _paidInvoicesForMonth() {
    return _allInvoices
        .where((entry) {
          if (!entry.draft.isPaid) {
            return false;
          }
          return _isThisMonth(_paidDateFor(entry));
        })
        .toList(growable: false);
  }

  List<VanInvoiceHistoryEntry> _paidInvoicesForYear() {
    return _allInvoices
        .where((entry) {
          if (!entry.draft.isPaid) {
            return false;
          }
          return _isThisYear(_paidDateFor(entry));
        })
        .toList(growable: false);
  }

  List<VanInvoiceHistoryEntry> _unpaidInvoicesForMonth() {
    return _allInvoices
        .where((entry) {
          if (entry.draft.isPaid) {
            return false;
          }
          final invoiceDate = _invoiceDateFor(entry);
          return invoiceDate != null && _isThisMonth(invoiceDate);
        })
        .toList(growable: false);
  }

  List<VanInvoiceHistoryEntry> _unpaidInvoicesForYear() {
    return _allInvoices
        .where((entry) {
          if (entry.draft.isPaid) {
            return false;
          }
          final invoiceDate = _invoiceDateFor(entry);
          return invoiceDate != null && _isThisYear(invoiceDate);
        })
        .toList(growable: false);
  }

  List<VanInvoiceHistoryEntry> get _allPaidInvoices =>
      _allInvoices.where((entry) => entry.draft.isPaid).toList(growable: false);

  List<VanInvoiceHistoryEntry> get _allUnpaidInvoices => _allInvoices
      .where((entry) => entry.draft.isUnpaid)
      .toList(growable: false);

  String _jobStatusLabel(DriverCustomerReplyMockData job) {
    final invoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );
    if (invoice == null) {
      return 'Completed';
    }
    return invoice.isPaid ? 'Paid' : 'Invoiced';
  }

  String _jobInvoiceReference(DriverCustomerReplyMockData job) {
    final invoice = DriverReplyMockState.instance.invoiceForJob(
      job.invoiceHistoryKey,
    );
    final invoiceNumber = invoice?.invoiceNumber.trim() ?? '';
    return invoiceNumber.isEmpty ? '-' : invoiceNumber;
  }

  String _jobAddress(DriverCustomerReplyMockData job) {
    final address = job.address.trim();
    final postcode = job.postcode.trim();
    if (address.isEmpty && postcode.isEmpty) {
      return '-';
    }
    if (address.isEmpty) {
      return postcode;
    }
    if (postcode.isEmpty ||
        address.toLowerCase().contains(postcode.toLowerCase())) {
      return address;
    }
    return '$address, $postcode';
  }

  String _invoiceDueLabel(VanInvoiceHistoryEntry entry) {
    final raw = sanitizeVanText(entry.draft.dueDate).trim();
    if (raw.isEmpty) {
      return 'Due on receipt';
    }
    final dueDate = _dueDateFor(entry);
    return dueDate == null ? raw : formatDate(dueDate);
  }

  Widget _buildShellCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? helperText,
  }) {
    return _buildShellCard(
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
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13.2,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12.2,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _exporting ? null : onTap,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_exporting ? 'Exporting...' : 'Export PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A7DFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport(VanReportDocument document) async {
    if (_exporting) {
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final pdfPath = await buildVanJobReportPdfPath(document);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfPath)],
          text: document.reportTitle,
          subject: document.reportTitle,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Report PDF export failed: $error');
      }
      _showSnack('Could not create report PDF.');
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  VanReportDocument _monthlyIncomeDocument() {
    final paid = _paidInvoicesForMonth();
    final unpaid = _unpaidInvoicesForMonth();
    final completedJobs = _completedJobs
        .where((job) => _isThisMonth(_completedDateFor(job)))
        .toList(growable: false);
    final now = DateTime.now();

    return VanReportDocument(
      businessProfile: _businessProfile,
      reportTitle: 'Monthly income report',
      dateRangeLabel: '${_monthName(now.month)} ${now.year}',
      generatedAt: now,
      summaryLines: [
        VanReportSummaryLine(
          label: 'Paid invoice total',
          value: formatCurrency(_sumInvoices(paid)),
        ),
        VanReportSummaryLine(
          label: 'Unpaid invoice total',
          value: formatCurrency(_sumInvoices(unpaid)),
        ),
        VanReportSummaryLine(
          label: 'Completed jobs',
          value: completedJobs.length.toString(),
        ),
      ],
      sections: [
        VanReportTableSection(
          title: 'Paid invoices',
          headers: const ['Invoice', 'Customer', 'Job', 'Amount', 'Paid date'],
          rows: [
            for (final entry in paid)
              [
                entry.draft.invoiceNumber.trim().isEmpty
                    ? '--'
                    : entry.draft.invoiceNumber.trim(),
                entry.draft.customerName.trim().isEmpty
                    ? 'Customer'
                    : entry.draft.customerName.trim(),
                entry.draft.jobReference.trim().isEmpty
                    ? 'Job'
                    : entry.draft.jobReference.trim(),
                entry.draft.totalDueText,
                formatDate(_paidDateFor(entry)),
              ],
          ],
        ),
        VanReportTableSection(
          title: 'Unpaid invoices',
          headers: const ['Invoice', 'Customer', 'Job', 'Amount', 'Due'],
          rows: [
            for (final entry in unpaid)
              [
                entry.draft.invoiceNumber.trim().isEmpty
                    ? '--'
                    : entry.draft.invoiceNumber.trim(),
                entry.draft.customerName.trim().isEmpty
                    ? 'Customer'
                    : entry.draft.customerName.trim(),
                entry.draft.jobReference.trim().isEmpty
                    ? 'Job'
                    : entry.draft.jobReference.trim(),
                entry.draft.totalDueText,
                _invoiceDueLabel(entry),
              ],
          ],
        ),
      ],
    );
  }

  VanReportDocument _yearlyIncomeDocument() {
    final paid = _paidInvoicesForYear();
    final unpaid = _unpaidInvoicesForYear();
    final completedJobs = _completedJobs
        .where((job) => _isThisYear(_completedDateFor(job)))
        .toList(growable: false);
    final now = DateTime.now();

    return VanReportDocument(
      businessProfile: _businessProfile,
      reportTitle: 'Yearly income report',
      dateRangeLabel: now.year.toString(),
      generatedAt: now,
      summaryLines: [
        VanReportSummaryLine(
          label: 'Paid invoice total',
          value: formatCurrency(_sumInvoices(paid)),
        ),
        VanReportSummaryLine(
          label: 'Unpaid invoice total',
          value: formatCurrency(_sumInvoices(unpaid)),
        ),
        VanReportSummaryLine(
          label: 'Completed jobs',
          value: completedJobs.length.toString(),
        ),
      ],
      sections: [
        VanReportTableSection(
          title: 'Paid invoices',
          headers: const ['Invoice', 'Customer', 'Job', 'Amount', 'Paid date'],
          rows: [
            for (final entry in paid)
              [
                entry.draft.invoiceNumber.trim().isEmpty
                    ? '--'
                    : entry.draft.invoiceNumber.trim(),
                entry.draft.customerName.trim().isEmpty
                    ? 'Customer'
                    : entry.draft.customerName.trim(),
                entry.draft.jobReference.trim().isEmpty
                    ? 'Job'
                    : entry.draft.jobReference.trim(),
                entry.draft.totalDueText,
                formatDate(_paidDateFor(entry)),
              ],
          ],
        ),
        VanReportTableSection(
          title: 'Unpaid invoices',
          headers: const ['Invoice', 'Customer', 'Job', 'Amount', 'Due'],
          rows: [
            for (final entry in unpaid)
              [
                entry.draft.invoiceNumber.trim().isEmpty
                    ? '--'
                    : entry.draft.invoiceNumber.trim(),
                entry.draft.customerName.trim().isEmpty
                    ? 'Customer'
                    : entry.draft.customerName.trim(),
                entry.draft.jobReference.trim().isEmpty
                    ? 'Job'
                    : entry.draft.jobReference.trim(),
                entry.draft.totalDueText,
                _invoiceDueLabel(entry),
              ],
          ],
        ),
      ],
    );
  }

  VanReportDocument _paidInvoicesDocument() {
    final paid = _allPaidInvoices;
    return VanReportDocument(
      businessProfile: _businessProfile,
      reportTitle: 'Paid invoices report',
      dateRangeLabel: 'All paid invoices',
      generatedAt: DateTime.now(),
      summaryLines: [
        VanReportSummaryLine(
          label: 'Paid invoice total',
          value: formatCurrency(_sumInvoices(paid)),
        ),
        VanReportSummaryLine(
          label: 'Paid invoice count',
          value: paid.length.toString(),
        ),
      ],
      sections: [
        VanReportTableSection(
          title: 'Paid invoices',
          headers: const [
            'Invoice',
            'Customer',
            'Job',
            'Amount',
            'Invoice date',
            'Paid date',
          ],
          rows: [
            for (final entry in paid)
              [
                entry.draft.invoiceNumber.trim().isEmpty
                    ? '--'
                    : entry.draft.invoiceNumber.trim(),
                entry.draft.customerName.trim().isEmpty
                    ? 'Customer'
                    : entry.draft.customerName.trim(),
                entry.draft.jobReference.trim().isEmpty
                    ? 'Job'
                    : entry.draft.jobReference.trim(),
                entry.draft.totalDueText,
                _invoiceDateFor(entry) == null
                    ? '--'
                    : formatDate(_invoiceDateFor(entry)!),
                formatDate(_paidDateFor(entry)),
              ],
          ],
        ),
      ],
    );
  }

  VanReportDocument _unpaidInvoicesDocument() {
    final unpaid = _allUnpaidInvoices;
    return VanReportDocument(
      businessProfile: _businessProfile,
      reportTitle: 'Unpaid invoices report',
      dateRangeLabel: 'Current unpaid invoices',
      generatedAt: DateTime.now(),
      summaryLines: [
        VanReportSummaryLine(
          label: 'Unpaid invoice total',
          value: formatCurrency(_sumInvoices(unpaid)),
        ),
        VanReportSummaryLine(
          label: 'Unpaid invoice count',
          value: unpaid.length.toString(),
        ),
      ],
      sections: [
        VanReportTableSection(
          title: 'Unpaid invoices',
          headers: const [
            'Invoice',
            'Customer',
            'Job',
            'Amount',
            'Invoice date',
            'Due date',
            'Phone',
          ],
          rows: [
            for (final entry in unpaid)
              [
                entry.draft.invoiceNumber.trim().isEmpty
                    ? '--'
                    : entry.draft.invoiceNumber.trim(),
                entry.draft.customerName.trim().isEmpty
                    ? 'Customer'
                    : entry.draft.customerName.trim(),
                entry.draft.jobReference.trim().isEmpty
                    ? 'Job'
                    : entry.draft.jobReference.trim(),
                entry.draft.totalDueText,
                _invoiceDateFor(entry) == null
                    ? '--'
                    : formatDate(_invoiceDateFor(entry)!),
                _invoiceDueLabel(entry),
                sanitizeVanCustomerPhoneNumber(
                      entry.draft.customerPhone,
                    ).isEmpty
                    ? '-'
                    : sanitizeVanCustomerPhoneNumber(entry.draft.customerPhone),
              ],
          ],
        ),
      ],
    );
  }

  VanReportDocument _completedJobsDocument() {
    final jobs = _completedJobs;
    return VanReportDocument(
      businessProfile: _businessProfile,
      reportTitle: 'Completed jobs report',
      dateRangeLabel: 'Completed job archive',
      generatedAt: DateTime.now(),
      summaryLines: [
        VanReportSummaryLine(
          label: 'Completed jobs',
          value: jobs.length.toString(),
        ),
        VanReportSummaryLine(
          label: 'Linked invoices',
          value: jobs
              .where(
                (job) =>
                    DriverReplyMockState.instance.invoiceForJob(
                      job.invoiceHistoryKey,
                    ) !=
                    null,
              )
              .length
              .toString(),
        ),
      ],
      sections: [
        VanReportTableSection(
          title: 'Completed jobs',
          headers: const [
            'Customer',
            'Job',
            'Completed',
            'Address',
            'Phone',
            'Invoice',
            'Status',
          ],
          rows: [
            for (final job in jobs)
              [
                job.customerName.trim().isEmpty
                    ? 'Customer'
                    : job.customerName.trim(),
                job.jobTitle.trim().isEmpty ? 'Job' : job.jobTitle.trim(),
                formatDate(_completedDateFor(job)),
                _jobAddress(job),
                sanitizeVanCustomerPhoneNumber(job.phoneNumber).isEmpty
                    ? '-'
                    : sanitizeVanCustomerPhoneNumber(job.phoneNumber),
                _jobInvoiceReference(job),
                _jobStatusLabel(job),
              ],
          ],
        ),
      ],
    );
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final hasAnyData = _allInvoices.isNotEmpty || _completedJobs.isNotEmpty;
    final paid = _allPaidInvoices;
    final unpaid = _allUnpaidInvoices;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Reports & Export'),
        automaticallyImplyLeading: false,
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
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reports & Export',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Export paperwork for yourself or your bookkeeper.',
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
                      if (!hasAnyData)
                        _buildShellCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No report data yet.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Invoices and completed jobs will appear here once you start using Business Hub.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () =>
                                    unawaited(openVanQuickInvoicePage(context)),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create an invoice'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _buildSectionTitle('Income reports'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 2 : 1;
                            final cardWidth =
                                (constraints.maxWidth - ((columns - 1) * 12)) /
                                columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildExportCard(
                                    title: 'Monthly income PDF',
                                    subtitle:
                                        'Paid and unpaid invoice summary for this month.',
                                    onTap: () => unawaited(
                                      _exportReport(_monthlyIncomeDocument()),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildExportCard(
                                    title: 'Yearly income PDF',
                                    subtitle: 'Year-to-date invoice summary.',
                                    onTap: () => unawaited(
                                      _exportReport(_yearlyIncomeDocument()),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSectionTitle('Invoice reports'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 2 : 1;
                            final cardWidth =
                                (constraints.maxWidth - ((columns - 1) * 12)) /
                                columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildExportCard(
                                    title: 'Paid invoices PDF',
                                    subtitle: 'Invoices marked as paid.',
                                    helperText: paid.isEmpty
                                        ? 'No paid invoices found.'
                                        : null,
                                    onTap: () => unawaited(
                                      _exportReport(_paidInvoicesDocument()),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildExportCard(
                                    title: 'Unpaid invoices PDF',
                                    subtitle:
                                        'Invoices still awaiting payment.',
                                    helperText: unpaid.isEmpty
                                        ? 'No unpaid invoices for this period.'
                                        : null,
                                    onTap: () => unawaited(
                                      _exportReport(_unpaidInvoicesDocument()),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSectionTitle('Job reports'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 2 : 1;
                            final cardWidth =
                                (constraints.maxWidth - ((columns - 1) * 12)) /
                                columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildExportCard(
                                    title: 'Customer History PDF',
                                    subtitle:
                                        'Completed customer jobs with invoice reference and status.',
                                    helperText: _completedJobs.isEmpty
                                        ? 'No completed jobs found.'
                                        : null,
                                    onTap: () => unawaited(
                                      _exportReport(_completedJobsDocument()),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
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
