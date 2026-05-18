import 'package:cloud_firestore/cloud_firestore.dart';

import 'van_route.dart';
import 'van_route_stop.dart';

class VanRouteTemplate {
  final String id;
  final String ownerId;
  final String createdBy;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VanRouteAnchor? startAnchor;
  final VanRouteAnchor? endAnchor;
  final List<VanRouteStop> stops;

  const VanRouteTemplate({
    required this.id,
    required this.ownerId,
    required this.createdBy,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.startAnchor,
    required this.endAnchor,
    required this.stops,
  });

  VanRouteTemplate copyWith({
    String? id,
    String? ownerId,
    String? createdBy,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    VanRouteAnchor? startAnchor,
    VanRouteAnchor? endAnchor,
    List<VanRouteStop>? stops,
    bool clearStartAnchor = false,
    bool clearEndAnchor = false,
  }) {
    return VanRouteTemplate(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      createdBy: createdBy ?? this.createdBy,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startAnchor: clearStartAnchor ? null : (startAnchor ?? this.startAnchor),
      endAnchor: clearEndAnchor ? null : (endAnchor ?? this.endAnchor),
      stops: stops ?? this.stops,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'createdBy': createdBy,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'startAnchor': startAnchor?.toJson(),
      'endAnchor': endAnchor?.toJson(),
      'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
    };
  }

  factory VanRouteTemplate.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final updatedAt =
        _readDateTime(data['updatedAt']) ??
        _readDateTime(data['createdAt']) ??
        DateTime.now();

    return VanRouteTemplate(
      id: snapshot.id,
      ownerId: _readString(data['ownerId']),
      createdBy: _readString(
        data['createdBy'],
        fallback: _readString(data['ownerId'], fallback: 'anonymous'),
      ),
      name: _readString(data['name'], fallback: 'Route Template'),
      createdAt: _readDateTime(data['createdAt']) ?? updatedAt,
      updatedAt: updatedAt,
      startAnchor: _readAnchor(data['startAnchor']),
      endAnchor: _readAnchor(data['endAnchor']),
      stops: _readStops(data['stops']),
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

  static String _readString(dynamic value, {String fallback = ''}) {
    final parsed = value?.toString().trim() ?? '';
    return parsed.isEmpty ? fallback : parsed;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }
}
