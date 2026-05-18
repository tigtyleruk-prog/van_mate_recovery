import 'package:cloud_firestore/cloud_firestore.dart';

import 'van_place.dart';

enum VanRouteStopStatus {
  queued('queued'),
  done('done'),
  failed('failed');

  const VanRouteStopStatus(this.storageValue);

  final String storageValue;

  static VanRouteStopStatus fromStorage(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    for (final status in values) {
      if (status.storageValue == normalized) {
        return status;
      }
    }

    return VanRouteStopStatus.queued;
  }
}

class VanRouteStop {
  final String id;
  final String placeId;
  final String name;
  final String address;
  final String postcodeArea;
  final String deliveryNote;
  final String warningNote;
  final VanPlaceType placeType;
  final double? latitude;
  final double? longitude;
  final int routeOrder;
  final VanRouteStopStatus status;
  final DateTime? completedAt;
  final String failureNote;
  final bool podRequired;

  const VanRouteStop({
    required this.id,
    required this.placeId,
    required this.name,
    required this.address,
    required this.postcodeArea,
    required this.deliveryNote,
    required this.warningNote,
    required this.placeType,
    required this.latitude,
    required this.longitude,
    required this.routeOrder,
    required this.status,
    required this.completedAt,
    required this.failureNote,
    required this.podRequired,
  });

  factory VanRouteStop.fromPlace({
    required String id,
    required VanPlace place,
    required int routeOrder,
    VanRouteStopStatus status = VanRouteStopStatus.queued,
    DateTime? completedAt,
    String failureNote = '',
    bool podRequired = false,
  }) {
    return VanRouteStop(
      id: id,
      placeId: place.id,
      name: place.name,
      address: place.address,
      postcodeArea: place.postcodeArea,
      deliveryNote: place.deliveryNote,
      warningNote: place.warningNote,
      placeType: place.placeType,
      latitude: place.latitude,
      longitude: place.longitude,
      routeOrder: routeOrder,
      status: status,
      completedAt: completedAt,
      failureNote: failureNote,
      podRequired: podRequired,
    );
  }

  bool get hasCoordinates =>
      _hasValidLatitude(latitude) && _hasValidLongitude(longitude);
  bool get isQueued => status == VanRouteStopStatus.queued;
  bool get isDone => status == VanRouteStopStatus.done;
  bool get isFailed => status == VanRouteStopStatus.failed;

  String get bestLocationLabel {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isNotEmpty) {
      return trimmedAddress;
    }

    return postcodeArea.trim();
  }

  VanRouteStop copyWith({
    String? id,
    String? placeId,
    String? name,
    String? address,
    String? postcodeArea,
    String? deliveryNote,
    String? warningNote,
    VanPlaceType? placeType,
    double? latitude,
    double? longitude,
    int? routeOrder,
    VanRouteStopStatus? status,
    DateTime? completedAt,
    String? failureNote,
    bool? podRequired,
    bool clearCoordinates = false,
    bool clearCompletedAt = false,
  }) {
    return VanRouteStop(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      address: address ?? this.address,
      postcodeArea: postcodeArea ?? this.postcodeArea,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      warningNote: warningNote ?? this.warningNote,
      placeType: placeType ?? this.placeType,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      routeOrder: routeOrder ?? this.routeOrder,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      failureNote: failureNote ?? this.failureNote,
      podRequired: podRequired ?? this.podRequired,
    );
  }

  VanRouteStop syncWithPlace(VanPlace place) {
    return copyWith(
      placeId: place.id,
      name: place.name,
      address: place.address,
      postcodeArea: place.postcodeArea,
      deliveryNote: place.deliveryNote,
      warningNote: place.warningNote,
      placeType: place.placeType,
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'placeId': placeId,
      'name': name,
      'address': address,
      'postcodeArea': postcodeArea,
      'deliveryNote': deliveryNote,
      'warningNote': warningNote,
      'placeType': placeType.storageValue,
      'latitude': latitude,
      'longitude': longitude,
      'routeOrder': routeOrder,
      'status': status.storageValue,
      'completedAt': completedAt?.toIso8601String(),
      'failureNote': failureNote,
      'podRequired': podRequired,
    };
  }

  factory VanRouteStop.fromJson(Map<String, dynamic> json) {
    return VanRouteStop(
      id: _readString(json['id']),
      placeId: _readString(json['placeId']),
      name: _readString(json['name']),
      address: _readString(json['address']),
      postcodeArea: _readString(json['postcodeArea']),
      deliveryNote: _readString(json['deliveryNote']),
      warningNote: _readString(json['warningNote']),
      placeType: VanPlaceType.fromStorage(json['placeType']),
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      routeOrder: _readInt(json['routeOrder']),
      status: VanRouteStopStatus.fromStorage(json['status']),
      completedAt: _readDateTime(json['completedAt']),
      failureNote: _readString(json['failureNote']),
      podRequired: _readBool(json['podRequired']),
    );
  }

  static String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true';
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }

  static bool _hasValidLatitude(double? value) {
    return value != null && value >= -90 && value <= 90;
  }

  static bool _hasValidLongitude(double? value) {
    return value != null && value >= -180 && value <= 180;
  }
}
