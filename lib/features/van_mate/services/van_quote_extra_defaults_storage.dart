import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/van_quote_extra_defaults.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanQuoteExtraDefaultsStorage {
  VanQuoteExtraDefaultsStorage._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final VanQuoteExtraDefaultsStorage instance =
      VanQuoteExtraDefaultsStorage._();

  static const String firestoreCollectionName = 'van_settings';
  static const String firestoreDocId = 'quote_extras';
  static const String firestorePathTemplate =
      'users/{uid}/van_settings/quote_extras';
  static const String _localKeyPrefix = 'van_quote_extra_defaults_v1';

  final FirebaseFirestore _firestore;

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

  Future<VanQuoteExtraDefaults> load() async {
    await ensureLoaded();
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.quote_extra_defaults_load',
    );
    final localDefaults = _loadLocal(ownerUid);

    if (ownerUid == null || ownerUid.trim().isEmpty) {
      return localDefaults;
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
        return localDefaults;
      }

      final data = snapshot.data();
      if (data == null || data.isEmpty) {
        return localDefaults;
      }

      final cloudDefaults = VanQuoteExtraDefaults.fromJson(data);
      await _saveLocal(cloudDefaults, normalizedOwnerUid);
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        source: 'van_mate.quote_extra_defaults_load',
      );
      return cloudDefaults;
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: firestoreDocId,
        uid: normalizedOwnerUid,
        error: error,
        source: 'van_mate.quote_extra_defaults_load',
      );
      return localDefaults;
    }
  }

  Future<void> save(VanQuoteExtraDefaults defaults) async {
    await ensureLoaded();
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.quote_extra_defaults_save',
    );
    await _saveLocal(defaults, ownerUid);

    if (ownerUid == null || ownerUid.trim().isEmpty) {
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
        ...defaults.toJson(),
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

  DocumentReference<Map<String, dynamic>> _settingsDoc(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection(firestoreCollectionName)
        .doc(firestoreDocId);
  }

  VanQuoteExtraDefaults _loadLocal(String? ownerUid) {
    final json = _preferences?.getString(_localKey(ownerUid));
    if (json == null || json.trim().isEmpty) {
      return VanQuoteExtraDefaults.defaults();
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return VanQuoteExtraDefaults.fromJson(
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
    return VanQuoteExtraDefaults.defaults();
  }

  Future<void> _saveLocal(
    VanQuoteExtraDefaults defaults,
    String? ownerUid,
  ) async {
    await _preferences?.setString(
      _localKey(ownerUid),
      jsonEncode(defaults.toJson()),
    );
  }

  String _localKey(String? ownerUid) {
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    if (normalizedOwnerUid.isEmpty) {
      return '${_localKeyPrefix}_local';
    }
    return '${_localKeyPrefix}_$normalizedOwnerUid';
  }
}
