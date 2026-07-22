import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'van_business_profile_scope_storage.dart';

class VanDriverMockStateStorage {
  VanDriverMockStateStorage._();

  static final VanDriverMockStateStorage instance =
      VanDriverMockStateStorage._();

  static const String _stateKey = 'van_driver_mock_state_v1';

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

  String _storageKeyForBusiness(String businessProfileId) {
    final normalizedId = businessProfileId.trim();
    if (normalizedId.isEmpty ||
        normalizedId == VanBusinessProfileScopeStorage.defaultBusinessId) {
      return _stateKey;
    }
    return '${_stateKey}_business_$normalizedId';
  }

  Future<Map<String, dynamic>?> loadJson({String? businessProfileId}) async {
    await ensureLoaded();
    final storageKey = businessProfileId == null
        ? await VanBusinessProfileScopeStorage.instance.scopedLocalKey(
            _stateKey,
          )
        : _storageKeyForBusiness(businessProfileId);
    final raw = _preferences?.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Future<void> saveJson(
    Map<String, dynamic> state, {
    String? businessProfileId,
  }) async {
    await ensureLoaded();
    final storageKey = businessProfileId == null
        ? await VanBusinessProfileScopeStorage.instance.scopedLocalKey(
            _stateKey,
          )
        : _storageKeyForBusiness(businessProfileId);
    await _preferences?.setString(
      storageKey,
      jsonEncode(_jsonSafeValue(state)),
    );
  }

  Future<void> clear({String? businessProfileId}) async {
    await ensureLoaded();
    final storageKey = businessProfileId == null
        ? await VanBusinessProfileScopeStorage.instance.scopedLocalKey(
            _stateKey,
          )
        : _storageKeyForBusiness(businessProfileId);
    await _preferences?.remove(storageKey);
  }
}

dynamic _jsonSafeValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _jsonSafeValue(item)),
    );
  }
  if (value is Iterable) {
    return value.map(_jsonSafeValue).toList(growable: false);
  }
  return value;
}
