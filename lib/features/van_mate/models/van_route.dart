import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'today_route_summary.dart';
import 'van_route_stop.dart';

enum VanRouteAnchorType {
  currentLocation('current_location', 'Current Location', Icons.my_location),
  savedPlace('saved_place', 'Saved Place', Icons.place_outlined),
  customPlace('custom_place', 'Custom Place', Icons.map_outlined);

  const VanRouteAnchorType(this.storageValue, this.label, this.icon);

  final String storageValue;
  final String label;
  final IconData icon;

  static VanRouteAnchorType fromStorage(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    for (final type in values) {
      if (type.storageValue == normalized) {
        return type;
      }
    }

    return VanRouteAnchorType.customPlace;
  }
}

class VanRouteAnchor {
  final VanRouteAnchorType type;
  final String label;
  final double? latitude;
  final double? longitude;
  final String savedPlaceId;

  const VanRouteAnchor({
    required this.type,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.savedPlaceId = '',
  });

  bool get hasCoordinates =>
      _hasValidLatitude(latitude) && _hasValidLongitude(longitude);

  String get bestLabel {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }

    return type.label;
  }

  VanRouteAnchor copyWith({
    VanRouteAnchorType? type,
    String? label,
    double? latitude,
    double? longitude,
    String? savedPlaceId,
    bool clearCoordinates = false,
  }) {
    return VanRouteAnchor(
      type: type ?? this.type,
      label: label ?? this.label,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      savedPlaceId: savedPlaceId ?? this.savedPlaceId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.storageValue,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'savedPlaceId': savedPlaceId,
    };
  }

  factory VanRouteAnchor.fromJson(Map<String, dynamic> json) {
    return VanRouteAnchor(
      type: VanRouteAnchorType.fromStorage(json['type']),
      label: _routeReadString(json['label']),
      latitude: _routeReadDouble(json['latitude']),
      longitude: _routeReadDouble(json['longitude']),
      savedPlaceId: _routeReadString(json['savedPlaceId']),
    );
  }
}

class VanRoute {
  final String id;
  final String routeDate;
  final String routeName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerId;
  final String createdBy;
  final bool isActive;
  final VanRouteAnchor? startAnchor;
  final VanRouteAnchor? endAnchor;
  final List<VanRouteStop> stops;
  final String premiumSummaryHash;
  final double? premiumDistanceMeters;
  final int? premiumDurationSeconds;
  final String? premiumEstimatedFinishIso;
  final String? premiumCalculatedAtIso;
  final int? premiumStopCount;
  final String premiumProvider;
  final String premiumSummaryError;
  final List<double> premiumLegDistanceMeters;
  final List<int> premiumLegDurationSeconds;
  final bool premiumHalfwayRefreshDone;
  final String? premiumHalfwayRefreshAtIso;
  final int? premiumTotalStopsAtStart;
  final int? premiumHalfwayTriggerStopCount;
  final String premiumLastSummaryMode;

  const VanRoute({
    required this.id,
    required this.routeDate,
    required this.routeName,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    required this.createdBy,
    required this.isActive,
    required this.startAnchor,
    required this.endAnchor,
    required this.stops,
    this.premiumSummaryHash = '',
    this.premiumDistanceMeters,
    this.premiumDurationSeconds,
    this.premiumEstimatedFinishIso,
    this.premiumCalculatedAtIso,
    this.premiumStopCount,
    this.premiumProvider = 'google_routes',
    this.premiumSummaryError = '',
    this.premiumLegDistanceMeters = const <double>[],
    this.premiumLegDurationSeconds = const <int>[],
    this.premiumHalfwayRefreshDone = false,
    this.premiumHalfwayRefreshAtIso,
    this.premiumTotalStopsAtStart,
    this.premiumHalfwayTriggerStopCount,
    this.premiumLastSummaryMode = 'start',
  });

