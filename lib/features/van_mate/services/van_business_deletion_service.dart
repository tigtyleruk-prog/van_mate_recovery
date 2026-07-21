import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'van_business_profile_scope_storage.dart';
import 'van_firebase_auth_service.dart';

class VanBusinessDeletionException implements Exception {
  const VanBusinessDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VanBusinessDeletionResult {
  const VanBusinessDeletionResult({
    required this.transition,
    required this.archivedInvoiceCount,
    required this.archivedJobCount,
  });

  final VanBusinessProfileDeletionTransition transition;
  final int archivedInvoiceCount;
  final int archivedJobCount;
}

class VanBusinessDeletionService {
  VanBusinessDeletionService._();

  static final VanBusinessDeletionService instance =
      VanBusinessDeletionService._();

  static const String _financialArchivePrefix =
      'van_deleted_business_financial_archive_v1';

  Future<VanBusinessDeletionResult> deleteBusiness({
    required VanBusinessProfileSummary profile,
    required String confirmedBusinessName,
  }) async {
    final normalizedName = confirmedBusinessName.trim();
    if (normalizedName != profile.name.trim()) {
      throw const VanBusinessDeletionException(
        'The business name confirmation does not match.',
      );
    }

    final scopeStorage = VanBusinessProfileScopeStorage.instance;
    final active = await scopeStorage.activeProfile();
    if (active.id != profile.id) {
      throw const VanBusinessDeletionException(
        'Switch to this business before deleting it.',
      );
    }

    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.business_delete',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      throw const VanBusinessDeletionException(
        'Sign in and try deleting the business again.',
      );
    }
    final publicConfigId = scopeStorage.publicConfigIdForBusiness(
      ownerUid,
      profile.id,
    );

    late final HttpsCallableResult<dynamic> response;
    try {
      response = await FirebaseFunctions.instance
          .httpsCallable('deleteBusinessProfileSafely')
          .call(<String, dynamic>{
            'businessProfileId': profile.id,
            'publicConfigId': publicConfigId,
            'confirmedBusinessName': normalizedName,
            'confirmed': true,
          });
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        '[BusinessDelete] cloud failure code=${error.code} message=${error.message}',
      );
      throw VanBusinessDeletionException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Business deletion could not be completed safely.',
      );
    } catch (error) {
      debugPrint('[BusinessDelete] unexpected cloud failure: $error');
      throw const VanBusinessDeletionException(
        'Business deletion could not be completed safely. Please try again.',
      );
    }

    final responseData = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    if (responseData['success'] != true) {
      throw const VanBusinessDeletionException(
        'Business deletion was not confirmed by Firebase.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await _archiveFinancialRecordsLocally(
      preferences: preferences,
      profile: profile,
    );
    await _removeLocalConfiguration(
      preferences: preferences,
      businessProfileId: profile.id,
    );
    final transition = await scopeStorage.deleteProfile(profile.id);

    return VanBusinessDeletionResult(
      transition: transition,
      archivedInvoiceCount: _readCount(responseData['archivedInvoiceCount']),
      archivedJobCount: _readCount(responseData['archivedJobCount']),
    );
  }

  Future<void> _archiveFinancialRecordsLocally({
    required SharedPreferences preferences,
    required VanBusinessProfileSummary profile,
  }) async {
    final driverStateKey = scopedBusinessLocalKey(
      'van_driver_mock_state_v1',
      profile.id,
    );
    final expensesKey = scopedBusinessLocalKey('van_expenses_v1', profile.id);
    final driverState = _decodeMap(preferences.getString(driverStateKey));
    final expenses = _decodeList(preferences.getString(expensesKey));
    final archive = buildDeletedBusinessFinancialArchive(
      businessProfileId: profile.id,
      businessName: profile.name,
      driverState: driverState,
      expenses: expenses,
      archivedAt: DateTime.now(),
    );
    if ((archive['invoices'] as List).isEmpty &&
        (archive['completedJobs'] as List).isEmpty &&
        (archive['expenses'] as List).isEmpty) {
      return;
    }
    await preferences.setString(
      '${_financialArchivePrefix}_${profile.id}',
      jsonEncode(archive),
    );
  }

  Future<void> _removeLocalConfiguration({
    required SharedPreferences preferences,
    required String businessProfileId,
  }) async {
    final keys = preferences.getKeys().where(
      (key) => isBusinessDeletionConfigurationKey(
        key,
        businessProfileId: businessProfileId,
      ),
    );
    for (final key in keys.toList(growable: false)) {
      await preferences.remove(key);
    }
  }

  int _readCount(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  List<dynamic> _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <dynamic>[];
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? List<dynamic>.from(decoded) : const <dynamic>[];
    } catch (_) {
      return const <dynamic>[];
    }
  }
}

