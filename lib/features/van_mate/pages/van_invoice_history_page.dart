// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/van_invoice_pdf_helper.dart';
import '../models/van_invoice_draft.dart';
import 'driver_customer_reply_mock_page.dart';
import 'van_invoice_preview_page.dart';

Future<void> openVanInvoiceHistoryPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const VanInvoiceHistoryPage()),
  );
}

class VanInvoiceHistoryPage extends StatefulWidget {
  const VanInvoiceHistoryPage({super.key});

  @override
  State<VanInvoiceHistoryPage> createState() => _VanInvoiceHistoryPageState();
}

class _VanInvoiceHistoryPageState extends State<VanInvoiceHistoryPage> {
  bool _isHydratingInvoices = false;

  @override
  void initState() {
    super.initState();
    _hydrateInvoices();
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _hydrateInvoices() async {
    _isHydratingInvoices = true;

    try {
      await DriverReplyMockState.instance.loadInvoicesFromCloud();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Past invoices cloud hydrate failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHydratingInvoices = false;
        });
      }
    }
  }

  List<VanInvoiceDraft> _invoices() {
    return DriverReplyMockState.instance.savedInvoiceHistory
        .map((entry) => entry.draft)
        .toList();
  }

  Future<void> _openInvoice(BuildContext context, VanInvoiceDraft draft) async {
    final updated = await openVanInvoicePreviewPage(context, draft);
    if (!mounted || updated == null) {
      return;
    }

    setState(() {});
  }

  Future<void> _shareText(BuildContext context, VanInvoiceDraft draft) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: draft.buildInvoiceShareText(),
          subject: 'Invoice ${draft.invoiceNumber}',
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Invoice text share failed: $error');
      }
      if (context.mounted) {
        _showSnack(context, 'Sharing is not available on this device.');
      }
    }
  }

  Future<void> _copyText(BuildContext context, VanInvoiceDraft draft) async {
    await Clipboard.setData(ClipboardData(text: draft.buildInvoiceShareText()));
    if (context.mounted) {
      _showSnack(context, 'Invoice text copied.');
    }
  }

  Future<void> _exportPdf(BuildContext context, VanInvoiceDraft draft) async {
    try {
      final pdfPath = await buildVanInvoicePdfPath(draft);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfPath, name: _safePdfAttachmentName(draft))],
          text: 'Invoice ${draft.invoiceNumber} from Van Mate',
          subject: 'Invoice ${draft.invoiceNumber}',
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Invoice PDF export failed: $error');
      }
      if (context.mounted) {
        _showSnack(context, 'Could not create invoice PDF.');
      }
    }
  }

  Future<void> _markPaid(BuildContext context, VanInvoiceDraft draft) async {
    final jobKey = draft.jobKey?.trim();
    if (jobKey == null || jobKey.isEmpty) {
      _showSnack(context, 'Save the invoice first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark invoice as paid?'),
        content: const Text('This will remove it from outstanding totals.'),
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
      _showSnack(context, 'Could not update invoice status.');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnack(context, 'Invoice marked as paid.');
  }

  String _safePdfAttachmentName(VanInvoiceDraft draft) {
    final invoiceNumber = draft.invoiceNumber.trim();
    final normalized = invoiceNumber.isEmpty
        ? 'VanMate-Invoice-${DateTime.now().millisecondsSinceEpoch}'
        : 'VanMate-Invoice-${invoiceNumber.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')}';
    return '${normalized.replaceAll(RegExp(r'\s+'), '-')}.pdf';
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
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

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.20),
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

  Widget _buildInvoiceCard(BuildContext context, VanInvoiceDraft draft) {
    final statusLabel = draft.isPaid ? 'Paid' : 'Unpaid';
    final statusColor = draft.isPaid
        ? const Color(0xFF58D0A4)
        : const Color(0xFFFFC56F);
    final statusIcon = draft.isPaid
        ? Icons.check_circle
        : Icons.hourglass_bottom;

    return _buildShellCard(
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
                      'Invoice ${draft.invoiceNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.customerName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.jobReference,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                draft.totalDueText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(statusLabel, statusColor, statusIcon),
              _buildStatusChip(
                'Completed job',
                const Color(0xFF4A7DFF),
                Icons.history,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            draft.invoiceDate,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final buttons = <Widget>[
                _buildActionButton(
                  label: 'View invoice',
                  icon: Icons.receipt_long,
                  color: const Color(0xFF4A7DFF),
                  filled: true,
                  onTap: () => _openInvoice(context, draft),
                ),
                _buildActionButton(
                  label: 'Export PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  color: const Color(0xFFB48CFF),
                  onTap: () => _exportPdf(context, draft),
                ),
                _buildActionButton(
                  label: 'Copy text',
                  icon: Icons.copy_rounded,
                  color: const Color(0xFF58D0A4),
                  onTap: () => _copyText(context, draft),
                ),
                _buildActionButton(
                  label: 'Share text',
                  icon: Icons.share_outlined,
                  color: const Color(0xFF4A7DFF),
                  onTap: () => _shareText(context, draft),
                ),
                if (!draft.isPaid)
                  _buildActionButton(
                    label: 'Mark paid',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF58D0A4),
                    onTap: () => _markPaid(context, draft),
                  ),
              ];

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                children: buttons
                    .map(
                      (button) => SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: button,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _invoices();

    return Scaffold(
      backgroundColor: const Color(0xFF09111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Past invoices'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShellCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice history',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Saved invoices from completed jobs appear here.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isHydratingInvoices && invoices.isEmpty)
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loading invoices...',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Fetching saved invoices from Firestore.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.74),
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      )
                    else if (invoices.isEmpty)
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No invoices yet.',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Saved invoices from completed jobs will appear here.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
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
                      )
                    else ...[
                      for (var i = 0; i < invoices.length; i++) ...[
                        _buildInvoiceCard(context, invoices[i]),
                        if (i < invoices.length - 1) const SizedBox(height: 12),
                      ],
                    ],
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
