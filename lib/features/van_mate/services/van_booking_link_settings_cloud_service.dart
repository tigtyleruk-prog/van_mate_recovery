import 'package:cloud_firestore/cloud_firestore.dart';

import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanBookingLinkSettingsCloudService {
  VanBookingLinkSettingsCloudService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final VanBookingLinkSettingsCloudService instance =
      VanBookingLinkSettingsCloudService._();

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _settingsDoc(
    String ownerUid,
    String businessProfileId,
  ) {
    final docId =
        businessProfileId.trim().isEmpty ||
            businessProfileId.trim() == 'default_business'
        ? 'settings'
        : businessProfileId.trim();
    return _firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection('van_booking_link_settings')
        .doc(docId);
  }

  Future<Map<String, dynamic>?> loadSettings({
    required String ownerUid,
    required String businessProfileId,
    String source = 'van_mate.booking_link_settings_load',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return null;
    }

    final docId =
        businessProfileId.trim().isEmpty ||
            businessProfileId.trim() == 'default_business'
        ? 'settings'
        : businessProfileId.trim();
    final collectionPath =
        'users/$normalizedOwnerUid/van_booking_link_settings';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: docId,
      uid: normalizedOwnerUid,
      source: source,
    );

    final snapshot = await _settingsDoc(
      normalizedOwnerUid,
      businessProfileId,
    ).get();
    if (!snapshot.exists) {
      logVanFirebaseSkip(
        reason: 'booking link settings load empty',
        extra: 'uid=$normalizedOwnerUid',
      );
      return null;
    }

    final data = snapshot.data();
    if (data == null || data.isEmpty) {
      return null;
    }

    logVanFirebaseWriteSuccess(
      collectionPath: collectionPath,
      docId: docId,
      uid: normalizedOwnerUid,
      source: source,
    );
    return Map<String, dynamic>.from(data);
  }

  Future<void> saveSettings({
    required String ownerUid,
    required String businessProfileId,
    required String title,
    required bool isActive,
    String source = 'van_mate.booking_link_settings_save',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'booking link settings save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid',
      );
      return;
    }

    final docId =
        businessProfileId.trim().isEmpty ||
            businessProfileId.trim() == 'default_business'
        ? 'settings'
        : businessProfileId.trim();
    final collectionPath =
        'users/$normalizedOwnerUid/van_booking_link_settings';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: docId,
      uid: normalizedOwnerUid,
      source: source,
    );

    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _settingsDoc(
        normalizedOwnerUid,
        businessProfileId,
      ).set(<String, dynamic>{
        'id': docId,
        'ownerUid': normalizedOwnerUid,
        'businessProfileId': businessProfileId.trim(),
        'source': source,
        'updatedAt': DateTime.now().toIso8601String(),
        'title': title.trim(),
        'isActive': isActive,
      }, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: docId,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: docId,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }
}
