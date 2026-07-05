import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/van_default_new_job_question_set.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanDefaultNewJobQuestionsCloudService {
  VanDefaultNewJobQuestionsCloudService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final VanDefaultNewJobQuestionsCloudService instance =
      VanDefaultNewJobQuestionsCloudService._();

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _setDoc(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection('question_sets')
        .doc(VanDefaultNewJobQuestionSet.defaultId);
  }

  Future<VanDefaultNewJobQuestionSet?> loadQuestionSet({
    required String ownerUid,
    String source = 'van_mate.default_new_job_questions_load',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return null;
    }

    final collectionPath = 'users/$normalizedOwnerUid/question_sets';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: VanDefaultNewJobQuestionSet.defaultId,
      uid: normalizedOwnerUid,
      source: source,
    );

    final snapshot = await _setDoc(normalizedOwnerUid).get();
    if (!snapshot.exists) {
      logVanFirebaseSkip(
        reason: 'default new job questions load empty',
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
      docId: VanDefaultNewJobQuestionSet.defaultId,
      uid: normalizedOwnerUid,
      source: source,
    );
    return VanDefaultNewJobQuestionSet.fromJson(data);
  }

  Future<void> saveQuestionSet({
    required String ownerUid,
    required VanDefaultNewJobQuestionSet set,
    String source = 'van_mate.default_new_job_questions_save',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'default new job questions save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid',
      );
      return;
    }

    final collectionPath = 'users/$normalizedOwnerUid/question_sets';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: set.id,
      uid: normalizedOwnerUid,
      source: source,
    );

    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _setDoc(normalizedOwnerUid).set(<String, dynamic>{
        ...set.toJson(),
        'ownerUid': normalizedOwnerUid,
        'source': source,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: set.id,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: set.id,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }

  Future<void> clearQuestionSet({
    required String ownerUid,
    String source = 'van_mate.default_new_job_questions_clear',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return;
    }

    final collectionPath = 'users/$normalizedOwnerUid/question_sets';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: VanDefaultNewJobQuestionSet.defaultId,
      uid: normalizedOwnerUid,
      source: source,
    );

    try {
      await _setDoc(normalizedOwnerUid).delete();
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: VanDefaultNewJobQuestionSet.defaultId,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: VanDefaultNewJobQuestionSet.defaultId,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }
}
