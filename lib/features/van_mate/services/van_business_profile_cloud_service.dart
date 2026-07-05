import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/van_business_profile.dart';
import 'van_firestore_payload_builder.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanBusinessProfileCloudService {
  VanBusinessProfileCloudService._({
    FirebaseFirestore? firestore,
    VanFirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? VanFirebaseAuthService.instance;

  static final VanBusinessProfileCloudService instance =
      VanBusinessProfileCloudService._();

  final FirebaseFirestore _firestore;
  final VanFirebaseAuthService _authService;

  DocumentReference<Map<String, dynamic>> _profile(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('van_business_profile')
        .doc('profile');
  }

  Future<VanBusinessProfile?> loadProfile({required String ownerUid}) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return null;
    }

    logVanFirebaseWriteStart(
      collectionPath: 'users/$normalizedOwnerUid/van_business_profile',
      docId: 'profile',
      uid: normalizedOwnerUid,
      source: 'van_mate.business_profile_load',
    );
    final snapshot = await _profile(normalizedOwnerUid).get();
    if (!snapshot.exists) {
      logVanFirebaseSkip(
        reason: 'business profile load empty',
        extra: 'uid=$normalizedOwnerUid',
      );
      return null;
    }

    final data = snapshot.data();
    if (data == null || data.isEmpty) {
      return null;
    }

    final normalized = Map<String, dynamic>.from(data);
    logVanFirebaseWriteSuccess(
      collectionPath: 'users/$normalizedOwnerUid/van_business_profile',
      docId: 'profile',
      uid: normalizedOwnerUid,
      source: 'van_mate.business_profile_load',
    );
    return VanBusinessProfile.fromJson(normalized);
  }

  Future<void> saveProfile({
    required String ownerUid,
    required VanBusinessProfile profile,
    String source = 'van_mate',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'business profile save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid',
      );
      return;
    }

    final now = DateTime.now();
    final payload = buildVanCloudDocPayload(
      id: 'profile',
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: now,
      updatedAt: now,
      data: profile.toJson(),
    );
    logVanFirebaseWriteStart(
      collectionPath: 'users/$normalizedOwnerUid/van_business_profile',
      docId: 'profile',
      uid: normalizedOwnerUid,
      source: source,
    );
    debugPrint(
      '[BusinessProfileCloud] write start '
      'path=users/$normalizedOwnerUid/van_business_profile/profile '
      'logoPath=${profile.logoPath} logoUrl=${profile.logoUrl}',
    );
    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _profile(normalizedOwnerUid).set(payload, SetOptions(merge: true));
      debugPrint(
        '[BusinessProfileCloud] write success '
        'path=users/$normalizedOwnerUid/van_business_profile/profile',
      );
      logVanFirebaseWriteSuccess(
        collectionPath: 'users/$normalizedOwnerUid/van_business_profile',
        docId: 'profile',
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BusinessProfileCloud] write failure '
        'path=users/$normalizedOwnerUid/van_business_profile/profile '
        'error=$error',
      );
      debugPrint('[BusinessProfileCloud] write stack=$stackTrace');
      logVanFirebaseWriteFailure(
        collectionPath: 'users/$normalizedOwnerUid/van_business_profile',
        docId: 'profile',
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }

  Future<void> clearProfile({required String ownerUid}) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'business profile clear skipped',
        extra: 'uid=$normalizedOwnerUid',
      );
      return;
    }

    await _profile(normalizedOwnerUid).delete();
    logVanFirebaseWriteSuccess(
      collectionPath: 'users/$normalizedOwnerUid/van_business_profile',
      docId: 'profile',
      uid: normalizedOwnerUid,
      source: 'van_mate.business_profile_clear',
    );
  }

  Future<String?> ensureCurrentOwnerUid({String source = 'van_mate'}) async {
    return _authService.ensureCurrentUid(source: source);
  }
}
