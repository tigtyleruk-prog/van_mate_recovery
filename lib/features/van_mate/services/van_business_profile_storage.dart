import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/van_business_logo_support.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_business_profile.dart';
import '../models/van_business_profile_settings.dart';
import 'van_booking_link_cloud_service.dart';
import 'van_business_profile_cloud_service.dart';
import 'van_business_profile_scope_storage.dart';
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
  static const String _defaultExtraHelperAmountKey =
      'van_business_default_extra_helper_amount';
  static const String _defaultStairsAccessAmountKey =
      'van_business_default_stairs_access_amount';
  static const String _defaultWaitingTimeAmountKey =
      'van_business_default_waiting_time_amount';
  static const String _defaultCollectionDeliveryAmountKey =
      'van_business_default_collection_delivery_amount';
  static const String _defaultMileageRateKey =
      'van_business_default_mileage_rate';
  static const String _logoPathKey = 'van_business_logo_path';
  static const String _logoUrlKey = 'van_business_logo_url';

  static const String _settingsPrefix = 'van_business_profile_settings_';
  static const String _settingsBusinessNameKey =
      '${_settingsPrefix}business_name';
  static const String _settingsOwnerNameKey = '${_settingsPrefix}owner_name';
  static const String _settingsBusinessTypeKey =
      '${_settingsPrefix}business_type';
  static const String _settingsPhoneNumberKey =
      '${_settingsPrefix}phone_number';
  static const String _settingsEmailAddressKey =
      '${_settingsPrefix}email_address';
  static const String _settingsWebsiteOrSocialLinkKey =
      '${_settingsPrefix}website_or_social_link';
  static const String _settingsAddressLine1Key =
      '${_settingsPrefix}address_line1';
  static const String _settingsAddressLine2Key =
      '${_settingsPrefix}address_line2';
  static const String _settingsTownOrCityKey = '${_settingsPrefix}town_or_city';
  static const String _settingsPostcodeKey = '${_settingsPrefix}postcode';
  static const String _settingsBankNameKey = '${_settingsPrefix}bank_name';
  static const String _settingsAccountNameKey =
      '${_settingsPrefix}account_name';
  static const String _settingsSortCodeKey = '${_settingsPrefix}sort_code';
  static const String _settingsAccountNumberKey =
      '${_settingsPrefix}account_number';
  static const String _settingsPaymentNotesKey =
      '${_settingsPrefix}payment_notes';
  static const String _settingsVatRegisteredKey =
      '${_settingsPrefix}vat_registered';
  static const String _settingsVatNumberKey = '${_settingsPrefix}vat_number';
  static const String _settingsDefaultInvoiceNotesKey =
      '${_settingsPrefix}default_invoice_notes';
  static const String _settingsDefaultPaymentTermsKey =
      '${_settingsPrefix}default_payment_terms';
  static const String _settingsThankYouMessageKey =
      '${_settingsPrefix}thank_you_message';
  static const String _settingsDefaultExtraHelperAmountKey =
      '${_settingsPrefix}default_extra_helper_amount';
  static const String _settingsDefaultStairsAccessAmountKey =
      '${_settingsPrefix}default_stairs_access_amount';
  static const String _settingsDefaultWaitingTimeAmountKey =
      '${_settingsPrefix}default_waiting_time_amount';
  static const String _settingsDefaultCollectionDeliveryAmountKey =
      '${_settingsPrefix}default_collection_delivery_amount';
  static const String _settingsDefaultMileageRateKey =
      '${_settingsPrefix}default_mileage_rate';
  static const String _settingsLogoPathKey = '${_settingsPrefix}logo_path';

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
    final scopeId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    String key(String baseKey) => _scopedKey(baseKey, scopeId);

    final defaults = const VanBusinessProfile.defaults();
    double readAmount(String key, double fallback) {
      final raw = _preferences?.get(key);
      if (raw is num) {
        return raw.toDouble();
      }
      if (raw is String) {
        return double.tryParse(sanitizeVanText(raw).trim()) ?? fallback;
      }
      return fallback;
    }

    return VanBusinessProfile(
      businessName:
          _preferences?.getString(key(_businessNameKey))?.trim().isNotEmpty ==
              true
          ? sanitizeVanText(
              _preferences!.getString(key(_businessNameKey)),
            ).trim()
          : defaults.businessName,
      contactName:
          _preferences?.getString(key(_contactNameKey))?.trim().isNotEmpty ==
              true
          ? sanitizeVanText(
              _preferences!.getString(key(_contactNameKey)),
            ).trim()
          : defaults.contactName,
      phone: _preferences?.getString(key(_phoneKey))?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(key(_phoneKey))).trim()
          : defaults.phone,
      email: _preferences?.getString(key(_emailKey))?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(key(_emailKey))).trim()
          : defaults.email,
      businessAddress:
          _preferences?.getString(key(_addressKey))?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(key(_addressKey))).trim()
          : defaults.businessAddress,
      paymentInstructions: resolveVanMatePaymentInstructions(
        _preferences?.getString(key(_paymentInstructionsKey)),
      ),
      defaultExtraHelperAmount: readAmount(
        key(_defaultExtraHelperAmountKey),
        defaults.defaultExtraHelperAmount,
      ),
      defaultStairsAccessAmount: readAmount(
        key(_defaultStairsAccessAmountKey),
        defaults.defaultStairsAccessAmount,
      ),
      defaultWaitingTimeAmount: readAmount(
        key(_defaultWaitingTimeAmountKey),
        defaults.defaultWaitingTimeAmount,
      ),
      defaultCollectionDeliveryAmount: readAmount(
        key(_defaultCollectionDeliveryAmountKey),
        defaults.defaultCollectionDeliveryAmount,
      ),
      defaultMileageRate: readAmount(
        key(_defaultMileageRateKey),
        defaults.defaultMileageRate,
      ),
      logoPath: resolveSavedVanBusinessLogoPath(
        _preferences?.getString(key(_logoPathKey)),
      ),
      logoUrl:
          _preferences?.getString(key(_logoUrlKey))?.trim().isNotEmpty == true
          ? sanitizeVanText(_preferences!.getString(key(_logoUrlKey))).trim()
          : null,
    );
  }

  Future<VanBusinessProfile> loadCanonicalProfile({
    bool allowLocalFallbackOnCloudError = true,
  }) async {
    await ensureLoaded();
    if (!await VanBusinessProfileScopeStorage.instance
        .isDefaultBusinessActive()) {
      return load();
    }

    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.business_profile_canonical_load',
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    if (normalizedOwnerUid.isEmpty) {
      return load();
    }

    try {
      final cloudProfile = await VanBusinessProfileCloudService.instance
          .loadProfile(ownerUid: normalizedOwnerUid);
      if (cloudProfile != null) {
        await save(
          cloudProfile.copyWith(
            paymentInstructions: resolveVanMatePaymentInstructions(
              cloudProfile.paymentInstructions,
            ),
          ),
          syncCloud: false,
        );
        return cloudProfile;
      }

      await _clearLocalProfileCache();
      await clearSettings();
      return const VanBusinessProfile.defaults();
    } catch (error) {
      if (!allowLocalFallbackOnCloudError) {
        rethrow;
      }
      debugPrint('[BusinessProfile] canonical load fallback: $error');
      return load();
    }
  }

  Future<VanBusinessProfile?> loadFromCloud() async {
    if (!await VanBusinessProfileScopeStorage.instance
        .isDefaultBusinessActive()) {
      return load();
    }
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

      await save(
        profile.copyWith(
          paymentInstructions: resolveVanMatePaymentInstructions(
            profile.paymentInstructions,
          ),
        ),
        syncCloud: false,
      );
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

  Future<void> save(
    VanBusinessProfile profile, {
    bool syncCloud = true,
    String? scopeIdOverride,
  }) async {
    await ensureLoaded();
    final override = scopeIdOverride?.trim() ?? '';
    final scopeId = override.isNotEmpty
        ? override
        : await VanBusinessProfileScopeStorage.instance.activeBusinessId();
    String key(String baseKey) => _scopedKey(baseKey, scopeId);

    final resolvedProfile = profile.copyWith(
      paymentInstructions: resolveVanMatePaymentInstructions(
        profile.paymentInstructions,
      ),
    );

    await _preferences?.setString(
      key(_businessNameKey),
      resolvedProfile.businessName,
    );
    await _preferences?.setString(
      key(_contactNameKey),
      resolvedProfile.contactName,
    );
    await _preferences?.setString(key(_phoneKey), resolvedProfile.phone);
    await _preferences?.setString(key(_emailKey), resolvedProfile.email);
    await _preferences?.setString(
      key(_addressKey),
      resolvedProfile.businessAddress,
    );
    await _preferences?.setString(
      key(_paymentInstructionsKey),
      resolvedProfile.paymentInstructions,
    );
    await _preferences?.setDouble(
      key(_defaultExtraHelperAmountKey),
      resolvedProfile.defaultExtraHelperAmount,
    );
    await _preferences?.setDouble(
      key(_defaultStairsAccessAmountKey),
      resolvedProfile.defaultStairsAccessAmount,
    );
    await _preferences?.setDouble(
      key(_defaultWaitingTimeAmountKey),
      resolvedProfile.defaultWaitingTimeAmount,
    );
    await _preferences?.setDouble(
      key(_defaultCollectionDeliveryAmountKey),
      resolvedProfile.defaultCollectionDeliveryAmount,
    );
    await _preferences?.setDouble(
      key(_defaultMileageRateKey),
      resolvedProfile.defaultMileageRate,
    );

    final logoPath = resolveSavedVanBusinessLogoPath(resolvedProfile.logoPath);
    if (logoPath != null) {
      await _preferences?.setString(key(_logoPathKey), logoPath);
    } else {
      await _preferences?.remove(key(_logoPathKey));
    }
    final logoUrl = sanitizeVanText(resolvedProfile.logoUrl).trim();
    if (logoUrl.isNotEmpty) {
      await _preferences?.setString(key(_logoUrlKey), logoUrl);
    } else {
      await _preferences?.remove(key(_logoUrlKey));
    }

    debugPrint('[BusinessProfile] saved');

    if (!syncCloud ||
        scopeId != VanBusinessProfileScopeStorage.defaultBusinessId) {
      return;
    }

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.business_profile_save',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }
      final normalizedOwnerUid = ownerUid.trim();

      await VanBusinessProfileCloudService.instance.saveProfile(
        ownerUid: normalizedOwnerUid,
        profile: resolvedProfile,
        source: 'van_mate.business_profile',
      );
      debugPrint(
        '[BusinessProfile] profile document write success '
        'path=users/$normalizedOwnerUid/van_business_profile/profile '
        'uid=$normalizedOwnerUid',
      );

      await VanBookingLinkCloudService.instance.syncBusinessProfileBranding(
        ownerUid: normalizedOwnerUid,
        profile: resolvedProfile,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'business profile cloud save',
        extra: 'uid=$normalizedOwnerUid',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BusinessProfile] profile document write failure '
        'path=users/${VanFirebaseAuthService.instance.currentUid ?? 'unknown'}/van_business_profile/profile '
        'error=$error',
      );
      debugPrint('[BusinessProfile] cloud save failed: $error');
      debugPrint('[BusinessProfile] cloud save stack=$stackTrace');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'business profile cloud save',
        extra: error.toString(),
      );
    }
  }

  Future<void> clear() async {
    await ensureLoaded();
    final syncCloud = await VanBusinessProfileScopeStorage.instance
        .isDefaultBusinessActive();
    await _clearLocalProfileCache();
    await clearSettings();

    debugPrint('[BusinessProfile] cleared');

    if (!syncCloud) {
      return;
    }

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

  Future<void> _clearLocalProfileCache() async {
    final scopeId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    String key(String baseKey) => _scopedKey(baseKey, scopeId);
    await _preferences?.remove(key(_businessNameKey));
    await _preferences?.remove(key(_contactNameKey));
    await _preferences?.remove(key(_phoneKey));
    await _preferences?.remove(key(_emailKey));
    await _preferences?.remove(key(_addressKey));
    await _preferences?.remove(key(_paymentInstructionsKey));
    await _preferences?.remove(key(_defaultExtraHelperAmountKey));
    await _preferences?.remove(key(_defaultStairsAccessAmountKey));
    await _preferences?.remove(key(_defaultWaitingTimeAmountKey));
    await _preferences?.remove(key(_defaultCollectionDeliveryAmountKey));
    await _preferences?.remove(key(_defaultMileageRateKey));
    await _preferences?.remove(key(_logoPathKey));
    await _preferences?.remove(key(_logoUrlKey));
  }

  Future<VanBusinessProfileSettings> loadSettings() async {
    await ensureLoaded();
    final scopeId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    String key(String baseKey) => _scopedKey(baseKey, scopeId);

    final legacyProfile = await load();
    String readText(String key, String fallback) {
      if (!(_preferences?.containsKey(key) ?? false)) {
        return fallback;
      }

      return sanitizeVanText(_preferences?.getString(key)).trim();
    }

    double readAmount(String key, double fallback) {
      if (!(_preferences?.containsKey(key) ?? false)) {
        return fallback;
      }
      final raw = _preferences?.get(key);
      if (raw is num) {
        return raw.toDouble();
      }
      if (raw is String) {
        return double.tryParse(sanitizeVanText(raw).trim()) ?? fallback;
      }
      return fallback;
    }

    return VanBusinessProfileSettings(
      businessName: readText(
        key(_settingsBusinessNameKey),
        legacyProfile.businessName,
      ),
      ownerName: readText(
        key(_settingsOwnerNameKey),
        legacyProfile.contactName,
      ),
      businessType: readText(key(_settingsBusinessTypeKey), ''),
      phoneNumber: readText(key(_settingsPhoneNumberKey), legacyProfile.phone),
      emailAddress: readText(
        key(_settingsEmailAddressKey),
        legacyProfile.email,
      ),
      websiteOrSocialLink: readText(key(_settingsWebsiteOrSocialLinkKey), ''),
      addressLine1: readText(
        key(_settingsAddressLine1Key),
        legacyProfile.businessAddress,
      ),
      addressLine2: readText(key(_settingsAddressLine2Key), ''),
      townOrCity: readText(key(_settingsTownOrCityKey), ''),
      postcode: readText(key(_settingsPostcodeKey), ''),
      bankName: readText(key(_settingsBankNameKey), ''),
      accountName: readText(key(_settingsAccountNameKey), ''),
      sortCode: readText(key(_settingsSortCodeKey), ''),
      accountNumber: readText(key(_settingsAccountNumberKey), ''),
      paymentNotes: readText(
        key(_settingsPaymentNotesKey),
        legacyProfile.paymentInstructions,
      ),
      vatRegistered:
          _preferences?.getBool(key(_settingsVatRegisteredKey)) ?? false,
      vatNumber: readText(key(_settingsVatNumberKey), ''),
      defaultInvoiceNotes: readText(key(_settingsDefaultInvoiceNotesKey), ''),
      defaultPaymentTerms: readText(key(_settingsDefaultPaymentTermsKey), ''),
      thankYouMessage: readText(key(_settingsThankYouMessageKey), ''),
      defaultExtraHelperAmount: readAmount(
        key(_settingsDefaultExtraHelperAmountKey),
        legacyProfile.defaultExtraHelperAmount,
      ),
      defaultStairsAccessAmount: readAmount(
        key(_settingsDefaultStairsAccessAmountKey),
        legacyProfile.defaultStairsAccessAmount,
      ),
      defaultWaitingTimeAmount: readAmount(
        key(_settingsDefaultWaitingTimeAmountKey),
        legacyProfile.defaultWaitingTimeAmount,
      ),
      defaultCollectionDeliveryAmount: readAmount(
        key(_settingsDefaultCollectionDeliveryAmountKey),
        legacyProfile.defaultCollectionDeliveryAmount,
      ),
      defaultMileageRate: readAmount(
        key(_settingsDefaultMileageRateKey),
        legacyProfile.defaultMileageRate,
      ),
      logoPath: resolveSavedVanBusinessLogoPath(
        _preferences?.containsKey(key(_settingsLogoPathKey)) == true
            ? _preferences?.getString(key(_settingsLogoPathKey))
            : legacyProfile.logoPath,
      ),
    );
  }

  Future<void> saveSettings(
    VanBusinessProfileSettings settings, {
    String? logoUrl,
    String? cloudLogoPath,
  }) async {
    await ensureLoaded();
    final scopeId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    String key(String baseKey) => _scopedKey(baseKey, scopeId);

    final resolved = settings.copyWith(
      logoPath: resolveSavedVanBusinessLogoPath(settings.logoPath),
    );

    Future<void> writeString(String key, String value) async {
      final normalized = sanitizeVanText(value).trim();
      await _preferences?.setString(key, normalized);
    }

    await writeString(key(_settingsBusinessNameKey), resolved.businessName);
    await writeString(key(_settingsOwnerNameKey), resolved.ownerName);
    await writeString(key(_settingsBusinessTypeKey), resolved.businessType);
    await writeString(key(_settingsPhoneNumberKey), resolved.phoneNumber);
    await writeString(key(_settingsEmailAddressKey), resolved.emailAddress);
    await writeString(
      key(_settingsWebsiteOrSocialLinkKey),
      resolved.websiteOrSocialLink,
    );
    await writeString(key(_settingsAddressLine1Key), resolved.addressLine1);
    await writeString(key(_settingsAddressLine2Key), resolved.addressLine2);
    await writeString(key(_settingsTownOrCityKey), resolved.townOrCity);
    await writeString(key(_settingsPostcodeKey), resolved.postcode);
    await writeString(key(_settingsBankNameKey), resolved.bankName);
    await writeString(key(_settingsAccountNameKey), resolved.accountName);
    await writeString(key(_settingsSortCodeKey), resolved.sortCode);
    await writeString(key(_settingsAccountNumberKey), resolved.accountNumber);
    await writeString(key(_settingsPaymentNotesKey), resolved.paymentNotes);
    await _preferences?.setBool(
      key(_settingsVatRegisteredKey),
      resolved.vatRegistered,
    );
    await writeString(key(_settingsVatNumberKey), resolved.vatNumber);
    await writeString(
      key(_settingsDefaultInvoiceNotesKey),
      resolved.defaultInvoiceNotes,
    );
    await writeString(
      key(_settingsDefaultPaymentTermsKey),
      resolved.defaultPaymentTerms,
    );
    await writeString(
      key(_settingsThankYouMessageKey),
      resolved.thankYouMessage,
    );
    await _preferences?.setDouble(
      key(_settingsDefaultExtraHelperAmountKey),
      resolved.defaultExtraHelperAmount,
    );
    await _preferences?.setDouble(
      key(_settingsDefaultStairsAccessAmountKey),
      resolved.defaultStairsAccessAmount,
    );
    await _preferences?.setDouble(
      key(_settingsDefaultWaitingTimeAmountKey),
      resolved.defaultWaitingTimeAmount,
    );
    await _preferences?.setDouble(
      key(_settingsDefaultCollectionDeliveryAmountKey),
      resolved.defaultCollectionDeliveryAmount,
    );
    await _preferences?.setDouble(
      key(_settingsDefaultMileageRateKey),
      resolved.defaultMileageRate,
    );

    final logoPath = resolveSavedVanBusinessLogoPath(resolved.logoPath);
    await _preferences?.setString(key(_settingsLogoPathKey), logoPath ?? '');
    final resolvedLogoUrl = resolveSavedVanBusinessLogoUrl(logoUrl);
    final resolvedCloudLogoPath = _normalizeCloudLogoPath(cloudLogoPath);
    debugPrint(
      '[BusinessProfile] saveSettings logo refs localPath=$logoPath '
      'cloudPath=$resolvedCloudLogoPath cloudUrl=$resolvedLogoUrl',
    );

    // Keep the legacy/shared business profile snapshot in sync so Booking Link
    // preview and other flows read the latest saved profile without restart.
    final currentProfile = await load();
    final shouldClearCloudLogo =
        logoPath == null &&
        resolvedCloudLogoPath == null &&
        resolvedLogoUrl == null;
    final nextCloudLogoPath = shouldClearCloudLogo
        ? null
        : (resolvedCloudLogoPath ??
              _normalizeCloudLogoPath(currentProfile.logoPath));
    final nextCloudLogoUrl = shouldClearCloudLogo
        ? null
        : (resolvedLogoUrl ??
              resolveSavedVanBusinessLogoUrl(currentProfile.logoUrl));

    final syncedProfile = VanBusinessProfile(
      businessName: resolved.businessName.trim().isEmpty
          ? currentProfile.businessName
          : resolved.businessName.trim(),
      contactName: resolved.ownerName.trim().isEmpty
          ? currentProfile.contactName
          : resolved.ownerName.trim(),
      phone: resolved.phoneNumber.trim().isEmpty
          ? currentProfile.phone
          : resolved.phoneNumber.trim(),
      email: resolved.emailAddress.trim().isEmpty
          ? currentProfile.email
          : resolved.emailAddress.trim(),
      businessAddress: resolved.addressLine1.trim().isEmpty
          ? currentProfile.businessAddress
          : resolved.addressLine1.trim(),
      paymentInstructions: resolved.paymentNotes.trim().isEmpty
          ? currentProfile.paymentInstructions
          : resolved.paymentNotes.trim(),
      defaultExtraHelperAmount: resolved.defaultExtraHelperAmount,
      defaultStairsAccessAmount: resolved.defaultStairsAccessAmount,
      defaultWaitingTimeAmount: resolved.defaultWaitingTimeAmount,
      defaultCollectionDeliveryAmount: resolved.defaultCollectionDeliveryAmount,
      defaultMileageRate: resolved.defaultMileageRate,
      logoPath: nextCloudLogoPath,
      logoUrl: nextCloudLogoUrl,
    );
    debugPrint(
      '[BusinessProfile] synced profile logo refs '
      'logoPath=${syncedProfile.logoPath} logoUrl=${syncedProfile.logoUrl}',
    );
    await save(syncedProfile);
  }

  Future<void> clearSettings() async {
    await ensureLoaded();
    final scopeId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    String key(String baseKey) => _scopedKey(baseKey, scopeId);

    await _preferences?.remove(key(_settingsBusinessNameKey));
    await _preferences?.remove(key(_settingsOwnerNameKey));
    await _preferences?.remove(key(_settingsBusinessTypeKey));
    await _preferences?.remove(key(_settingsPhoneNumberKey));
    await _preferences?.remove(key(_settingsEmailAddressKey));
    await _preferences?.remove(key(_settingsWebsiteOrSocialLinkKey));
    await _preferences?.remove(key(_settingsAddressLine1Key));
    await _preferences?.remove(key(_settingsAddressLine2Key));
    await _preferences?.remove(key(_settingsTownOrCityKey));
    await _preferences?.remove(key(_settingsPostcodeKey));
    await _preferences?.remove(key(_settingsBankNameKey));
    await _preferences?.remove(key(_settingsAccountNameKey));
    await _preferences?.remove(key(_settingsSortCodeKey));
    await _preferences?.remove(key(_settingsAccountNumberKey));
    await _preferences?.remove(key(_settingsPaymentNotesKey));
    await _preferences?.remove(key(_settingsVatRegisteredKey));
    await _preferences?.remove(key(_settingsVatNumberKey));
    await _preferences?.remove(key(_settingsDefaultInvoiceNotesKey));
    await _preferences?.remove(key(_settingsDefaultPaymentTermsKey));
    await _preferences?.remove(key(_settingsThankYouMessageKey));
    await _preferences?.remove(key(_settingsDefaultExtraHelperAmountKey));
    await _preferences?.remove(key(_settingsDefaultStairsAccessAmountKey));
    await _preferences?.remove(key(_settingsDefaultWaitingTimeAmountKey));
    await _preferences?.remove(
      key(_settingsDefaultCollectionDeliveryAmountKey),
    );
    await _preferences?.remove(key(_settingsDefaultMileageRateKey));
    await _preferences?.remove(key(_settingsLogoPathKey));
  }

  String? _normalizeCloudLogoPath(String? value) {
    final normalized = sanitizeVanText(value).trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lower = normalized.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('file:') ||
        normalized.contains('://') ||
        normalized.contains('\\') ||
        normalized.startsWith('/')) {
      return null;
    }

    return normalized;
  }

  String _scopedKey(String baseKey, String scopeId) {
    if (scopeId == VanBusinessProfileScopeStorage.defaultBusinessId) {
      return baseKey;
    }
    return '${baseKey}_business_$scopeId';
  }
}