  VanRouteStop? get currentJob {
    for (final stop in getActiveOrderedStops()) {
      if (stop.isQueued) {
        return stop;
      }
    }

    return null;
  }

  int get completedCount =>
      getActiveOrderedStops().where((stop) => stop.isDone).length;
  int get queuedCount =>
      getActiveOrderedStops().where((stop) => stop.isQueued).length;
  int get failedCount =>
      getActiveOrderedStops().where((stop) => stop.isFailed).length;

  List<VanRouteStop> get remainingStops {
    return getActiveOrderedStops()
        .where((stop) => stop.isQueued)
        .toList(growable: false);
  }

  List<VanRouteStop> get completedStops {
    return getActiveOrderedStops()
        .where((stop) => stop.isDone)
        .toList(growable: false);
  }

  List<VanRouteStop> get failedStops {
    return getActiveOrderedStops()
        .where((stop) => stop.isFailed)
        .toList(growable: false);
  }

  int get totalStopsAtStart {
    final stored = premiumTotalStopsAtStart;
    if (stored != null && stored > 0) {
      return stored;
    }

    return getActiveOrderedStops().length;
  }

  int get halfwayTriggerStopCount {
    final stored = premiumHalfwayTriggerStopCount;
    if (stored != null && stored > 0) {
      return stored;
    }

    final total = totalStopsAtStart;
    return (total / 2).ceil();
  }

  bool get hasHalfwayRefreshDone => premiumHalfwayRefreshDone;

  DateTime? get premiumHalfwayRefreshAt =>
      DateTime.tryParse(premiumHalfwayRefreshAtIso?.trim() ?? '');

  List<VanRouteStop> getActiveOrderedStops() {
    final orderedStops = List<VanRouteStop>.from(stops)
      ..sort((a, b) => a.routeOrder.compareTo(b.routeOrder));
    return List<VanRouteStop>.unmodifiable(orderedStops);
  }

  TodayRouteSummary? premiumSummaryCacheIfMatches(String expectedHash) {
    final normalizedHash = expectedHash.trim();
    if (normalizedHash.isEmpty || premiumSummaryHash.trim() != normalizedHash) {
      return null;
    }

    if (premiumSummaryError.trim().isNotEmpty) {
      return null;
    }

    final distanceMeters = premiumDistanceMeters;
    final durationSeconds = premiumDurationSeconds;
    final stopCount = premiumStopCount;
    final finish = DateTime.tryParse(premiumEstimatedFinishIso?.trim() ?? '');
    final calculatedAt = DateTime.tryParse(
      premiumCalculatedAtIso?.trim() ?? '',
    );

    if (distanceMeters == null ||
        durationSeconds == null ||
        stopCount == null ||
        finish == null ||
        calculatedAt == null) {
      return null;
    }

    return TodayRouteSummary(
      totalDistanceMeters: distanceMeters,
      totalDurationSeconds: durationSeconds,
      estimatedFinish: finish,
      calculatedAt: calculatedAt,
      stopCount: stopCount,
      summaryHash: premiumSummaryHash,
      provider: premiumProvider,
      fromCache: true,
      summaryError: null,
      legDistanceMeters: List<double>.unmodifiable(premiumLegDistanceMeters),
      legDurationSeconds: List<int>.unmodifiable(premiumLegDurationSeconds),
    );
  }

