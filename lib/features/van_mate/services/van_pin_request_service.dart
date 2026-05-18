import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../firebase_options.dart';
import '../models/van_pin_request.dart';
import '../models/van_place.dart';
import '../models/van_route_stop.dart';
import 'auth_service.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanPinRequestService {
  VanPinRequestService._({
    FirebaseFirestore? firestore,
    AuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? AuthService.instance;

  static final VanPinRequestService instance = VanPinRequestService._();
  static const String collectionName = 'van_pin_requests';
  static const Duration requestLifetime = Duration(hours: 48);

  final FirebaseFirestore _firestore;
  final AuthService _authService;

  static const String _placeholderHostingHost = 'van-mate.local';

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(collectionName);

  CollectionReference<Map<String, dynamic>> _privateRequests(String ownerId) {
    return _firestore
        .collection('users')
        .doc(ownerId.trim())
        .collection('van_pin_requests');
  }

  Future<void> _mirrorPrivateRequest({
    required String ownerId,
    required VanPinRequest request,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    if (normalizedOwnerId.isEmpty) {
      logVanFirebaseSkip(
        reason: 'pin request mirror skipped',
        extra: 'uid=$normalizedOwnerId requestId=${request.id}',
      );
      return;
    }

    final concretePath = 'users/$normalizedOwnerId/van_pin_requests';
    logVanFirebaseWriteStart(
      collectionPath: concretePath,
      docId: request.id,
      uid: normalizedOwnerId,
      source: 'van_mate.pin_request',
    );
    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerId,
        authType: 'anonymous',
        source: 'van_mate.pin_request',
      );
      await _privateRequests(normalizedOwnerId).doc(request.id).set(
        request.toFirestore(),
        SetOptions(merge: true),
      );
      logVanFirebaseWriteSuccess(
        collectionPath: concretePath,
        docId: request.id,
        uid: normalizedOwnerId,
        source: 'van_mate.pin_request',
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: concretePath,
        docId: request.id,
        uid: normalizedOwnerId,
        error: error,
        source: 'van_mate.pin_request',
      );
    }
  }

  bool get isHostingUrlConfigured {
    return DefaultFirebaseOptions.web.projectId.trim().isNotEmpty;
  }

  String buildRequestUrl(String requestId) {
    final projectId = DefaultFirebaseOptions.web.projectId.trim();
    final host = projectId.isEmpty
        ? _placeholderHostingHost
        : '$projectId.web.app';

    return Uri.https(host, '/pin_request.html', <String, String>{
      'id': requestId,
    }).toString();
  }

  Future<VanPinRequest?> createRequestForPlace(VanPlace place) async {
    return _createRequest(
      dropId: place.id,
      dropName: place.name,
      address: place.address,
      postcode: place.postcodeArea,
    );
  }

  Future<VanPinRequest?> createEmergencyRequest({
    required String phoneNumber,
    String? driverNote,
  }) async {
    await _authService.ensureSignedIn(source: 'van_mate.pin_request');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('Firebase auth currentUser is null after sign-in.');
    }
    final ownerId = currentUser.uid.trim();
    if (ownerId.isEmpty) {
      throw StateError('Firebase auth user uid is empty.');
    }

    final requestRef = _requests.doc();
    final now = DateTime.now();
    final request = VanPinRequest(
      id: requestRef.id,
      ownerId: ownerId,
      createdBy: ownerId,
      dropId: '',
      dropName: 'Unmatched pin request',
      address: '',
      postcode: '',
      phoneNumber: phoneNumber.trim(),
      requestType: 'emergency_number_only',
      status: VanPinRequestStatus.pending,
      createdAt: now,
      expiresAt: now.add(requestLifetime),
      requestUrl: buildRequestUrl(requestRef.id),
      responseLat: null,
      responseLng: null,
      responseAccuracy: null,
      responseAt: null,
      responseNote: '',
      driverNote: driverNote?.trim() ?? '',
      linkedDropId: '',
      usedAsExactPin: false,
      archived: false,
    );

    debugPrint('[PinRequest] Creating emergency number-only request');
    debugPrint('[PinRequest] current FirebaseAuth uid: ${currentUser.uid}');
    debugPrint('[PinRequest] ownerId being written: $ownerId');
    debugPrint('[PinRequest] document path: ${requestRef.path}');
    debugPrint('[PinRequest] requestType: ${request.requestType}');
    debugPrint('[PinRequest] phoneNumber: ${request.phoneNumber}');
    debugPrint('[PinRequest] driverNote: ${request.driverNote}');
    debugPrint('[PinRequest] fields: ${request.toFirestore()}');

    logVanFirebaseWriteStart(
      collectionPath: collectionName,
      docId: requestRef.id,
      uid: ownerId,
      source: 'van_mate.pin_request',
    );
    try {
      await requestRef.set(request.toFirestore());
      logVanFirebaseWriteSuccess(
        collectionPath: collectionName,
        docId: requestRef.id,
        uid: ownerId,
        source: 'van_mate.pin_request',
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionName,
        docId: requestRef.id,
        uid: ownerId,
        error: error,
        source: 'van_mate.pin_request',
      );
      rethrow;
    }
    await _mirrorPrivateRequest(ownerId: ownerId, request: request);
    debugPrint('[PinRequest] requestUrl: ${request.requestUrl}');
    return request;
  }

  Future<VanPinRequest?> createOrReuseRequestForPlace(VanPlace place) async {
    return _createOrReuseRequest(
      dropId: place.id,
      dropName: place.name,
      address: place.address,
      postcode: place.postcodeArea,
    );
  }

  Future<VanPinRequest?> createRequestForStop(VanRouteStop stop) async {
    return _createRequest(
      dropId: stop.placeId,
      dropName: stop.name,
      address: stop.address,
      postcode: stop.postcodeArea,
    );
  }

  Future<VanPinRequest?> createOrReuseRequestForStop(VanRouteStop stop) async {
    return _createOrReuseRequest(
      dropId: stop.placeId,
      dropName: stop.name,
      address: stop.address,
      postcode: stop.postcodeArea,
    );
  }

  Future<VanPinRequest?> getLatestRequestForDropId(
    String dropId, {
    String? ownerId,
  }) async {
    final requests = await _fetchRequestsForDropId(dropId, ownerId: ownerId);
    return _latestRequestFromList(requests);
  }

  Future<VanPinRequest?> getLatestExactPinRequestForDropId(
    String dropId, {
    String? ownerId,
  }) {
    return getLatestRequestForDropId(dropId, ownerId: ownerId);
  }

  Stream<VanPinRequest?> watchLatestRequestForDropId(
    String dropId, {
    String? ownerId,
  }) {
    final normalizedDropId = dropId.trim();
    final normalizedOwnerId = (ownerId ?? _authService.currentUid ?? '').trim();
    if (normalizedDropId.isEmpty || normalizedOwnerId.isEmpty) {
      return const Stream<VanPinRequest?>.empty();
    }

    debugPrint(
      '[PinRequest] watchLatestRequestForDropId dropId=$normalizedDropId ownerId=$normalizedOwnerId',
    );

    return _requests
        .where(Filter('ownerId', isEqualTo: normalizedOwnerId))
        .where(Filter('dropId', isEqualTo: normalizedDropId))
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(VanPinRequest.fromFirestore)
              .toList(growable: false);
          final latestRequest = _latestRequestFromList(requests);
          debugPrint(
            '[PinRequest] matching request count for drop $normalizedDropId: ${requests.length}',
          );
          if (latestRequest == null) {
            debugPrint(
              '[PinRequest] no request found for drop $normalizedDropId ownerId=$normalizedOwnerId',
            );
          } else {
            debugPrint(
              '[PinRequest] latest request for drop $normalizedDropId: ${latestRequest.id} status=${latestRequest.status} responseLat=${latestRequest.responseLat != null} responseLng=${latestRequest.responseLng != null}',
            );
          }
          return latestRequest;
        });
  }

  Stream<VanPinRequest?> watchLatestExactPinRequestForDropId(
    String dropId, {
    String? ownerId,
  }) {
    return watchLatestRequestForDropId(dropId, ownerId: ownerId);
  }

  Future<VanPinRequest?> getRequestById(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }

    final snapshot = await _requests.doc(normalizedId).get();
    if (!snapshot.exists) {
      return null;
    }

    return VanPinRequest.fromFirestore(snapshot);
  }

  Future<VanPinRequest?> _createRequest({
    required String dropId,
    required String dropName,
    required String address,
    required String postcode,
  }) async {
    await _authService.ensureSignedIn(source: 'van_mate.pin_request');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('Firebase auth currentUser is null after sign-in.');
    }
    final ownerId = currentUser.uid.trim();
    if (ownerId.isEmpty) {
      throw StateError('Firebase auth user uid is empty.');
    }

    final requestRef = _requests.doc();
    final now = DateTime.now();
    final request = VanPinRequest(
      id: requestRef.id,
      ownerId: ownerId,
      createdBy: ownerId,
      dropId: dropId.trim(),
      dropName: dropName.trim(),
      address: address.trim(),
      postcode: postcode.trim(),
      status: VanPinRequestStatus.pending,
      createdAt: now,
      expiresAt: now.add(requestLifetime),
      requestUrl: buildRequestUrl(requestRef.id),
      responseLat: null,
      responseLng: null,
      responseAccuracy: null,
      responseAt: null,
      responseNote: '',
      usedAsExactPin: false,
    );

    debugPrint('[PinRequest] Creating fresh exact pin request');
    debugPrint('[PinRequest] current FirebaseAuth uid: ${currentUser.uid}');
    debugPrint('[PinRequest] ownerId being written: $ownerId');
    debugPrint('[PinRequest] document path: ${requestRef.path}');
    debugPrint('[PinRequest] status: ${request.status}');
    debugPrint('[PinRequest] dropId: ${request.dropId}');
    debugPrint('[PinRequest] dropName: ${request.dropName}');
    debugPrint('[PinRequest] address: ${request.address}');
    debugPrint('[PinRequest] postcode: ${request.postcode}');
    debugPrint('[PinRequest] fields: ${request.toFirestore()}');

    logVanFirebaseWriteStart(
      collectionPath: collectionName,
      docId: requestRef.id,
      uid: ownerId,
      source: 'van_mate.pin_request',
    );
    try {
      await requestRef.set(request.toFirestore());
      logVanFirebaseWriteSuccess(
        collectionPath: collectionName,
        docId: requestRef.id,
        uid: ownerId,
        source: 'van_mate.pin_request',
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: collectionName,
        docId: requestRef.id,
        uid: ownerId,
        error: error,
        source: 'van_mate.pin_request',
      );
      rethrow;
    }
    await _mirrorPrivateRequest(ownerId: ownerId, request: request);
    debugPrint('[PinRequest] requestUrl: ${request.requestUrl}');
    return request;
  }

  Future<VanPinRequest?> _createOrReuseRequest({
    required String dropId,
    required String dropName,
    required String address,
    required String postcode,
  }) async {
    final currentUid = _authService.currentUid?.trim();
    if (currentUid == null || currentUid.isEmpty) {
      return null;
    }

    debugPrint(
      '[PinRequest] lookup query: collection=$collectionName ownerId=$currentUid dropId=${dropId.trim()}',
    );

    final latestRequest = await getLatestRequestForDropId(
      dropId,
      ownerId: currentUid,
    );
    if (latestRequest != null &&
        latestRequest.ownerId == currentUid &&
        latestRequest.status == VanPinRequestStatus.pending &&
        !latestRequest.isExpired) {
      return latestRequest;
    }

    return _createRequest(
      dropId: dropId,
      dropName: dropName,
      address: address,
      postcode: postcode,
    );
  }

  Future<void> markUsedAsExactPin(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final request = await getRequestById(normalizedId);
    final ownerId = request?.ownerId.trim() ?? '';
    final update = <String, dynamic>{
      'usedAsExactPin': true,
    };
    logVanFirebaseWriteStart(
      collectionPath: collectionName,
      docId: normalizedId,
      uid: ownerId.isEmpty ? 'unknown' : ownerId,
      source: 'van_mate.pin_request',
    );
    await _requests.doc(normalizedId).set(update, SetOptions(merge: true));
    logVanFirebaseWriteSuccess(
      collectionPath: collectionName,
      docId: normalizedId,
      uid: ownerId.isEmpty ? 'unknown' : ownerId,
      source: 'van_mate.pin_request',
    );
    if (ownerId.isNotEmpty && request != null) {
      await _mirrorPrivateRequest(
        ownerId: ownerId,
        request: request.copyWith(usedAsExactPin: true),
      );
    }
  }

  Future<void> archiveRequest(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final request = await getRequestById(normalizedId);
    final ownerId = request?.ownerId.trim() ?? '';
    final update = <String, dynamic>{
      'archived': true,
    };
    logVanFirebaseWriteStart(
      collectionPath: collectionName,
      docId: normalizedId,
      uid: ownerId.isEmpty ? 'unknown' : ownerId,
      source: 'van_mate.pin_request',
    );
    await _requests.doc(normalizedId).set(update, SetOptions(merge: true));
    logVanFirebaseWriteSuccess(
      collectionPath: collectionName,
      docId: normalizedId,
      uid: ownerId.isEmpty ? 'unknown' : ownerId,
      source: 'van_mate.pin_request',
    );
    if (ownerId.isNotEmpty && request != null) {
      await _mirrorPrivateRequest(
        ownerId: ownerId,
        request: request.copyWith(archived: true),
      );
    }
  }

  Future<void> markEmergencyRequestLinkedToDrop(
    String requestId, {
    required String linkedDropId,
  }) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final request = await getRequestById(normalizedId);
    final ownerId = request?.ownerId.trim() ?? '';
    final update = <String, dynamic>{
      'linkedDropId': linkedDropId.trim(),
      'usedAsExactPin': true,
      'archived': true,
    };
    logVanFirebaseWriteStart(
      collectionPath: collectionName,
      docId: normalizedId,
      uid: ownerId.isEmpty ? 'unknown' : ownerId,
      source: 'van_mate.pin_request',
    );
    await _requests.doc(normalizedId).set(update, SetOptions(merge: true));
    logVanFirebaseWriteSuccess(
      collectionPath: collectionName,
      docId: normalizedId,
      uid: ownerId.isEmpty ? 'unknown' : ownerId,
      source: 'van_mate.pin_request',
    );
    if (ownerId.isNotEmpty && request != null) {
      await _mirrorPrivateRequest(
        ownerId: ownerId,
        request: request.copyWith(
          linkedDropId: linkedDropId.trim(),
          usedAsExactPin: true,
          archived: true,
        ),
      );
    }
  }

  Stream<List<VanPinRequest>> watchEmergencyUnmatchedRequests({
    String? ownerId,
  }) {
    final normalizedOwnerId = (ownerId ?? _authService.currentUid ?? '').trim();
    if (normalizedOwnerId.isEmpty) {
      return const Stream<List<VanPinRequest>>.empty();
    }

    debugPrint(
      '[PinRequest] current FirebaseAuth uid for emergency unmatched stream: $normalizedOwnerId',
    );
    debugPrint(
      '[PinRequest] emergency unmatched request query started collection=$collectionName ownerId=$normalizedOwnerId',
    );

    return _requests
        .where(Filter('ownerId', isEqualTo: normalizedOwnerId))
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(VanPinRequest.fromFirestore)
              .where((request) {
                final isEmergencyType =
                    request.requestType == 'emergency_number_only';
                final isUnmatched = request.dropId.trim().isEmpty;
                final isRelevantStatus =
                    request.status == VanPinRequestStatus.received ||
                    request.status == VanPinRequestStatus.receivedNote;
                return isEmergencyType &&
                    isUnmatched &&
                    isRelevantStatus &&
                    !request.archived &&
                    !request.usedAsExactPin;
              })
              .toList(growable: false)
            ..sort(_compareRequestsByFreshness);

          debugPrint(
            '[PinRequest] unmatched emergency received count=${requests.length} ownerId=$normalizedOwnerId',
          );
          for (final request in requests) {
            debugPrint(
              '[PinRequest] unmatched emergency request id=${request.id} status=${request.status} responseLat=${request.responseLat} responseLng=${request.responseLng} archived=${request.archived} usedAsExactPin=${request.usedAsExactPin}',
            );
          }

          return requests;
        });
  }

  Future<List<VanPinRequest>> _fetchRequestsForDropId(
    String dropId, {
    String? ownerId,
  }) async {
    final normalizedDropId = dropId.trim();
    final normalizedOwnerId = (ownerId ?? _authService.currentUid ?? '').trim();
    if (normalizedDropId.isEmpty || normalizedOwnerId.isEmpty) {
      return const <VanPinRequest>[];
    }

    final snapshot = await _requests
        .where(Filter('ownerId', isEqualTo: normalizedOwnerId))
        .where(Filter('dropId', isEqualTo: normalizedDropId))
        .get();

    return snapshot.docs
        .map(VanPinRequest.fromFirestore)
        .toList(growable: false);
  }

  Stream<VanPinRequest?> watchLatestEmergencyUnmatchedRequest({
    String? ownerId,
  }) {
    return watchEmergencyUnmatchedRequests(ownerId: ownerId).map(
      _latestRequestFromList,
    );
  }

  VanPinRequest? _latestRequestFromList(List<VanPinRequest> requests) {
    if (requests.isEmpty) {
      return null;
    }

    final sortedRequests = List<VanPinRequest>.from(requests)
      ..sort(_compareRequestsByFreshness);
    return sortedRequests.first;
  }

  int _compareRequestsByFreshness(VanPinRequest a, VanPinRequest b) {
    final aFreshness = a.responseAt ?? a.createdAt;
    final bFreshness = b.responseAt ?? b.createdAt;
    final freshnessComparison = bFreshness.compareTo(aFreshness);
    if (freshnessComparison != 0) {
      return freshnessComparison;
    }

    return b.createdAt.compareTo(a.createdAt);
  }
}
