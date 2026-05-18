import 'dart:ui';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/van_job_report_pdf_helper.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_business_profile.dart';
import '../models/van_job_report.dart';
import '../pages/driver_customer_reply_mock_page.dart';
import '../services/van_business_profile_storage.dart';

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

class _VanJobReportsPageState extends State<VanJobReportsPage> {
  final VanBusinessProfileStorage _storage = VanBusinessProfileStorage.instance;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _previewKey = GlobalKey();
  VanBusinessProfile? _businessProfile;
  VanJobReportRange _range = VanJobReportRange.today;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _storage.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _businessProfile = profile;
      _loading = false;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _startOfWeek(DateTime date) {
    final start = _startOfDay(date).subtract(Duration(days: date.weekday - 1));
    return start;
  }

  DateTime? _completedAtForReport(DriverCustomerReplyMockData reply) {
    return reply.completedAt ??
        reply.scheduledAtOrParsed ??
        reply.updatedAt ??
        reply.createdAt;
  }

  DateTime? _scheduledAtForReport(DriverCustomerReplyMockData reply) {
    return reply.scheduledAtOrParsed;
  }

  VanJobReportData _buildReportData() {
    final profile = _businessProfile ?? const VanBusinessProfile.defaults();
    final now = DateTime.now();
    final rangeStart = _range == VanJobReportRange.today
        ? _startOfDay(now)
        : _startOfWeek(now);
    final rangeEndExclusive = rangeStart.add(
      Duration(days: _range == VanJobReportRange.today ? 1 : 7),
    );

    final entries = <VanJobReportEntry>[];
    for (final reply in DriverReplyMockState.instance.jobs) {
      if (reply.status != 'completed') {
        continue;
      }

      final invoice = DriverReplyMockState.instance.invoiceForJob(
        reply.invoiceHistoryKey,
      );
      final completedAt = _completedAtForReport(reply);
      if (completedAt == null) {
        continue;
      }

      final scheduledAt = _scheduledAtForReport(reply);
      if (completedAt.isBefore(rangeStart) ||
          !completedAt.isBefore(rangeEndExclusive)) {
        continue;
      }

      entries.add(
        VanJobReportEntry(
          customerName: reply.customerName,
          jobTitle: reply.jobTitle,
          jobDateLabel: reply.jobDateLabel,
          completedAt: completedAt,
          scheduledAt: scheduledAt,
          address: reply.address,
          phone: reply.phoneNumber,
          exactPinSaved: reply.exactPinShared,
          quoteAmount: reply.quoteAmount,
          invoiceNumber: invoice?.invoiceNumber,
          invoiceTotal: invoice?.totalDue,
          mileageCharge: invoice?.mileageCharge ?? 0,
          paymentStatus: invoice?.paymentStatus ?? 'unpaid',
          estimatedMiles: invoice != null
              ? double.tryParse(invoice.estimatedMiles.trim())
              : 18.4,
          notes: summarizeVanNotes(
            invoice?.invoiceNotes.isNotEmpty == true
                ? invoice!.invoiceNotes
                : reply.additionalNotes,
          ),
        ),
      );
    }

    return VanJobReportData(
      businessProfile: profile,
      range: _range,
      generatedAt: now,
      rangeStart: rangeStart,
      rangeEndExclusive: rangeEndExclusive,
      entries: entries,
    );
  }