  VanRoute copyWith({
    String? id,
    String? routeDate,
    String? routeName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerId,
    String? createdBy,
    bool? isActive,
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
    List<VanRouteStop>? stops,
    String? premiumSummaryHash,
    double? premiumDistanceMeters,
    int? premiumDurationSeconds,
    String? premiumEstimatedFinishIso,
    String? premiumCalculatedAtIso,
    int? premiumStopCount,
    String? premiumProvider,
    String? premiumSummaryError,
    List<double>? premiumLegDistanceMeters,
    List<int>? premiumLegDurationSeconds,
    bool? premiumHalfwayRefreshDone,
    String? premiumHalfwayRefreshAtIso,
    int? premiumTotalStopsAtStart,
    int? premiumHalfwayTriggerStopCount,
    String? premiumLastSummaryMode,
    bool clearStartAnchor = false,
    bool clearEndAnchor = false,
  }) {
    return VanRoute(
      id: id ?? this.id,
      routeDate: routeDate ?? this.routeDate,
      routeName: routeName ?? this.routeName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerId: ownerId ?? this.ownerId,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      startAnchor: clearStartAnchor ? null : (startAnchor ?? this.startAnchor),
      endAnchor: clearEndAnchor ? null : (endAnchor ?? this.endAnchor),
      stops: stops ?? this.stops,
      premiumSummaryHash: premiumSummaryHash ?? this.premiumSummaryHash,
      premiumDistanceMeters:
          premiumDistanceMeters ?? this.premiumDistanceMeters,
      premiumDurationSeconds:
          premiumDurationSeconds ?? this.premiumDurationSeconds,
      premiumEstimatedFinishIso:
          premiumEstimatedFinishIso ?? this.premiumEstimatedFinishIso,
      premiumCalculatedAtIso:
          premiumCalculatedAtIso ?? this.premiumCalculatedAtIso,
      premiumStopCount: premiumStopCount ?? this.premiumStopCount,
      premiumProvider: premiumProvider ?? this.premiumProvider,
      premiumSummaryError: premiumSummaryError ?? this.premiumSummaryError,
      premiumLegDistanceMeters:
          premiumLegDistanceMeters ?? this.premiumLegDistanceMeters,
      premiumLegDurationSeconds:
          premiumLegDurationSeconds ?? this.premiumLegDurationSeconds,
      premiumHalfwayRefreshDone:
          premiumHalfwayRefreshDone ?? this.premiumHalfwayRefreshDone,
      premiumHalfwayRefreshAtIso:
          premiumHalfwayRefreshAtIso ?? this.premiumHalfwayRefreshAtIso,
      premiumTotalStopsAtStart:
          premiumTotalStopsAtStart ?? this.premiumTotalStopsAtStart,
      premiumHalfwayTriggerStopCount:
          premiumHalfwayTriggerStopCount ?? this.premiumHalfwayTriggerStopCount,
      premiumLastSummaryMode:
          premiumLastSummaryMode ?? this.premiumLastSummaryMode,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'routeDate': routeDate,
      'routeName': routeName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'ownerId': ownerId,
      'createdBy': createdBy,
      'isActive': isActive,
      'startAnchor': startAnchor?.toJson(),
      'endAnchor': endAnchor?.toJson(),
      'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
      'premiumSummaryHash': premiumSummaryHash,
      'premiumDistanceMeters': premiumDistanceMeters,
      'premiumDurationSeconds': premiumDurationSeconds,
      'premiumEstimatedFinishIso': premiumEstimatedFinishIso,
      'premiumCalculatedAt': premiumCalculatedAtIso,
      'premiumStopCount': premiumStopCount,
      'premiumProvider': premiumProvider,
      'premiumSummaryError': premiumSummaryError,
      'premiumLegDistanceMeters': premiumLegDistanceMeters,
      'premiumLegDurationSeconds': premiumLegDurationSeconds,
      'premiumHalfwayRefreshDone': premiumHalfwayRefreshDone,
      'premiumHalfwayRefreshAt': premiumHalfwayRefreshAtIso,
      'premiumTotalStopsAtStart': premiumTotalStopsAtStart,
      'premiumHalfwayTriggerStopCount': premiumHalfwayTriggerStopCount,
      'premiumLastSummaryMode': premiumLastSummaryMode,
    };
  }

  factory VanRoute.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final updatedAt =
        _readDateTime(data['updatedAt']) ??
        _readDateTime(data['createdAt']) ??
        DateTime.now();

