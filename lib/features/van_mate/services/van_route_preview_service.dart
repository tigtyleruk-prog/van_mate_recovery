import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/van_route.dart';
import '../models/van_route_preview_summary.dart';
import '../models/van_place.dart';
import '../models/van_route_stop.dart';

enum VanRoadRoutePreviewWaypointSource { start, stop, end }

class VanRoadRoutePreviewWaypoint {
  const VanRoadRoutePreviewWaypoint({
    required this.label,
    required this.source,
    this.coordinates,
    this.geocodeQuery,
  });

  final String label;
  final VanRoadRoutePreviewWaypointSource source;
  final LatLng? coordinates;
  final String? geocodeQuery;
}

class VanRoadRoutePreviewResult {
  const VanRoadRoutePreviewResult({
    required this.resolvedPoints,
    required this.polylinePoints,
    required this.distanceMeters,
    required this.duration,
  });

  final List<LatLng> resolvedPoints;
  final List<LatLng> polylinePoints;
  final double? distanceMeters;
  final Duration? duration;
}

class VanGoogleMapsDirectionsLaunchResult {
  const VanGoogleMapsDirectionsLaunchResult({
    required this.uri,
    required this.isTruncated,
    required this.totalRemainingStops,
    required this.includedRemainingStops,
    required this.usesCurrentLocationOrigin,
  });

  final Uri? uri;
  final bool isTruncated;
  final int totalRemainingStops;
  final int includedRemainingStops;
  final bool usesCurrentLocationOrigin;

  bool get hasUri => uri != null;
}

class VanRoadRoutePreviewException implements Exception {
  const VanRoadRoutePreviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

Uri? buildVanGoogleMapsDirectionsUriForRoute(VanRoute? route) {
  if (route == null) {
    return null;
  }

  return buildVanGoogleMapsDirectionsUri(
    buildVanRoadRoutePreviewWaypoints(route),
  );
}

Uri? buildVanGoogleMapsDirectionsUriForRemainingRoute(VanRoute? route) {
  return buildVanGoogleMapsDirectionsResultForRemainingRoute(route).uri;
}

VanGoogleMapsDirectionsLaunchResult
buildVanGoogleMapsDirectionsResultForRemainingRoute(
  VanRoute? route, {
  Map<String, VanPlace> placeLookup = const <String, VanPlace>{},
  int maxRemainingStops = 9,
}) {
  if (route == null) {
    return const VanGoogleMapsDirectionsLaunchResult(
      uri: null,
      isTruncated: false,
      totalRemainingStops: 0,
      includedRemainingStops: 0,
      usesCurrentLocationOrigin: false,
    );
  }

  final remainingStops = route.remainingStops;
  if (remainingStops.isEmpty) {
    return const VanGoogleMapsDirectionsLaunchResult(
      uri: null,
      isTruncated: false,
      totalRemainingStops: 0,
      includedRemainingStops: 0,
      usesCurrentLocationOrigin: false,
    );
  }

  final safeRemainingStops = remainingStops.length <= maxRemainingStops
      ? remainingStops
      : remainingStops.sublist(0, maxRemainingStops);
  final origin = _googleMapsOriginForRoute(route);
  final locations = safeRemainingStops
      .map((stop) => _googleMapsLocationForRemainingStop(stop, placeLookup))
      .where((location) => location.trim().isNotEmpty)
      .toList(growable: false);

  return VanGoogleMapsDirectionsLaunchResult(
    uri: _buildGoogleMapsDirectionsUriWithOptionalOrigin(
      origin: origin,
      locations: locations,
    ),
    isTruncated: remainingStops.length > safeRemainingStops.length,
    totalRemainingStops: remainingStops.length,
    includedRemainingStops: safeRemainingStops.length,
    usesCurrentLocationOrigin: origin != null,
  );
}

Uri? buildVanGoogleMapsDirectionsUri(
  List<VanRoadRoutePreviewWaypoint> waypoints,
) {
  final locations = waypoints
      .map(_googleMapsLocationForWaypoint)
      .map((location) => location.trim())
      .where((location) => location.isNotEmpty)
      .toList(growable: false);

  if (locations.isEmpty) {
    return null;
  }

  final params = <String, String>{'api': '1', 'travelmode': 'driving'};

  if (locations.length == 1) {
    params['destination'] = locations.single;
  } else {
    params['origin'] = locations.first;
    params['destination'] = locations.last;
    if (locations.length > 2) {
      params['waypoints'] = locations
          .sublist(1, locations.length - 1)
          .join('|');
    }
  }

  return Uri.https('www.google.com', '/maps/dir/', params);
}

Uri? _buildGoogleMapsDirectionsUriWithOptionalOrigin({
  LatLng? origin,
  required List<String> locations,
}) {
  final cleanedLocations = locations
      .map((location) => location.trim())
      .where((location) => location.isNotEmpty)
      .toList(growable: false);

  if (cleanedLocations.isEmpty) {
    return null;
  }

  final params = <String, String>{'api': '1', 'travelmode': 'driving'};
  if (origin != null) {
    params['origin'] = '${origin.latitude},${origin.longitude}';
  }

  if (cleanedLocations.length == 1) {
    params['destination'] = cleanedLocations.single;
  } else {
    params['destination'] = cleanedLocations.last;
    params['waypoints'] = cleanedLocations
        .sublist(0, cleanedLocations.length - 1)
        .join('|');
  }

  return Uri.https('www.google.com', '/maps/dir/', params);
}

List<VanRouteStop> buildVanFreeRoutePreviewStopsForRoute(VanRoute? route) {
  if (route == null) {
    return const <VanRouteStop>[];
  }

  final remainingStops = route.remainingStops;
  if (remainingStops.isEmpty) {
    return const <VanRouteStop>[];
  }

  final filteredStops = remainingStops
      .where(_canUseFreeRoutePreviewStop)
      .toList(growable: false);

  return filteredStops;
}

List<VanRoadRoutePreviewWaypoint> buildVanFreeRoutePreviewWaypointsForRoute(
  VanRoute? route,
) {
  final stops = buildVanFreeRoutePreviewStopsForRoute(route);
  if (stops.isEmpty) {
    return const <VanRoadRoutePreviewWaypoint>[];
  }

  return <VanRoadRoutePreviewWaypoint>[
    for (final stop in stops)
      VanRoadRoutePreviewWaypoint(
        label: stop.name,
        source: VanRoadRoutePreviewWaypointSource.stop,
        coordinates: stop.hasCoordinates
            ? LatLng(stop.latitude!, stop.longitude!)
            : null,
        geocodeQuery: _freeRoutePreviewQueryForStop(stop),
      ),
  ];
}

class VanRoadRoutePreviewService {
  VanRoadRoutePreviewService._();

