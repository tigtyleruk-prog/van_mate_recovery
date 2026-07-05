import 'package:shared_preferences/shared_preferences.dart';

import 'van_booking_link_settings_cloud_service.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';

class VanBookingLinkSettingsStorage {
  VanBookingLinkSettingsStorage._();

  static final VanBookingLinkSettingsStorage instance =
      VanBookingLinkSettingsStorage._();

  static const String _isActiveKey = 'van_booking_link_is_active_v1';
  static const String _titleKey = 'van_booking_link_title_v1';

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

  Future<bool> isActive() async {
    await ensureLoaded();
    return _preferences?.getBool(_isActiveKey) ?? true;
  }

  Future<void> setActive(bool value, {bool syncCloud = true}) async {
    await ensureLoaded();
    await _preferences?.setBool(_isActiveKey, value);
    if (!syncCloud) {
      return;
    }
    await _syncCloud();
  }

  Future<String> loadTitle() async {
    await ensureLoaded();
    return _preferences?.getString(_titleKey)?.trim() ?? '';
  }

  Future<void> saveTitle(String value, {bool syncCloud = true}) async {
    await ensureLoaded();
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      await _preferences?.remove(_titleKey);
    } else {
      await _preferences?.setString(_titleKey, cleaned);
    }
    if (!syncCloud) {
      return;
    }
    await _syncCloud();
  }

  Future<Map<String, dynamic>?> loadFromCloud() async {
    logVanFirebaseHydration(
      stage: 'started',
      target: 'booking link settings cloud load',
    );
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.booking_link_settings_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'booking link settings cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return null;
    }

    try {
      final data = await VanBookingLinkSettingsCloudService.instance
          .loadSettings(ownerUid: ownerUid);
      if (data == null) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'booking link settings cloud load',
          extra: 'no_cloud_doc uid=$ownerUid',
        );
        return null;
      }

      await ensureLoaded();
      final title = data['title']?.toString().trim() ?? '';
      final isActive = data['isActive'] == false ? false : true;
      if (title.isEmpty) {
        await _preferences?.remove(_titleKey);
      } else {
        await _preferences?.setString(_titleKey, title);
      }
      await _preferences?.setBool(_isActiveKey, isActive);
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'booking link settings cloud load',
        extra: 'uid=$ownerUid active=$isActive',
      );
      return data;
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'booking link settings cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> _syncCloud() async {
    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.booking_link_settings_save',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanBookingLinkSettingsCloudService.instance.saveSettings(
        ownerUid: ownerUid,
        title: await loadTitle(),
        isActive: await isActive(),
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'booking link settings cloud save',
        extra: 'uid=$ownerUid active=${await isActive()}',
      );
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'booking link settings cloud save',
        extra: error.toString(),
      );
    }
  }
}
