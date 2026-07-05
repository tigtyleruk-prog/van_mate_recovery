import 'package:shared_preferences/shared_preferences.dart';

class VanDeletedRequestsStore {
  VanDeletedRequestsStore._();

  static final VanDeletedRequestsStore instance = VanDeletedRequestsStore._();

  static const String _deletedKeysKey = 'van_deleted_request_keys_v1';

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

  Future<Set<String>> loadDeletedKeys() async {
    await ensureLoaded();
    final stored = _preferences?.getStringList(_deletedKeysKey) ?? const <String>[];
    return stored.map((item) => item.trim()).where((item) => item.isNotEmpty).toSet();
  }

  Future<void> saveDeletedKeys(Set<String> keys) async {
    await ensureLoaded();
    final values = keys.map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false)
      ..sort();
    await _preferences?.setStringList(_deletedKeysKey, values);
  }

  Future<void> clear() async {
    await ensureLoaded();
    await _preferences?.remove(_deletedKeysKey);
  }
}