  static final VanRoadRoutePreviewService instance =
      VanRoadRoutePreviewService._();

  final http.Client _client = http.Client();
  final Map<String, VanRoadRoutePreviewResult> _cache =
      <String, VanRoadRoutePreviewResult>{};
  static const MethodChannel _platform = MethodChannel(
    'van_mate/google_services',
  );

  Future<List<LatLng>> resolveWaypoints({
    required List<VanRoadRoutePreviewWaypoint> waypoints,
  }) async {
    final resolved = <LatLng>[];

    for (final waypoint in waypoints) {
      final coordinates = waypoint.coordinates;
      if (coordinates != null) {
        debugPrint(
          '[RoadPreview] exact pin used for ${waypoint.label}: '
          '${coordinates.latitude.toStringAsFixed(6)}, '
          '${coordinates.longitude.toStringAsFixed(6)}',
        );
        resolved.add(coordinates);
        continue;
      }

      final query = waypoint.geocodeQuery?.trim() ?? '';
      if (query.isEmpty) {
        throw VanRoadRoutePreviewException(
          'Missing coordinates for ${waypoint.label}.',
        );
      }

      debugPrint(
        '[RoadPreview] fallback geocode used for ${waypoint.label}: $query',
      );

      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        throw VanRoadRoutePreviewException(
          'Could not geocode ${waypoint.label}.',
        );
      }

      final location = locations.first;
      resolved.add(LatLng(location.latitude, location.longitude));
    }

    return resolved;
  }

