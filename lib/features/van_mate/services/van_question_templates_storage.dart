import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/van_question_template.dart';

class VanQuestionTemplatesStorage extends ChangeNotifier {
  VanQuestionTemplatesStorage._();

  static final VanQuestionTemplatesStorage instance =
      VanQuestionTemplatesStorage._();

  static const String _templatesKey = 'van_question_templates_v1';

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

  Future<List<VanQuestionTemplate>> loadAll() async {
    await ensureLoaded();
    final raw = _preferences?.getString(_templatesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <VanQuestionTemplate>[];
    }

    final decoded = jsonDecode(raw);
    final items = <VanQuestionTemplate>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          items.add(
            VanQuestionTemplate.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    items.sort(_sortTemplates);
    return items;
  }

  Future<List<VanQuestionTemplate>> loadActiveTemplates() async {
    final all = await loadAll();
    return all
        .where((template) => template.isActive && !template.isArchived)
        .toList(growable: false);
  }

  Future<void> saveAll(List<VanQuestionTemplate> templates) async {
    await ensureLoaded();
    final sorted = List<VanQuestionTemplate>.from(templates)
      ..sort(_sortTemplates);
    await _preferences?.setString(
      _templatesKey,
      jsonEncode(
        sorted.map((template) => template.toJson()).toList(growable: false),
      ),
    );
    notifyListeners();
  }

  Future<void> upsert(VanQuestionTemplate template) async {
    final all = await loadAll();
    final next = <VanQuestionTemplate>[
      template,
      for (final item in all)
        if (item.id != template.id) item,
    ];
    await saveAll(next);
  }

  Future<void> setActive(String templateId, bool value) async {
    final all = await loadAll();
    final now = DateTime.now();
    final updated = all
        .map(
          (item) => item.id == templateId
              ? item.copyWith(isActive: value, updatedAt: now)
              : item,
        )
        .toList(growable: false);
    await saveAll(updated);
  }

  Future<void> setArchived(String templateId, bool value) async {
    final all = await loadAll();
    final now = DateTime.now();
    final updated = all
        .map(
          (item) => item.id == templateId
              ? item.copyWith(
                  isArchived: value,
                  isActive: value ? false : item.isActive,
                  updatedAt: now,
                )
              : item,
        )
        .toList(growable: false);
    await saveAll(updated);
  }

  Future<void> delete(String templateId) async {
    final all = await loadAll();
    final updated = all
        .where((template) => template.id != templateId)
        .toList(growable: false);
    await saveAll(updated);
  }

  Future<void> clear() async {
    await ensureLoaded();
    await _preferences?.remove(_templatesKey);
    notifyListeners();
  }

  int _sortTemplates(VanQuestionTemplate a, VanQuestionTemplate b) {
    if (a.isArchived != b.isArchived) {
      return a.isArchived ? 1 : -1;
    }
    if (a.isActive != b.isActive) {
      return a.isActive ? -1 : 1;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }
}