    return VanRoute(
      id: snapshot.id,
      routeDate: _routeReadString(data['routeDate']),
      routeName: _routeReadString(data['routeName'], fallback: 'Van Route'),
      createdAt: _readDateTime(data['createdAt']) ?? updatedAt,
      updatedAt: updatedAt,
      ownerId: _routeReadString(
        data['ownerId'],
        fallback: _routeReadString(data['createdBy'], fallback: 'anonymous'),
      ),
      createdBy: _routeReadString(data['createdBy'], fallback: 'anonymous'),
      isActive: _readBool(data['isActive'], fallback: true),
      startAnchor: _readAnchor(data['startAnchor']),
      endAnchor: _readAnchor(data['endAnchor']),
      stops: _readStops(data['stops']),
      premiumSummaryHash: _routeReadString(data['premiumSummaryHash']),
      premiumDistanceMeters: _readNullableDouble(data['premiumDistanceMeters']),
      premiumDurationSeconds: _readNullableInt(data['premiumDurationSeconds']),
      premiumEstimatedFinishIso: _readNullableString(
        data['premiumEstimatedFinishIso'],
      ),
      premiumCalculatedAtIso: _readNullableString(data['premiumCalculatedAt']),
      premiumStopCount: _readNullableInt(data['premiumStopCount']),
      premiumProvider: _routeReadString(
        data['premiumProvider'],
        fallback: 'google_routes',
      ),
      premiumSummaryError: _routeReadString(data['premiumSummaryError']),
      premiumLegDistanceMeters: _readDoubleList(
        data['premiumLegDistanceMeters'],
      ),
      premiumLegDurationSeconds: _readIntList(
        data['premiumLegDurationSeconds'],
      ),
      premiumHalfwayRefreshDone: _readBool(
        data['premiumHalfwayRefreshDone'],
        fallback: false,
      ),
      premiumHalfwayRefreshAtIso: _readNullableString(
        data['premiumHalfwayRefreshAt'],
      ),
      premiumTotalStopsAtStart: _readNullableInt(
        data['premiumTotalStopsAtStart'],
      ),
      premiumHalfwayTriggerStopCount: _readNullableInt(
        data['premiumHalfwayTriggerStopCount'],
      ),
      premiumLastSummaryMode: _routeReadString(
        data['premiumLastSummaryMode'],
        fallback: 'start',
      ),
    );
  }

  static VanRouteAnchor? _readAnchor(dynamic value) {
    if (value is Map) {
      final mapped = Map<String, dynamic>.from(value);
      final anchor = VanRouteAnchor.fromJson(mapped);
      return anchor.bestLabel.isEmpty && !anchor.hasCoordinates ? null : anchor;
    }

    return null;
  }

  static List<VanRouteStop> _readStops(dynamic value) {
    if (value is Iterable) {
      final stops = value
          .map((item) => VanRouteStop.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      stops.sort((a, b) => a.routeOrder.compareTo(b.routeOrder));
      return stops;
    }

    return const <VanRouteStop>[];
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return fallback;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }

  static String? _readNullableString(dynamic value) {
    final parsed = value?.toString().trim() ?? '';
    return parsed.isEmpty ? null : parsed;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString().trim());
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static List<double> _readDoubleList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => _readNullableDouble(item) ?? 0)
          .toList(growable: false);
    }

    return const <double>[];
  }

  static List<int> _readIntList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => _readNullableInt(item) ?? 0)
          .toList(growable: false);
    }

    return const <int>[];
  }
}

String _routeReadString(dynamic value, {String fallback = ''}) {
  final parsed = value?.toString().trim() ?? '';
  return parsed.isEmpty ? fallback : parsed;
}

double? _routeReadDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

bool _hasValidLatitude(double? value) {
  return value != null && value >= -90 && value <= 90;
}

bool _hasValidLongitude(double? value) {
  return value != null && value >= -180 && value <= 180;
}
