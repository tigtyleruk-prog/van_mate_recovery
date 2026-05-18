import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  Future<Map<String, dynamic>?> loadJson() async {
    await ensureLoaded();
    final raw = _preferences?.getString(_stateKey);
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

  Future<void> saveJson(Map<String, dynamic> state) async {
    await ensureLoaded();
    await _preferences?.setString(_stateKey, jsonEncode(state));
  }

  Future<void> clear() async {
    await ensureLoaded();
    await _preferences?.remove(_stateKey);
  }
}
