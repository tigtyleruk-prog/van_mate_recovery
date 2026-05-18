import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../helpers/van_note_utils.dart';
import '../models/van_community_place_submission.dart';
import '../models/van_place.dart';

enum VanCommunityShareOutcome {
  shared,
  duplicate,
  missingExactPin,
  notSignedIn,
  failed,
}

class VanCommunityShareResult {
  final VanCommunityShareOutcome outcome;
  final String message;

  const VanCommunityShareResult._({
    required this.outcome,
    required this.message,
  });

  const VanCommunityShareResult.shared(String message)
    : this._(outcome: VanCommunityShareOutcome.shared, message: message);

  const VanCommunityShareResult.duplicate(String message)
    : this._(outcome: VanCommunityShareOutcome.duplicate, message: message);

  const VanCommunityShareResult.missingExactPin(String message)
    : this._(
        outcome: VanCommunityShareOutcome.missingExactPin,
        message: message,
      );

  const VanCommunityShareResult.notSignedIn(String message)
    : this._(outcome: VanCommunityShareOutcome.notSignedIn, message: message);

  const VanCommunityShareResult.failed(String message)
    : this._(outcome: VanCommunityShareOutcome.failed, message: message);

  bool get didShare => outcome == VanCommunityShareOutcome.shared;
}

class VanCommunityShareService {
  static const String pendingCollectionName = 'van_community_places_pending';

  VanCommunityShareService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _pendingCollection =>
      _firestore.collection(pendingCollectionName);

  Future<VanCommunityShareResult> shareEntranceInfo(VanPlace place) async {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      return const VanCommunityShareResult.notSignedIn(
        'Van Mate needs a signed-in account before sharing.',
      );
    }

    if (!place.hasTrustedExactPin || !place.hasCoordinates) {
      return const VanCommunityShareResult.missingExactPin(
        'Add an exact entrance pin before sharing.',
      );
    }

    final sourcePlaceId = place.id.trim();
    if (sourcePlaceId.isEmpty) {
      return const VanCommunityShareResult.failed(
        'That saved drop could not be shared right now.',
      );
    }

    final submissionId = '${uid}_$sourcePlaceId';
    final docRef = _pendingCollection.doc(submissionId);

    final deliveryNote =
        cleanVanNoteText(place.deliveryNote, postcode: place.postcodeArea) ??
        '';
    final warningNote =
        cleanVanNoteText(place.warningNote, postcode: place.postcodeArea) ?? '';
    final submission = VanCommunityPlaceSubmission(
      submittedBy: uid,
      submittedAt: DateTime.now(),
      sourcePlaceId: sourcePlaceId,
      placeName: place.name.trim(),
      dropName: place.name.trim(),
      dropType: place.placeType.storageValue,
      postcodeArea: place.postcodeArea.trim(),
      exactLat: place.latitude!,
      exactLng: place.longitude!,
      deliveryNote: deliveryNote,
      warningNote: warningNote,
    );

    // OCR raw text and detected phone numbers must never be included in community share payloads.
    // Private driver info must never be included in community submissions.
    final payload = submission.toFirestore();
    payload['placeName'] = place.name.trim();
    payload.remove('privateInfo');
    payload.remove('privateNotes');
    payload['accessNote'] = '';

    try {
      await docRef.set(payload, SetOptions(merge: false));
      await _firestore.waitForPendingWrites();
      debugPrint(
        '[CommunityShare] submitted uid=$uid route=place sourcePlaceId=$sourcePlaceId status=pending',
      );
      return const VanCommunityShareResult.shared(
        'Shared for review. Thanks for helping other drivers.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[CommunityShare] share failed uid=$uid sourcePlaceId=$sourcePlaceId error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);

      return const VanCommunityShareResult.failed(
        'Could not send this drop for review right now.',
      );
    }
  }
}
