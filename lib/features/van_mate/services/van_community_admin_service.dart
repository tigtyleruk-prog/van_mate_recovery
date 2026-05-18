import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/van_community_review_models.dart';

class VanCommunityAdminService {
  static const String adminsCollectionName = 'admins';
  static const String pendingCollectionName = 'van_community_places_pending';
  static const String approvedCollectionName = 'van_community_places';

  VanCommunityAdminService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final VanCommunityAdminService instance = VanCommunityAdminService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _auth.currentUser?.uid.trim() ?? '';

  CollectionReference<Map<String, dynamic>> get _admins =>
      _firestore.collection(adminsCollectionName);

  CollectionReference<Map<String, dynamic>> get _pending =>
      _firestore.collection(pendingCollectionName);

  CollectionReference<Map<String, dynamic>> get _approved =>
      _firestore.collection(approvedCollectionName);

  Stream<bool> watchIsAdmin(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return const Stream<bool>.empty();
    }

    return _admins.doc(normalizedUid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return false;
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final enabled = data['isAdmin'];
      if (enabled is bool) {
        return enabled;
      }

      final role = data['role']?.toString().trim().toLowerCase() ?? '';
      if (role.isNotEmpty) {
        return role == 'admin';
      }

      return true;
    });
  }

  Future<bool> isCurrentUserAdmin() async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      return false;
    }

    final snapshot = await _admins.doc(uid).get();
    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final enabled = data['isAdmin'];
    if (enabled is bool) {
      return enabled;
    }

    final role = data['role']?.toString().trim().toLowerCase() ?? '';
    if (role.isNotEmpty) {
      return role == 'admin';
    }

    return true;
  }

  Stream<List<VanCommunityReviewSubmission>> watchPendingSubmissions() {
    return _pending.snapshots().map((snapshot) {
      final submissions =
          snapshot.docs
              .map(VanCommunityReviewSubmission.fromFirestore)
              .where((submission) => submission.status == 'pending')
              .toList(growable: false)
            ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return submissions;
    });
  }

  Future<void> approveSubmission({
    required VanCommunityReviewSubmission submission,
    required VanCommunityReviewDraft draft,
  }) async {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw StateError('Van Mate needs an admin account before approving.');
    }

    final approvedRef = _approved.doc(submission.id);
    final pendingRef = _pending.doc(submission.id);

    // Private driver info must never be included in community approvals.
    final approvedPayload = <String, dynamic>{
      'approvedBy': uid,
      'approvedAt': FieldValue.serverTimestamp(),
      'sourcePendingId': submission.id,
      'sourcePlaceId': submission.sourcePlaceId,
      'placeName': draft.placeName.trim(),
      'dropName': draft.placeName.trim(),
      'dropType': draft.dropType.trim(),
      'postcodeArea': draft.postcodeArea.trim(),
      'exactLat': submission.exactLat,
      'exactLng': submission.exactLng,
      'deliveryNote': draft.deliveryNote.trim(),
      'warningNote': draft.warningNote.trim(),
      'accessNote': draft.accessNote.trim(),
      'status': 'approved',
      'verifyCount': 0,
      'reportCount': 0,
    };

    await _firestore.runTransaction((transaction) async {
      transaction.set(approvedRef, approvedPayload, SetOptions(merge: true));
      transaction.update(pendingRef, <String, dynamic>{
        'status': 'approved',
        'approvedBy': uid,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedCommunityPlaceId': approvedRef.id,
      });
    });
    await _firestore.waitForPendingWrites();
    debugPrint(
      '[CommunityReview] approved pendingId=${submission.id} sourcePlaceId=${submission.sourcePlaceId} approvedBy=$uid',
    );
  }

  Future<void> rejectSubmission({
    required VanCommunityReviewSubmission submission,
    String? rejectReason,
  }) async {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw StateError('Van Mate needs an admin account before rejecting.');
    }

    final pendingRef = _pending.doc(submission.id);
    final payload = <String, dynamic>{
      'status': 'rejected',
      'rejectedBy': uid,
      'rejectedAt': FieldValue.serverTimestamp(),
    };
    final trimmedReason = rejectReason?.trim() ?? '';
    if (trimmedReason.isNotEmpty) {
      payload['rejectReason'] = trimmedReason;
    }

    await pendingRef.update(payload);
    await _firestore.waitForPendingWrites();
    debugPrint(
      '[CommunityReview] rejected pendingId=${submission.id} sourcePlaceId=${submission.sourcePlaceId} rejectedBy=$uid',
    );
  }
}
