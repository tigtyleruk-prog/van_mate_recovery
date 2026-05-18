import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/van_community_place.dart';
import '../models/van_place.dart';
import 'van_storage_service.dart';

class VanCommunityPlacesService {
  VanCommunityPlacesService._();

  static final VanCommunityPlacesService instance =
      VanCommunityPlacesService._();

  static const String approvedCollectionName = 'van_community_places';
  static const String reportsCollectionName = 'van_community_place_reports';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VanStorageService _storage = VanStorageService();

  String get currentUserId => _auth.currentUser?.uid.trim() ?? '';

  Stream<List<VanCommunityPlace>> watchApprovedPlaces() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<List<VanCommunityPlace>>.value(
          const <VanCommunityPlace>[],
        );
      }

      return _firestore
          .collection(approvedCollectionName)
          .where('status', isEqualTo: 'approved')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(VanCommunityPlace.fromFirestore)
                .where((place) => place.hasExactPin)
                .toList(growable: false),
          );
    });
  }

  Future<VanPlace> saveToMyDrops(VanCommunityPlace place) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw StateError('Van Mate needs a signed-in account to save a drop.');
    }

    if (!place.hasExactPin) {
      throw StateError('This community pin does not have an exact location.');
    }

    final now = DateTime.now();
    final privatePlace = VanPlace(
      id: _storage.createPlaceId(),
      ownerId: uid,
      name: place.placeName.trim().isEmpty ? 'Community drop' : place.placeName,
      address: place.postcodeArea.trim(),
      postcodeArea: place.postcodeArea.trim(),
      deliveryNote: place.deliveryNote.trim(),
      warningNote: place.warningNote.trim(),
      privateInfo: place.accessNote.trim(),
      placeType: place.placeType,
      latitude: place.exactLat,
      longitude: place.exactLng,
      trustedExactPin: true,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
    );

    await _storage.savePlace(privatePlace, checkForDuplicate: false);
    debugPrint(
      '[CommunityMap] saved to my drops placeId=${privatePlace.id} sourcePlaceId=${place.sourcePlaceId}',
    );
    return privatePlace;
  }

  Future<void> reportPlace(VanCommunityPlace place) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw StateError('Van Mate needs a signed-in account to report a pin.');
    }

    final now = DateTime.now();
    final reportId = '${uid}_${place.id}';
    final payload = <String, dynamic>{
      'reportedBy': uid,
      'reportedAt': Timestamp.fromDate(now),
      'communityPlaceId': place.id,
      'sourcePlaceId': place.sourcePlaceId,
      'placeName': place.placeName,
      'dropType': place.dropType,
      'postcodeArea': place.postcodeArea,
      'exactLat': place.exactLat,
      'exactLng': place.exactLng,
      'status': 'open',
      'reason': 'map_review',
    };

    await _firestore
        .collection(reportsCollectionName)
        .doc(reportId)
        .set(payload, SetOptions(merge: false));

    debugPrint(
      '[CommunityMap] report submitted placeId=${place.id} sourcePlaceId=${place.sourcePlaceId}',
    );
  }
}
