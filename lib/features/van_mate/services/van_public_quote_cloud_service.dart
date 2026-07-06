import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../helpers/van_text_formatters.dart';
import '../models/van_exact_pin_source.dart';
import '../pages/driver_customer_reply_mock_page.dart';
import '../models/van_job_request_record.dart';
import 'van_firestore_payload_builder.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';

class VanPublicQuoteDeleteResult {
  const VanPublicQuoteDeleteResult({
    this.deletedQuotes = 0,
    this.deletedTokens = 0,
  });

  final int deletedQuotes;
  final int deletedTokens;

  int get totalDeleted => deletedQuotes + deletedTokens;
}

class VanPublicQuoteCloudService {
  VanPublicQuoteCloudService._({
    FirebaseFirestore? firestore,
    VanFirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? VanFirebaseAuthService.instance;

  static final VanPublicQuoteCloudService instance =
      VanPublicQuoteCloudService._();

  final FirebaseFirestore _firestore;
  final VanFirebaseAuthService _authService;

  CollectionReference<Map<String, dynamic>> _publicQuotes() {
    return _firestore.collection('public_quote_responses');
  }

  CollectionReference<Map<String, dynamic>> _publicQuoteTokens() {
    return _firestore.collection('public_quote_response_tokens');
  }

  bool _readBoolLike(dynamic value) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true';
  }

  String _quoteDocId(DriverCustomerReplyMockData job) {
    final activeQuoteId = job.quoteResponseId.trim();
    if (activeQuoteId.isNotEmpty) {
      return activeQuoteId;
    }
    final jobId = job.jobId.trim();
    if (jobId.isNotEmpty) {
      return jobId;
    }
    final requestId = job.requestId?.trim() ?? '';
    if (requestId.isNotEmpty) {
      return requestId;
    }
    return '';
  }

  Future<List<DriverCustomerReplyMockData>> loadQuotes({
    required String ownerUid,
    Source source = Source.serverAndCache,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const <DriverCustomerReplyMockData>[];
    }

    if (kDebugMode) {
      debugPrint(
        '[VanPublicQuoteCloud] load start uid=$normalizedOwnerUid path=public_quote_responses',
      );
    }
    final snapshot = await _publicQuotes()
        .where(Filter('ownerUid', isEqualTo: normalizedOwnerUid))
        .get(GetOptions(source: source));
    if (kDebugMode) {
      final fetchedIds = snapshot.docs.map((doc) => doc.id).join(', ');
      debugPrint(
        '[VanPublicQuoteCloud] fetched ${snapshot.docs.length} quote docs uid=$normalizedOwnerUid ids=${fetchedIds.isEmpty ? '(none)' : fetchedIds}',
      );
    }
    final quotes = <DriverCustomerReplyMockData>[];
    var hiddenCount = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final normalized = Map<String, dynamic>.from(data);
      if ((normalized['jobId']?.toString().trim() ?? '').isEmpty) {
        normalized['jobId'] = doc.id;
      }
      if ((normalized['quoteResponseId']?.toString().trim() ?? '').isEmpty) {
        normalized['quoteResponseId'] = doc.id;
      }
      try {
        final quote = DriverCustomerReplyMockData.fromJson(normalized);
        if (kDebugMode) {
          debugPrint(
            '[VanPublicQuoteCloud][doc] path=public_quote_responses docId=${doc.id} jobId=${quote.jobId} requestId=${quote.requestId ?? '(none)'} status=${quote.status} requestStatus=${quote.requestStatus} deleted=${quote.deleted} archived=${quote.archived}',
          );
        }
        if (quote.isHiddenFromNormalLists) {
          hiddenCount += 1;
          if (kDebugMode) {
            debugPrint(
              '[VanPublicQuoteCloud] hidden quote ${doc.id}: deleted=${quote.deleted} archived=${quote.archived}',
            );
          }
        }
        quotes.add(quote);
      } catch (error) {
        debugPrint('[VanPublicQuoteCloud] skip quote ${doc.id}: $error');
      }
    }
    quotes.sort((a, b) {
      final aUpdated =
          a.quoteAcceptedAt ??
          a.quoteDeclinedAt ??
          a.quoteSentAt ??
          a.updatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bUpdated =
          b.quoteAcceptedAt ??
          b.quoteDeclinedAt ??
          b.quoteSentAt ??
          b.updatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bUpdated.compareTo(aUpdated);
    });
    if (kDebugMode) {
      final visibleCount = quotes
          .where((job) => !job.isHiddenFromNormalLists)
          .length;
      debugPrint(
        '[VanPublicQuoteCloud] showing $visibleCount quotes uid=$normalizedOwnerUid hidden=$hiddenCount totalLoaded=${quotes.length}',
      );
    }
    return quotes;
  }

