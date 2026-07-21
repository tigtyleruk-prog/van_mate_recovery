import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_expense_entry.dart';
import '../services/van_expenses_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';

enum VanExpensesFilter { all, thisMonth, thisYear, category }

Future<void> openVanExpensesPage(
  BuildContext context, {
  VanExpensesFilter initialFilter = VanExpensesFilter.all,
  String? initialCategory,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VanExpensesPage(
        initialFilter: initialFilter,
        initialCategory: initialCategory,
      ),
    ),
  );
}

class VanExpensesPage extends StatefulWidget {
  const VanExpensesPage({
    super.key,
    this.initialFilter = VanExpensesFilter.all,
    this.initialCategory,
  });

  final VanExpensesFilter initialFilter;
  final String? initialCategory;

  @override
  State<VanExpensesPage> createState() => _VanExpensesPageState();
}

class _VanExpensesPageState extends State<VanExpensesPage> {
  static const List<String> _categories = <String>[
    'Fuel',
    'Vehicle Maintenance',
    'Insurance',
    'Parking',
    'Tolls',
    'Equipment',
    'Phone / Internet',
    'Advertising',
    'Other',
  ];

  final VanExpensesStorage _storage = VanExpensesStorage.instance;
  List<VanExpenseEntry> _expenses = <VanExpenseEntry>[];
  bool _loading = true;
  late VanExpensesFilter _activeFilter;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
    _selectedCategory = _categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : _categories.first;
    _storage.addListener(_handleStorageChanged);
    unawaited(_loadExpenses());
  }

  @override
  void dispose() {
    _storage.removeListener(_handleStorageChanged);
    super.dispose();
  }

  void _handleStorageChanged() {
    unawaited(_loadExpenses(showLoader: false));
  }

  Future<void> _loadExpenses({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
      });
    }

    final loaded = await _storage.loadAll();
    if (!mounted) {
      return;
    }

    setState(() {
      _expenses = loaded;
      _loading = false;
    });
  }

  Future<void> _openEditor([VanExpenseEntry? expense]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            VanExpenseEditorPage(expense: expense, categories: _categories),
      ),
    );

    if (changed == true) {
      await _loadExpenses(showLoader: false);
    }
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool _isThisYear(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year;
  }

  List<VanExpenseEntry> get _filteredExpenses {
    return _expenses
        .where((expense) {
          return switch (_activeFilter) {
            VanExpensesFilter.all => true,
            VanExpensesFilter.thisMonth => _isThisMonth(expense.date),
            VanExpensesFilter.thisYear => _isThisYear(expense.date),
            VanExpensesFilter.category => expense.category == _selectedCategory,
          };
        })
        .toList(growable: false);
  }

  double _sum(Iterable<VanExpenseEntry> source) {
    return source.fold<double>(0, (total, expense) => total + expense.amount);
  }

  double get _thisMonthTotal =>
      _sum(_expenses.where((expense) => _isThisMonth(expense.date)));

  double get _thisYearTotal =>
      _sum(_expenses.where((expense) => _isThisYear(expense.date)));

  double get _totalExpenses => _sum(_expenses);

  double get _averageMonthlySpend {
    if (_expenses.isEmpty) {
      return 0;
    }
    final months = <String>{};
    for (final expense in _expenses) {
      months.add('${expense.date.year}-${expense.date.month}');
    }
    return _totalExpenses / months.length;
  }

  Future<void> _deleteFromList(VanExpenseEntry expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This removes the expense from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD24C4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _storage.delete(expense.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense deleted.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHeroCard() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expenses',
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
            'Track business spending and running costs.',
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

  Widget _buildSummaryGrid() {
    final cards = <_SummaryCardData>[
      _SummaryCardData(
        title: 'This Month',
        value: formatCurrency(_thisMonthTotal),
        icon: Icons.calendar_month_outlined,
      ),
      _SummaryCardData(
        title: 'This Year',
        value: formatCurrency(_thisYearTotal),
        icon: Icons.date_range_outlined,
      ),
      _SummaryCardData(
        title: 'Total Expenses',
        value: formatCurrency(_totalExpenses),
        icon: Icons.trending_down_rounded,
      ),
      _SummaryCardData(
        title: 'Average Monthly Spend',
        value: formatCurrency(_averageMonthlySpend),
        icon: Icons.analytics_outlined,
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
    Widget filterChip(VanExpensesFilter filter, String label) {
      final selected = _activeFilter == filter;
      return ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: Text(label),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.78),
          fontWeight: FontWeight.w700,
          fontSize: 12.6,
        ),
        selectedColor: const Color(0xFF4A7DFF).withValues(alpha: 0.26),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        side: BorderSide(
          color: selected
              ? const Color(0xFF4A7DFF).withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (_) {
          setState(() {
            _activeFilter = filter;
          });
        },
      );
    }

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              filterChip(VanExpensesFilter.all, 'All'),
              filterChip(VanExpensesFilter.thisMonth, 'This Month'),
              filterChip(VanExpensesFilter.thisYear, 'This Year'),
              filterChip(VanExpensesFilter.category, 'Category'),
            ],
          ),
          if (_activeFilter == VanExpensesFilter.category) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: const Color(0xFF131B2A),
              iconEnabledColor: Colors.white.withValues(alpha: 0.76),
              style: kVanMateFieldTextStyle,
              items: _categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(growable: false),
              decoration: vanMateFieldDecoration(
                label: 'Category',
                hintText: 'Choose a category',
                prefixIcon: const Icon(Icons.sell_outlined),
                labelOpacity: 0.68,
                hintOpacity: 0.48,
              ),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final filtered = _filteredExpenses;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Expenses'),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: const Color(0xFF4A7DFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('+ Add Expense'),
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
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 90),
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 12),
                      _buildSummaryGrid(),
                      const SizedBox(height: 12),
                      _buildFilterBar(),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        _EmptyExpensesState(
                          onAdd: () => unawaited(_openEditor()),
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < filtered.length; i++) ...[
                              _ExpenseCard(
                                expense: filtered[i],
                                onEdit: () => _openEditor(filtered[i]),
                                onDelete: () => _deleteFromList(filtered[i]),
                              ),
                              if (i < filtered.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class VanExpenseEditorPage extends StatefulWidget {
  const VanExpenseEditorPage({
    super.key,
    this.expense,
    required this.categories,
  });

  final VanExpenseEntry? expense;
  final List<String> categories;

  @override
  State<VanExpenseEditorPage> createState() => _VanExpenseEditorPageState();
}

class _VanExpenseEditorPageState extends State<VanExpenseEditorPage> {
  final VanExpensesStorage _storage = VanExpensesStorage.instance;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late String _category;
  late DateTime _selectedDate;
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    _notesController = TextEditingController(text: expense?.notes ?? '');
    _category = widget.categories.contains(expense?.category)
        ? expense!.category
        : widget.categories.first;
    _selectedDate = DateUtils.dateOnly(expense?.date ?? DateTime.now());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4A7DFF),
              surface: Color(0xFF151B2D),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = DateUtils.dateOnly(picked);
    });
  }

  Future<void> _saveExpense() async {
    if (_saving) {
      return;
    }

    final amount = parseCurrencyValue(_amountController.text);
    if (amount <= 0) {
      _showSnack('Please enter a valid amount.');
      return;
    }

    final description = sanitizeVanText(_descriptionController.text).trim();
    if (description.isEmpty) {
      _showSnack('Please enter a description.');
      return;
    }

    final now = DateTime.now();
    final existing = widget.expense;
    final entry = VanExpenseEntry(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      amount: amount,
      category: _category,
      date: DateUtils.dateOnly(_selectedDate),
      supplier: description,
      notes: sanitizeVanText(_notesController.text).trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      receiptPath: existing?.receiptPath,
      receiptName: existing?.receiptName,
    );

    setState(() {
      _saving = true;
    });

    try {
      await _storage.upsert(entry);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnack('Could not save expense.');
    }
  }

  Future<void> _deleteExpense() async {
    final expense = widget.expense;
    if (expense == null || _saving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This removes the expense from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD24C4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _storage.delete(expense.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnack('Could not delete expense.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = _isEditing ? 'Edit Expense' : 'Add Expense';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(false),
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomInset + keyboardInset + 24,
              ),
              children: [
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log business costs quickly so earnings and profit stay accurate.',
                        style: TextStyle(
                          fontSize: 13.2,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.76),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expense Details',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ExpenseField(
                        controller: _amountController,
                        label: 'Amount',
                        hint: '0.00',
                        prefixText: '\u00A3',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        dropdownColor: const Color(0xFF131B2A),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _category = value;
                          });
                        },
                        iconEnabledColor: Colors.white.withValues(alpha: 0.76),
                        style: kVanMateFieldTextStyle,
                        items: widget.categories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(growable: false),
                        decoration: vanMateFieldDecoration(
                          label: 'Category',
                          hintText: 'Choose a category',
                          prefixIcon: const Icon(Icons.sell_outlined),
                          labelOpacity: 0.68,
                          hintOpacity: 0.48,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ExpenseDateField(date: _selectedDate, onTap: _pickDate),
                      const SizedBox(height: 12),
                      _ExpenseField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'What was this expense for?',
                      ),
                      const SizedBox(height: 12),
                      _ExpenseField(
                        controller: _notesController,
                        label: 'Notes (optional)',
                        hint: 'Optional notes',
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_isEditing)
                      SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _deleteExpense,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveExpense,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isEditing ? 'Save' : 'Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
  });

  final String title;
  final String value;
  final IconData icon;
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: const Color(0xFF4A7DFF).withValues(alpha: 0.16),
              border: Border.all(
                color: const Color(0xFF4A7DFF).withValues(alpha: 0.28),
              ),
            ),
            child: Icon(card.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            card.value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            card.title,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final VanExpenseEntry expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                      expense.category,
                      style: const TextStyle(
                        fontSize: 16.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(expense.date),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCurrency(expense.amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            expense.description.trim().isEmpty
                ? '--'
                : expense.description.trim(),
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          if (expense.hasNotes) ...[
            const SizedBox(height: 8),
            Text(
              expense.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.3,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF9B9B),
                    side: BorderSide(
                      color: const Color(0xFFFF9B9B).withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No expenses saved yet.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record fuel, insurance, parking and other running costs here.',
            style: TextStyle(
              fontSize: 13.0,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add an expense'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseField extends StatelessWidget {
  const _ExpenseField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.prefixText,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      onSubmitted: maxLines > 1
          ? null
          : (_) => FocusScope.of(context).nextFocus(),
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        hintText: hint,
        prefixText: prefixText,
        labelOpacity: 0.68,
        hintOpacity: 0.48,
      ),
    );
  }
}

class _ExpenseDateField extends StatelessWidget {
  const _ExpenseDateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: InputDecorator(
          decoration:
              vanMateFieldDecoration(
                label: 'Date',
                hintText: 'Pick a date',
                prefixIcon: const Icon(Icons.event_outlined),
                labelOpacity: 0.68,
                hintOpacity: 0.48,
              ).copyWith(
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.56),
                ),
              ),
          child: Text(formatDate(date), style: kVanMateFieldTextStyle),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

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

double _cardWidth(double maxWidth, int columns, double spacing) {
  if (columns <= 1) {
    return maxWidth;
  }
  return (maxWidth - ((columns - 1) * spacing)) / columns;
}
