import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/today_route_summary.dart';
import '../models/van_place.dart';
import '../models/van_route.dart';
import '../models/van_route_stop.dart';

class TodayRouteSummaryException implements Exception {
  const TodayRouteSummaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum PremiumRouteSummaryMode { start, halfway, routeChanged }

class PremiumRouteSummaryService {
  PremiumRouteSummaryService._();

  static final PremiumRouteSummaryService instance =
      PremiumRouteSummaryService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Map<String, TodayRouteSummary> _memoryCache =
      <String, TodayRouteSummary>{};

  bool shouldTriggerHalfwayRefresh(VanRoute route) {
    if (route.hasHalfwayRefreshDone) {
      return false;
    }

    return route.completedCount >= route.halfwayTriggerStopCount;
  }

  Future<TodayRouteSummary?> loadSummaryForRoute({
    required VanRoute route,
    required List<VanRouteStop> remainingStops,
    required Map<String, VanPlace> placesById,
    PremiumRouteSummaryMode summaryMode = PremiumRouteSummaryMode.start,
    bool force = false,
  }) async {
    if (remainingStops.isEmpty) {
      return null;
    }

    final summaryHash = buildTodayRouteSummaryHash(
      route: route,
      remainingStops: remainingStops,
      placesById: placesById,
    );
    final routeHashChanged = route.premiumSummaryHash.trim() != summaryHash;
    final modeLabel = summaryMode.name;

    if (!force) {
      final cached = route.premiumSummaryCacheIfMatches(summaryHash);
      final memoryCached = _memoryCache[summaryHash];

      if (summaryMode != PremiumRouteSummaryMode.halfway) {
        if (cached != null) {
          debugPrint(
            '[RouteSummary] mode=$modeLabel route=${route.id} uid=${route.ownerId} cache=route-doc hash=$summaryHash routeChanged=$routeHashChanged halfwayDone=${route.hasHalfwayRefreshDone}',
          );
          _memoryCache[summaryHash] = cached;
          return cached;
        }

        if (memoryCached != null) {
          debugPrint(
            '[RouteSummary] mode=$modeLabel route=${route.id} uid=${route.ownerId} cache=memory hash=$summaryHash routeChanged=$routeHashChanged halfwayDone=${route.hasHalfwayRefreshDone}',
          );
          return memoryCached;
        }
      } else if (route.hasHalfwayRefreshDone) {
        if (cached != null) {
          debugPrint(
            '[RouteSummary] mode=$modeLabel route=${route.id} uid=${route.ownerId} cache=route-doc hash=$summaryHash routeChanged=$routeHashChanged halfwayDone=true',
          );
          _memoryCache[summaryHash] = cached;
          return cached;
        }

        if (memoryCached != null) {
          debugPrint(
            '[RouteSummary] mode=$modeLabel route=${route.id} uid=${route.ownerId} cache=memory hash=$summaryHash routeChanged=$routeHashChanged halfwayDone=true',
          );
          return memoryCached;
        }
      }

      if (route.premiumSummaryHash.trim() == summaryHash &&
          route.premiumSummaryError.trim().isNotEmpty) {
        throw TodayRouteSummaryException(route.premiumSummaryError.trim());
      }
    }

    final payload = <String, dynamic>{
      'routeId': route.id,
      'routeHash': summaryHash,
      'force': force,
      'mode': summaryMode.name,
      'routeDate': route.routeDate,
      'remainingStops': remainingStops
          .map((stop) => _stopPayload(stop, placesById[stop.placeId]))
          .toList(growable: false),
      if (route.startAnchor != null)
        'startLocation': _anchorPayload(route.startAnchor!),
      if (route.endAnchor != null)
        'endLocation': _anchorPayload(route.endAnchor!),
    };

    debugPrint(
      '[RouteSummary] callable request started route=${route.id} uid=${route.ownerId} mode=$modeLabel stopCount=${remainingStops.length} routeChanged=$routeHashChanged halfwayDone=${route.hasHalfwayRefreshDone}',
    );

    final callable = _functions.httpsCallable('calculateRouteSummary');
    late final HttpsCallableResult<dynamic> response;
    try {
      response = await callable.call(payload);
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        '[RouteSummary] callable failed code=${error.code} message=${error.message} details=${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw TodayRouteSummaryException(_userFacingCallableErrorMessage(error));
    } catch (error, stackTrace) {
      debugPrint('[RouteSummary] callable failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const TodayRouteSummaryException('Route summary unavailable.');
    }

    final data = response.data;
    if (data is! Map) {
      debugPrint(
        '[RouteSummary] callable returned invalid payload type=${data.runtimeType}',
      );
      throw const TodayRouteSummaryException(
        'Route summary response was invalid.',
      );
    }

    final summary = TodayRouteSummary.fromFunctionResponse(
      Map<String, dynamic>.from(data),
      fromCache: false,
    );
    if (summary.summaryHash.trim().isNotEmpty &&
        summary.summaryHash.trim() != summaryHash) {
      debugPrint(
        '[RouteSummary] hash mismatch route=$summaryHash response=${summary.summaryHash}',
      );
    }

    _memoryCache[summaryHash] = summary;
    return summary;
  }

  TodayRouteSummary? buildLocalSummaryAfterCurrentStopCompleted({
    required TodayRouteSummary currentSummary,
    required VanRoute route,
    required List<VanRouteStop> remainingStops,
    required Map<String, VanPlace> placesById,
  }) {
    if (!currentSummary.canShiftFromFirstStop ||
        remainingStops.length != currentSummary.stopCount - 1) {
      return null;
    }

    final nextHash = buildTodayRouteSummaryHash(
      route: route,
      remainingStops: remainingStops,
      placesById: placesById,
    );

    final nextSummary = currentSummary.shiftAfterRemovingFirstStop(
      summaryHash: nextHash,
      calculatedAt: DateTime.now(),
    );
    if (nextSummary == null) {
      return null;
    }

    _memoryCache[nextHash] = nextSummary;
    return nextSummary;
  }

  String buildTodayRouteSummaryHash({
    required VanRoute route,
    required List<VanRouteStop> remainingStops,
    required Map<String, VanPlace> placesById,
  }) {
    final payload = _summaryHashPayload(
      route: route,
      remainingStops: remainingStops,
      placesById: placesById,
    );
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  Map<String, dynamic> _summaryHashPayload({
    required VanRoute route,
    required List<VanRouteStop> remainingStops,
    required Map<String, VanPlace> placesById,
  }) {
    return <String, dynamic>{
      'routeId': route.id,
      'routeDate': route.routeDate,
      'start': _anchorHashPayload(route.startAnchor),
      'end': _anchorHashPayload(route.endAnchor),
      'stops': [
        for (final stop in remainingStops)
          <String, dynamic>{
            'id': stop.id,
            'placeId': stop.placeId,
            'order': stop.routeOrder,
            'location': _stopLocationHashPayload(
              stop,
              placesById[stop.placeId],
            ),
          },
      ],
    };
  }

  Map<String, dynamic> _stopPayload(VanRouteStop stop, VanPlace? place) {
    final location = _resolveStopLocationPayload(stop, place);
    return <String, dynamic>{
      'id': stop.id,
      'placeId': stop.placeId,
      'order': stop.routeOrder,
      'location': location,
    };
  }

  Map<String, dynamic> _anchorPayload(VanRouteAnchor anchor) {
    final hasCoordinates = anchor.hasCoordinates;
    return <String, dynamic>{
      'type': anchor.type.storageValue,
      'label': anchor.bestLabel,
      if (hasCoordinates) 'lat': anchor.latitude,
      if (hasCoordinates) 'lng': anchor.longitude,
    };
  }

  Map<String, dynamic> _anchorHashPayload(VanRouteAnchor? anchor) {
    if (anchor == null) {
      return const <String, dynamic>{'kind': 'missing'};
    }

    if (anchor.hasCoordinates) {
      return <String, dynamic>{
        'kind': 'exact',
        'type': anchor.type.storageValue,
        'label': anchor.bestLabel,
        'lat': _round6(anchor.latitude),
        'lng': _round6(anchor.longitude),
        'savedPlaceId': anchor.savedPlaceId,
      };
    }

    final label = anchor.bestLabel.trim();
    if (label.isEmpty || anchor.type == VanRouteAnchorType.currentLocation) {
      return const <String, dynamic>{'kind': 'missing'};
    }

    return <String, dynamic>{'kind': 'text', 'value': label};
  }

  Map<String, dynamic> _stopLocationHashPayload(
    VanRouteStop stop,
    VanPlace? place,
  ) {
    return _resolveStopLocationPayload(stop, place);
  }

  Map<String, dynamic> _resolveStopLocationPayload(
    VanRouteStop stop,
    VanPlace? place,
  ) {
    if (place?.hasTrustedExactPin == true) {
      return <String, dynamic>{
        'kind': 'exact',
        'lat': place!.latitude,
        'lng': place.longitude,
      };
    }

    final postcode = _firstNonEmpty([stop.postcodeArea, place?.postcodeArea]);
    if (postcode.isNotEmpty) {
      return <String, dynamic>{'kind': 'text', 'value': postcode};
    }

    final address = _firstNonEmpty([stop.address, place?.address]);
    if (address.isNotEmpty) {
      return <String, dynamic>{'kind': 'text', 'value': address};
    }

    final name = _firstNonEmpty([stop.name, place?.name]);
    if (name.isNotEmpty) {
      return <String, dynamic>{'kind': 'text', 'value': name};
    }

    return const <String, dynamic>{'kind': 'missing'};
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return '';
  }

  double? _round6(double? value) {
    if (value == null) {
      return null;
    }

    return double.parse(value.toStringAsFixed(6));
  }

  String _userFacingCallableErrorMessage(FirebaseFunctionsException error) {
    final message = error.message?.trim() ?? '';
    if (message.isEmpty) {
      return 'Route summary unavailable.';
    }
    return 'Route summary unavailable.';
  }
}
