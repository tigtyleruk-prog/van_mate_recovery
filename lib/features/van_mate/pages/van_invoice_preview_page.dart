// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/van_business_logo_support.dart';
import '../helpers/van_invoice_pdf_helper.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_invoice_draft.dart';
import 'driver_customer_reply_mock_page.dart';
import '../widgets/van_back_business_hub_buttons.dart';

Future<VanInvoiceDraft?> openVanInvoicePreviewPage(
  BuildContext context,
  VanInvoiceDraft draft,
) {
  return Navigator.of(context).push<VanInvoiceDraft?>(
    MaterialPageRoute<VanInvoiceDraft?>(
      builder: (_) => VanInvoicePreviewPage(draft: draft),
    ),
  );
}

class VanInvoicePreviewPage extends StatefulWidget {
  const VanInvoicePreviewPage({super.key, required this.draft});

  final VanInvoiceDraft draft;

  @override
  State<VanInvoicePreviewPage> createState() => _VanInvoicePreviewPageState();
}

class _VanInvoicePreviewPageState extends State<VanInvoicePreviewPage> {
  late VanInvoiceDraft _draft;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _moneyText(num amount) => formatCurrency(amount);

  String _invoiceShareText() => _draft.buildInvoiceShareText();

  bool _validateDueDateBeforeInvoiceAction() {
    if (_draft.dueDate.trim().isNotEmpty) {
      return true;
    }
    _showSnack(
      context,
      'Add a due date or choose Due on receipt before saving the invoice.',
    );
    return false;
  }

  DriverCustomerReplyMockData? get _linkedJob {
    final linkedJobId = _draft.linkedJobId?.trim() ?? '';
    final jobKey = _draft.jobKey?.trim() ?? '';
    if (linkedJobId.isNotEmpty) {
      return DriverReplyMockState.instance.jobById(linkedJobId);
    }
    if (jobKey.isNotEmpty) {
      return DriverReplyMockState.instance.jobById(jobKey);
    }
    return null;
  }

