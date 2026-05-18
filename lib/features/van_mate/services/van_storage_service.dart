import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../helpers/duplicate_place_matcher.dart';
import '../models/van_place.dart';
import '../models/van_route.dart';
import '../models/van_route_template.dart';
import '../models/van_route_stop.dart';
import '../models/today_route_summary.dart';
import 'auth_service.dart';

class VanRoutePlanResult {
  final List<VanRouteStop> orderedStops;
  final int plannedStopCount;
  final int manualStopCount;

  const VanRoutePlanResult({
    required this.orderedStops,
    required this.plannedStopCount,
    required this.manualStopCount,
  });
}

enum VanSavePlaceResultType { saved, duplicateSuggested }

class VanSavePlaceResult {
  const VanSavePlaceResult._({
    required this.type,
    this.place,
    this.duplicatePlace,
    this.duplicateReason,
  });

  const VanSavePlaceResult.saved(VanPlace place)
    : this._(type: VanSavePlaceResultType.saved, place: place);

  const VanSavePlaceResult.duplicateSuggested(
    VanPlace duplicatePlace, {
    String? reason,
  }) : this._(
         type: VanSavePlaceResultType.duplicateSuggested,
         duplicatePlace: duplicatePlace,
         duplicateReason: reason,
       );

  final VanSavePlaceResultType type;
  final VanPlace? place;
  final VanPlace? duplicatePlace;
  final String? duplicateReason;

  bool get didSave => type == VanSavePlaceResultType.saved && place != null;
}

class VanRouteStopLimitExceeded implements Exception {
  final int stopCount;
  final int stopLimit;

  const VanRouteStopLimitExceeded({
    required this.stopCount,
    required this.stopLimit,
  });
}

class VanStorageService {
  static const String vanPlacesCollection = 'van_places';
  static const String vanRoutesCollection = 'van_routes';
  static const String vanRouteTemplatesCollection = 'van_route_templates';
  static const int _exactRoutePlanningStopLimit = 8;

