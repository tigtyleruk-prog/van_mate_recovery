import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../pages/driver_customer_reply_mock_page.dart';
import 'van_firestore_payload_builder.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanQuotesCloudService {
  VanQuotesCloudService._({
    FirebaseFirestore? firestore,
    VanFirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? VanFirebaseAuthService.instance;

  static final VanQuotesCloudService instance = VanQuotesCloudService._();

  final FirebaseFirestore _firestore;
  final VanFirebaseAuthService _authService;

  CollectionReference<Map<String, dynamic>> _quotes(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('van_quotes');
  }

  bool _hasQuoteState(DriverCustomerReplyMockData job) {
    return job.quoteAmount != null ||
        job.quoteSavedAt != null ||
        job.quoteSentAt != null ||
        job.isQuoteSent ||
        job.isConfirmed;
  }

  Future<List<DriverCustomerReplyMockData>> loadQuotes({
    required String ownerUid,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const <DriverCustomerReplyMockData>[];
    }

    if (kDebugMode) {
      debugPrint(
        '[VanQuotesCloud] load start uid=$normalizedOwnerUid path=users/$normalizedOwnerUid/van_quotes',
      );
    }
    final snapshot = await _quotes(normalizedOwnerUid).get();
    if (kDebugMode) {
      final fetchedIds = snapshot.docs.map((doc) => doc.id).join(', ');
      debugPrint(
        '[VanQuotesCloud] fetched ${snapshot.docs.length} quote docs uid=$normalizedOwnerUid ids=${fetchedIds.isEmpty ? '(none)' : fetchedIds}',
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
      try {
        final quote = DriverCustomerReplyMockData.fromJson(normalized);
        if (quote.isHiddenFromNormalLists) {
          hiddenCount += 1;
          if (kDebugMode) {
            debugPrint(
              '[VanQuotesCloud] hidden quote ${doc.id}: deleted=${quote.deleted} archived=${quote.archived}',
            );
          }
        }
        quotes.add(quote);
      } catch (error) {
        debugPrint('[VanQuotesCloud] skip quote ${doc.id}: $error');
      }
    }
    quotes.sort((a, b) {
      final aUpdated =
          a.quoteSentAt ??
          a.quoteSavedAt ??
          a.updatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bUpdated =
          b.quoteSentAt ??
          b.quoteSavedAt ??
          b.updatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bUpdated.compareTo(aUpdated);
    });
    if (kDebugMode) {
      final visibleCount = quotes
          .where((job) => !job.isHiddenFromNormalLists)
          .length;
      debugPrint(
        '[VanQuotesCloud] showing $visibleCount quotes uid=$normalizedOwnerUid hidden=$hiddenCount totalLoaded=${quotes.length}',
      );
    }
    return quotes;
  }

  Future<void> saveQuote({
    required String ownerUid,
    required DriverCustomerReplyMockData job,
    String source = 'van_mate',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedJobId = job.jobId.trim();
    if (normalizedOwnerUid.isEmpty || normalizedJobId.isEmpty) {
      logVanFirebaseSkip(
        reason: 'quote save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid docId=$normalizedJobId',
      );
      return;
    }

    if (!_hasQuoteState(job)) {
      logVanFirebaseSkip(
        reason: 'quote save skipped',
        extra:
            'source=$source uid=$normalizedOwnerUid docId=$normalizedJobId reason=no_quote_state',
      );
      return;
    }

    final payload = buildVanCloudDocPayload(
      id: normalizedJobId,
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: job.createdAt ?? job.quoteSavedAt ?? DateTime.now(),
      updatedAt: job.updatedAt ?? DateTime.now(),
      data: job.toJson(),
    );
    final collectionPath = 'users/$normalizedOwnerUid/van_quotes';
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
      await _quotes(
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

  Future<void> saveQuotes({
    required String ownerUid,
    required List<DriverCustomerReplyMockData> jobs,
    String source = 'van_mate',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty || jobs.isEmpty) {
      logVanFirebaseSkip(
        reason: 'quote batch save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid jobs=${jobs.length}',
      );
      return;
    }

    final batch = _firestore.batch();
    final collection = _quotes(normalizedOwnerUid);
    final collectionPath = 'users/$normalizedOwnerUid/van_quotes';
    final docIds = <String>[];
    var writes = 0;
    for (final job in jobs) {
      if (!_hasQuoteState(job)) {
        continue;
      }
      final normalizedJobId = job.jobId.trim();
      if (normalizedJobId.isEmpty) {
        continue;
      }

      final payload = buildVanCloudDocPayload(
        id: normalizedJobId,
        ownerUid: normalizedOwnerUid,
        source: source,
        createdAt: job.createdAt ?? job.quoteSavedAt ?? DateTime.now(),
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
      writes++;
      docIds.add(normalizedJobId);
    }

    if (writes == 0) {
      logVanFirebaseSkip(
        reason: 'quote batch save empty',
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

  Future<String?> ensureCurrentOwnerUid({String source = 'van_mate'}) async {
    return _authService.ensureCurrentUid(source: source);
  }
}