  String _safeAttachmentFileName() {
    final invoiceNumber = _draft.invoiceNumber.trim();
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

  Widget _buildPreviewCard() {
    final draft = _draft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.97),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF0E1522), height: 1.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ColoredBox(
                      color: const Color(0xFF0E1522).withValues(alpha: 0.04),
                      child: buildVanBusinessLogoPreview(
                        draft.logoPath,
                        logoUrl: draft.logoUrl,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    draft.businessName,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0E1522),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Invoice No: ${draft.invoiceNumber}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0E1522),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${draft.invoiceDate}',
              style: TextStyle(
                color: const Color(0xFF0E1522).withValues(alpha: 0.70),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Due: ${draft.dueDateLabel}',
              style: TextStyle(
                color: const Color(0xFF0E1522).withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(
                  draft.isPaid ? 'Paid' : 'Unpaid',
                  draft.isPaid
                      ? const Color(0xFF58D0A4)
                      : const Color(0xFFFFC56F),
                  draft.isPaid ? Icons.check_circle : Icons.hourglass_bottom,
                ),
                if (draft.paidAt != null)
                  Text(
                    'Paid on ${draft.paidAt!.day}/${draft.paidAt!.month}/${draft.paidAt!.year}',
                    style: TextStyle(
                      color: const Color(0xFF0E1522).withValues(alpha: 0.68),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFF0E1522).withValues(alpha: 0.10),
            ),
            const SizedBox(height: 14),
            Text(
              'Bill to:',
              style: TextStyle(
                color: const Color(0xFF0E1522).withValues(alpha: 0.66),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              draft.customerName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0E1522),
              ),
            ),
            Text(
              draft.billingAddress,
              style: TextStyle(
                color: const Color(0xFF0E1522).withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (draft.customerPhone.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                draft.customerPhone,
                style: TextStyle(
                  color: const Color(0xFF0E1522).withValues(alpha: 0.80),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (draft.customerEmail.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                draft.customerEmail,
                style: TextStyle(
                  color: const Color(0xFF0E1522).withValues(alpha: 0.80),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Job: ${draft.jobReference}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF0E1522),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              draft.visibleJobDescription,
              style: TextStyle(
                color: const Color(0xFF0E1522).withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_linkedJob?.completedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Completed: ${formatDate(_linkedJob!.completedAt!)}',
                style: TextStyle(
                  color: const Color(0xFF0E1522).withValues(alpha: 0.74),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF0E1522).withValues(alpha: 0.04),
                border: Border.all(
                  color: const Color(0xFF0E1522).withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0E1522),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < draft.lineItems.length; i++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            draft.lineItems[i].description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0E1522),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _moneyText(draft.lineItems[i].total),
                            textAlign: TextAlign.right,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0E1522),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < draft.lineItems.length - 1)
                      const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: const Color(0xFF0E1522).withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total due',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0E1522),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          draft.totalDueText,
                          textAlign: TextAlign.right,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0E1522),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Payment instructions',
              style: TextStyle(
                color: const Color(0xFF0E1522).withValues(alpha: 0.66),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              draft.paymentInstructionsLabel,
              style: TextStyle(
                color: const Color(0xFF0E1522).withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (draft.hasVisibleInvoiceNotes) ...[
              const SizedBox(height: 14),
              Text(
                'Notes',
                style: TextStyle(
                  color: const Color(0xFF0E1522).withValues(alpha: 0.66),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                draft.visibleInvoiceNotes,
                style: TextStyle(
                  color: const Color(0xFF0E1522).withValues(alpha: 0.88),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF0E1522).withValues(alpha: 0.80),
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid() async {
    final draft = _draft;
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

    final resolvedDraft =
        DriverReplyMockState.instance.invoiceForJob(jobKey) ?? draft;
    final updated = DriverReplyMockState.instance.markInvoicePaidForDraft(
      resolvedDraft,
    );
    if (updated == null) {
      _showSnack(context, 'Could not update invoice status.');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _draft = updated;
    });
    _showSnack(context, 'Invoice marked as paid.');
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf) {
      return;
    }
    if (!_validateDueDateBeforeInvoiceAction()) {
      return;
    }

    setState(() {
      _isExportingPdf = true;
    });

    try {
      final pdfPath = await buildVanInvoicePdfPath(_draft);
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfPath, name: _safeAttachmentFileName())],
          text: 'Invoice ${_draft.invoiceNumber} from Van Mate',
          subject: 'Invoice ${_draft.invoiceNumber}',
        ),
      );

      if (!mounted) {
        return;
      }

      if (shareResult.status == ShareResultStatus.unavailable) {
        _showSnack(context, 'Could not create invoice PDF.');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not create invoice PDF: $error');
      }
      if (mounted) {
        _showSnack(context, 'Could not create invoice PDF.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  Widget _buildActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final exportLabel = _isExportingPdf ? 'Exporting...' : 'Export PDF';
        final canMarkPaid =
            _draft.jobKey?.trim().isNotEmpty == true && !_draft.isPaid;

        final buttons = <Widget>[
          _buildActionButton(
            label: 'Share invoice',
            icon: Icons.share_outlined,
            color: const Color(0xFF4A7DFF),
            filled: true,
            onTap: () async {
              if (!_validateDueDateBeforeInvoiceAction()) {
                return;
              }
              final invoiceText = _invoiceShareText();
              try {
                await SharePlus.instance.share(
                  ShareParams(
                    text: invoiceText,
                    subject: 'Invoice ${_draft.invoiceNumber}',
                  ),
                );
              } catch (_) {
                if (context.mounted) {
                  _showSnack(
                    context,
                    'Sharing is not available on this device.',
                  );
                }
              }
            },
          ),
          _buildActionButton(
            label: _draft.isPaid ? 'Paid' : 'Mark as paid',
            icon: _draft.isPaid ? Icons.check_circle : Icons.payments_outlined,
            color: const Color(0xFF58D0A4),
            onTap: canMarkPaid ? _markAsPaid : null,
          ),
          _buildActionButton(
            label: exportLabel,
            icon: Icons.picture_as_pdf_outlined,
            color: const Color(0xFFB48CFF),
            onTap: _isExportingPdf ? null : _exportPdf,
          ),
          _buildActionButton(
            label: 'Copy invoice text',
            icon: Icons.copy_rounded,
            color: const Color(0xFF58D0A4),
            onTap: () async {
              if (!_validateDueDateBeforeInvoiceAction()) {
                return;
              }
              await Clipboard.setData(ClipboardData(text: _invoiceShareText()));
              if (context.mounted) {
                _showSnack(context, 'Invoice text copied.');
              }
            },
          ),
          _buildActionButton(
            label: 'Back to edit',
            icon: Icons.arrow_back_rounded,
            color: const Color(0xFF4A7DFF),
            onTap: () => Navigator.of(context).pop(_draft),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_draft);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF09111A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Invoice preview'),
          leadingWidth: 96,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: VanBackBusinessHubButtons(
              onBack: () => Navigator.of(context).pop(_draft),
            ),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildShellCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice preview',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review, share or export this invoice.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildShellCard(child: _buildPreviewCard()),
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
                        _buildActions(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
