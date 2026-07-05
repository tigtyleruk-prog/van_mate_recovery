import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_invoice_history_entry.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import 'driver_customer_reply_mock_page.dart';
import 'van_invoice_preview_page.dart';

enum VanPaymentsEarningsInvoiceFilter { all, awaitingPayment, paid }

Future<void> openVanPaymentsEarningsPage(
  BuildContext context, {
  VanPaymentsEarningsInvoiceFilter initialFilter =
      VanPaymentsEarningsInvoiceFilter.all,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VanPaymentsEarningsPage(initialFilter: initialFilter),
    ),
  );
}

class VanPaymentsEarningsPage extends StatefulWidget {
  const VanPaymentsEarningsPage({
    super.key,
    this.initialFilter = VanPaymentsEarningsInvoiceFilter.all,
  });

  final VanPaymentsEarningsInvoiceFilter initialFilter;

  @override
  State<VanPaymentsEarningsPage> createState() =>
      _VanPaymentsEarningsPageState();
}

class _VanPaymentsEarningsPageState extends State<VanPaymentsEarningsPage> {
  final GlobalKey _invoiceSectionKey = GlobalKey();

  bool _hydratingInvoices = false;
  late VanPaymentsEarningsInvoiceFilter _invoiceFilter;

  @override
  void initState() {
    super.initState();
    _invoiceFilter =
        widget.initialFilter == VanPaymentsEarningsInvoiceFilter.all
        ? VanPaymentsEarningsInvoiceFilter.awaitingPayment
        : widget.initialFilter;
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
      _hydratingInvoices = true;
    });
    try {
      await DriverReplyMockState.instance.loadInvoicesFromCloud();
    } finally {
      if (mounted) {
        setState(() {
          _hydratingInvoices = false;
        });
      }
    }
  }

  List<VanInvoiceHistoryEntry> get _invoices =>
      DriverReplyMockState.instance.savedInvoiceHistory;

  List<VanInvoiceHistoryEntry> get _paidInvoices =>
      _invoices.where((entry) => entry.draft.isPaid).toList(growable: false);

  List<VanInvoiceHistoryEntry> get _unpaidInvoices =>
      _invoices.where((entry) => entry.draft.isUnpaid).toList(growable: false);

  bool _isThisMonth(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year && value.month == now.month;
  }

  bool _isThisYear(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year;
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
      final yearRaw = int.tryParse(slash.group(3) ?? '');
      if (day == null || month == null || yearRaw == null) {
        return null;
      }
      final year = yearRaw < 100 ? yearRaw + 2000 : yearRaw;
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
      final month = _monthFromName(words.group(2) ?? '');
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

  int? _monthFromName(String month) {
    const lookup = <String, int>{
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
    return lookup[month.trim().toLowerCase()];
  }

  DateTime _invoiceActivityDate(VanInvoiceHistoryEntry entry) {
    if (entry.draft.isPaid) {
      return entry.draft.paidAt ?? entry.updatedAt ?? entry.savedAt;
    }
    return entry.createdAt ?? entry.savedAt;
  }

  DateTime? _invoiceDate(VanInvoiceHistoryEntry entry) {
    return _parseInvoiceDate(entry.draft.invoiceDate) ??
        entry.createdAt ??
        entry.savedAt;
  }

  DateTime? _paidDate(VanInvoiceHistoryEntry entry) {
    if (!entry.draft.isPaid) {
      return null;
    }
    return entry.draft.paidAt ?? entry.updatedAt ?? entry.savedAt;
  }

  double _sumInvoices(Iterable<VanInvoiceHistoryEntry> entries) {
    return entries.fold<double>(
      0,
      (total, entry) => total + entry.draft.totalDue,
    );
  }

  double _thisMonthIncome() {
    return _paidInvoices.fold<double>(0, (total, entry) {
      final paidAt = _invoiceActivityDate(entry);
      if (_isThisMonth(paidAt)) {
        return total + entry.draft.totalDue;
      }
      return total;
    });
  }

  double _yearToDateIncome() {
    return _paidInvoices.fold<double>(0, (total, entry) {
      final paidAt = _invoiceActivityDate(entry);
      if (_isThisYear(paidAt)) {
        return total + entry.draft.totalDue;
      }
      return total;
    });
  }

  List<VanInvoiceHistoryEntry> _filteredInvoiceEntries() {
    return switch (_invoiceFilter) {
      VanPaymentsEarningsInvoiceFilter.all => _invoices,
      VanPaymentsEarningsInvoiceFilter.awaitingPayment => _unpaidInvoices,
      VanPaymentsEarningsInvoiceFilter.paid => _paidInvoices,
    };
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

  Future<void> _callCustomer(VanInvoiceHistoryEntry entry) async {
    await launchCustomerPhone(context, entry.draft.customerPhone);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _setInvoiceFilterAndJump(VanPaymentsEarningsInvoiceFilter filter) {
    setState(() {
      _invoiceFilter = filter;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _invoiceSectionKey.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
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
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payments & Earnings',
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
            'See what you\'ve been paid and what\'s still owed.',
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

  Widget _buildMetricGrid(List<_MetricCardData> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 420
            ? 2
            : 1;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: _cardWidth(constraints.maxWidth, columns, 8),
                child: _MetricCard(data: item),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Money Overview',
          subtitle: 'What is still owed and what has already been paid.',
        ),
        const SizedBox(height: 12),
        _buildMetricGrid([
          _MetricCardData(
            title: 'Awaiting payment',
            value: formatCurrency(_sumInvoices(_unpaidInvoices)),
            subtitle:
                '${_unpaidInvoices.length} unpaid invoice${_unpaidInvoices.length == 1 ? '' : 's'}',
            icon: Icons.pending_actions_outlined,
            accent: const Color(0xFFFFC56F),
            onTap: () => _setInvoiceFilterAndJump(
              VanPaymentsEarningsInvoiceFilter.awaitingPayment,
            ),
          ),
          _MetricCardData(
            title: 'Paid this month',
            value: formatCurrency(_thisMonthIncome()),
            subtitle: 'Paid invoice income',
            icon: Icons.calendar_month_outlined,
            accent: const Color(0xFF4A7DFF),
            onTap: () =>
                _setInvoiceFilterAndJump(VanPaymentsEarningsInvoiceFilter.paid),
          ),
          _MetricCardData(
            title: 'Paid this year',
            value: formatCurrency(_yearToDateIncome()),
            subtitle: 'Paid invoice income',
            icon: Icons.timeline_outlined,
            accent: const Color(0xFF4A7DFF),
            onTap: () =>
                _setInvoiceFilterAndJump(VanPaymentsEarningsInvoiceFilter.paid),
          ),
        ]),
      ],
    );
  }

  Widget _buildInvoiceFilterChips() {
    Widget buildChip(VanPaymentsEarningsInvoiceFilter filter, String label) {
      final selected = _invoiceFilter == filter;
      return ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: Text(label),
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
            _invoiceFilter = filter;
          });
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        buildChip(
          VanPaymentsEarningsInvoiceFilter.awaitingPayment,
          'Awaiting payment',
        ),
        buildChip(VanPaymentsEarningsInvoiceFilter.paid, 'Paid'),
      ],
    );
  }

  _InvoiceUrgency _invoiceUrgency(VanInvoiceHistoryEntry entry) {
    if (entry.draft.isPaid) {
      return const _InvoiceUrgency(
        label: 'Paid',
        color: Color(0xFF58D0A4),
        icon: Icons.payments_outlined,
      );
    }
    return const _InvoiceUrgency(
      label: 'Awaiting payment',
      color: Color(0xFFFFC56F),
      icon: Icons.hourglass_bottom,
    );
  }

  Widget _buildStatusChip({required _InvoiceUrgency urgency}) {
    final label = urgency.label;
    final color = urgency.color;
    final icon = urgency.icon;

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

  Widget _buildInvoiceAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    if (filled) {
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
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.36)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(VanInvoiceHistoryEntry entry) {
    final isPaid = entry.draft.isPaid;
    final urgency = _invoiceUrgency(entry);
    final invoiceDate = _invoiceDate(entry);
    final paidDate = _paidDate(entry);
    final phone = sanitizeVanCustomerPhoneNumber(entry.draft.customerPhone);
    final invoiceNumber = sanitizeVanText(entry.draft.invoiceNumber).trim();
    final customerName = sanitizeVanText(entry.draft.customerName).trim();
    final jobTitle = sanitizeVanText(entry.draft.jobReference).trim();
    final dueLabel = entry.draft.dueDateLabel;

    return _GlassCard(
      borderColor: isPaid ? null : urgency.color.withValues(alpha: 0.42),
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
                      'Invoice ${invoiceNumber.isEmpty ? '--' : invoiceNumber}',
                      style: const TextStyle(
                        fontSize: 16.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customerName.isEmpty ? 'Customer not set' : customerName,
                      style: TextStyle(
                        fontSize: 13.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    if (jobTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        jobTitle,
                        style: TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.64),
                        ),
                      ),
                    ],
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
          _buildStatusChip(urgency: urgency),
          const SizedBox(height: 12),
          Text(
            'Invoice date: ${invoiceDate == null ? '--' : formatDate(invoiceDate)}',
            style: TextStyle(
              fontSize: 12.6,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPaid
                ? 'Paid date: ${paidDate == null ? '--' : formatDate(paidDate)}'
                : 'Due: $dueLabel',
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
              _buildInvoiceAction(
                label: 'View invoice',
                icon: Icons.receipt_long_outlined,
                onPressed: () => _openInvoice(entry),
                filled: true,
              ),
              if (!isPaid)
                _buildInvoiceAction(
                  label: 'Mark paid',
                  icon: Icons.payments_outlined,
                  onPressed: () => _markPaid(entry),
                ),
              if (phone.isNotEmpty)
                _buildInvoiceAction(
                  label: 'Call customer',
                  icon: Icons.phone,
                  onPressed: () => _callCustomer(entry),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePaymentsSection() {
    final filtered = _filteredInvoiceEntries();
    return Column(
      key: _invoiceSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Invoice Payments',
          subtitle: 'Manage invoices that are unpaid or paid.',
        ),
        const SizedBox(height: 12),
        _GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: _buildInvoiceFilterChips(),
        ),
        const SizedBox(height: 12),
        if (_invoices.isEmpty)
          _GlassCard(
            child: Text(
              'No invoices yet.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else if (filtered.isEmpty)
          _GlassCard(
            child: Text(
              _invoiceFilter == VanPaymentsEarningsInvoiceFilter.paid
                  ? 'No paid invoices yet.'
                  : 'No invoices awaiting payment.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < filtered.length; i++) ...[
                _buildInvoiceCard(filtered[i]),
                if (i < filtered.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final loading = _hydratingInvoices && _invoices.isEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Payments & Earnings'),
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
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeroCard(),
                              const SizedBox(height: 12),
                              _buildOverviewSection(),
                              const SizedBox(height: 12),
                              _buildInvoicePaymentsSection(),
                            ],
                          ),
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

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = textScale > 1.0;

    final card = _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: data.accent.withValues(alpha: 0.16),
                border: Border.all(color: data.accent.withValues(alpha: 0.28)),
              ),
              child: Icon(data.icon, color: Colors.white, size: 17),
            ),
            SizedBox(height: compact ? 8 : 9),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 17.8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 4 : 5),
            Text(
              data.title,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 13.1 : 13.4,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.96),
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.subtitle,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11.6 : 12.0,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),
    );

    if (data.onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(28),
        child: card,
      ),
    );
  }
}

class _InvoiceUrgency {
  const _InvoiceUrgency({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
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