const Set<String> _businessConfigurationBaseKeys = <String>{
  'van_business_name',
  'van_business_contact_name',
  'van_business_phone',
  'van_business_email',
  'van_business_address',
  'van_business_payment_instructions',
  'van_business_default_extra_helper_amount',
  'van_business_default_stairs_access_amount',
  'van_business_default_waiting_time_amount',
  'van_business_default_collection_delivery_amount',
  'van_business_default_mileage_rate',
  'van_business_logo_path',
  'van_business_logo_url',
  'van_job_services_v1',
  'van_custom_job_questions_v1',
  'van_booking_link_is_active_v1',
  'van_booking_link_title_v1',
  'van_booking_link_public_config_id_v1',
  'van_driver_mock_state_v1',
  'van_expenses_v1',
  'van_invoice_next_number',
};

String scopedBusinessLocalKey(String baseKey, String businessProfileId) {
  final normalizedId = businessProfileId.trim();
  if (normalizedId == VanBusinessProfileScopeStorage.defaultBusinessId) {
    return baseKey;
  }
  return '${baseKey}_business_$normalizedId';
}

bool isBusinessDeletionConfigurationKey(
  String key, {
  required String businessProfileId,
}) {
  final normalizedId = businessProfileId.trim();
  if (normalizedId.isEmpty) {
    return false;
  }
  final isDefault =
      normalizedId == VanBusinessProfileScopeStorage.defaultBusinessId;
  final suffix = '_business_$normalizedId';
  final baseKey = isDefault
      ? key
      : (key.endsWith(suffix)
            ? key.substring(0, key.length - suffix.length)
            : '');
  if (baseKey.isEmpty) {
    return false;
  }
  if (isDefault && RegExp(r'_business_[A-Za-z0-9_-]+$').hasMatch(key)) {
    return false;
  }
  return _businessConfigurationBaseKeys.contains(baseKey) ||
      baseKey.startsWith('van_business_profile_settings_') ||
      baseKey.startsWith('van_quote_extra_defaults_v1_');
}

Map<String, dynamic> buildDeletedBusinessFinancialArchive({
  required String businessProfileId,
  required String businessName,
  required Map<String, dynamic> driverState,
  required List<dynamic> expenses,
  required DateTime archivedAt,
}) {
  final invoices = driverState['invoiceHistory'] is List
      ? List<dynamic>.from(driverState['invoiceHistory'] as List)
      : const <dynamic>[];
  final jobs = driverState['jobs'] is List
      ? List<dynamic>.from(driverState['jobs'] as List)
      : const <dynamic>[];
  final completedJobs = jobs
      .where((item) {
        if (item is! Map) {
          return false;
        }
        final data = Map<String, dynamic>.from(item);
        final status = (data['status'] ?? data['requestStatus'])
            ?.toString()
            .trim()
            .toLowerCase();
        return data['jobCompleted'] == true ||
            data['isCompleted'] == true ||
            data['completedAt'] != null ||
            <String>{
              'completed',
              'complete',
              'paid',
              'invoiced',
            }.contains(status);
      })
      .toList(growable: false);
  return <String, dynamic>{
    'businessProfileId': businessProfileId,
    'businessName': businessName,
    'archivedAt': archivedAt.toIso8601String(),
    'readOnly': true,
    'invoices': invoices,
    'completedJobs': completedJobs,
    'expenses': List<dynamic>.from(expenses),
  };
}