  VanStorageService({
    FirebaseFirestore? firestore,
    AuthService? authService,
    DuplicatePlaceMatcher? duplicatePlaceMatcher,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? AuthService.instance,
       _duplicatePlaceMatcher =
           duplicatePlaceMatcher ?? const DuplicatePlaceMatcher();

  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final DuplicatePlaceMatcher _duplicatePlaceMatcher;
  final math.Random _random = math.Random();

  CollectionReference<Map<String, dynamic>> get _places =>
      _firestore.collection(vanPlacesCollection);

  CollectionReference<Map<String, dynamic>> get _routes =>
      _firestore.collection(vanRoutesCollection);

  CollectionReference<Map<String, dynamic>> get _routeTemplates =>
      _firestore.collection(vanRouteTemplatesCollection);

  Future<String?> ensureCurrentUid({String source = 'van_mate'}) async {
    return _authService.ensureCurrentUid(source: source);
  }

  Stream<List<VanPlace>> watchPlaces({required String ownerId}) {
    final normalizedOwnerId = _normalizeOwnerId(ownerId);
    if (normalizedOwnerId == null) {
      return const Stream<List<VanPlace>>.empty();
    }

    debugPrint(
      '[PlacesLoad] watchPlaces collection=$vanPlacesCollection ownerId=$normalizedOwnerId',
    );

    return _ownedPlacesQuery(normalizedOwnerId).snapshots().map((snapshot) {
      final places = snapshot.docs
          .map(VanPlace.fromFirestore)
          .toList(growable: false);
      places.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return places;
    });
  }

  Stream<VanRoute?> watchActiveRouteForDate({
    required String ownerId,
    required String routeDate,
  }) {
    final normalizedOwnerId = _normalizeOwnerId(ownerId);
    if (normalizedOwnerId == null) {
      return const Stream<VanRoute?>.empty();
    }

    return _routes
        .doc(routeIdForDate(ownerId: normalizedOwnerId, routeDate: routeDate))
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }

          final route = VanRoute.fromFirestore(snapshot);
          return route.isActive ? route : null;
        });
  }

  Future<List<VanPlace>> getPlaces({required String ownerId}) async {
    final normalizedOwnerId = _normalizeOwnerId(ownerId);
    if (normalizedOwnerId == null) {
      return const <VanPlace>[];
    }

    debugPrint(
      '[PlacesLoad] getPlaces collection=$vanPlacesCollection ownerId=$normalizedOwnerId',
    );

    final snapshot = await _ownedPlacesQuery(normalizedOwnerId).get();
    final places = snapshot.docs
        .map(VanPlace.fromFirestore)
        .toList(growable: false);
    places.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return places;
  }

  Stream<List<VanRouteTemplate>> watchRouteTemplates({
    required String ownerId,
  }) {
    final normalizedOwnerId = _normalizeOwnerId(ownerId);
    if (normalizedOwnerId == null) {
      return const Stream<List<VanRouteTemplate>>.empty();
    }

    return _routeTemplates
        .where(Filter('ownerId', isEqualTo: normalizedOwnerId))
        .snapshots()
        .map((snapshot) {
          final templates = snapshot.docs
              .map(VanRouteTemplate.fromFirestore)
              .toList(growable: false);
          templates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return templates;
        });
  }

  Future<List<VanRouteTemplate>> getRouteTemplates({
    required String ownerId,
  }) async {
    final normalizedOwnerId = _normalizeOwnerId(ownerId);
    if (normalizedOwnerId == null) {
      return const <VanRouteTemplate>[];
    }

    final snapshot = await _routeTemplates
        .where(Filter('ownerId', isEqualTo: normalizedOwnerId))
        .get();
    final templates = snapshot.docs
        .map(VanRouteTemplate.fromFirestore)
        .toList(growable: false);
    templates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return templates;
  }

  Future<VanPlace?> findDuplicatePlace(
    VanPlace place, {
    String? excludePlaceId,
  }) async {
    final match = await findDuplicatePlaceMatch(
      place,
      excludePlaceId: excludePlaceId,
    );
    return match?.source;
  }

  Future<DuplicatePlaceMatch<VanPlace>?> findDuplicatePlaceMatch(
    VanPlace place, {
    String? excludePlaceId,
  }) async {
    final places = await getPlaces(ownerId: place.ownerId);
    return _duplicatePlaceMatcher.findDuplicate<VanPlace>(
      candidate: _duplicateRecordForPlace(place),
      existing: places.map(_duplicateRecordForPlace),
      excludeId: excludePlaceId ?? place.id,
    );
  }

  Future<VanSavePlaceResult> savePlace(
    VanPlace place, {
    bool checkForDuplicate = true,
    String? excludePlaceId,
  }) async {
    final normalizedOwnerId = _requireOwnerId(place.ownerId);
    final ownedPlace = place.copyWith(
      ownerId: normalizedOwnerId,
      createdBy: normalizedOwnerId,
    );

    try {
      if (checkForDuplicate) {
        try {
          final duplicateMatch = await findDuplicatePlaceMatch(
            ownedPlace,
            excludePlaceId: excludePlaceId,
          );
          if (duplicateMatch != null) {
            return VanSavePlaceResult.duplicateSuggested(
              duplicateMatch.source,
              reason: duplicateMatch.reason,
            );
          }
        } catch (_) {}
      }

      final payload = ownedPlace.toFirestore();
      payload['exactDropPinLabel'] = FieldValue.delete();
      await _places.doc(ownedPlace.id).set(payload, SetOptions(merge: true));
      await _firestore.waitForPendingWrites();
      return VanSavePlaceResult.saved(ownedPlace);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> deletePlace(VanPlace place) async {
    final normalizedId = place.id.trim();
    final normalizedOwnerId = _normalizeOwnerId(place.ownerId);
    if (normalizedId.isEmpty || normalizedOwnerId == null) {
      return;
    }

    final docRef = _places.doc(normalizedId);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        return;
      }

      final currentPlace = VanPlace.fromFirestore(snapshot);
      if (currentPlace.ownerId != normalizedOwnerId) {
        throw StateError('This drop does not belong to the current account.');
      }

      await docRef.delete();
    } catch (_) {
      rethrow;
    }
  }

  Future<VanRoute> saveActiveRoute({
    required String ownerId,
    required String routeDate,
    required String routeName,
    required int maxStopsAllowed,
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
    required List<VanRouteStop> stops,
  }) async {
    final normalizedOwnerId = _requireOwnerId(ownerId);
    final routeId = routeIdForDate(
      ownerId: normalizedOwnerId,
      routeDate: routeDate,
    );
    final routeRef = _routes.doc(routeId);
    VanRoute? existingRoute;
    try {
      final existingSnapshot = await routeRef.get();
      existingRoute = existingSnapshot.exists
          ? VanRoute.fromFirestore(existingSnapshot)
          : null;
    } catch (_) {}
    final now = DateTime.now();
    final normalizedStops = normalizeStops(stops);

    if (normalizedStops.length > maxStopsAllowed) {
      throw VanRouteStopLimitExceeded(
        stopCount: normalizedStops.length,
        stopLimit: maxStopsAllowed,
      );
    }

    final route = VanRoute(
      id: routeId,
      routeDate: routeDate,
      routeName: routeName.trim().isEmpty
          ? defaultRouteNameForDate(routeDate)
          : routeName.trim(),
      createdAt: existingRoute?.createdAt ?? now,
      updatedAt: now,
      ownerId: normalizedOwnerId,
      createdBy: normalizedOwnerId,
      isActive: true,
      startAnchor: startAnchor,
      endAnchor: endAnchor,
      stops: normalizedStops,
    );

    try {
      await routeRef.set(route.toFirestore(), SetOptions(merge: true));
      await _firestore.waitForPendingWrites();
      return route;
    } catch (_) {
      rethrow;
    }
  }

  Future<VanRouteTemplate> saveRouteTemplate({
    required String ownerId,
    required String templateName,
    required int maxStopsAllowed,
    required List<VanRouteStop> stops,
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
    String? templateId,
  }) async {
    final normalizedOwnerId = _requireOwnerId(ownerId);
    final normalizedStops = normalizeTemplateStops(stops);
    if (normalizedStops.length > maxStopsAllowed) {
      throw VanRouteStopLimitExceeded(
        stopCount: normalizedStops.length,
        stopLimit: maxStopsAllowed,
      );
    }

    final normalizedTemplateId = templateId?.trim() ?? '';
    final templateRef = normalizedTemplateId.isNotEmpty
        ? _routeTemplates.doc(normalizedTemplateId)
        : _routeTemplates.doc();
    VanRouteTemplate? existingTemplate;
    try {
      final existingSnapshot = await templateRef.get();
      existingTemplate = existingSnapshot.exists
          ? VanRouteTemplate.fromFirestore(existingSnapshot)
          : null;
    } catch (_) {}

    final now = DateTime.now();
    final template = VanRouteTemplate(
      id: templateRef.id,
      ownerId: normalizedOwnerId,
      createdBy: normalizedOwnerId,
      name: templateName.trim().isEmpty
          ? 'Route Template'
          : templateName.trim(),
      createdAt: existingTemplate?.createdAt ?? now,
      updatedAt: now,
      startAnchor: startAnchor,
      endAnchor: endAnchor,
      stops: normalizedStops,
    );

    await templateRef.set(template.toFirestore(), SetOptions(merge: true));
    await _firestore.waitForPendingWrites();
    return template;
  }

  Future<VanRouteTemplate> updateRouteTemplateName({
    required String ownerId,
    required String templateId,
    required String name,
  }) async {
    final normalizedOwnerId = _requireOwnerId(ownerId);
    final normalizedTemplateId = templateId.trim();
    if (normalizedTemplateId.isEmpty) {
      throw StateError('A route template id is required.');
    }

    final templateRef = _routeTemplates.doc(normalizedTemplateId);
    final snapshot = await templateRef.get();
    if (!snapshot.exists) {
      throw StateError('Route template could not be found anymore.');
    }

    final existingTemplate = VanRouteTemplate.fromFirestore(snapshot);
    if (existingTemplate.ownerId != normalizedOwnerId) {
      throw StateError('Route template ownership could not be verified.');
    }

    final updatedTemplate = existingTemplate.copyWith(
      name: name.trim().isEmpty ? existingTemplate.name : name.trim(),
      updatedAt: DateTime.now(),
    );
    await templateRef.set(
      updatedTemplate.toFirestore(),
      SetOptions(merge: true),
    );
    return updatedTemplate;
  }

  Future<void> deleteRouteTemplate({
    required String ownerId,
    required String templateId,
  }) async {
    final normalizedOwnerId = _requireOwnerId(ownerId);
    final normalizedTemplateId = templateId.trim();
    if (normalizedTemplateId.isEmpty) {
      return;
    }

    final templateRef = _routeTemplates.doc(normalizedTemplateId);
    final snapshot = await templateRef.get();
    if (!snapshot.exists) {
      return;
    }

    final existingTemplate = VanRouteTemplate.fromFirestore(snapshot);
    if (existingTemplate.ownerId != normalizedOwnerId) {
      throw StateError('Route template ownership could not be verified.');
    }

    await templateRef.delete();
  }

  Future<VanRoute> updateStopStatus({
    required String ownerId,
    required String routeDate,
    required String stopId,
    required VanRouteStopStatus status,
    String failureNote = '',
  }) async {
    final normalizedOwnerId = _requireOwnerId(ownerId);
    final routeRef = _routes.doc(
      routeIdForDate(ownerId: normalizedOwnerId, routeDate: routeDate),
    );
    final now = DateTime.now();

    try {
      final updatedRoute = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(routeRef);
        if (!snapshot.exists) {
          throw StateError('Van route could not be found anymore.');
        }

        final route = VanRoute.fromFirestore(snapshot);
        final nextStops = normalizeStops(
          route.stops
              .map((stop) {
                if (stop.id != stopId) {
                  return stop;
                }

                switch (status) {
                  case VanRouteStopStatus.queued:
                    return stop.copyWith(
                      status: status,
                      clearCompletedAt: true,
                      failureNote: '',
                    );
                  case VanRouteStopStatus.done:
                    return stop.copyWith(
                      status: status,
                      completedAt: now,
                      failureNote: '',
                    );
                  case VanRouteStopStatus.failed:
                    return stop.copyWith(
                      status: status,
                      completedAt: now,
                      failureNote: failureNote.trim(),
                    );
                }
              })
              .toList(growable: false),
        );

        final routeUpdate = route.copyWith(updatedAt: now, stops: nextStops);
        transaction.set(
          routeRef,
          routeUpdate.toFirestore(),
          SetOptions(merge: true),
        );
        return routeUpdate;
      });
      await _firestore.waitForPendingWrites();
      return updatedRoute;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updatePremiumRouteSummaryCache({
    required String ownerId,
    required String routeDate,
    required TodayRouteSummary summary,
  }) async {
    final normalizedOwnerId = _requireOwnerId(ownerId);
    final routeRef = _routes.doc(
      routeIdForDate(ownerId: normalizedOwnerId, routeDate: routeDate),
    );

    await routeRef.set(summary.toCacheMap(), SetOptions(merge: true));
    await _firestore.waitForPendingWrites();
  }

  String createPlaceId() => _places.doc().id;

  String createStopId([String prefix = 'van_stop']) {
    final random = _random.nextInt(999999).toString().padLeft(6, '0');
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$random';
  }

  String routeIdForDate({required String ownerId, required String routeDate}) {
    final safeOwnerId = ownerId.replaceAll('/', '_');
    return 'van_route_${safeOwnerId}_$routeDate';
  }

  String defaultRouteNameForDate(String routeDate) {
    return 'Van Route $routeDate';
  }

  static String routeDateFromDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static List<VanRouteStop> normalizeStops(List<VanRouteStop> stops) {
    return <VanRouteStop>[
      for (var index = 0; index < stops.length; index++)
        stops[index].copyWith(routeOrder: index),
    ];
  }

  static List<VanRouteStop> normalizeTemplateStops(List<VanRouteStop> stops) {
    return normalizeStops(
      stops
          .map(
            (stop) => stop.copyWith(
              status: VanRouteStopStatus.queued,
              clearCompletedAt: true,
              failureNote: '',
            ),
          )
          .toList(growable: false),
    );
  }

  VanRoutePlanResult autoPlanRoute(
    List<VanRouteStop> stops, {
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
  }) {
    if (stops.length < 2) {
      final normalized = normalizeStops(_dedupeStopsById(stops));
      return VanRoutePlanResult(
        orderedStops: normalized,
        plannedStopCount: normalized
            .where((stop) => stop.hasCoordinates)
            .length,
        manualStopCount: normalized
            .where((stop) => !stop.hasCoordinates)
            .length,
      );
    }

    final normalized = normalizeStops(_dedupeStopsById(stops));
    final plannedStops = normalized
        .where((stop) => stop.hasCoordinates)
        .toList(growable: true);
    final manualStops = normalized
        .where((stop) => !stop.hasCoordinates)
        .toList(growable: false);
    final manualStopCount = manualStops.length;

    if (plannedStops.length < 2) {
      return VanRoutePlanResult(
        orderedStops: normalized,
        plannedStopCount: plannedStops.length,
        manualStopCount: manualStopCount,
      );
    }

    final ordered = plannedStops.length <= _exactRoutePlanningStopLimit
        ? _planStopsExactly(
            plannedStops,
            startAnchor: startAnchor,
            endAnchor: endAnchor,
          )
        : _planStopsHeuristically(
            plannedStops,
            startAnchor: startAnchor,
            endAnchor: endAnchor,
          );

    return VanRoutePlanResult(
      orderedStops: normalizeStops(<VanRouteStop>[...ordered, ...manualStops]),
      plannedStopCount: ordered.length,
      manualStopCount: manualStopCount,
    );
  }

  static List<VanRouteStop> _dedupeStopsById(List<VanRouteStop> stops) {
    final seenIds = <String>{};
    return stops.where((stop) => seenIds.add(stop.id)).toList(growable: false);
  }

  List<VanRouteStop> _planStopsHeuristically(
    List<VanRouteStop> plannedStops, {
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
  }) {
    return _planStopsWithAnchors(
      plannedStops,
      startAnchor: startAnchor,
      endAnchor: endAnchor,
    );
  }

  List<VanRouteStop> _planStopsExactly(
    List<VanRouteStop> plannedStops, {
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
  }) {
    return _planStopsWithAnchors(
      plannedStops,
      startAnchor: startAnchor,
      endAnchor: endAnchor,
    );
  }

  List<VanRouteStop> _planStopsWithAnchors(
    List<VanRouteStop> plannedStops, {
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
  }) {
    if (startAnchor?.hasCoordinates == true &&
        endAnchor?.hasCoordinates == true) {
      return _planStopsAlongAnchorLine(
        plannedStops,
        startAnchor: startAnchor!,
        endAnchor: endAnchor!,
      );
    }

    return _planStopsNearestNeighbour(plannedStops, startAnchor: startAnchor);
  }

  List<VanRouteStop> _planStopsAlongAnchorLine(
    List<VanRouteStop> plannedStops, {
    required VanRouteAnchor startAnchor,
    required VanRouteAnchor endAnchor,
  }) {
    if (plannedStops.length < 2) {
      return List<VanRouteStop>.from(plannedStops, growable: false);
    }

    final startPoint = _RouteAnchorPoint(
      startAnchor.latitude!,
      startAnchor.longitude!,
    );
    final endPoint = _RouteAnchorPoint(
      endAnchor.latitude!,
      endAnchor.longitude!,
    );
    final lineDx = endPoint.latitude - startPoint.latitude;
    final lineDy = endPoint.longitude - startPoint.longitude;
    final lineLengthSq = (lineDx * lineDx) + (lineDy * lineDy);

    if (lineLengthSq <= 0.0000001) {
      return _planStopsNearestNeighbour(plannedStops, startAnchor: startAnchor);
    }

    final sortedStops = List<VanRouteStop>.from(plannedStops, growable: false)
      ..sort((a, b) {
        final aScore = _anchorLineProjectionScore(
          startPoint: startPoint,
          lineDx: lineDx,
          lineDy: lineDy,
          lineLengthSq: lineLengthSq,
          stop: a,
        );
        final bScore = _anchorLineProjectionScore(
          startPoint: startPoint,
          lineDx: lineDx,
          lineDy: lineDy,
          lineLengthSq: lineLengthSq,
          stop: b,
        );

        final scoreCompare = aScore.projection.compareTo(bScore.projection);
        if (scoreCompare != 0) {
          return scoreCompare;
        }

        final distanceCompare = aScore.perpendicularDistanceSquared.compareTo(
          bScore.perpendicularDistanceSquared,
        );
        if (distanceCompare != 0) {
          return distanceCompare;
        }

        return a.routeOrder.compareTo(b.routeOrder);
      });

    return normalizeStops(sortedStops);
  }

  List<VanRouteStop> _planStopsNearestNeighbour(
    List<VanRouteStop> plannedStops, {
    VanRouteAnchor? startAnchor,
  }) {
    if (plannedStops.length < 2) {
      return List<VanRouteStop>.from(plannedStops, growable: false);
    }

    final remainingStops = List<VanRouteStop>.from(
      plannedStops,
      growable: true,
    );
    final orderedStops = <VanRouteStop>[];
    final visitedStopIds = <String>{};
    var currentPoint = _anchorPointFromRouteAnchor(startAnchor);

    if (currentPoint == null && remainingStops.isNotEmpty) {
      final firstStop = remainingStops.removeAt(0);
      if (visitedStopIds.add(firstStop.id)) {
        orderedStops.add(firstStop);
      }
      currentPoint = _anchorPointFromRouteStop(firstStop);
    }

    while (remainingStops.isNotEmpty) {
      var nearestIndex = -1;
      var nearestDistance = double.infinity;

      for (var index = 0; index < remainingStops.length; index++) {
        final candidate = remainingStops[index];
        if (visitedStopIds.contains(candidate.id)) {
          continue;
        }

        final candidatePoint = _anchorPointFromRouteStop(candidate);
        final distance = currentPoint == null
            ? 0.0
            : _anchorSquaredDistance(currentPoint, candidatePoint);
        final isCloser = distance < nearestDistance;
        final isStableTie =
            distance == nearestDistance &&
            nearestIndex >= 0 &&
            candidate.routeOrder < remainingStops[nearestIndex].routeOrder;
        if (nearestIndex < 0 || isCloser || isStableTie) {
          nearestDistance = distance;
          nearestIndex = index;
        }
      }

      if (nearestIndex < 0) {
        break;
      }

      final nextStop = remainingStops.removeAt(nearestIndex);
      if (!visitedStopIds.add(nextStop.id)) {
        continue;
      }

      orderedStops.add(nextStop);
      currentPoint = _anchorPointFromRouteStop(nextStop);
    }

    if (remainingStops.isNotEmpty) {
      for (final stop in remainingStops) {
        if (visitedStopIds.add(stop.id)) {
          orderedStops.add(stop);
        }
      }
    }

    return normalizeStops(orderedStops);
  }

  _AnchorLineScore _anchorLineProjectionScore({
    required _RouteAnchorPoint startPoint,
    required double lineDx,
    required double lineDy,
    required double lineLengthSq,
    required VanRouteStop stop,
  }) {
    final stopPoint = _anchorPointFromRouteStop(stop);
    final toStopDx = stopPoint.latitude - startPoint.latitude;
    final toStopDy = stopPoint.longitude - startPoint.longitude;
    final projection =
        ((toStopDx * lineDx) + (toStopDy * lineDy)) / lineLengthSq;
    final projectedLat = startPoint.latitude + (lineDx * projection);
    final projectedLng = startPoint.longitude + (lineDy * projection);
    final latDiff = stopPoint.latitude - projectedLat;
    final lngDiff = stopPoint.longitude - projectedLng;
    final perpendicularDistanceSquared =
        (latDiff * latDiff) + (lngDiff * lngDiff);

    return _AnchorLineScore(
      projection: projection,
      perpendicularDistanceSquared: perpendicularDistanceSquared,
    );
  }

  _RouteAnchorPoint? _anchorPointFromRouteAnchor(VanRouteAnchor? anchor) {
    if (anchor == null || !anchor.hasCoordinates) {
      return null;
    }

    return _RouteAnchorPoint(anchor.latitude!, anchor.longitude!);
  }

  _RouteAnchorPoint _anchorPointFromRouteStop(VanRouteStop stop) {
    return _RouteAnchorPoint(stop.latitude ?? 0, stop.longitude ?? 0);
  }

  double _anchorSquaredDistance(_RouteAnchorPoint a, _RouteAnchorPoint b) {
    final latDiff = a.latitude - b.latitude;
    final lngDiff = a.longitude - b.longitude;
    return (latDiff * latDiff) + (lngDiff * lngDiff);
  }

  DuplicatePlaceRecord<VanPlace> _duplicateRecordForPlace(VanPlace place) {
    return DuplicatePlaceRecord<VanPlace>(
      source: place,
      id: place.id,
      name: place.name,
      address: place.address,
      postcode: place.postcodeArea,
      typeKey: place.placeType.storageValue,
      typeFamily: _vanTypeFamily(place.placeType),
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }

  String _vanTypeFamily(VanPlaceType placeType) {
    switch (placeType) {
      case VanPlaceType.shop:
      case VanPlaceType.business:
      case VanPlaceType.office:
        return 'customer_site';
      case VanPlaceType.industrialUnit:
      case VanPlaceType.warehouse:
        return 'industrial_site';
      case VanPlaceType.other:
        return placeType.storageValue;
    }
  }

  Query<Map<String, dynamic>> _ownedPlacesQuery(String ownerId) {
    return _places.where(Filter('ownerId', isEqualTo: ownerId));
  }

  String? _normalizeOwnerId(String ownerId) {
    final normalized = ownerId.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _requireOwnerId(String ownerId) {
    final normalized = _normalizeOwnerId(ownerId);
    if (normalized == null) {
      throw StateError('No Firebase user is available for Van Mate storage.');
    }

    return normalized;
  }
}

class _RouteAnchorPoint {
  const _RouteAnchorPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _AnchorLineScore {
  const _AnchorLineScore({
    required this.projection,
    required this.perpendicularDistanceSquared,
  });

  final double projection;
  final double perpendicularDistanceSquared;
}