  Future<VanRoadRoutePreviewResult> calculateRoadPreviewRoute({
    required LatLng start,
    required List<LatLng> stops,
    LatLng? end,
    bool force = false,
  }) async {
    final routePoints = <LatLng>[start, ...stops];
    if (end != null) {
      routePoints.add(end);
    }

    if (routePoints.length < 2) {
      throw const VanRoadRoutePreviewException(
        'At least two route points are required.',
      );
    }

    final cacheKey = _cacheKey(routePoints);
    final cached = _cache[cacheKey];
    if (!force && cached != null) {
      return cached;
    }

    debugPrint(
      '[RoadPreview] route calculation started: '
      '${routePoints.length} points / ${stops.length} stops',
    );

    final apiKey = await _loadMapsApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const VanRoadRoutePreviewException(
        'Google Maps API key is unavailable for road routing.',
      );
    }

    final body = <String, dynamic>{
      'origin': _waypointPayload(routePoints.first),
      'destination': _waypointPayload(routePoints.last),
      if (routePoints.length > 2)
        'intermediates': routePoints
            .sublist(1, routePoints.length - 1)
            .map(_waypointPayload)
            .toList(growable: false),
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
      'languageCode': 'en-GB',
      'units': 'METRIC',
    };

    final response = await _client.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw VanRoadRoutePreviewException(
        'Google route request failed (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const VanRoadRoutePreviewException(
        'Google route response was not valid JSON.',
      );
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const VanRoadRoutePreviewException(
        'Google route service returned no routes.',
      );
    }

    final route = routes.first;
    if (route is! Map<String, dynamic>) {
      throw const VanRoadRoutePreviewException(
        'Google route payload was invalid.',
      );
    }

    final polyline = route['polyline'];
    if (polyline is! Map<String, dynamic>) {
      throw const VanRoadRoutePreviewException(
        'Google route polyline was missing.',
      );
    }

    final encodedPolyline =
        polyline['encodedPolyline']?.toString().trim() ?? '';
    if (encodedPolyline.isEmpty) {
      throw const VanRoadRoutePreviewException(
        'Google route polyline was empty.',
      );
    }

    final roadPoints = _decodePolyline(encodedPolyline);
    if (roadPoints.length < 2) {
      throw const VanRoadRoutePreviewException(
        'Google route polyline contained too few points.',
      );
    }

    final distanceMeters = (route['distanceMeters'] as num?)?.toDouble();
    final durationText = route['duration']?.toString().trim() ?? '';
    final duration = _parseGoogleDuration(durationText);
    final result = VanRoadRoutePreviewResult(
      resolvedPoints: List<LatLng>.unmodifiable(routePoints),
      polylinePoints: List<LatLng>.unmodifiable(roadPoints),
      distanceMeters: distanceMeters,
      duration: duration,
    );

    debugPrint(
      '[RoadPreview] route calculation success: '
      '${roadPoints.length} polyline points'
      '${distanceMeters == null ? '' : ', ${(distanceMeters / 1000).toStringAsFixed(1)} km'}'
      '${duration == null ? '' : ', $duration'}',
    );

    _cache[cacheKey] = result;
    return result;
  }

  Future<VanRoutePreviewSummary> calculateRemainingRouteSummaryForRoute({
    required VanRoute route,
    DateTime? calculatedAt,
  }) async {
    final remainingStops = route
        .getActiveOrderedStops()
        .where((stop) => stop.isQueued)
        .toList(growable: false);
    if (remainingStops.length < 2) {
      throw const VanRoadRoutePreviewException(
        'At least two remaining stops are required.',
      );
    }

    final waypoints = buildVanRoadRoutePreviewWaypointsFromPieces(
      routeStops: remainingStops,
    );
    if (waypoints.length < 2) {
      throw const VanRoadRoutePreviewException(
        'At least two remaining stops are required.',
      );
    }

    final result = await calculateRoadPreviewRouteForWaypoints(
      waypoints: waypoints,
    );
    final duration = result.duration;
    final distanceMeters = result.distanceMeters;
    if (duration == null || distanceMeters == null) {
      throw const VanRoadRoutePreviewException(
        'Google route response was missing summary data.',
      );
    }

    final now = calculatedAt ?? DateTime.now();
    final durationMinutes =
        duration.inMinutes + (duration.inSeconds % 60 == 0 ? 0 : 1);

    return VanRoutePreviewSummary(
      remainingStopsCount: remainingStops.length,
      estimatedDurationMinutes: durationMinutes <= 0 ? 1 : durationMinutes,
      estimatedDistanceMeters: distanceMeters,
      estimatedFinishTime: now.add(duration),
      calculatedAt: now,
      basedOnStopIds: remainingStops
          .map((stop) => stop.id)
          .toList(growable: false),
      provider: 'google_routes_preview',
      needsRefresh: false,
    );
  }

  Future<VanRoadRoutePreviewResult> calculateRoadPreviewRouteForWaypoints({
    required List<VanRoadRoutePreviewWaypoint> waypoints,
    bool force = false,
  }) async {
    if (waypoints.length < 2) {
      throw const VanRoadRoutePreviewException(
        'At least two route points are required.',
      );
    }

    final resolvedPoints = await resolveWaypoints(waypoints: waypoints);
    if (resolvedPoints.length < 2) {
      throw const VanRoadRoutePreviewException(
        'At least two route points are required.',
      );
    }

    final hasEndAnchor =
        waypoints.last.source == VanRoadRoutePreviewWaypointSource.end;
    return calculateRoadPreviewRoute(
      start: resolvedPoints.first,
      stops: hasEndAnchor
          ? resolvedPoints.sublist(1, resolvedPoints.length - 1)
          : resolvedPoints.sublist(1),
      end: hasEndAnchor ? resolvedPoints.last : null,
      force: force,
    );
  }

  String _cacheKey(List<LatLng> points) {
    return points
        .map(
          (point) =>
              '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
        )
        .join('|');
  }

  Future<String?> _loadMapsApiKey() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final apiKey = await _platform.invokeMethod<String>('getMapsApiKey');
      return apiKey?.trim();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Map<String, dynamic> _waypointPayload(LatLng point) {
    return <String, dynamic>{
      'location': <String, dynamic>{
        'latLng': <String, dynamic>{
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
      },
    };
  }

  List<LatLng> _decodePolyline(String encodedPolyline) {
    final polyline = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encodedPolyline.length) {
      var shift = 0;
      var result = 0;

      while (true) {
        final byte = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
        if (byte < 0x20) {
          break;
        }
      }

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      while (true) {
        final byte = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
        if (byte < 0x20) {
          break;
        }
      }

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;
      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return polyline;
  }

  Duration? _parseGoogleDuration(String durationText) {
    if (durationText.isEmpty) {
      return null;
    }

    final match = RegExp(r'^(\d+)(?:\.(\d+))?s$').firstMatch(durationText);
    if (match != null) {
      final wholeSeconds = int.tryParse(match.group(1) ?? '') ?? 0;
      final fractional = match.group(2) ?? '';
      final milliseconds = fractional.isEmpty
          ? 0
          : int.parse(fractional.padRight(3, '0').substring(0, 3));
      return Duration(seconds: wholeSeconds, milliseconds: milliseconds);
    }

    final parsed = double.tryParse(durationText);
    if (parsed != null) {
      return Duration(milliseconds: (parsed * 1000).round());
    }

    return null;
  }
}

