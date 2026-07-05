import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_expense_entry.dart';
import '../models/van_invoice_history_entry.dart';
import '../pages/driver_customer_reply_mock_page.dart';
import '../pages/jobs_calendar_schedule_page.dart';
import '../pages/van_expenses_page.dart';
import '../pages/van_payments_page.dart';
import '../services/van_expenses_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';

Future<void> openVanEarningsPage(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VanEarningsPage()));
}

class VanEarningsPage extends StatefulWidget {
  const VanEarningsPage({super.key});

  @override
  State<VanEarningsPage> createState() => _VanEarningsPageState();
}

class _VanEarningsPageState extends State<VanEarningsPage> {
  final VanExpensesStorage _expensesStorage = VanExpensesStorage.instance;
  List<VanExpenseEntry> _expenses = <VanExpenseEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    _expensesStorage.addListener(_handleExpensesChanged);
    unawaited(_loadExpenses());
  }

  @override
  void dispose() {
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    _expensesStorage.removeListener(_handleExpensesChanged);
    super.dispose();
  }

  void _handleDriverStateChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _handleExpensesChanged() {
    unawaited(_loadExpenses());
  }

  Future<void> _loadExpenses() async {
    final loaded = await _expensesStorage.loadAll();
    if (!mounted) {
      return;
    }

    setState(() {
      _expenses = loaded;
      _loading = false;
    });
  }

  List<VanInvoiceHistoryEntry> get _invoiceEntries =>
      DriverReplyMockState.instance.savedInvoiceHistory;

  List<DriverCustomerReplyMockData> get _completedJobs => DriverReplyMockState
      .instance
      .jobs
      .where((job) => job.isCompleted)
      .toList(growable: false);

  bool get _hasEarningsData =>
      _invoiceEntries.isNotEmpty || _completedJobs.isNotEmpty;

  Iterable<VanInvoiceHistoryEntry> get _paidInvoices =>
      _invoiceEntries.where((entry) => entry.draft.isPaid);

  Iterable<VanInvoiceHistoryEntry> get _unpaidInvoices =>
      _invoiceEntries.where((entry) => entry.draft.isUnpaid);

  double _invoiceTotal(VanInvoiceHistoryEntry entry) => entry.draft.totalDue;

  DateTime _invoiceActivityDate(VanInvoiceHistoryEntry entry) {
    return entry.draft.isPaid
        ? (entry.draft.paidAt ?? entry.updatedAt ?? entry.savedAt)
        : (entry.createdAt ?? entry.savedAt);
  }

  double _thisMonthEarned() {
    final now = DateTime.now();
    return _paidInvoices.fold<double>(0, (total, entry) {
      final date = _invoiceActivityDate(entry);
      if (date.year == now.year && date.month == now.month) {
        return total + _invoiceTotal(entry);
      }
      return total;
    });
  }

  double _yearToDateEarned() {
    final now = DateTime.now();
    return _paidInvoices.fold<double>(0, (total, entry) {
      final date = _invoiceActivityDate(entry);
      if (date.year == now.year) {
        return total + _invoiceTotal(entry);
      }
      return total;
    });
  }

  double _outstandingTotal() {
    return _unpaidInvoices.fold<double>(0, (total, entry) {
      return total + _invoiceTotal(entry);
    });
  }

  double _paidInvoicesTotal() {
    return _paidInvoices.fold<double>(0, (total, entry) {
      return total + _invoiceTotal(entry);
    });
  }

  double _totalInvoiceValue() {
    return _invoiceEntries.fold<double>(0, (total, entry) {
      return total + _invoiceTotal(entry);
    });
  }

  double _totalRecordedExpenses() {
    return _expenses.fold<double>(
      0,
      (total, expense) => total + expense.amount,
    );
  }

  double _monthExpenseTotal() {
    final now = DateTime.now();
    return _expenses.fold<double>(0, (total, expense) {
      if (expense.date.year == now.year && expense.date.month == now.month) {
        return total + expense.amount;
      }
      return total;
    });
  }

  double _yearExpenseTotal() {
    final now = DateTime.now();
    return _expenses.fold<double>(0, (total, expense) {
      if (expense.date.year == now.year) {
        return total + expense.amount;
      }
      return total;
    });
  }

  double _totalCompletedJobValue() {
    return _completedJobs.fold<double>(0, (total, job) {
      final invoice = job.invoiceHistoryKey.isNotEmpty
          ? DriverReplyMockState.instance.invoiceForJob(job.invoiceHistoryKey)
          : null;
      return total + (invoice?.totalDue ?? job.quoteAmount ?? 0);
    });
  }

  double _averageJobValue() {
    if (_completedJobs.isEmpty) {
      return 0;
    }
    return _totalCompletedJobValue() / _completedJobs.length;
  }

  List<_ActivityItem> _buildRecentActivity() {
    final items = <_ActivityItem>[];

    for (final entry in _invoiceEntries) {
      final isPaid = entry.draft.isPaid;
      final timestamp = _invoiceActivityDate(entry);
      final invoiceNumber = sanitizeVanText(entry.draft.invoiceNumber).trim();
      final customerName = sanitizeVanText(entry.draft.customerName).trim();
      final jobReference = sanitizeVanText(entry.draft.jobReference).trim();
      final title = isPaid ? 'Paid invoice' : 'New invoice';
      final subtitleParts = <String>[
        if (invoiceNumber.isNotEmpty) invoiceNumber,
        if (customerName.isNotEmpty) customerName,
        if (jobReference.isNotEmpty && jobReference != customerName)
          jobReference,
      ];

      items.add(
        _ActivityItem(
          kind: isPaid ? _ActivityKind.paidInvoice : _ActivityKind.newInvoice,
          title: title,
          subtitle: subtitleParts.join(' | '),
          amount: _invoiceTotal(entry),
          timestamp: timestamp,
        ),
      );
    }

    for (final expense in _expenses) {
      final subtitleParts = <String>[
        if (sanitizeVanText(expense.category).trim().isNotEmpty)
          sanitizeVanText(expense.category).trim(),
        if (expense.supplier.trim().isNotEmpty) expense.supplier.trim(),
      ];

      items.add(
        _ActivityItem(
          kind: _ActivityKind.expenseAdded,
          title: 'Expense added',
          subtitle: subtitleParts.join(' | '),
          amount: -expense.amount,
          timestamp: expense.createdAt,
        ),
      );
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(6).toList(growable: false);
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

  Widget _buildSummaryGrid(List<_MetricCardData> items) {
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

  Widget _buildExpenseGrid(List<_MetricCardData> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 520
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

  Widget _buildIncomeSection() {
    final paidInvoicesCount = _paidInvoices.length;
    final paidInvoicesTotal = _paidInvoicesTotal();
    final totalInvoiceValue = _totalInvoiceValue();
    final completedJobsCount = _completedJobs.length;
    final averageJobValue = _averageJobValue();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Income',
          subtitle: 'A quick view of invoice and completed job performance.',
        ),
        const SizedBox(height: 12),
        _buildSummaryGrid(<_MetricCardData>[
          _MetricCardData(
            title: 'Paid Invoices',
            value: paidInvoicesCount.toString(),
            subtitle: '${_formatPounds(paidInvoicesTotal)} received',
            icon: Icons.payments_outlined,
            accent: const Color(0xFF58D0A4),
            onTap: () => unawaited(
              openVanPaymentsPage(
                context,
                initialFilter: VanPaymentsFilter.paid,
              ),
            ),
          ),
          _MetricCardData(
            title: 'Total Invoice Value',
            value: _formatPounds(totalInvoiceValue),
            subtitle: 'All saved invoices',
            icon: Icons.receipt_long_outlined,
            accent: const Color(0xFF4A7DFF),
            onTap: () => unawaited(openVanPaymentsPage(context)),
          ),
          _MetricCardData(
            title: 'Completed Jobs',
            value: completedJobsCount.toString(),
            subtitle: 'Jobs marked complete',
            icon: Icons.check_circle_outline,
            accent: const Color(0xFF4A7DFF),
            onTap: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const JobsCalendarSchedulePage(),
                ),
              ),
            ),
          ),
          _MetricCardData(
            title: 'Average Job Value',
            value: _formatPounds(averageJobValue),
            subtitle: 'Based on completed jobs',
            icon: Icons.calculate_outlined,
            accent: const Color(0xFFB48CFF),
          ),
        ]),
      ],
    );
  }

  Widget _buildExpensesSection() {
    final monthTotal = _monthExpenseTotal();
    final yearTotal = _yearExpenseTotal();
    final totalRecorded = _totalRecordedExpenses();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Expenses',
          subtitle: 'Pulled from your saved expense entries on this device.',
        ),
        const SizedBox(height: 12),
        _buildExpenseGrid(<_MetricCardData>[
          _MetricCardData(
            title: 'This Month Expenses',
            value: _formatPounds(monthTotal),
            subtitle: 'Saved expenses',
            icon: Icons.calendar_month_outlined,
            accent: const Color(0xFFFFC56F),
            onTap: () => unawaited(
              openVanExpensesPage(
                context,
                initialFilter: VanExpensesFilter.thisMonth,
              ),
            ),
          ),
          _MetricCardData(
            title: 'This Year Expenses',
            value: _formatPounds(yearTotal),
            subtitle: 'Saved expenses',
            icon: Icons.date_range_outlined,
            accent: const Color(0xFFB48CFF),
            onTap: () => unawaited(
              openVanExpensesPage(
                context,
                initialFilter: VanExpensesFilter.thisYear,
              ),
            ),
          ),
          _MetricCardData(
            title: 'Total Expenses',
            value: _formatPounds(totalRecorded),
            subtitle: 'All expenses stored',
            icon: Icons.trending_down_rounded,
            accent: const Color(0xFFFF8E8E),
            onTap: () => unawaited(
              openVanExpensesPage(
                context,
                initialFilter: VanExpensesFilter.all,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    final items = _buildRecentActivity();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Recent Activity',
          subtitle: 'Latest paid invoices, new invoices and expenses added.',
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _ActivityEmptyState()
        else
          Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _ActivityCard(item: items[i]),
                if (i < items.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyEarningsState() {
    return const _EmptyEarningsState();
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
            'Earnings',
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
            'See how your business is performing.',
            style: TextStyle(
              fontSize: 13.2,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Live summary from invoices, payments, completed jobs and saved expenses.',
            style: TextStyle(
              fontSize: 12.8,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }

  _MetricCardData _buildProfitCard() {
    final estimatedProfit = _paidInvoicesTotal() - _totalRecordedExpenses();
    final isPositive = estimatedProfit >= 0;
    final accent = isPositive
        ? const Color(0xFF58D0A4)
        : const Color(0xFFFF8E8E);

    return _MetricCardData(
      title: 'Estimated Profit',
      value: _formatSignedPounds(estimatedProfit),
      subtitle: 'Paid income minus recorded expenses',
      icon: Icons.account_balance_outlined,
      accent: accent,
      emphasis: true,
    );
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
        title: const Text('Earnings'),
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
                              if (!_hasEarningsData) ...[
                                _buildEmptyEarningsState(),
                                const SizedBox(height: 12),
                                _buildExpensesSection(),
                              ] else ...[
                                _buildSummaryGrid(<_MetricCardData>[
                                  _MetricCardData(
                                    title: 'This Month',
                                    value: _formatPounds(_thisMonthEarned()),
                                    subtitle: 'Paid invoice income',
                                    icon: Icons.calendar_month_outlined,
                                    accent: const Color(0xFF4A7DFF),
                                  ),
                                  _MetricCardData(
                                    title: 'Year To Date',
                                    value: _formatPounds(_yearToDateEarned()),
                                    subtitle: 'Paid invoice income',
                                    icon: Icons.timeline_outlined,
                                    accent: const Color(0xFF4A7DFF),
                                  ),
                                  _MetricCardData(
                                    title: 'Outstanding Payments',
                                    value: _formatPounds(_outstandingTotal()),
                                    subtitle:
                                        '${_unpaidInvoices.length} unpaid invoice${_unpaidInvoices.length == 1 ? '' : 's'}',
                                    icon: Icons.warning_amber_outlined,
                                    accent: const Color(0xFFFFC56F),
                                    onTap: () => unawaited(
                                      openVanPaymentsPage(
                                        context,
                                        initialFilter:
                                            VanPaymentsFilter.outstanding,
                                      ),
                                    ),
                                  ),
                                  _buildProfitCard(),
                                ]),
                                const SizedBox(height: 12),
                                _buildIncomeSection(),
                                const SizedBox(height: 12),
                                _buildExpensesSection(),
                                const SizedBox(height: 12),
                                _buildRecentActivitySection(),
                              ],
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
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool emphasis;
  final VoidCallback? onTap;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.emphasis = false,
    this.onTap,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = textScale > 1.0;

    final card = _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: data.emphasis ? 142 : 132),
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
                    fontSize: data.emphasis ? 19 : 17.8,
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

class _EmptyEarningsState extends StatelessWidget {
  const _EmptyEarningsState();

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.insights_outlined, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(
            'No earnings data yet.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete jobs and create invoices to see business performance.',
            style: TextStyle(
              fontSize: 13.0,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Text(
        'Nothing recent yet.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.76),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.accent;
    final amountColor = item.kind == _ActivityKind.expenseAdded
        ? const Color(0xFFFF8E8E)
        : const Color(0xFF8FF0C6);

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(item.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15.2,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatSignedPounds(item.amount),
                      style: TextStyle(
                        fontSize: 14.4,
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                if (item.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 12.4,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  formatDate(item.timestamp),
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.58),
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
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

enum _ActivityKind { paidInvoice, newInvoice, expenseAdded }

class _ActivityItem {
  final _ActivityKind kind;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime timestamp;

  const _ActivityItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.timestamp,
  });

  IconData get icon {
    return switch (kind) {
      _ActivityKind.paidInvoice => Icons.payments_outlined,
      _ActivityKind.newInvoice => Icons.receipt_long_outlined,
      _ActivityKind.expenseAdded => Icons.trending_down_rounded,
    };
  }

  Color get accent {
    return switch (kind) {
      _ActivityKind.paidInvoice => const Color(0xFF58D0A4),
      _ActivityKind.newInvoice => const Color(0xFF4A7DFF),
      _ActivityKind.expenseAdded => const Color(0xFFFF8E8E),
    };
  }
}

String _formatPounds(num value) => formatCurrency(value);

String _formatSignedPounds(num value) {
  final absolute = value.abs().toStringAsFixed(2);
  return value < 0 ? '-£$absolute' : '£$absolute';
}

double _cardWidth(double maxWidth, int columns, double spacing) {
  if (columns <= 1) {
    return maxWidth;
  }
  return (maxWidth - ((columns - 1) * spacing)) / columns;
}
