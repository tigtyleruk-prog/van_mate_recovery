import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/van_custom_job_question.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanCustomJobQuestionsCloudService {
  VanCustomJobQuestionsCloudService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final VanCustomJobQuestionsCloudService instance =
      VanCustomJobQuestionsCloudService._();

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _questionsDoc(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection('van_custom_job_questions')
        .doc('library');
  }

  Future<List<VanCustomJobQuestion>?> loadQuestions({
    required String ownerUid,
    String source = 'van_mate.custom_questions_load',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return null;
    }

    final collectionPath = 'users/$normalizedOwnerUid/van_custom_job_questions';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: 'library',
      uid: normalizedOwnerUid,
      source: source,
    );

    final snapshot = await _questionsDoc(normalizedOwnerUid).get();
    if (!snapshot.exists) {
      logVanFirebaseSkip(
        reason: 'custom questions load empty',
        extra: 'uid=$normalizedOwnerUid',
      );
      return null;
    }

    final data = snapshot.data();
    final rawItems = data?['questions'];
    if (rawItems is! List) {
      logVanFirebaseSkip(
        reason: 'custom questions load missing questions list',
        extra: 'uid=$normalizedOwnerUid',
      );
      return const <VanCustomJobQuestion>[];
    }

    final questions = <VanCustomJobQuestion>[];
    for (final item in rawItems) {
      if (item is Map) {
        questions.add(
          VanCustomJobQuestion.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    logVanFirebaseWriteSuccess(
      collectionPath: collectionPath,
      docId: 'library',
      uid: normalizedOwnerUid,
      source: source,
    );
    return questions;
  }

  Future<void> saveQuestions({
    required String ownerUid,
    required List<VanCustomJobQuestion> questions,
    String source = 'van_mate.custom_questions_save',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'custom questions save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid',
      );
      return;
    }

    final collectionPath = 'users/$normalizedOwnerUid/van_custom_job_questions';
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
      await _questionsDoc(normalizedOwnerUid).set(<String, dynamic>{
        'id': 'library',
        'ownerUid': normalizedOwnerUid,
        'source': source,
        'updatedAt': DateTime.now().toIso8601String(),
        'questions': questions
            .map((question) => question.toJson())
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

  Future<void> clearQuestions({
    required String ownerUid,
    String source = 'van_mate.custom_questions_clear',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return;
    }

    final collectionPath = 'users/$normalizedOwnerUid/van_custom_job_questions';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: 'library',
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await _questionsDoc(normalizedOwnerUid).delete();
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