  Future<void> _scrollToPreview() async {
    final context = _previewKey.currentContext;
    if (context == null) {
      return;
    }

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  Future<void> _shareReportText(VanJobReportData report) async {
    if (!report.hasEntries) {
      _showSnack('No completed jobs yet.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: report.buildShareText(),
          subject: 'Job report ${report.rangeLabel}',
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Job report text share failed: $error');
      }
      if (mounted) {
        _showSnack('Sharing is not available on this device.');
      }
    }
  }

  Future<void> _exportReportPdf(VanJobReportData report) async {
    if (!report.hasEntries || _exporting) {
      if (!report.hasEntries) {
        _showSnack('No completed jobs yet.');
      }
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final pdfPath = await buildVanJobReportPdfPath(report);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfPath, name: _safeAttachmentName(report))],
          text: 'Van Mate job report',
          subject: 'Job report ${report.rangeLabel}',
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Job report PDF export failed: $error');
      }
      if (mounted) {
        _showSnack('Could not create report PDF.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  String _safeAttachmentName(VanJobReportData report) {
    final prefix = report.range == VanJobReportRange.today
        ? formatVanDateForFile(report.rangeStart)
        : 'Week-${formatVanDateForFile(report.rangeStart)}';
    return 'VanMate-Job-Report-$prefix.pdf';
  }

  Widget _buildShellCard({Key? key, required Widget child}) {
    return KeyedSubtree(
      key: key,
      child: ClipRRect(
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
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final button = filled
        ? FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: color.withValues(alpha: 0.65)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );

    return SizedBox(height: 48, child: button);
  }

  Widget _buildFilterChip(String label, VanJobReportRange range) {
    final selected = _range == range;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _range = range;
        });
      },
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.85),
        fontWeight: FontWeight.w800,
      ),
      selectedColor: const Color(0xFF4A7DFF).withValues(alpha: 0.30),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _buildComingSoonChip() {
    return Chip(
      label: Text(
        'Custom later',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.70),
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
  }

  Widget _buildSummaryCard(VanJobReportData report) {
    return _buildShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job reports',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Export completed jobs, quotes and invoices for the office.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('Today', VanJobReportRange.today),
              _buildFilterChip('This week', VanJobReportRange.thisWeek),
              _buildComingSoonChip(),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                'Completed ${report.completedJobsCount}',
                Colors.white,
              ),
              _buildInfoChip(
                'Quotes ${report.quotesSentCount}',
                const Color(0xFF58D0A4),
              ),
              _buildInfoChip(
                'Invoices ${report.invoicesCreatedCount}',
                const Color(0xFF4A7DFF),
              ),
              _buildInfoChip(
                'Quoted ${report.totalQuotedText}',
                const Color(0xFFB48CFF),
              ),
              _buildInfoChip(
                'Invoiced ${report.totalInvoicedText}',
                const Color(0xFF4A7DFF),
              ),
              _buildInfoChip(
                'Paid ${report.totalPaidText}',
                const Color(0xFF58D0A4),
              ),
              _buildInfoChip(
                'Outstanding ${report.totalOutstandingText}',
                const Color(0xFFFFC56F),
              ),
              _buildInfoChip(
                'Miles ${report.totalMilesText}',
                const Color(0xFF58D0A4),
              ),
              _buildInfoChip(
                'Mileage charges ${report.totalMileageChargesText}',
                const Color(0xFFB48CFF),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Completed job value ${report.totalCompletedJobValueText}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.20),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.96),
          fontSize: 11.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildReportPreview(VanJobReportData report) {
    if (!report.hasEntries) {
      return _buildShellCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No completed jobs yet.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Completed jobs will appear in reports after they are marked completed.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            _buildActionButton(
              label: 'Back to jobs',
              icon: Icons.arrow_back_rounded,
              color: const Color(0xFF4A7DFF),
              filled: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    return _buildShellCard(
      key: _previewKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.previewTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            report.previewSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Completed jobs: ${report.completedJobsCount}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quotes sent: ${report.quotesSentCount}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Invoices created: ${report.invoicesCreatedCount}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Total quoted: ${report.totalQuotedText}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Total invoiced: ${report.totalInvoicedText}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Paid: ${report.totalPaidText}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Outstanding: ${report.totalOutstandingText}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Total miles: ${report.totalMilesText}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Mileage charges included: ${report.totalMileageChargesText}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Completed job value: ${report.totalCompletedJobValueText}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < report.entries.length; i++) ...[
            _buildJobPreviewCard(report.entries[i], index: i + 1),
            if (i < report.entries.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildJobPreviewCard(VanJobReportEntry entry, {required int index}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ${sanitizeVanText(entry.customerName).trim()} - ${sanitizeVanText(entry.jobTitle).trim()}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.completionLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          if (entry.scheduledLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.scheduledLabel!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildSmallChip(
                entry.hasQuote
                    ? 'Quote ${formatVanCurrency(entry.quoteAmount ?? 0)}'
                    : 'Quote none',
                const Color(0xFF58D0A4),
              ),
              _buildSmallChip(entry.invoiceLabel, const Color(0xFF4A7DFF)),
              _buildSmallChip(
                entry.exactPinSaved ? 'Pin saved' : 'Pin not saved',
                const Color(0xFFB48CFF),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.address,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          if (entry.phone != null && entry.phone!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.phone!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            entry.quoteLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            entry.invoiceLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Text(
            'Miles: ${entry.estimatedMiles == null ? '-' : formatVanMileage(entry.estimatedMiles ?? 0)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          if (entry.hasMileageCharge)
            Text(
              'Mileage charge included: ${formatVanCurrency(entry.mileageCharge ?? 0)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.80),
              ),
            ),
          Text(
            'Exact pin: ${entry.exactPinSaved ? 'saved' : 'not saved'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          if ((entry.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${entry.notes}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 10.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _buildReportData();

    return Scaffold(
      backgroundColor: const Color(0xFF09111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Job reports'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1622), Color(0xFF09111A)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(report),
                          const SizedBox(height: 12),
                          _buildReportPreview(report),
                          const SizedBox(height: 12),
                          _buildShellCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Actions',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final stacked = constraints.maxWidth < 520;
                                    final buttons = <Widget>[
                                      _buildActionButton(
                                        label: 'Preview report',
                                        icon: Icons.preview_outlined,
                                        color: const Color(0xFF4A7DFF),
                                        filled: true,
                                        onTap: report.hasEntries
                                            ? _scrollToPreview
                                            : null,
                                      ),
                                      _buildActionButton(
                                        label: _exporting
                                            ? 'Exporting...'
                                            : 'Export report PDF',
                                        icon: Icons.picture_as_pdf_outlined,
                                        color: const Color(0xFFB48CFF),
                                        onTap: report.hasEntries && !_exporting
                                            ? () => _exportReportPdf(report)
                                            : null,
                                      ),
                                      _buildActionButton(
                                        label: 'Share report text',
                                        icon: Icons.share_outlined,
                                        color: const Color(0xFF58D0A4),
                                        onTap: report.hasEntries
                                            ? () => _shareReportText(report)
                                            : null,
                                      ),
                                      _buildActionButton(
                                        label: 'Back to jobs',
                                        icon: Icons.arrow_back_rounded,
                                        color: const Color(0xFF4A7DFF),
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                    ];

                                    if (stacked) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (
                                            var i = 0;
                                            i < buttons.length;
                                            i++
                                          ) ...[
                                            buttons[i],
                                            if (i < buttons.length - 1)
                                              const SizedBox(height: 10),
                                          ],
                                        ],
                                      );
                                    }

                                    return Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: buttons
                                          .map(
                                            (button) => SizedBox(
                                              width:
                                                  (constraints.maxWidth - 10) /
                                                  2,
                                              child: button,
                                            ),
                                          )
                                          .toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
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
