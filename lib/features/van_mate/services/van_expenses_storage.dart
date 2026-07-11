import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/van_expense_entry.dart';
import 'van_business_profile_scope_storage.dart';

class VanExpensesStorage extends ChangeNotifier {
  VanExpensesStorage._();

  static final VanExpensesStorage instance = VanExpensesStorage._();

  static const String _expensesKey = 'van_expenses_v1';

  SharedPreferences? _preferences;
  Future<void>? _loadFuture;
  bool _isLoaded = false;

  Future<void> ensureLoaded() {
    if (_isLoaded) {
      return Future<void>.value();
    }

    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _isLoaded = true;
  }

  Future<List<VanExpenseEntry>> loadAll() async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_expensesKey);
    final raw = _preferences?.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <VanExpenseEntry>[];
    }

    final decoded = jsonDecode(raw);
    final items = <VanExpenseEntry>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          items.add(VanExpenseEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    items.sort(_compareNewestFirst);
    return items;
  }

  Future<void> saveAll(List<VanExpenseEntry> expenses) async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_expensesKey);
    final sorted = List<VanExpenseEntry>.from(expenses)
      ..sort(_compareNewestFirst);
    await _preferences?.setString(
      storageKey,
      jsonEncode(sorted.map((item) => item.toJson()).toList(growable: false)),
    );
    notifyListeners();
  }

  Future<void> upsert(VanExpenseEntry expense) async {
    final items = await loadAll();
    final next = <VanExpenseEntry>[
      expense,
      for (final item in items)
        if (item.id != expense.id) item,
    ];
    await saveAll(next);
  }

  Future<void> delete(String expenseId) async {
    final items = await loadAll();
    await saveAll(
      items.where((item) => item.id != expenseId).toList(growable: false),
    );
  }

  Future<void> clear() async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_expensesKey);
    await _preferences?.remove(storageKey);
    notifyListeners();
  }

  int _compareNewestFirst(VanExpenseEntry a, VanExpenseEntry b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) {
      return byDate;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }
}