String _googleMapsLocationForWaypoint(VanRoadRoutePreviewWaypoint waypoint) {
  final coordinates = waypoint.coordinates;
  if (coordinates != null) {
    return '${coordinates.latitude},${coordinates.longitude}';
  }

  final query = waypoint.geocodeQuery?.trim();
  if (query != null && query.isNotEmpty) {
    return query;
  }

  return waypoint.label.trim();
}

LatLng? _googleMapsOriginForRoute(VanRoute route) {
  final startAnchor = route.startAnchor;
  if (startAnchor == null ||
      startAnchor.type != VanRouteAnchorType.currentLocation ||
      !startAnchor.hasCoordinates) {
    return null;
  }

  return LatLng(startAnchor.latitude!, startAnchor.longitude!);
}

String _googleMapsLocationForRemainingStop(
  VanRouteStop stop,
  Map<String, VanPlace> placeLookup,
) {
  final place = placeLookup[stop.placeId];
  if (place?.hasTrustedExactPin == true && place!.hasCoordinates) {
    return '${place.latitude},${place.longitude}';
  }

  if (place == null && stop.hasCoordinates) {
    return '${stop.latitude},${stop.longitude}';
  }

  final postcode = (place?.postcodeArea ?? stop.postcodeArea).trim();
  if (postcode.isNotEmpty) {
    return postcode;
  }

  final address = (place?.address ?? stop.address).trim();
  if (address.isNotEmpty) {
    return address;
  }

  final name = stop.name.trim();
  if (name.isNotEmpty) {
    return name;
  }

  return '';
}

