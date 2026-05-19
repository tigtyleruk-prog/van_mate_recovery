import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/van_job_request_draft.dart';
import '../models/van_job_request_record.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanJobRequestCloudService {
  VanJobRequestCloudService._({
    FirebaseFirestore? firestore,
    VanFirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? VanFirebaseAuthService.instance;

  static final VanJobRequestCloudService instance =
      VanJobRequestCloudService._();

  static const String rootCollectionName = 'van_job_requests';

  final FirebaseFirestore _firestore;
  final VanFirebaseAuthService _authService;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(rootCollectionName);

  CollectionReference<Map<String, dynamic>> _privateRequests(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection('van_job_requests');
  }

  String createRequestId() {
    return _requests.doc().id;
  }

  Future<void> _mirrorPrivateRequest({
    required String ownerUid,
    required VanJobRequestRecord request,
    String source = 'van_mate.job_request',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      logVanFirebaseSkip(
        reason: 'job request mirror skipped',
        extra: 'source=$source requestId=${request.requestId}',
      );
      return;
    }

    final collectionPath = 'users/$normalizedOwnerUid/van_job_requests';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: request.requestId,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _privateRequests(normalizedOwnerUid)
          .doc(request.requestId)
          .set(request.toPrivateFirestore(), SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: request.requestId,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: request.requestId,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
    }
  }

  Future<VanJobRequestRecord?> loadRequestById(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }

    final snapshot = await _requests.doc(normalizedId).get();
    if (!snapshot.exists) {
      return null;
    }

    return VanJobRequestRecord.fromFirestore(snapshot);
  }

  Future<List<VanJobRequestRecord>> loadRequestsForOwner({
    required String ownerUid,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const <VanJobRequestRecord>[];
    }

    final snapshot = await _requests
        .where(Filter('ownerUid', isEqualTo: normalizedOwnerUid))
        .get();
    final requests = <VanJobRequestRecord>[];
    for (final doc in snapshot.docs) {
      try {
        requests.add(VanJobRequestRecord.fromFirestore(doc));
      } catch (error) {
        debugPrint('[VanJobRequestCloud] skip request ${doc.id}: $error');
      }
    }
    requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return requests;
  }

  Future<VanJobRequestRecord> createOrUpdateFromDraft({
    required String ownerUid,
    required String jobId,
    required VanJobRequestDraft draft,
    String? requestId,
    String source = 'van_mate.job_request',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedJobId = jobId.trim();
    if (normalizedOwnerUid.isEmpty || normalizedJobId.isEmpty) {
      throw StateError('Cannot create a request without ownerUid/jobId.');
    }

    await _authService.ensureSignedIn(source: source);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('Firebase auth currentUser is null after sign-in.');
    }

    final docRef = requestId == null || requestId.trim().isEmpty
        ? _requests.doc()
        : _requests.doc(requestId.trim());
    final now = DateTime.now();
    final request = VanJobRequestRecord(
      requestId: docRef.id,
      ownerUid: normalizedOwnerUid,
      jobId: normalizedJobId,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 48)),
      scheduledAt: draft.scheduledAt,
      jobDateLabel: draft.jobDateLabel,
      jobTimeLabel: draft.jobTimeLabel,
      publicJobTitle: draft.jobTitle.trim(),
      publicCustomerName: draft.customerName.trim(),
      publicAddressSummary: draft.address.trim(),
      publicPhoneNumber: draft.phoneNumber.trim(),
      publicCustomerEmail: draft.customerEmail.trim(),
      checklistItems: List<String>.unmodifiable(draft.checklistItems),
      customQuestions: List<String>.unmodifiable(draft.customQuestions),
      exactPinRequested: draft.requestExactPin,
      driverMessagePreview: draft.notesMessage.trim(),
      submittedAt: null,
      customerSubmittedAt: null,
      checklistResponses: const <VanJobRequestChecklistResponse>[],
      customQuestionResponses: const <VanJobRequestCustomQuestionResponse>[],
      additionalNotes: '',
      exactPinLat: null,
      exactPinLng: null,
      exactPinSource: '',
      exactPinNote: '',
    );

    final collectionPath = rootCollectionName;
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: request.requestId,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: currentUser.isAnonymous ? 'anonymous' : 'authenticated',
        source: source,
      );
      await docRef.set(request.toFirestore(), SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: request.requestId,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: request.requestId,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }

    await _mirrorPrivateRequest(
      ownerUid: normalizedOwnerUid,
      request: request,
      source: source,
    );
    return request;
  }

  Future<void> saveRequests({
    required String ownerUid,
    required List<VanJobRequestRecord> requests,
    String source = 'van_mate.job_request',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty || requests.isEmpty) {
      logVanFirebaseSkip(
        reason: 'job request batch save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid requests=${requests.length}',
      );
      return;
    }

    final validRequests = requests
        .where((request) => request.requestId.trim().isNotEmpty)
        .toList(growable: false);
    if (validRequests.isEmpty) {
      logVanFirebaseSkip(
        reason: 'job request batch save empty',
        extra: 'source=$source uid=$normalizedOwnerUid',
      );
      return;
    }

    await VanUserCloudService.instance.ensureUserDocument(
      uid: normalizedOwnerUid,
      authType: 'anonymous',
      source: source,
    );

    final batch = _firestore.batch();
    final collectionPath = rootCollectionName;
    for (final request in validRequests) {
      final cloudRequest = request.ownerUid.trim().isEmpty
          ? request.copyWith(ownerUid: normalizedOwnerUid)
          : request;
      logVanFirebaseWriteStart(
        collectionPath: collectionPath,
        docId: cloudRequest.requestId,
        uid: normalizedOwnerUid,
        source: source,
      );
      batch.set(
        _requests.doc(cloudRequest.requestId),
        cloudRequest.toFirestore(),
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit();
      for (final request in validRequests) {
        final cloudRequest = request.ownerUid.trim().isEmpty
            ? request.copyWith(ownerUid: normalizedOwnerUid)
            : request;
        logVanFirebaseWriteSuccess(
          collectionPath: collectionPath,
          docId: cloudRequest.requestId,
          uid: normalizedOwnerUid,
          source: source,
        );
        await _mirrorPrivateRequest(
          ownerUid: normalizedOwnerUid,
          request: cloudRequest,
          source: source,
        );
      }
    } catch (error) {
      for (final request in validRequests) {
        logVanFirebaseWriteFailure(
          collectionPath: collectionPath,
          docId: request.requestId,
          uid: normalizedOwnerUid,
          error: error,
          source: source,
        );
      }
      rethrow;
    }
  }

  Future<VanJobRequestRecord?> submitCustomerReply({
    required String requestId,
    required String ownerUid,
    required String jobId,
    required List<VanJobRequestChecklistResponse> checklistResponses,
    required List<VanJobRequestCustomQuestionResponse> customQuestionResponses,
    required String additionalNotes,
    required String exactPinSource,
    required String exactPinNote,
    double? exactPinLat,
    double? exactPinLng,
    String source = 'van_mate.job_request',
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedJobId = jobId.trim();
    if (normalizedRequestId.isEmpty ||
        normalizedOwnerUid.isEmpty ||
        normalizedJobId.isEmpty) {
      return null;
    }

    final existing = await loadRequestById(normalizedRequestId);
    if (existing == null) {
      return null;
    }
    if (existing.status != 'pending' || existing.isExpired) {
      return existing;
    }

    final now = DateTime.now();
    final updated = VanJobRequestRecord(
      requestId: existing.requestId,
      ownerUid: existing.ownerUid,
      jobId: existing.jobId,
      status: 'submitted',
      createdAt: existing.createdAt,
      updatedAt: now,
      expiresAt: existing.expiresAt,
      scheduledAt: existing.scheduledAt,
      jobDateLabel: existing.jobDateLabel,
      jobTimeLabel: existing.jobTimeLabel,
      publicJobTitle: existing.publicJobTitle,
      publicCustomerName: existing.publicCustomerName,
      publicAddressSummary: existing.publicAddressSummary,
      publicPhoneNumber: existing.publicPhoneNumber,
      publicCustomerEmail: existing.publicCustomerEmail,
      checklistItems: existing.checklistItems,
      customQuestions: existing.customQuestions,
      exactPinRequested: existing.exactPinRequested,
      driverMessagePreview: existing.driverMessagePreview,
      submittedAt: now,
      customerSubmittedAt: now,
      checklistResponses: checklistResponses,
      customQuestionResponses: customQuestionResponses,
      additionalNotes: additionalNotes.trim(),
      exactPinLat: exactPinLat,
      exactPinLng: exactPinLng,
      exactPinSource: exactPinSource.trim(),
      exactPinNote: exactPinNote.trim(),
    );

    final collectionPath = rootCollectionName;
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: normalizedRequestId,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await _requests.doc(normalizedRequestId).set(
        updated.toFirestore(),
        SetOptions(merge: true),
      );
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: normalizedRequestId,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: normalizedRequestId,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }

    await _mirrorPrivateRequest(
      ownerUid: normalizedOwnerUid,
      request: updated,
      source: source,
    );
    return updated;
  }

  Future<String?> ensureCurrentOwnerUid({String source = 'van_mate'}) async {
    return _authService.ensureCurrentUid(source: source);
  }
}
