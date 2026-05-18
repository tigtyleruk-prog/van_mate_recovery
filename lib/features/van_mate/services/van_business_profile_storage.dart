import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/van_business_logo_support.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_business_profile.dart';
import 'van_business_profile_cloud_service.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';

class VanBusinessProfileStorage {
  VanBusinessProfileStorage._();

  static final VanBusinessProfileStorage instance =
      VanBusinessProfileStorage._();

  static const String _businessNameKey = 'van_business_name';
  static const String _contactNameKey = 'van_business_contact_name';
  static const String _phoneKey = 'van_business_phone';
  static const String _emailKey = 'van_business_email';
  static const String _addressKey = 'van_business_address';
  static const String _paymentInstructionsKey =
      'van_business_payment_instructions';
  static const String _logoPathKey = 'van_business_logo_path';

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
    debugPrint('[BusinessProfile] loaded');
  }

  Future<VanBusinessProfile> load() async {
    await ensureLoaded();

    final defaults = const VanBusinessProfile.defaults();
    return VanBusinessProfile(
      businessName:
          _preferences?.getString(_businessNameKey)?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(_businessNameKey)).trim()
          : defaults.businessName,
      contactName:
          _preferences?.getString(_contactNameKey)?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(_contactNameKey)).trim()
          : defaults.contactName,
      phone: _preferences?.getString(_phoneKey)?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(_phoneKey)).trim()
          : defaults.phone,
      email: _preferences?.getString(_emailKey)?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(_emailKey)).trim()
          : defaults.email,
      businessAddress:
          _preferences?.getString(_addressKey)?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(_addressKey)).trim()
          : defaults.businessAddress,
      paymentInstructions:
          _preferences?.getString(_paymentInstructionsKey)?.trim().isNotEmpty ==
              true
          ? sanitizeVanText(
              _preferences!.getString(_paymentInstructionsKey),
            ).trim()
          : defaults.paymentInstructions,
      logoPath: resolveSavedVanBusinessLogoPath(
        _preferences?.getString(_logoPathKey),
      ),
    );
  }

  Future<VanBusinessProfile?> loadFromCloud() async {
    logVanFirebaseHydration(
      stage: 'started',
      target: 'business profile cloud load',
    );
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.business_profile_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'business profile cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return null;
    }

    try {
      final profile = await VanBusinessProfileCloudService.instance.loadProfile(
        ownerUid: ownerUid,
      );
      if (profile == null) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'business profile cloud load',
          extra: 'no_profile_doc',
        );
        return null;
      }

      await save(profile, syncCloud: false);
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'business profile cloud load',
        extra: 'uid=$ownerUid',
      );
      return profile;
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'business profile cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> save(VanBusinessProfile profile, {bool syncCloud = true}) async {
    await ensureLoaded();

    await _preferences?.setString(_businessNameKey, profile.businessName);
    await _preferences?.setString(_contactNameKey, profile.contactName);
    await _preferences?.setString(_phoneKey, profile.phone);
    await _preferences?.setString(_emailKey, profile.email);
    await _preferences?.setString(_addressKey, profile.businessAddress);
    await _preferences?.setString(
      _paymentInstructionsKey,
      profile.paymentInstructions,
    );

    final logoPath = resolveSavedVanBusinessLogoPath(profile.logoPath);
    if (logoPath != null) {
      await _preferences?.setString(_logoPathKey, logoPath);
    } else {
      await _preferences?.remove(_logoPathKey);
    }

    debugPrint('[BusinessProfile] saved');

    if (!syncCloud) {
      return;
    }

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.business_profile_save',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanBusinessProfileCloudService.instance.saveProfile(
        ownerUid: ownerUid,
        profile: profile,
        source: 'van_mate.business_profile',
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'business profile cloud save',
        extra: 'uid=$ownerUid',
      );
    } catch (error) {
      debugPrint('[BusinessProfile] cloud save failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'business profile cloud save',
        extra: error.toString(),
      );
    }
  }

  Future<void> clear() async {
    await ensureLoaded();

    await _preferences?.remove(_businessNameKey);
    await _preferences?.remove(_contactNameKey);
    await _preferences?.remove(_phoneKey);
    await _preferences?.remove(_emailKey);
    await _preferences?.remove(_addressKey);
    await _preferences?.remove(_paymentInstructionsKey);
    await _preferences?.remove(_logoPathKey);

    debugPrint('[BusinessProfile] cleared');

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.business_profile_clear',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanBusinessProfileCloudService.instance.clearProfile(
        ownerUid: ownerUid,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'business profile cloud clear',
        extra: 'uid=$ownerUid',
      );
    } catch (error) {
      debugPrint('[BusinessProfile] cloud clear failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'business profile cloud clear',
        extra: error.toString(),
      );
    }
  }
}
