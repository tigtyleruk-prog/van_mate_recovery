import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/van_invoice_history_entry.dart';
import 'van_firestore_payload_builder.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanInvoicesCloudService {
  VanInvoicesCloudService._({
    FirebaseFirestore? firestore,
    VanFirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? VanFirebaseAuthService.instance;

  static final VanInvoicesCloudService instance = VanInvoicesCloudService._();

  final FirebaseFirestore _firestore;
  final VanFirebaseAuthService _authService;

  CollectionReference<Map<String, dynamic>> _invoices(String ownerUid) {
    return _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('van_invoices');
  }

  Future<List<VanInvoiceHistoryEntry>> loadInvoices({
    required String ownerUid,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return const <VanInvoiceHistoryEntry>[];
    }

    final snapshot = await _invoices(normalizedOwnerUid).get();
    final invoices = <VanInvoiceHistoryEntry>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final normalized = Map<String, dynamic>.from(data);
      if ((normalized['jobKey']?.toString().trim() ?? '').isEmpty) {
        normalized['jobKey'] = doc.id;
      }
      try {
        invoices.add(VanInvoiceHistoryEntry.fromJson(normalized));
      } catch (error) {
        debugPrint('[VanInvoicesCloud] skip invoice ${doc.id}: $error');
      }
    }
    invoices.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return invoices;
  }

  Future<void> saveInvoice({
    required String ownerUid,
    required VanInvoiceHistoryEntry invoice,
    String source = 'van_mate',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedJobKey = invoice.jobKey.trim();
    if (normalizedOwnerUid.isEmpty || normalizedJobKey.isEmpty) {
      logVanFirebaseSkip(
        reason: 'invoice save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid docId=$normalizedJobKey',
      );
      return;
    }

    final payload = buildVanCloudDocPayload(
      id: normalizedJobKey,
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: invoice.savedAt,
      updatedAt: invoice.savedAt,
      data: invoice.toJson(),
    );
    final collectionPath = 'users/$normalizedOwnerUid/van_invoices';
    logVanFirebaseWriteStart(
      collectionPath: collectionPath,
      docId: normalizedJobKey,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _invoices(normalizedOwnerUid).doc(normalizedJobKey).set(
        payload,
        SetOptions(merge: true),
      );
      logVanFirebaseWriteSuccess(
        collectionPath: collectionPath,
        docId: normalizedJobKey,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionPath,
        docId: normalizedJobKey,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }

  Future<void> saveInvoices({
    required String ownerUid,
    required List<VanInvoiceHistoryEntry> invoices,
    String source = 'van_mate',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty || invoices.isEmpty) {
      logVanFirebaseSkip(
        reason: 'invoice batch save skipped',
        extra: 'source=$source uid=$normalizedOwnerUid invoices=${invoices.length}',
      );
      return;
    }

    final batch = _firestore.batch();
    final collection = _invoices(normalizedOwnerUid);
    final collectionPath = 'users/$normalizedOwnerUid/van_invoices';
    final docIds = <String>[];
    for (final invoice in invoices) {
      final normalizedJobKey = invoice.jobKey.trim();
      if (normalizedJobKey.isEmpty) {
        continue;
      }

      final payload = buildVanCloudDocPayload(
        id: normalizedJobKey,
        ownerUid: normalizedOwnerUid,
        source: source,
        createdAt: invoice.savedAt,
        updatedAt: invoice.savedAt,
        data: invoice.toJson(),
      );
      logVanFirebaseWriteStart(
        collectionPath: collectionPath,
        docId: normalizedJobKey,
        uid: normalizedOwnerUid,
        source: source,
      );
      batch.set(collection.doc(normalizedJobKey), payload, SetOptions(merge: true));
      docIds.add(normalizedJobKey);
    }

    if (docIds.isEmpty) {
      logVanFirebaseSkip(
        reason: 'invoice batch save empty',
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
