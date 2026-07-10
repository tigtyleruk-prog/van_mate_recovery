import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/van_quote_extra_defaults.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanQuoteExtraDefaultsStorage extends ChangeNotifier {
  VanQuoteExtraDefaultsStorage._({FirebaseFirestore? firestore})
    : _firestore = firestore;

  static final VanQuoteExtraDefaultsStorage instance =
      VanQuoteExtraDefaultsStorage._();

  static const String firestoreCollectionName = 'van_settings';
  static const String firestoreDocId = 'quote_extras';
  static const String firestorePathTemplate =
      'users/{uid}/van_settings/quote_extras';
  static const String _localKeyPrefix = 'van_quote_extra_defaults_v1';

  final FirebaseFirestore? _firestore;

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

  Future<VanQuoteExtraDefaults> load({bool preferLocal = false}) async {
    await ensureLoaded();
    final ownerUid = await _ensureOwnerUidOrNull(
      source: 'van_mate.quote_extra_defaults_load',
    );
    final localDocument = _loadLocalDocument(ownerUid);

    if (preferLocal || ownerUid == null || ownerUid.trim().isEmpty) {
      return localDocument.globalDefaults;
    }

    final normalizedOwnerUid = ownerUid.trim();
    final collectionPath = 'users/$normalizedOwnerUid/$firestoreCollectionName';
    try {
      logVanFirebaseWriteStart(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_load',
      );
      final snapshot = await _settingsDoc(normalizedOwnerUid).get();
      if (!snapshot.exists) {
        logVanFirebaseSkip(
          reason: 'quote extra defaults load empty',
          extra: 'uid=$normalizedOwnerUid',
        );
        return localDocument.globalDefaults;
      }

      final data = snapshot.data();
      if (data == null || data.isEmpty) {
        return localDocument.globalDefaults;
      }

      final cloudDocument = _QuoteExtraDefaultsDocument.fromJson(data);
      await _saveLocalDocument(cloudDocument, normalizedOwnerUid);
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_load',
      );
      return cloudDocument.globalDefaults;
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        error: error,
        source: 'van_mate.quote_extra_defaults_load',
      );
      return localDocument.globalDefaults;
    }
  }

  Future<VanQuoteExtraDefaults> loadForService({
    required String serviceKey,
    required String serviceName,
    bool preferLocal = false,
  }) async {
    final normalizedServiceKey = _serviceDefaultsKey(
      serviceKey: serviceKey,
      serviceName: serviceName,
    );
    if (normalizedServiceKey.isEmpty) {
      return load(preferLocal: preferLocal);
    }

    await ensureLoaded();
    final ownerUid = await _ensureOwnerUidOrNull(
      source: 'van_mate.quote_extra_defaults_load_service',
    );
    final localDocument = _loadLocalDocument(ownerUid);
    VanQuoteExtraDefaults localServiceDefaults() {
      return localDocument.defaultsForService(
        normalizedServiceKey,
        serviceName: serviceName,
      );
    }

    if (preferLocal || ownerUid == null || ownerUid.trim().isEmpty) {
      return localServiceDefaults();
    }

    final normalizedOwnerUid = ownerUid.trim();
    final collectionPath = 'users/$normalizedOwnerUid/$firestoreCollectionName';
    try {
      logVanFirebaseWriteStart(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_load_service',
      );
      final snapshot = await _settingsDoc(normalizedOwnerUid).get();
      if (!snapshot.exists) {
        return localServiceDefaults();
      }

      final data = snapshot.data();
      if (data == null || data.isEmpty) {
        return localServiceDefaults();
      }

      final cloudDocument = _QuoteExtraDefaultsDocument.fromJson(data);
      await _saveLocalDocument(cloudDocument, normalizedOwnerUid);
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_load_service',
      );
      return cloudDocument.defaultsForService(
        normalizedServiceKey,
        serviceName: serviceName,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        error: error,
        source: 'van_mate.quote_extra_defaults_load_service',
      );
      return localServiceDefaults();
    }
  }

  Future<void> save(VanQuoteExtraDefaults defaults) async {
    await ensureLoaded();
    final ownerUid = await _ensureOwnerUidOrNull(
      source: 'van_mate.quote_extra_defaults_save',
    );
    final document = _loadLocalDocument(
      ownerUid,
    ).copyWith(globalDefaults: defaults);
    await _saveLocalDocument(document, ownerUid);

    if (ownerUid == null || ownerUid.trim().isEmpty) {
      notifyListeners();
      return;
    }

    final normalizedOwnerUid = ownerUid.trim();
    final collectionPath = 'users/$normalizedOwnerUid/$firestoreCollectionName';
    try {
      logVanFirebaseWriteStart(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_save',
      );
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: 'van_mate.quote_extra_defaults_save',
      );
      await _settingsDoc(normalizedOwnerUid).set(<String, dynamic>{
        ...document.toJson(),
        'id': firestoreDocId,
        'ownerUid': normalizedOwnerUid,
        'source': 'van_mate.quote_extra_defaults_save',
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_save',
      );
      notifyListeners();
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        error: error,
        source: 'van_mate.quote_extra_defaults_save',
      );
      rethrow;
    }
  }

  Future<void> saveForService({
    required String serviceKey,
    required String serviceName,
    required VanQuoteExtraDefaults defaults,
  }) async {
    final normalizedServiceKey = _serviceDefaultsKey(
      serviceKey: serviceKey,
      serviceName: serviceName,
    );
    if (normalizedServiceKey.isEmpty) {
      await save(defaults);
      return;
    }

    await ensureLoaded();
    final ownerUid = await _ensureOwnerUidOrNull(
      source: 'van_mate.quote_extra_defaults_save_service',
    );
    final document = _loadLocalDocument(ownerUid).copyWithService(
      serviceKey: normalizedServiceKey,
      serviceName: serviceName,
      defaults: defaults,
    );
    await _saveLocalDocument(document, ownerUid);

    if (ownerUid == null || ownerUid.trim().isEmpty) {
      notifyListeners();
      return;
    }

    final normalizedOwnerUid = ownerUid.trim();
    final collectionPath = 'users/$normalizedOwnerUid/$firestoreCollectionName';
    try {
      logVanFirebaseWriteStart(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_save_service',
      );
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: 'van_mate.quote_extra_defaults_save_service',
      );
      await _settingsDoc(normalizedOwnerUid).set(<String, dynamic>{
        ...document.toJson(),
        'id': firestoreDocId,
        'ownerUid': normalizedOwnerUid,
        'source': 'van_mate.quote_extra_defaults_save_service',
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_save_service',
      );
      notifyListeners();
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        error: error,
        source: 'van_mate.quote_extra_defaults_save_service',
      );
      rethrow;
    }
  }

  Future<String?> _ensureOwnerUidOrNull({required String source}) async {
    try {
      return await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: source,
      );
    } catch (error) {
      debugPrint('[QuoteExtras] auth unavailable source=$source: $error');
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _settingsDoc(String ownerUid) {
    final firestore = _firestore ?? FirebaseFirestore.instance;
    return firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection(firestoreCollectionName)
        .doc(firestoreDocId);
  }

  _QuoteExtraDefaultsDocument _loadLocalDocument(String? ownerUid) {
    final json = _preferences?.getString(_localKey(ownerUid));
    if (json == null || json.trim().isEmpty) {
      return _QuoteExtraDefaultsDocument.empty();
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return _QuoteExtraDefaultsDocument.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'quote extra defaults local load',
        extra: error.toString(),
      );
    }
    return _QuoteExtraDefaultsDocument.empty();
  }

  Future<void> _saveLocalDocument(
    _QuoteExtraDefaultsDocument document,
    String? ownerUid,
  ) async {
    await _preferences?.setString(
      _localKey(ownerUid),
      jsonEncode(document.toJson()),
    );
  }

  String _localKey(String? ownerUid) {
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    if (normalizedOwnerUid.isEmpty) {
      return '${_localKeyPrefix}_local';
    }
    return '${_localKeyPrefix}_$normalizedOwnerUid';
  }

  String _serviceDefaultsKey({
    required String serviceKey,
    required String serviceName,
  }) {
    final key = serviceKey.trim();
    if (key.isNotEmpty) {
      return _normalizeServiceDefaultsKey(key);
    }
    return _normalizeServiceDefaultsKey(serviceName);
  }

  String _normalizeServiceDefaultsKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