  Future<void> saveQuote({
    required DriverCustomerReplyMockData job,
    Map<String, dynamic> extraData = const <String, dynamic>{},
    String source = 'van_mate.public_quote',
  }) async {
    final normalizedOwnerUid = await _authService.ensureCurrentUid(
      source: source,
    );
    if (normalizedOwnerUid == null || normalizedOwnerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'public quote save skipped',
        extra: 'source=$source docId=${_quoteDocId(job)}',
      );
      return;
    }

    final docId = _quoteDocId(job);
    if (docId.isEmpty) {
      logVanFirebaseSkip(
        reason: 'public quote save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid docId=(empty)',
      );
      return;
    }

    final quoteResponseToken = job.quoteResponseToken.trim().isNotEmpty
        ? job.quoteResponseToken.trim()
        : buildVanQuoteResponseToken(docId);
    final quoteResponseLink = resolveVanQuoteResponseDisplayLink(
      quoteResponseLink: job.quoteResponseLink,
      quoteResponseToken: quoteResponseToken,
      quoteId: docId,
    );
    final explicitQuoteStatus =
        extraData['quoteStatus']?.toString().trim() ?? '';
    final explicitQuoteResponseStatus =
        extraData['quoteResponseStatus']?.toString().trim() ?? '';
    final explicitResponse =
        extraData['quoteResponse']?.toString().trim() ?? '';
    final effectiveQuoteAccepted = extraData.containsKey('quoteAccepted')
        ? _readBoolLike(extraData['quoteAccepted'])
        : job.isQuoteAccepted;
    final effectiveQuoteDeclined = extraData.containsKey('quoteDeclined')
        ? _readBoolLike(extraData['quoteDeclined'])
        : job.isQuoteDeclined;
    final effectiveQuoteStatus = explicitQuoteStatus.isNotEmpty
        ? explicitQuoteStatus
        : effectiveQuoteAccepted
        ? 'accepted'
        : effectiveQuoteDeclined
        ? 'declined'
        : job.quoteStatus.trim();
    final effectiveQuoteResponseStatus = explicitQuoteResponseStatus.isNotEmpty
        ? explicitQuoteResponseStatus
        : effectiveQuoteAccepted
        ? 'accepted'
        : effectiveQuoteDeclined
        ? 'declined'
        : job.quoteResponseStatus.trim();
    final effectiveQuoteResponse = explicitResponse.isNotEmpty
        ? explicitResponse
        : effectiveQuoteAccepted
        ? 'accepted'
        : effectiveQuoteDeclined
        ? 'declined'
        : 'pending';
    final effectiveQuoteTimingChoice =
        extraData['quoteTimingChoice']?.toString().trim().isNotEmpty == true
        ? extraData['quoteTimingChoice'].toString().trim()
        : job.quoteTimingChoice.trim();
    final effectiveStatus =
        extraData['status']?.toString().trim().isNotEmpty == true
        ? extraData['status'].toString().trim()
        : job.status.trim();
    final effectiveRequestStatus =
        extraData['requestStatus']?.toString().trim().isNotEmpty == true
        ? extraData['requestStatus'].toString().trim()
        : job.requestStatus.trim();
    final effectiveQuoteRespondedAt = extraData.containsKey('quoteRespondedAt')
        ? extraData['quoteRespondedAt']
        : job.quoteRespondedAt?.toIso8601String();
    final effectiveQuoteAcceptedAt = extraData.containsKey('quoteAcceptedAt')
        ? extraData['quoteAcceptedAt']
        : job.quoteAcceptedAt?.toIso8601String();
    final effectiveQuoteDeclinedAt = extraData.containsKey('quoteDeclinedAt')
        ? extraData['quoteDeclinedAt']
        : job.quoteDeclinedAt?.toIso8601String();
    final effectiveDeclineReasonCode =
        extraData['declineReasonCode']?.toString() ?? job.declineReasonCode;
    final effectiveDeclineReasonLabel =
        extraData['declineReasonLabel']?.toString() ?? job.declineReasonLabel;
    final effectiveDeclineReasonText =
        extraData['declineReasonText']?.toString() ?? job.declineReasonText;
    final effectiveDeclineNote =
        extraData['declineNote']?.toString() ?? job.declineNote;

