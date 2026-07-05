import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/van_job_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanJobServicesCloudService {
  VanJobServicesCloudService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final VanJobServicesCloudService instance =
      VanJobServicesCloudService._();

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _servicesDoc(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection('van_job_services')
        .doc('library');
  }

  Future<List<VanJobService>?> loadServices({
    required String ownerUid,
    String source = 'van_mate.job_services_load',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return null;
    }

    final collectionPath = 'users/$normalizedOwnerUid/van_job_services';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: 'library',
      uid: normalizedOwnerUid,
      source: source,
    );

    final snapshot = await _servicesDoc(normalizedOwnerUid).get();
    if (!snapshot.exists) {
      logVanFirebaseSkip(
        reason: 'job services load empty',
        extra: 'uid=$normalizedOwnerUid',
      );
      return null;
    }

    final data = snapshot.data();
    final rawItems = data?['services'];
    if (rawItems is! List) {
      logVanFirebaseSkip(
        reason: 'job services load missing services list',
        extra: 'uid=$normalizedOwnerUid',
      );
      return const <VanJobService>[];
    }

    final services = <VanJobService>[];
    for (final item in rawItems) {
      if (item is Map) {
        services.add(VanJobService.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    logVanFirebaseWriteSuccess(
      collectionPath: collectionPath,
      docId: 'library',
      uid: normalizedOwnerUid,
      source: source,
    );
    return services;
  }

  Future<void> saveServices({
    required String ownerUid,
    required List<VanJobService> services,
    String source = 'van_mate.job_services_save',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'job services save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid',
      );
      return;
    }

    final collectionPath = 'users/$normalizedOwnerUid/van_job_services';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: 'library',
      uid: normalizedOwnerUid,
      source: source,
    );

    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _servicesDoc(normalizedOwnerUid).set(<String, dynamic>{
        'id': 'library',
        'ownerUid': normalizedOwnerUid,
        'source': source,
        'updatedAt': DateTime.now().toIso8601String(),
        'services': services
            .map((service) => service.toJson())
            .toList(growable: false),
      }, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: 'library',
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: 'library',
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }

  Future<void> clearServices({
    required String ownerUid,
    String source = 'van_mate.job_services_clear',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return;
    }

    final collectionPath = 'users/$normalizedOwnerUid/van_job_services';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: 'library',
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await _servicesDoc(normalizedOwnerUid).delete();
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: 'library',
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: 'library',
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }
}
