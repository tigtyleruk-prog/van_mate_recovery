import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_job_request_state.dart';
import '../models/van_job_request_draft.dart';
import '../models/van_job_request_record.dart';
import 'van_firestore_payload_builder.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanJobRequestDeleteResult {
  const VanJobRequestDeleteResult({
    this.deletedPublicRequests = 0,
    this.deletedPrivateRequests = 0,
    this.deletedLegacyRequests = 0,
  });

  final int deletedPublicRequests;
  final int deletedPrivateRequests;
  final int deletedLegacyRequests;

  int get totalDeleted =>
      deletedPublicRequests + deletedPrivateRequests + deletedLegacyRequests;
}

class VanJobRequestCloudService {
  VanJobRequestCloudService._({
    FirebaseFirestore? firestore,
    VanFirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? VanFirebaseAuthService.instance;

  static final VanJobRequestCloudService instance =
      VanJobRequestCloudService._();

  static const String rootCollectionName = 'public_job_requests';
  static const String _shortCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _shortCodeLength = 6;
  static final Random _shortCodeRandom = Random.secure();

  final FirebaseFirestore _firestore;
  final VanFirebaseAuthService _authService;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(rootCollectionName);

  CollectionReference<Map<String, dynamic>> get _legacyRequests =>
      _firestore.collection('van_job_requests');

  CollectionReference<Map<String, dynamic>> _privateRequests(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid.trim())
        .collection('van_job_requests');
  }

  String createRequestId() {
    return _requests.doc().id;
  }

  String generateShortCode() {
    final buffer = StringBuffer();
    for (var index = 0; index < _shortCodeLength; index++) {
      final alphabetIndex = _shortCodeRandom.nextInt(_shortCodeAlphabet.length);
      buffer.write(_shortCodeAlphabet[alphabetIndex]);
    }
    return buffer.toString();
  }

  Future<String> _generateUniqueShortCode({
    String excludeRequestId = '',
  }) async {
    final normalizedExcludedId = excludeRequestId.trim();
    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate = generateShortCode();
      final existing = await _requests
          .where('shortCode', isEqualTo: candidate)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (existing.docs.isEmpty) {
        return candidate;
      }
      final docId = existing.docs.first.id.trim();
      if (docId.isNotEmpty && docId == normalizedExcludedId) {
        return candidate;
      }
    }
    throw StateError(
      'Could not generate a unique short code for this request.',
    );
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
          .set(
            sanitizeVanFirestoreMap(request.toPrivateFirestore()),
            SetOptions(merge: true),
          );
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

    final publicSnapshot = await _requests
        .doc(normalizedId)
        .get(const GetOptions(source: Source.serverAndCache));
    if (publicSnapshot.exists) {
      final request = VanJobRequestRecord.fromFirestore(publicSnapshot);
      return request.isHiddenFromNormalLists ? null : request;
    }

    try {
      final legacySnapshot = await _legacyRequests
          .doc(normalizedId)
          .get(const GetOptions(source: Source.serverAndCache));
      if (legacySnapshot.exists) {
        final request = VanJobRequestRecord.fromFirestore(legacySnapshot);
        return request.isHiddenFromNormalLists ? null : request;
      }
    } catch (error) {
      debugPrint('[VanJobRequestCloud] legacy request load failed: $error');
    }

    return null;
  }

  Stream<VanJobRequestRecord?> watchRequestById(
    String requestId, {
    String debugOrigin = 'job_request_cloud',
  }) {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      return const Stream<VanJobRequestRecord?>.empty();
    }

