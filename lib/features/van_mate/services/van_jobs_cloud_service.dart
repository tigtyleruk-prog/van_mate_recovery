import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../pages/driver_customer_reply_mock_page.dart';
import 'van_firestore_payload_builder.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanJobsCloudService {
  VanJobsCloudService._({
    FirebaseFirestore? firestore,
    VanFirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? VanFirebaseAuthService.instance;

  static final VanJobsCloudService instance = VanJobsCloudService._();

  final FirebaseFirestore _firestore;
  final VanFirebaseAuthService _authService;

  CollectionReference<Map<String, dynamic>> _jobs(String ownerUid) {
    return _firestore.collection('users').doc(ownerUid).collection('van_jobs');
  }

  Future<List<DriverCustomerReplyMockData>> loadJobs({
    required String ownerUid,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const <DriverCustomerReplyMockData>[];
    }

    if (kDebugMode) {
      debugPrint(
        '[VanJobsCloud] load start uid=$normalizedOwnerUid path=users/$normalizedOwnerUid/van_jobs',
      );
    }
    final snapshot = await _jobs(normalizedOwnerUid).get();
    if (kDebugMode) {
      final fetchedIds = snapshot.docs.map((doc) => doc.id).join(', ');
      debugPrint(
        '[VanJobsCloud] fetched ${snapshot.docs.length} job docs uid=$normalizedOwnerUid ids=${fetchedIds.isEmpty ? '(none)' : fetchedIds}',
      );
    }
    final jobs = <DriverCustomerReplyMockData>[];
    var hiddenCount = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final normalized = Map<String, dynamic>.from(data);
      if ((normalized['jobId']?.toString().trim() ?? '').isEmpty) {
        normalized['jobId'] = doc.id;
      }
      try {
        final job = DriverCustomerReplyMockData.fromJson(normalized);
        if (job.isHiddenFromNormalLists) {
          hiddenCount += 1;
          if (kDebugMode) {
            debugPrint(
              '[VanJobsCloud] hidden job ${doc.id}: deleted=${job.deleted} archived=${job.archived}',
            );
          }
        }
        jobs.add(job);
      } catch (error) {
        debugPrint('[VanJobsCloud] skip job ${doc.id}: $error');
      }
    }
    jobs.sort((a, b) {
      final aUpdated =
          a.updatedAt ??
          a.completedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bUpdated =
          b.updatedAt ??
          b.completedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bUpdated.compareTo(aUpdated);
    });
    if (kDebugMode) {
      final visibleCount = jobs
          .where((job) => !job.isHiddenFromNormalLists)
          .length;
      debugPrint(
        '[VanJobsCloud] showing $visibleCount jobs uid=$normalizedOwnerUid hidden=$hiddenCount totalLoaded=${jobs.length}',
      );
    }
    return jobs;
  }

  Future<void> saveJob({
    required String ownerUid,
    required DriverCustomerReplyMockData job,
    String source = 'van_mate',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedJobId = job.jobId.trim();
    if (normalizedOwnerUid.isEmpty || normalizedJobId.isEmpty) {
      logVanFirebaseSkip(
        reason: 'job save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid docId=$normalizedJobId',
      );
      return;
    }

    final payload = buildVanCloudDocPayload(
      id: normalizedJobId,
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: job.createdAt ?? job.draftSavedAt ?? DateTime.now(),
      updatedAt: job.updatedAt ?? DateTime.now(),
      data: job.toJson(),
    );
    final collectionPath = 'users/$normalizedOwnerUid/van_jobs';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: normalizedJobId,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _jobs(
        normalizedOwnerUid,
      ).doc(normalizedJobId).set(payload, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: normalizedJobId,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: normalizedJobId,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }

  Future<void> saveJobs({
    required String ownerUid,
    required List<DriverCustomerReplyMockData> jobs,
    String source = 'van_mate',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty || jobs.isEmpty) {
      logVanFirebaseSkip(
        reason: 'job batch save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid jobs=${jobs.length}',
      );
      return;
    }

    final batch = _firestore.batch();
    final collection = _jobs(normalizedOwnerUid);
    final collectionPath = 'users/$normalizedOwnerUid/van_jobs';
    final docIds = <String>[];
    for (final job in jobs) {
      final normalizedJobId = job.jobId.trim();
      if (normalizedJobId.isEmpty) {
        continue;
      }

      final payload = buildVanCloudDocPayload(
        id: normalizedJobId,
        ownerUid: normalizedOwnerUid,
        source: source,
        createdAt: job.createdAt ?? job.draftSavedAt ?? DateTime.now(),
        updatedAt: job.updatedAt ?? DateTime.now(),
        data: job.toJson(),
      );
      logVanFirebaseWriteStart(
        collectionPath: collectionPath,
        docId: normalizedJobId,
        uid: normalizedOwnerUid,
        source: source,
      );
      batch.set(
        collection.doc(normalizedJobId),
        payload,
        SetOptions(merge: true),
      );
      docIds.add(normalizedJobId);
    }

    if (docIds.isEmpty) {
      logVanFirebaseSkip(
        reason: 'job batch save empty',
        extra: 'source=$source uid=$normalizedOwnerUid',
      );
      return;
    }

    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await batch.commit();
      for (final docId in docIds) {
        logVanFirebaseWriteSuccess(
          collectionPath: collectionPath,
          docId: docId,
          uid: normalizedOwnerUid,
          source: source,
        );
      }
    } catch (error) {
      for (final docId in docIds) {
        logVanFirebaseWriteFailure(
          collectionPath: collectionPath,
          docId: docId,
          uid: normalizedOwnerUid,
          error: error,
          source: source,
        );
      }
      rethrow;
    }
  }

  Future<void> deleteJob({
    required String ownerUid,
    required String jobId,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedJobId = jobId.trim();
    if (normalizedOwnerUid.isEmpty || normalizedJobId.isEmpty) {
      return;
    }

    await _jobs(normalizedOwnerUid).doc(normalizedJobId).delete();
  }

  Future<String?> ensureCurrentOwnerUid({String source = 'van_mate'}) async {
    return _authService.ensureCurrentUid(source: source);
  }
}