    final payload = buildVanCloudDocPayload(
      id: docId,
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: job.createdAt ?? job.quoteSavedAt ?? DateTime.now(),
      updatedAt: job.updatedAt ?? DateTime.now(),
      data: <String, dynamic>{
        'ownerUid': normalizedOwnerUid,
        'jobId': job.jobId.trim(),
        'requestId': job.requestId?.trim() ?? '',
        'quoteResponseId': docId,
        'quoteResponseToken': quoteResponseToken,
        'quoteResponseLink': quoteResponseLink,
        'customerName': job.customerName,
        'jobTitle': job.jobTitle,
        'jobDescription': job.jobTitle,
        'address': job.address,
        'scheduledAt': job.scheduledAt?.toIso8601String(),
        'jobDateLabel': job.jobDateLabel,
        'jobTimeLabel': job.jobTimeLabel,
        'proposedDate': job.proposedDate,
        'proposedStartTime': job.proposedStartTime,
        'proposedAppointmentNote': job.proposedAppointmentNote,
        'acceptedProposedDate': job.acceptedProposedDate,
        'acceptedProposedStartTime': job.acceptedProposedStartTime,
        'schedulingStatus': job.schedulingStatus,
        'estimatedDurationMinutes': job.estimatedDurationMinutes,
        'quoteAmount': job.quoteAmount,
        'quoteAmountText': job.quoteAmount != null
            ? formatCurrency(job.quoteAmount!)
            : formatCurrency(0),
        'quoteJobDescription': extraData['jobDescription'] ?? job.jobTitle,
        'quoteNotes': extraData['quoteNotes'] ?? '',
        'paymentInstructions': extraData['paymentInstructions'] ?? '',
        'quoteExtras': extraData['quoteExtras'] ?? const <String>[],
        'quoteMessage': extraData['quoteMessage'] ?? '',
        'quoteSentAt': (job.quoteSentAt ?? DateTime.now()).toIso8601String(),
        'quoteStatus': effectiveQuoteStatus,
        'quoteResponseStatus': effectiveQuoteResponseStatus,
        'quoteTimingChoice': effectiveQuoteTimingChoice,
        'agreedDateTime': job.agreedDateTime?.toIso8601String(),
        'quoteResponse': effectiveQuoteResponse,
        'quoteAccepted': effectiveQuoteAccepted,
        'quoteDeclined': effectiveQuoteDeclined,
        'quoteRespondedAt': effectiveQuoteRespondedAt,
        'quoteAcceptedAt': effectiveQuoteAcceptedAt,
        'quoteDeclinedAt': effectiveQuoteDeclinedAt,
        'declineReasonCode': effectiveDeclineReasonCode,
        'declineReasonLabel': effectiveDeclineReasonLabel,
        'declineReasonText': effectiveDeclineReasonText,
        'declineNote': effectiveDeclineNote,
        'quoteDeclineReasonCode': effectiveDeclineReasonCode,
        'quoteDeclineReasonLabel': effectiveDeclineReasonLabel,
        'quoteDeclineReason': effectiveDeclineReasonLabel,
        'quoteDeclineNote': effectiveDeclineNote,
        'quoteDeclinedReasonCode': effectiveDeclineReasonCode,
        'quoteDeclinedReasonLabel': effectiveDeclineReasonLabel,
        'quoteDeclinedReason': effectiveDeclineReasonLabel,
        'quoteDeclinedNote': effectiveDeclineNote,
        'lastQuoteDeclineReason': effectiveDeclineReasonLabel,
        'lastQuoteDeclineNote': effectiveDeclineNote,
        'quoteDecline': <String, dynamic>{
          'reasonCode': effectiveDeclineReasonCode,
          'reasonLabel': effectiveDeclineReasonLabel,
          'reason': effectiveDeclineReasonLabel,
          'note': effectiveDeclineNote,
          'reasonText': effectiveDeclineReasonText,
        },
        'status': effectiveStatus,
        'requestStatus': effectiveRequestStatus,
        'phoneNumber': '',
        'requestExactPin': job.requestExactPin,
        'requiresExactPinAfterQuoteAccepted':
            job.requiresExactPinAfterQuoteAccepted,
        'exactPinShared': false,
        'exactPinShareSource':
            vanExactPinSourceToStorage(job.exactPinShareSource) ?? '',
        'exactPinSource': job.exactPinSource,
        'exactPinNote': job.exactPinNote ?? '',
        'exactPinLatitude': job.exactPinLatitude,
        'exactPinLongitude': job.exactPinLongitude,
        'exactPinLat': job.exactPinLatitude,
        'exactPinLng': job.exactPinLongitude,
        'checklistResponses': const <dynamic>[],
        'customQuestionResponses': const <dynamic>[],
        'additionalNotes': '',
        'hasReply': false,
        'hasExactPin': job.exactPinSaved,
        'deleted': job.deleted,
        'archived': job.archived,
        ...extraData,
      },
      deleted: job.deleted,
      archived: job.archived,
    );
    final collectionPath = 'public_quote_responses';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: docId,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      final batch = _firestore.batch();
      batch.set(_publicQuotes().doc(docId), payload, SetOptions(merge: true));
      if (quoteResponseToken.isNotEmpty) {
        batch.set(
          _publicQuoteTokens().doc(quoteResponseToken),
          buildVanCloudDocPayload(
            id: quoteResponseToken,
            ownerUid: normalizedOwnerUid,
            source: source,
            createdAt: job.createdAt ?? job.quoteSavedAt ?? DateTime.now(),
            updatedAt: job.updatedAt ?? DateTime.now(),
            data: <String, dynamic>{
              'ownerUid': normalizedOwnerUid,
              'jobId': job.jobId.trim(),
              'requestId': job.requestId?.trim() ?? '',
              'quoteResponseId': docId,
              'quoteResponseToken': quoteResponseToken,
              'quoteResponseLink': quoteResponseLink,
            },
          ),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      debugPrint(
        '[PublicQuoteSave] quoteId=$docId requestId=${job.requestId?.trim().isNotEmpty == true ? job.requestId : '(none)'} requiresExactPinAfterQuoteAccepted=${job.requiresExactPinAfterQuoteAccepted} requestExactPin=${job.requestExactPin} exactPinSaved=${job.exactPinSaved}',
      );
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

  Future<void> mergeQuoteFields({
    required String quoteId,
    required Map<String, dynamic> fields,
    String source = 'van_mate.public_quote',
  }) async {
    final normalizedQuoteId = quoteId.trim();
    if (normalizedQuoteId.isEmpty || fields.isEmpty) {
      logVanFirebaseSkip(
        reason: 'public quote merge skipped',
        extra: 'source=$source docId=$normalizedQuoteId',
      );
      return;
    }

    final sanitizedFields = sanitizeVanFirestoreMap(fields);
    final collectionPath = 'public_quote_responses';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: normalizedQuoteId,
      uid: '(public)',
      source: source,
    );
    try {
      await _publicQuotes()
          .doc(normalizedQuoteId)
          .set(sanitizedFields, SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: normalizedQuoteId,
        uid: '(public)',
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: normalizedQuoteId,
        uid: '(public)',
        error: error,
        source: source,
      );
      rethrow;
    }
  }

  Future<VanPublicQuoteDeleteResult> deleteAllQuotesForOwner({
    required String ownerUid,
    String source = 'van_mate.debug_clear_saved_jobs',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const VanPublicQuoteDeleteResult();
    }

    final quoteSnapshot = await _publicQuotes()
        .where(Filter('ownerUid', isEqualTo: normalizedOwnerUid))
        .get(const GetOptions(source: Source.server));
    final tokenSnapshot = await _publicQuoteTokens()
        .where(Filter('ownerUid', isEqualTo: normalizedOwnerUid))
        .get(const GetOptions(source: Source.server));

    var deletedQuotes = 0;
    var deletedTokens = 0;
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

    for (final doc in quoteSnapshot.docs) {
      batch.delete(doc.reference);
      batchWrites += 1;
      deletedQuotes += 1;
      await commitIfFull();
    }
    for (final doc in tokenSnapshot.docs) {
      batch.delete(doc.reference);
      batchWrites += 1;
      deletedTokens += 1;
      await commitIfFull();
    }
    if (batchWrites > 0) {
      await batch.commit();
    }
    if (kDebugMode) {
      debugPrint(
        '[VanPublicQuoteCloud][deleteAllQuotesForOwner] path=public_quote_responses deleted=$deletedQuotes tokenPath=public_quote_response_tokens tokensDeleted=$deletedTokens source=$source',
      );
    }
    return VanPublicQuoteDeleteResult(
      deletedQuotes: deletedQuotes,
      deletedTokens: deletedTokens,
    );
  }
}