    return Stream<VanJobRequestRecord?>.multi((controller) {
      debugPrint(
        '[VanJobRequestStream] listen origin=$debugOrigin requestId=$normalizedId',
      );
      final subscription = _requests
          .doc(normalizedId)
          .snapshots()
          .listen(
            (snapshot) {
              debugPrint(
                '[VanJobRequestStream] snapshot origin=$debugOrigin requestId=$normalizedId '
                'exists=${snapshot.exists} fromCache=${snapshot.metadata.isFromCache} '
                'pendingWrites=${snapshot.metadata.hasPendingWrites}',
              );
              if (!snapshot.exists) {
                controller.add(null);
                return;
              }
              try {
                controller.add(VanJobRequestRecord.fromFirestore(snapshot));
              } catch (error) {
                debugPrint(
                  '[VanJobRequestCloud] watch request parse failed requestId=$normalizedId error=$error',
                );
                controller.add(null);
              }
            },
            onError: (error, stackTrace) {
              debugPrint(
                '[VanJobRequestStream] error origin=$debugOrigin requestId=$normalizedId error=$error',
              );
              controller.addError(error, stackTrace);
            },
            onDone: () {
              debugPrint(
                '[VanJobRequestStream] done origin=$debugOrigin requestId=$normalizedId',
              );
              controller.close();
            },
          );
      controller.onCancel = () async {
        debugPrint(
          '[VanJobRequestStream] cancel origin=$debugOrigin requestId=$normalizedId',
        );
        await subscription.cancel();
      };
    });
  }

  Future<List<VanJobRequestRecord>> loadRequestsForOwner({
    required String ownerUid,
    Source source = Source.serverAndCache,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const <VanJobRequestRecord>[];
    }

    if (kDebugMode) {
      debugPrint(
        '[VanJobRequestCloud] load start uid=$normalizedOwnerUid path=$rootCollectionName source=$source',
      );
    }
    final snapshot = await _requests
        .where(Filter('ownerUid', isEqualTo: normalizedOwnerUid))
        .get(GetOptions(source: source));
    if (kDebugMode) {
      final fetchedIds = snapshot.docs.map((doc) => doc.id).join(', ');
      debugPrint(
        '[VanJobRequestCloud] fetched ${snapshot.docs.length} request docs uid=$normalizedOwnerUid ids=${fetchedIds.isEmpty ? '(none)' : fetchedIds}',
      );
    }
    final requests = <VanJobRequestRecord>[];
    var hiddenCount = 0;
    for (final doc in snapshot.docs) {
      try {
        final request = VanJobRequestRecord.fromFirestore(doc);
        if (kDebugMode) {
          final parsedAnswerCount = request.answers
              .where((item) => item.hasAnswer)
              .length;
          final parsedPhotoCount = request.photos
              .where((item) => item.hasUrl)
              .length;
          debugPrint(
            '[VanJobRequestCloud][doc] path=$rootCollectionName docId=${doc.id} jobId=${request.jobId} requestId=${request.requestId} status=${request.status} requestStatus=${request.status} deleted=${request.deleted} archived=${request.archived} parsedAnswerCount=$parsedAnswerCount parsedPhotoCount=$parsedPhotoCount preferredDate=${request.preferredDate?.toIso8601String() ?? '(none)'} preferredTimeWindow=${request.preferredTimeWindow.isEmpty ? '(none)' : request.preferredTimeWindow} preferredIsFlexible=${request.preferredIsFlexible} preferredTimingNote=${request.preferredTimingNote.isEmpty ? '(none)' : request.preferredTimingNote}',
          );
        }
        if (request.deleted || request.archived) {
          hiddenCount += 1;
          if (kDebugMode) {
            debugPrint(
              '[VanJobRequestCloud] hidden request ${doc.id}: deleted=${request.deleted} archived=${request.archived}',
            );
          }
        }
        requests.add(request);
      } catch (error) {
        debugPrint('[VanJobRequestCloud] skip request ${doc.id}: $error');
      }
    }
    requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (kDebugMode) {
      final visibleCount = requests
          .where((request) => !request.deleted && !request.archived)
          .length;
      debugPrint(
        '[VanJobRequestCloud] showing $visibleCount request mirrors uid=$normalizedOwnerUid hidden=$hiddenCount totalLoaded=${requests.length}',
      );
    }
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
    final customerPhone = sanitizeVanCustomerPhoneNumber(draft.phoneNumber);
    final existingRequest = await loadRequestById(docRef.id);
    final shortCode =
        normalizeVanJobRequestShortCode(
          existingRequest?.shortCode ?? '',
        ).isNotEmpty
        ? normalizeVanJobRequestShortCode(existingRequest!.shortCode)
        : await _generateUniqueShortCode(excludeRequestId: docRef.id);
    final request = VanJobRequestRecord(
      requestId: docRef.id,
      ownerUid: normalizedOwnerUid,
      jobId: normalizedJobId,
      linkedJobId: normalizedJobId,
      status: 'request_sent',
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(vanJobRequestDefaultExpiry),
      shortCode: shortCode,
      scheduledAt: draft.scheduledAt,
      jobDateLabel: draft.jobDateLabel,
      jobTimeLabel: draft.jobTimeLabel,
      scheduledDate: draft.scheduledDate,
      scheduledStartTime: draft.scheduledStartTime,
      estimatedDurationMinutes: draft.estimatedDurationMinutes,
      calendarStatus: draft.calendarStatus,
      locationPending: draft.locationPending,
      publicJobTitle: draft.jobTitle.trim(),
      publicCustomerName: draft.customerName.trim(),
      publicAddressSummary: draft.address.trim(),
      publicPhoneNumber: customerPhone,
      publicCustomerEmail: draft.customerEmail.trim(),
      customerPostcode: draft.postcode.trim(),
      checklistItems: List<String>.unmodifiable(draft.checklistItems),
      customQuestions: List<String>.unmodifiable(draft.customQuestions),
      selectedServiceId: draft.selectedServiceId.trim(),
      selectedServiceName: draft.selectedServiceName.trim(),
      exactPinRequested: draft.requestExactPin,
      requestPhotos: draft.requestPhotos,
      requiresExactPinAfterQuoteAccepted:
          draft.requiresExactPinAfterQuoteAccepted,
      source: 'new_job',
      sourceLabel: 'New Job',
      driverMessagePreview: draft.notesMessage.trim(),
      submittedAt: null,
      customerSubmittedAt: null,
      checklistResponses: const <VanJobRequestChecklistResponse>[],
      customQuestionResponses: const <VanJobRequestCustomQuestionResponse>[],
      answers: List<VanJobRequestAnswer>.unmodifiable(draft.answers),
      additionalNotes: '',
      exactPinLat: draft.exactPinLatitude,
      exactPinLng: draft.exactPinLongitude,
      exactPinSource: draft.exactPinSource,
      exactPinNote: '',
      isTestData: kDebugMode,
      testMode: kDebugMode,
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
      await docRef.set(
        sanitizeVanFirestoreMap(request.toPublicFirestore()),
        SetOptions(merge: true),
      );
      debugPrint(
        '[PhoneSave] requestId=${request.requestId} customerPhone=$customerPhone',
      );
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
        extra:
            'source=$source uid=$normalizedOwnerUid requests=${requests.length}',
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
        sanitizeVanFirestoreMap(cloudRequest.toPublicFirestore()),
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

  Future<void> mergeRequestFields({
    required String ownerUid,
    required String requestId,
    required Map<String, dynamic> fields,
    String source = 'van_mate.booking_link',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty || fields.isEmpty) {
      return;
    }

    final sanitizedFields = sanitizeVanFirestoreMap(fields);
    await _requests
        .doc(normalizedRequestId)
        .set(sanitizedFields, SetOptions(merge: true));

    if (normalizedOwnerUid.isNotEmpty) {
      await _privateRequests(
        normalizedOwnerUid,
      ).doc(normalizedRequestId).set(sanitizedFields, SetOptions(merge: true));
    }

    logVanFirebaseHydration(
      stage: 'completed',
      target: 'booking link request metadata',
      extra:
          'source=$source requestId=$normalizedRequestId ownerUid=${normalizedOwnerUid.isEmpty ? '(none)' : normalizedOwnerUid}',
    );
  }

  Future<void> deleteRequest({
    required String ownerUid,
    required String requestId,
    String source = 'van_mate.job_request',
    bool testCleanup = false,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedRequestId = requestId.trim();
    if (normalizedOwnerUid.isEmpty || normalizedRequestId.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    final ownerPrivateRequests = _privateRequests(normalizedOwnerUid);
    final collectionPath = rootCollectionName;
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: normalizedRequestId,
      uid: normalizedOwnerUid,
      source: source,
    );
    final deletedPayload = sanitizeVanFirestoreMap(<String, dynamic>{
      'deleted': true,
      'archived': true,
      'deletedByDriver': true,
      'testCleanup': testCleanup,
      'status': 'deleted',
      'requestStatus': 'deleted',
      'quoteStatus': 'deleted',
      'quoteResponseStatus': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _requests.doc(normalizedRequestId),
      deletedPayload,
      SetOptions(merge: true),
    );
    batch.set(
      _legacyRequests.doc(normalizedRequestId),
      deletedPayload,
      SetOptions(merge: true),
    );
    batch.set(
      ownerPrivateRequests.doc(normalizedRequestId),
      deletedPayload,
      SetOptions(merge: true),
    );

    try {
      await batch.commit();
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
  }

  Future<VanJobRequestDeleteResult> deleteAllRequestsForOwner({
    required String ownerUid,
    String source = 'van_mate.debug_clear_saved_jobs',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const VanJobRequestDeleteResult();
    }

    final publicSnapshot = await _requests
        .where(Filter('ownerUid', isEqualTo: normalizedOwnerUid))
        .get(const GetOptions(source: Source.server));
    final legacySnapshot = await _legacyRequests
        .where(Filter('ownerUid', isEqualTo: normalizedOwnerUid))
        .get(const GetOptions(source: Source.server));
    final privateSnapshot = await _privateRequests(
      normalizedOwnerUid,
    ).get(const GetOptions(source: Source.server));

    var deletedPublicRequests = 0;
    var deletedPrivateRequests = 0;
    var deletedLegacyRequests = 0;
    var batch = _firestore.batch();
    var batchWrites = 0;

    Future<void> commitIfFull() async {
      if (batchWrites < 450) {
        return;
      }
      await batch.commit();
      batch = _firestore.batch();
      batchWrites = 0;
    }

    for (final doc in publicSnapshot.docs) {
      batch.delete(doc.reference);
      batchWrites += 1;
      deletedPublicRequests += 1;
      await commitIfFull();
    }
    for (final doc in privateSnapshot.docs) {
      batch.delete(doc.reference);
      batchWrites += 1;
      deletedPrivateRequests += 1;
      await commitIfFull();
    }
    for (final doc in legacySnapshot.docs) {
      batch.delete(doc.reference);
      batchWrites += 1;
      deletedLegacyRequests += 1;
      await commitIfFull();
    }
    if (batchWrites > 0) {
      await batch.commit();
    }

    if (kDebugMode) {
      debugPrint(
        '[VanJobRequestCloud][deleteAllRequestsForOwner] path=public_job_requests deleted=$deletedPublicRequests privatePath=users/$normalizedOwnerUid/van_job_requests privateDeleted=$deletedPrivateRequests legacyPath=van_job_requests legacyDeleted=$deletedLegacyRequests source=$source',
      );
    }
    return VanJobRequestDeleteResult(
      deletedPublicRequests: deletedPublicRequests,
      deletedPrivateRequests: deletedPrivateRequests,
      deletedLegacyRequests: deletedLegacyRequests,
    );
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
    if (existing.isHiddenFromNormalLists) {
      return existing;
    }
    if (normalizeVanJobRequestStatus(existing.status) != 'request_sent' ||
        existing.isExpired) {
      return existing;
    }

    final now = DateTime.now();
    final updated = VanJobRequestRecord(
      requestId: existing.requestId,
      ownerUid: existing.ownerUid,
      jobId: existing.jobId,
      linkedJobId: existing.linkedJobId,
      status: 'reply_received',
      createdAt: existing.createdAt,
      updatedAt: now,
      expiresAt: existing.expiresAt,
      scheduledAt: existing.scheduledAt,
      jobDateLabel: existing.jobDateLabel,
      jobTimeLabel: existing.jobTimeLabel,
      scheduledDate: existing.scheduledDate,
      scheduledStartTime: existing.scheduledStartTime,
      estimatedDurationMinutes: existing.estimatedDurationMinutes,
      calendarStatus: existing.calendarStatus,
      publicJobTitle: existing.publicJobTitle,
      publicCustomerName: existing.publicCustomerName,
      publicAddressSummary: existing.publicAddressSummary,
      publicPhoneNumber: existing.publicPhoneNumber,
      publicCustomerEmail: existing.publicCustomerEmail,
      checklistItems: existing.checklistItems,
      customQuestions: existing.customQuestions,
      exactPinRequested: existing.exactPinRequested,
      requestPhotos: existing.requestPhotos,
      requiresExactPinAfterQuoteAccepted:
          existing.requiresExactPinAfterQuoteAccepted,
      source: existing.source,
      isPreview: existing.isPreview,
      sourceLabel: existing.sourceLabel,
      selectedServiceId: existing.selectedServiceId,
      selectedServiceName: existing.selectedServiceName,
      driverMessagePreview: existing.driverMessagePreview,
      submittedAt: now,
      customerSubmittedAt: now,
      requestSubmittedAt: now,
      replyReceivedAt: now,
      checklistResponses: checklistResponses,
      customQuestionResponses: customQuestionResponses,
      answers: existing.answers,
      photos: existing.photos,
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
      await _requests
          .doc(normalizedRequestId)
          .set(
            sanitizeVanFirestoreMap(updated.toPublicFirestore()),
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

  Future<VanJobRequestRecord?> cancelRequest({
    required String requestId,
    required String ownerUid,
    String source = 'van_mate.job_request',
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedRequestId.isEmpty || normalizedOwnerUid.isEmpty) {
      return null;
    }

    final existing = await loadRequestById(normalizedRequestId);
    if (existing == null || existing.ownerUid.trim() != normalizedOwnerUid) {
      return existing;
    }
    if (existing.isHiddenFromNormalLists) {
      return existing;
    }

    final updated = existing.copyWith(
      status: 'cancelled',
      updatedAt: DateTime.now(),
    );

    final collectionPath = rootCollectionName;
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: normalizedRequestId,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await _requests
          .doc(normalizedRequestId)
          .set(
            sanitizeVanFirestoreMap(updated.toPublicFirestore()),
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
