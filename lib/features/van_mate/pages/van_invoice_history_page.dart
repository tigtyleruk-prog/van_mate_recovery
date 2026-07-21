// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_invoice_pdf_helper.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_invoice_history_entry.dart';
import '../services/van_invoice_reminder_service.dart';
import 'driver_customer_reply_mock_page.dart';
import 'van_quick_invoice_page.dart';
import 'van_invoice_preview_page.dart';
import '../widgets/van_back_business_hub_buttons.dart';

enum VanInvoiceHistoryFilter { all, unpaid, paid }

Future<void> openVanInvoiceHistoryPage(
  BuildContext context, {
  VanInvoiceHistoryFilter initialFilter = VanInvoiceHistoryFilter.all,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VanInvoiceHistoryPage(initialFilter: initialFilter),
    ),
  );
}

class VanInvoiceHistoryPage extends StatefulWidget {
  const VanInvoiceHistoryPage({
    super.key,
    this.initialFilter = VanInvoiceHistoryFilter.all,
  });

  final VanInvoiceHistoryFilter initialFilter;

  @override
  State<VanInvoiceHistoryPage> createState() => _VanInvoiceHistoryPageState();
}

class _VanInvoiceHistoryPageState extends State<VanInvoiceHistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isHydratingInvoices = false;
  String _searchQuery = '';
  VanInvoiceHistoryFilter _activeFilter = VanInvoiceHistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
    DriverReplyMockState.instance.addListener(_handleStateChanged);
    unawaited(_hydrateInvoices());
  }

  @override
  void dispose() {
    _searchController.dispose();
    DriverReplyMockState.instance.removeListener(_handleStateChanged);
    super.dispose();
  }

  void _handleStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _hydrateInvoices() async {
    setState(() {
      _isHydratingInvoices = true;
    });

    try {
      await DriverReplyMockState.instance.loadInvoicesFromCloud();
      await _runReminderCheck();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Invoice cloud hydrate failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHydratingInvoices = false;
        });
      }
    }
  }

  Future<void> _runReminderCheck() {
    return VanInvoiceReminderService.instance.runReminderCheck(
      invoices: DriverReplyMockState.instance.savedInvoiceHistory,
      onReminderSent: (jobKey, stageDays, sentAt) async {
        DriverReplyMockState.instance.markInvoiceReminderSentForJob(
          jobKey,
          stageDays: stageDays,
          sentAt: sentAt,
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<VanInvoiceHistoryEntry> get _allInvoices {
    final invoices = DriverReplyMockState.instance.savedInvoiceHistory.toList(
      growable: false,
    )..sort((a, b) => _activityDateFor(b).compareTo(_activityDateFor(a)));
    return invoices;
  }

  List<VanInvoiceHistoryEntry> get _visibleInvoices {
    final query = _searchQuery.trim().toLowerCase();
    return _allInvoices
        .where((entry) {
          final matchesFilter = switch (_activeFilter) {
            VanInvoiceHistoryFilter.all => true,
            VanInvoiceHistoryFilter.unpaid => entry.draft.isUnpaid,
            VanInvoiceHistoryFilter.paid => entry.draft.isPaid,
          };
          if (!matchesFilter) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final haystack = <String>[
            entry.draft.invoiceNumber,
            entry.draft.customerName,
            entry.draft.jobReference,
            entry.draft.customerPhone,
            entry.draft.billingAddress,
          ].join('\n').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  DateTime _activityDateFor(VanInvoiceHistoryEntry entry) {
    if (entry.draft.isPaid) {
      return entry.draft.paidAt ?? entry.updatedAt ?? entry.savedAt;
    }
    return _invoiceDate(entry) ?? entry.createdAt ?? entry.savedAt;
  }

  DateTime? _invoiceDate(VanInvoiceHistoryEntry entry) {
    return parseVanInvoiceReminderDate(entry.draft.invoiceDate) ??
        entry.createdAt ??
        entry.savedAt;
  }

  DateTime? _dueDate(VanInvoiceHistoryEntry entry) {
    return parseVanInvoiceReminderDate(entry.draft.dueDate);
  }

  DateTime? _paidDate(VanInvoiceHistoryEntry entry) {
    if (!entry.draft.isPaid) {
      return null;
    }
    return entry.draft.paidAt ?? entry.updatedAt ?? entry.savedAt;
  }

  String _displayInvoiceNumber(VanInvoiceHistoryEntry entry) {
    final number = sanitizeVanText(entry.draft.invoiceNumber).trim();
    return number.isEmpty ? '--' : number;
  }

  String _displayCustomerName(VanInvoiceHistoryEntry entry) {
    final customer = sanitizeVanText(entry.draft.customerName).trim();
    return customer.isEmpty ? 'Customer not set' : customer;
  }

  String _displayJobTitle(VanInvoiceHistoryEntry entry) {
    final job = sanitizeVanText(entry.draft.jobReference).trim();
    return job.isEmpty ? 'Job not set' : job;
  }

  String _displayPhone(VanInvoiceHistoryEntry entry) {
    return sanitizeVanCustomerPhoneNumber(entry.draft.customerPhone);
  }

  String _displayInvoiceDateLabel(VanInvoiceHistoryEntry entry) {
    final date = _invoiceDate(entry);
    return date == null ? '--' : formatDate(date);
  }

  String _displayDueLabel(VanInvoiceHistoryEntry entry) {
    final rawDue = sanitizeVanText(entry.draft.dueDate).trim();
    if (rawDue.isEmpty) {
      return 'Due on receipt';
    }
    final dueDate = _dueDate(entry);
    return dueDate == null ? rawDue : formatDate(dueDate);
  }

  String _displayPaidDateLabel(VanInvoiceHistoryEntry entry) {
    final paidDate = _paidDate(entry);
    return paidDate == null ? '--' : formatDate(paidDate);
  }

  Future<void> _openInvoice(VanInvoiceHistoryEntry entry) async {
    final updated = await openVanInvoicePreviewPage(context, entry.draft);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {});
  }

  Future<void> _shareInvoice(VanInvoiceHistoryEntry entry) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: entry.draft.buildInvoiceShareText(),
          subject: 'Invoice ${_displayInvoiceNumber(entry)}',
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Invoice share failed: $error');
      }
      _showSnack('Sharing is not available on this device.');
    }
  }

  Future<void> _exportPdf(VanInvoiceHistoryEntry entry) async {
    try {
      final pdfPath = await buildVanInvoicePdfPath(entry.draft);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfPath, name: _safePdfAttachmentName(entry))],
          text: 'Invoice ${_displayInvoiceNumber(entry)} from Van Mate',
          subject: 'Invoice ${_displayInvoiceNumber(entry)}',
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Invoice PDF export failed: $error');
      }
      _showSnack('Could not create invoice PDF.');
    }
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

    setState(() {});
    _showSnack('Invoice marked as paid.');
  }

  Future<void> _callCustomer(VanInvoiceHistoryEntry entry) async {
    await launchCustomerPhone(context, entry.draft.customerPhone);
  }

  Future<void> _textCustomerReminder(VanInvoiceHistoryEntry entry) async {
    final phone = _displayPhone(entry);
    if (phone.isEmpty) {
      _showSnack('No customer phone number is saved.');
      return;
    }

    final invoiceNumber = _displayInvoiceNumber(entry);
    final customerName = _displayCustomerName(entry);
    final message =
        'Hi $customerName, invoice $invoiceNumber for ${entry.draft.totalDueText} '
        'is still awaiting payment. Thank you.';
    final launched = await textCustomerRequest(
      phoneNumber: phone,
      message: message,
    );
    if (!launched && mounted) {
      _showSnack('Could not open your text app.');
    }
  }

  VanInvoiceReminderInsight _reminderInsight(VanInvoiceHistoryEntry entry) {
    return analyzeVanInvoiceReminder(entry);
  }

  String _safePdfAttachmentName(VanInvoiceHistoryEntry entry) {
    final invoiceNumber = _displayInvoiceNumber(entry);
    final normalized = invoiceNumber == '--'
        ? 'VanMate-Invoice-${DateTime.now().millisecondsSinceEpoch}'
        : 'VanMate-Invoice-${invoiceNumber.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')}';
    return '${normalized.replaceAll(RegExp(r'\s+'), '-')}.pdf';
  }

  String _emptyStateTitle() {
    if (_searchQuery.trim().isNotEmpty) {
      return 'No invoices found.';
    }
    return switch (_activeFilter) {
      VanInvoiceHistoryFilter.all => 'No invoices yet.',
      VanInvoiceHistoryFilter.unpaid => 'No unpaid invoices.',
      VanInvoiceHistoryFilter.paid => 'No paid invoices yet.',
    };
  }

  String _emptyStateBody() {
    if (_searchQuery.trim().isNotEmpty) {
      return 'Try another customer, job or invoice number.';
    }
    return switch (_activeFilter) {
      VanInvoiceHistoryFilter.all =>
        'Create an invoice now, or generate one later from a completed job.',
      VanInvoiceHistoryFilter.unpaid => 'Everything is paid up.',
      VanInvoiceHistoryFilter.paid => '',
    };
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

  Widget _buildStatusChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
              side: BorderSide(color: color.withValues(alpha: 0.56)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );

    return SizedBox(height: 48, child: button);
  }

  Widget _buildFilterChip(VanInvoiceHistoryFilter filter, String label) {
    final selected = _activeFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.78),
        fontWeight: FontWeight.w800,
        fontSize: 12.8,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(
        color: selected
            ? const Color(0xFF4A7DFF).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.22),
      ),
      selectedColor: const Color(0xFF4A7DFF).withValues(alpha: 0.26),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      onSelected: (_) {
        setState(() {
          _activeFilter = filter;
        });
      },
    );
  }

  Widget _buildInvoiceCard(VanInvoiceHistoryEntry entry) {
    final draft = entry.draft;
    final phone = _displayPhone(entry);
    final isPaid = draft.isPaid;
    final statusLabel = isPaid ? 'Paid' : 'Awaiting payment';
    final statusColor = isPaid
        ? const Color(0xFF58D0A4)
        : const Color(0xFFFFC56F);
    final statusIcon = isPaid ? Icons.check_circle : Icons.hourglass_bottom;
    final reminderInsight = _reminderInsight(entry);

    final buttons = <Widget>[
      _buildActionButton(
        label: 'View invoice',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF4A7DFF),
        filled: true,
        onTap: () => _openInvoice(entry),
      ),
      _buildActionButton(
        label: 'Share invoice',
        icon: Icons.share_outlined,
        color: const Color(0xFF4A7DFF),
        onTap: () => _shareInvoice(entry),
      ),
      _buildActionButton(
        label: 'Export PDF',
        icon: Icons.picture_as_pdf_outlined,
        color: const Color(0xFF4A7DFF),
        onTap: () => _exportPdf(entry),
      ),
      if (!isPaid)
        _buildActionButton(
          label: 'Mark paid',
          icon: Icons.payments_outlined,
          color: const Color(0xFF58D0A4),
          onTap: () => _markPaid(entry),
        ),
      if (phone.isNotEmpty)
        _buildActionButton(
          label: 'Call customer',
          icon: Icons.phone,
          color: const Color(0xFF4A7DFF),
          onTap: () => _callCustomer(entry),
        ),
      if (!isPaid && phone.isNotEmpty)
        _buildActionButton(
          label: 'Text customer',
          icon: Icons.sms_outlined,
          color: const Color(0xFF4A7DFF),
          onTap: () => _textCustomerReminder(entry),
        ),
    ];

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
                      'Invoice ${_displayInvoiceNumber(entry)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _displayCustomerName(entry),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _displayJobTitle(entry),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                draft.totalDueText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
              _buildStatusChip(
                label: statusLabel,
                color: statusColor,
                icon: statusIcon,
              ),
              if (!isPaid && reminderInsight.showReminderHint)
                _buildStatusChip(
                  label: reminderInsight.reminderHintLabel,
                  color: reminderInsight.hasReminderSent
                      ? const Color(0xFF4A7DFF)
                      : const Color(0xFFFF8D6C),
                  icon: reminderInsight.hasReminderSent
                      ? Icons.notifications_active_outlined
                      : Icons.schedule_outlined,
                ),
              if (!isPaid && reminderInsight.hasReminderSent)
                _buildStatusChip(
                  label: 'Reminder sent',
                  color: const Color(0xFF4A7DFF),
                  icon: Icons.check_circle_outline,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Invoice date: ${_displayInvoiceDateLabel(entry)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPaid
                ? 'Paid date: ${_displayPaidDateLabel(entry)}'
                : 'Due: ${_displayDueLabel(entry)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
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

              final columns = buttons.length >= 4 ? 2 : buttons.length;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final button in buttons)
                    SizedBox(width: width, child: button),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _visibleInvoices;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final emptyStateBody = _emptyStateBody();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Invoices'),
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
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
              children: [
                _buildShellCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invoices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search, view and share saved invoices.',
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
                _buildShellCard(
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
                      hintText: 'Search invoice, customer or job',
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
                _buildShellCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(VanInvoiceHistoryFilter.all, 'All'),
                      _buildFilterChip(
                        VanInvoiceHistoryFilter.unpaid,
                        'Unpaid',
                      ),
                      _buildFilterChip(VanInvoiceHistoryFilter.paid, 'Paid'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_isHydratingInvoices && _allInvoices.isEmpty)
                  _buildShellCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loading invoices...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fetching saved invoices.',
                          style: TextStyle(
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
                          _emptyStateTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (emptyStateBody.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            emptyStateBody,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _allInvoices.isEmpty
                              ? () =>
                                    unawaited(openVanQuickInvoicePage(context))
                              : () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _activeFilter = VanInvoiceHistoryFilter.all;
                                  });
                                },
                          icon: Icon(
                            _allInvoices.isEmpty
                                ? Icons.add_rounded
                                : Icons.filter_alt_off_outlined,
                          ),
                          label: Text(
                            _allInvoices.isEmpty
                                ? 'Create an invoice'
                                : 'Clear filters',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (var index = 0; index < invoices.length; index++) ...[
                    _buildInvoiceCard(invoices[index]),
                    if (index < invoices.length - 1) const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
