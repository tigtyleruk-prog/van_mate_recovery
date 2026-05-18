import 'package:cloud_firestore/cloud_firestore.dart';

import 'van_firebase_debug_logging.dart';

class VanUserCloudService {
  VanUserCloudService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final VanUserCloudService instance = VanUserCloudService._();

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid.trim());
  }

  Future<void> ensureUserDocument({
    required String uid,
    String authType = 'anonymous',
    String source = 'van_mate',
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'user document skipped',
        extra: 'source=$source reason=empty_uid',
      );
      return;
    }

    final docRef = _userDoc(normalizedUid);
    final collectionPath = 'users';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: normalizedUid,
      uid: normalizedUid,
      source: source,
    );

    try {
      final now = DateTime.now().toIso8601String();
      final snapshot = await docRef.get();
      final createdAt = snapshot.data()?['createdAt']?.toString().trim();
      final payload = <String, dynamic>{
        'uid': normalizedUid,
        'updatedAt': now,
        'app': 'van_mate',
        'authType': authType,
      };
      if (createdAt == null || createdAt.isEmpty) {
        payload['createdAt'] = now;
      }
      await docRef.set(payload, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: normalizedUid,
        uid: normalizedUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: normalizedUid,
        uid: normalizedUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }
}