class _QuoteExtraDefaultsDocument {
  const _QuoteExtraDefaultsDocument({
    required this.globalDefaults,
    required this.serviceDefaults,
  });

  factory _QuoteExtraDefaultsDocument.empty() {
    return _QuoteExtraDefaultsDocument(
      globalDefaults: VanQuoteExtraDefaults.defaults(),
      serviceDefaults: const <String, _ServiceQuoteExtraDefaults>{},
    );
  }

  factory _QuoteExtraDefaultsDocument.fromJson(Map<String, dynamic> json) {
    final globalDefaultsJson = json['globalDefaults'];
    final globalDefaults = globalDefaultsJson is Map
        ? VanQuoteExtraDefaults.fromJson(
            Map<String, dynamic>.from(globalDefaultsJson),
          )
        : VanQuoteExtraDefaults.fromJson(json);

    final serviceDefaults = <String, _ServiceQuoteExtraDefaults>{};
    final rawServiceDefaults =
        json['serviceDefaults'] ??
        json['serviceQuoteExtras'] ??
        json['services'];
    if (rawServiceDefaults is Map) {
      rawServiceDefaults.forEach((key, value) {
        if (value is! Map) {
          return;
        }
        final entry = _ServiceQuoteExtraDefaults.fromJson(
          key.toString(),
          Map<String, dynamic>.from(value),
        );
        serviceDefaults[entry.serviceKey] = entry;
      });
    }

    return _QuoteExtraDefaultsDocument(
      globalDefaults: globalDefaults,
      serviceDefaults: Map<String, _ServiceQuoteExtraDefaults>.unmodifiable(
        serviceDefaults,
      ),
    );
  }