String? _freeRoutePreviewQueryForStop(VanRouteStop stop) {
  final address = stop.address.trim();
  final postcode = stop.postcodeArea.trim();
  final parts = <String>[
    if (address.isNotEmpty) address,
    if (postcode.isNotEmpty) postcode,
  ];

  if (parts.isEmpty) {
    return null;
  }

  return parts.join(', ');
}

bool _canUseFreeRoutePreviewStop(VanRouteStop stop) {
  return stop.hasCoordinates || _freeRoutePreviewQueryForStop(stop) != null;
}

String buildVanRoadRoutePreviewSignature(
  List<VanRoadRoutePreviewWaypoint> waypoints,
) {
  return waypoints
      .map(
        (waypoint) => [
          waypoint.source.name,
          waypoint.label.trim(),
          waypoint.coordinates == null
              ? ''
              : '${waypoint.coordinates!.latitude.toStringAsFixed(6)},${waypoint.coordinates!.longitude.toStringAsFixed(6)}',
          waypoint.geocodeQuery?.trim() ?? '',
        ].join('~'),
      )
      .join('|');
}

List<VanRoadRoutePreviewWaypoint> buildVanRoadRoutePreviewWaypoints(
  VanRoute? route,
) {
  if (route == null) {
    return const <VanRoadRoutePreviewWaypoint>[];
  }

  return buildVanRoadRoutePreviewWaypointsFromPieces(
    routeStops: route.getActiveOrderedStops(),
    routeStartAnchor: route.startAnchor,
    routeEndAnchor: route.endAnchor,
  );
}

List<VanRoadRoutePreviewWaypoint> buildVanRoadRoutePreviewWaypointsFromPieces({
  required List<VanRouteStop> routeStops,
  VanRouteAnchor? routeStartAnchor,
  VanRouteAnchor? routeEndAnchor,
}) {
  final waypoints = <VanRoadRoutePreviewWaypoint>[];

  if (routeStartAnchor != null) {
    waypoints.add(
      VanRoadRoutePreviewWaypoint(
        label: routeStartAnchor.bestLabel,
        source: VanRoadRoutePreviewWaypointSource.start,
        coordinates: routeStartAnchor.hasCoordinates
            ? LatLng(routeStartAnchor.latitude!, routeStartAnchor.longitude!)
            : null,
        geocodeQuery: routeStartAnchor.bestLabel,
      ),
    );
  }

  final orderedStops = routeStops
      .where((stop) => stop.hasCoordinates || _canGeocodeStop(stop))
      .toList(growable: false);

  for (final stop in orderedStops) {
    waypoints.add(
      VanRoadRoutePreviewWaypoint(
        label: stop.name,
        source: VanRoadRoutePreviewWaypointSource.stop,
        coordinates: stop.hasCoordinates
            ? LatLng(stop.latitude!, stop.longitude!)
            : null,
        geocodeQuery: _routePreviewQueryForStop(stop),
      ),
    );
  }

  if (routeEndAnchor != null) {
    waypoints.add(
      VanRoadRoutePreviewWaypoint(
        label: routeEndAnchor.bestLabel,
        source: VanRoadRoutePreviewWaypointSource.end,
        coordinates: routeEndAnchor.hasCoordinates
            ? LatLng(routeEndAnchor.latitude!, routeEndAnchor.longitude!)
            : null,
        geocodeQuery: routeEndAnchor.bestLabel,
      ),
    );
  }

  return waypoints;
}

String _routePreviewQueryForStop(VanRouteStop stop) {
  final postcode = stop.postcodeArea.trim();
  final address = stop.address.trim();
  final addressParts = <String>[
    if (postcode.isNotEmpty) postcode,
    if (address.isNotEmpty) address,
  ];
  if (addressParts.isNotEmpty) {
    return addressParts.join(', ');
  }

  final name = stop.name.trim();
  if (name.isNotEmpty) {
    return name;
  }

  return '';
}

bool _canGeocodeStop(VanRouteStop stop) {
  return stop.name.trim().isNotEmpty ||
      stop.address.trim().isNotEmpty ||
      stop.postcodeArea.trim().isNotEmpty;
}
