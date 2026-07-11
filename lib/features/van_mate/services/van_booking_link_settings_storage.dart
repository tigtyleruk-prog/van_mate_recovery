import 'package:shared_preferences/shared_preferences.dart';

import 'van_booking_link_settings_cloud_service.dart';
import 'van_business_profile_scope_storage.dart';
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
    return _preferences?.getBool(
          await VanBusinessProfileScopeStorage.instance.scopedLocalKey(
            _isActiveKey,
          ),
        ) ??
        true;
  }

  Future<void> setActive(bool value, {bool syncCloud = true}) async {
    await ensureLoaded();
    await _preferences?.setBool(
      await VanBusinessProfileScopeStorage.instance.scopedLocalKey(
        _isActiveKey,
      ),
      value,
    );
    if (!syncCloud) {
      return;
    }
    await _syncCloud();
  }

  Future<String> loadTitle() async {
    await ensureLoaded();
    return _preferences
            ?.getString(
              await VanBusinessProfileScopeStorage.instance.scopedLocalKey(
                _titleKey,
              ),
            )
            ?.trim() ??
        '';
  }

  Future<void> saveTitle(String value, {bool syncCloud = true}) async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_titleKey);
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      await _preferences?.remove(storageKey);
    } else {
      await _preferences?.setString(storageKey, cleaned);
    }
    if (!syncCloud) {
      return;
    }
    await _syncCloud();
  }

  Future<Map<String, dynamic>?> loadFromCloud() async {
    final businessProfileId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
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
          .loadSettings(
            ownerUid: ownerUid,
            businessProfileId: businessProfileId,
          );
      if (data == null) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'booking link settings cloud load',
          extra: 'no_cloud_doc uid=$ownerUid',
        );
        return null;
      }

      await ensureLoaded();
      final titleKey = await VanBusinessProfileScopeStorage.instance
          .scopedLocalKey(_titleKey);
      final isActiveKey = await VanBusinessProfileScopeStorage.instance
          .scopedLocalKey(_isActiveKey);
      final title = data['title']?.toString().trim() ?? '';
      final isActive = data['isActive'] == false ? false : true;
      if (title.isEmpty) {
        await _preferences?.remove(titleKey);
      } else {
        await _preferences?.setString(titleKey, title);
      }
      await _preferences?.setBool(isActiveKey, isActive);
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
    final businessProfileId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.booking_link_settings_save',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanBookingLinkSettingsCloudService.instance.saveSettings(
        ownerUid: ownerUid,
        businessProfileId: businessProfileId,
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