  final VanQuoteExtraDefaults globalDefaults;
  final Map<String, _ServiceQuoteExtraDefaults> serviceDefaults;

  VanQuoteExtraDefaults defaultsForService(
    String serviceKey, {
    required String serviceName,
  }) {
    return serviceDefaults[serviceKey]?.defaults ??
        VanQuoteExtraDefaults.starterForServiceName(serviceName);
  }

  _QuoteExtraDefaultsDocument copyWith({
    VanQuoteExtraDefaults? globalDefaults,
  }) {
    return _QuoteExtraDefaultsDocument(
      globalDefaults: globalDefaults ?? this.globalDefaults,
      serviceDefaults: serviceDefaults,
    );
  }

  _QuoteExtraDefaultsDocument copyWithService({
    required String serviceKey,
    required String serviceName,
    required VanQuoteExtraDefaults defaults,
  }) {
    return _QuoteExtraDefaultsDocument(
      globalDefaults: globalDefaults,
      serviceDefaults: Map<String, _ServiceQuoteExtraDefaults>.unmodifiable(
        <String, _ServiceQuoteExtraDefaults>{
          ...serviceDefaults,
          serviceKey: _ServiceQuoteExtraDefaults(
            serviceKey: serviceKey,
            serviceName: serviceName.trim(),
            defaults: defaults,
          ),
        },
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...globalDefaults.toJson(),
      'globalDefaults': globalDefaults.toJson(),
      'serviceDefaults': <String, dynamic>{
        for (final entry in serviceDefaults.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }
}

class _ServiceQuoteExtraDefaults {
  const _ServiceQuoteExtraDefaults({
    required this.serviceKey,
    required this.serviceName,
    required this.defaults,
  });

  factory _ServiceQuoteExtraDefaults.fromJson(
    String fallbackServiceKey,
    Map<String, dynamic> json,
  ) {
    final rawDefaults = json['defaults'] ?? json['quoteExtraDefaults'];
    return _ServiceQuoteExtraDefaults(
      serviceKey: (json['serviceKey'] ?? fallbackServiceKey).toString().trim(),
      serviceName: json['serviceName']?.toString().trim() ?? '',
      defaults: rawDefaults is Map
          ? VanQuoteExtraDefaults.fromJson(
              Map<String, dynamic>.from(rawDefaults),
            )
          : VanQuoteExtraDefaults.fromJson(json),
    );
  }

  final String serviceKey;
  final String serviceName;
  final VanQuoteExtraDefaults defaults;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'serviceKey': serviceKey,
      'serviceName': serviceName,
      'defaults': defaults.toJson(),
    };
  }
}
