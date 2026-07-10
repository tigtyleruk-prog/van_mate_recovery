import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_invoice_history_entry.dart';
import 'driver_customer_reply_mock_page.dart';
import 'van_invoice_preview_page.dart';
import '../widgets/van_back_business_hub_buttons.dart';

enum VanPaymentsFilter { all, outstanding, paid }

Future<void> openVanPaymentsPage(
  BuildContext context, {
  VanPaymentsFilter initialFilter = VanPaymentsFilter.all,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VanPaymentsPage(initialFilter: initialFilter),
    ),
  );
}

class VanPaymentsPage extends StatefulWidget {
  const VanPaymentsPage({
    super.key,
    this.initialFilter = VanPaymentsFilter.all,
  });

  final VanPaymentsFilter initialFilter;

  @override
  State<VanPaymentsPage> createState() => _VanPaymentsPageState();
}

class _VanPaymentsPageState extends State<VanPaymentsPage> {
  bool _isHydratingInvoices = false;
  late VanPaymentsFilter _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    unawaited(_hydrateInvoices());
  }

  @override
  void dispose() {
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    super.dispose();
  }

  void _handleDriverStateChanged() {
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
    } finally {
      if (mounted) {
        setState(() {
          _isHydratingInvoices = false;
        });
      }
    }
  }

  List<VanInvoiceHistoryEntry> get _allInvoices =>
      DriverReplyMockState.instance.savedInvoiceHistory;

  List<VanInvoiceHistoryEntry> get _paidInvoices =>
      _allInvoices.where((entry) => entry.draft.isPaid).toList(growable: false);

  List<VanInvoiceHistoryEntry> get _outstandingInvoices => _allInvoices
      .where((entry) => entry.draft.isUnpaid)
      .toList(growable: false);

  List<VanInvoiceHistoryEntry> get _overdueInvoices =>
      _outstandingInvoices.where(_isOverdue).toList(growable: false);

  bool _isOverdue(VanInvoiceHistoryEntry entry) {
    final dueDate = _parseInvoiceDate(entry.draft.dueDate);
    if (dueDate == null || entry.draft.isPaid) {
      return false;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(dueDate).isBefore(today);
  }

  double _sumAmounts(Iterable<VanInvoiceHistoryEntry> entries) {
    return entries.fold<double>(0, (sum, entry) => sum + entry.draft.totalDue);
  }

  String _displayInvoiceNumber(VanInvoiceHistoryEntry entry) {
    final number = sanitizeVanText(entry.draft.invoiceNumber).trim();
    return number.isEmpty ? '--' : number;
  }

  String _displayCustomerName(VanInvoiceHistoryEntry entry) {
    final customer = sanitizeVanText(entry.draft.customerName).trim();
    return customer.isEmpty ? 'Customer not set' : customer;
  }

  DateTime? _invoiceDate(VanInvoiceHistoryEntry entry) {
    return _parseInvoiceDate(entry.draft.invoiceDate) ??
        entry.createdAt ??
        entry.savedAt;
  }

  DateTime? _dueDate(VanInvoiceHistoryEntry entry) {
    return _parseInvoiceDate(entry.draft.dueDate);
  }

  DateTime? _paidDate(VanInvoiceHistoryEntry entry) {
    if (!entry.draft.isPaid) {
      return null;
    }
    return entry.draft.paidAt ?? entry.updatedAt ?? entry.savedAt;
  }

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
      return _tryBuildDate(year, month, day);
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
      return _tryBuildDate(year, month, day);
    }

    return null;
  }

  int? _monthNumber(String raw) {
    final month = raw.trim().toLowerCase();
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
    return months[month];
  }

  DateTime? _tryBuildDate(int year, int month, int day) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final built = DateTime(year, month, day);
    if (built.year != year || built.month != month || built.day != day) {
      return null;
    }
    return built;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
            child: const Text('Mark Paid'),
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

  Widget _buildHeroCard() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF4A7DFF).withValues(alpha: 0.16),
              border: Border.all(
                color: const Color(0xFF4A7DFF).withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(Icons.payments_outlined, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payments',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track paid, unpaid and overdue invoices.',
            style: TextStyle(
              fontSize: 13.2,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalPaid = _sumAmounts(_paidInvoices);
    final outstanding = _sumAmounts(_outstandingInvoices);
    final overdue = _sumAmounts(_overdueInvoices);
    final totalInvoices = _allInvoices.length;

    final cards = <_SummaryCardData>[
      _SummaryCardData(
        title: 'Total Paid',
        value: formatCurrency(totalPaid),
        icon: Icons.check_circle_outline,
        accent: const Color(0xFF58D0A4),
      ),
      _SummaryCardData(
        title: 'Outstanding',
        value: formatCurrency(outstanding),
        icon: Icons.pending_actions_outlined,
        accent: const Color(0xFFFFC56F),
      ),
      _SummaryCardData(
        title: 'Overdue',
        value: formatCurrency(overdue),
        icon: Icons.warning_amber_outlined,
        accent: const Color(0xFFFF8E8E),
      ),
      _SummaryCardData(
        title: 'Total Invoices',
        value: totalInvoices.toString(),
        icon: Icons.receipt_long_outlined,
        accent: const Color(0xFF4A7DFF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 440
            ? 2
            : 1;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final card in cards)
              SizedBox(
                width: _cardWidth(constraints.maxWidth, columns, 8),
                child: _SummaryCard(card: card),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    Widget chip(VanPaymentsFilter filter, String label) {
      final selected = _activeFilter == filter;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.76),
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

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(VanPaymentsFilter.all, 'All invoices'),
          chip(VanPaymentsFilter.outstanding, 'Outstanding'),
          chip(VanPaymentsFilter.paid, 'Paid'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.8,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
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
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
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
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
    Color color = Colors.white,
  }) {
    if (primary) {
      return SizedBox(
        height: 42,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4A7DFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.36)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildOutstandingCard(VanInvoiceHistoryEntry entry) {
    final dueDate = _dueDate(entry);
    final overdue = _isOverdue(entry);
    final phone = sanitizeVanCustomerPhoneNumber(entry.draft.customerPhone);
    final invoiceDate = _invoiceDate(entry);

    return _GlassCard(
      borderColor: overdue
          ? const Color(0xFFFF8E8E).withValues(alpha: 0.42)
          : null,
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
                        fontSize: 16.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayCustomerName(entry),
                      style: TextStyle(
                        fontSize: 13.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCurrency(entry.draft.totalDue),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
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
                label: overdue ? 'Overdue' : 'Unpaid',
                color: overdue
                    ? const Color(0xFFFF8E8E)
                    : const Color(0xFFFFC56F),
                icon: overdue ? Icons.warning_amber : Icons.hourglass_bottom,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Invoice date: ${invoiceDate == null ? (entry.draft.invoiceDate.trim().isEmpty ? '--' : entry.draft.invoiceDate.trim()) : formatDate(invoiceDate)}',
            style: TextStyle(
              fontSize: 12.6,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Due date: ${dueDate == null ? (entry.draft.dueDate.trim().isEmpty ? '--' : entry.draft.dueDate.trim()) : formatDate(dueDate)}',
            style: TextStyle(
              fontSize: 12.6,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionButton(
                label: 'View Invoice',
                icon: Icons.receipt_long_outlined,
                primary: true,
                onPressed: () => _openInvoice(entry),
              ),
              _buildActionButton(
                label: 'Mark Paid',
                icon: Icons.payments_outlined,
                onPressed: () => _markPaid(entry),
              ),
              if (phone.isNotEmpty)
                _buildActionButton(
                  label: 'Call Customer',
                  icon: Icons.phone,
                  color: const Color(0xFF4A7DFF),
                  onPressed: () => _callCustomer(entry),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaidCard(VanInvoiceHistoryEntry entry) {
    final paidDate = _paidDate(entry);
    return _GlassCard(
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
                        fontSize: 16.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayCustomerName(entry),
                      style: TextStyle(
                        fontSize: 13.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCurrency(entry.draft.totalDue),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
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
                label: 'Paid',
                color: const Color(0xFF58D0A4),
                icon: Icons.check_circle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Paid date: ${paidDate == null ? '--' : formatDate(paidDate)}',
            style: TextStyle(
              fontSize: 12.6,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'View Invoice',
            icon: Icons.receipt_long_outlined,
            primary: true,
            onPressed: () => _openInvoice(entry),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList({
    required String title,
    required String subtitle,
    required List<VanInvoiceHistoryEntry> entries,
    required Widget Function(VanInvoiceHistoryEntry entry) builder,
    String? emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          _GlassCard(
            child: Text(
              emptyMessage ?? 'No invoices in this section.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                builder(entries[i]),
                if (i < entries.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isHydratingInvoices && _allInvoices.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final showAll = _activeFilter == VanPaymentsFilter.all;
    final showOutstanding =
        showAll || _activeFilter == VanPaymentsFilter.outstanding;
    final showPaid = showAll || _activeFilter == VanPaymentsFilter.paid;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewPaddingOf(context).bottom + 24,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 12),
                _buildSummaryCards(),
                const SizedBox(height: 12),
                _buildFilterBar(),
                const SizedBox(height: 12),
                if (_allInvoices.isEmpty)
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No invoices yet.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create and save invoices to track payments here.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (showOutstanding) ...[
                    _buildSectionList(
                      title: 'Outstanding Payments',
                      subtitle: 'Unpaid invoices awaiting payment.',
                      entries: _outstandingInvoices,
                      builder: _buildOutstandingCard,
                      emptyMessage: 'No outstanding invoices.',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionList(
                      title: 'Overdue Invoices',
                      subtitle: 'Unpaid invoices past their due date.',
                      entries: _overdueInvoices,
                      builder: _buildOutstandingCard,
                      emptyMessage: 'No overdue invoices.',
                    ),
                  ],
                  if (showOutstanding && showPaid) const SizedBox(height: 12),
                  if (showPaid)
                    _buildSectionList(
                      title: 'Paid Invoices',
                      subtitle: 'Invoices marked as paid.',
                      entries: _paidInvoices,
                      builder: _buildPaidCard,
                      emptyMessage: 'No paid invoices yet.',
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Payments'),
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
          SafeArea(bottom: false, child: _buildBody()),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.card});

  final _SummaryCardData card;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: card.accent.withValues(alpha: 0.16),
              border: Border.all(color: card.accent.withValues(alpha: 0.28)),
            ),
            child: Icon(card.icon, color: Colors.white, size: 17),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                card.value,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 17.8,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            card.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.4,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.96),
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: padding,
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
              color: borderColor ?? Colors.white.withValues(alpha: 0.13),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

double _cardWidth(double maxWidth, int columns, double spacing) {
  if (columns <= 1) {
    return maxWidth;
  }
  return (maxWidth - ((columns - 1) * spacing)) / columns;
}
