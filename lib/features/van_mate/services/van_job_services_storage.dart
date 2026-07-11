import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/van_job_service.dart';
import 'van_business_profile_scope_storage.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_job_services_cloud_service.dart';

class VanJobServicesStorage extends ChangeNotifier {
  VanJobServicesStorage._();

  static final VanJobServicesStorage instance = VanJobServicesStorage._();

  static const String _servicesKey = 'van_job_services_v1';

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

  Future<List<VanJobService>> loadAll() async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_servicesKey);
    final raw = _preferences?.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <VanJobService>[];
    }

    final decoded = jsonDecode(raw);
    final items = <VanJobService>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          items.add(VanJobService.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    items.sort(_sortServices);
    return items;
  }

  Future<List<VanJobService>?> loadFromCloud() async {
    if (!await VanBusinessProfileScopeStorage.instance
        .isDefaultBusinessActive()) {
      return loadAll();
    }
    logVanFirebaseHydration(
      stage: 'started',
      target: 'job services cloud load',
    );
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.job_services_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'job services cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return null;
    }

    try {
      final services = await VanJobServicesCloudService.instance.loadServices(
        ownerUid: ownerUid,
      );
      if (services == null) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'job services cloud load',
          extra: 'no_cloud_doc uid=$ownerUid',
        );
        return null;
      }

      final localServices = await loadAll();
      if (localServices.isNotEmpty &&
          !_shouldReplaceLocal(localServices, services)) {
        logVanFirebaseSkip(
          reason: 'job services cloud load skipped newer local state',
          extra:
              'uid=$ownerUid local=${localServices.length} cloud=${services.length}',
        );
        return localServices;
      }

      await saveAll(services, syncCloud: false);
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'job services cloud load',
        extra: 'uid=$ownerUid count=${services.length}',
      );
      return services;
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'job services cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> saveAll(
    List<VanJobService> services, {
    bool syncCloud = true,
  }) async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_servicesKey);
    final sorted = List<VanJobService>.from(services)..sort(_sortServices);
    await _preferences?.setString(
      storageKey,
      jsonEncode(
        sorted.map((service) => service.toJson()).toList(growable: false),
      ),
    );
    debugPrint('[JobServices] saved count=${sorted.length}');
    notifyListeners();

    if (!syncCloud ||
        !await VanBusinessProfileScopeStorage.instance
            .isDefaultBusinessActive()) {
      return;
    }

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.job_services_save',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanJobServicesCloudService.instance.saveServices(
        ownerUid: ownerUid,
        services: sorted,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'job services cloud save',
        extra: 'uid=$ownerUid count=${sorted.length}',
      );
    } catch (error) {
      debugPrint('[JobServices] cloud save failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'job services cloud save',
        extra: error.toString(),
      );
    }
  }

  Future<void> upsert(VanJobService service) async {
    final all = await loadAll();
    final next = <VanJobService>[
      service,
      for (final existing in all)
        if (existing.id != service.id) existing,
    ];
    await saveAll(next);
  }

  Future<void> delete(String serviceId) async {
    final all = await loadAll();
    final next = all
        .where((service) => service.id != serviceId)
        .toList(growable: false);
    await saveAll(next);
  }

  Future<void> setArchived(String serviceId, bool value) async {
    final all = await loadAll();
    final now = DateTime.now();
    final next = all
        .map(
          (service) => service.id == serviceId
              ? service.copyWith(
                  isArchived: value,
                  isActive: value ? false : service.isActive,
                  updatedAt: now,
                )
              : service,
        )
        .toList(growable: false);
    await saveAll(next);
  }

  Future<void> clear() async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_servicesKey);
    await _preferences?.remove(storageKey);
    notifyListeners();

    if (!await VanBusinessProfileScopeStorage.instance
        .isDefaultBusinessActive()) {
      return;
    }

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.job_services_clear',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }
      await VanJobServicesCloudService.instance.clearServices(
        ownerUid: ownerUid,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'job services cloud clear',
        extra: 'uid=$ownerUid',
      );
    } catch (error) {
      debugPrint('[JobServices] cloud clear failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'job services cloud clear',
        extra: error.toString(),
      );
    }
  }

  int _sortServices(VanJobService a, VanJobService b) {
    if (a.isArchived != b.isArchived) {
      return a.isArchived ? 1 : -1;
    }
    if (a.isActive != b.isActive) {
      return a.isActive ? -1 : 1;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  bool _shouldReplaceLocal(
    List<VanJobService> local,
    List<VanJobService> cloud,
  ) {
    if (local.isEmpty) {
      return true;
    }
    if (cloud.isEmpty) {
      return false;
    }

    final localLatest = local
        .map((item) => item.updatedAt)
        .reduce((value, element) => value.isAfter(element) ? value : element);
    final cloudLatest = cloud
        .map((item) => item.updatedAt)
        .reduce((value, element) => value.isAfter(element) ? value : element);
    return cloudLatest.isAfter(localLatest);
  }
}
