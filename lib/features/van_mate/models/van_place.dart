import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum VanPlaceType {
  shop('shop', 'Shop', Icons.storefront_outlined, Color(0xFF79A8FF)),
  business('business', 'Business', Icons.business_outlined, Color(0xFF63C7FF)),
  industrialUnit(
    'industrial_unit',
    'Industrial Unit',
    Icons.precision_manufacturing_outlined,
    Color(0xFFFFB15C),
  ),
  warehouse(
    'warehouse',
    'Warehouse',
    Icons.warehouse_outlined,
    Color(0xFF7D9DFF),
  ),
  office('office', 'Office', Icons.apartment_outlined, Color(0xFF71B6FF)),
  other('other', 'Other', Icons.place_outlined, Color(0xFF8EA7FF));

  const VanPlaceType(this.storageValue, this.label, this.icon, this.accent);

  final String storageValue;
  final String label;
  final IconData icon;
  final Color accent;

  static VanPlaceType fromStorage(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    for (final type in values) {
      if (type.storageValue == normalized) {
        return type;
      }
    }

    return VanPlaceType.other;
  }
}

class VanPlace {
  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String postcodeArea;
  final String deliveryNote;
  final String warningNote;
  final String privateInfo;
  final VanPlaceType placeType;
  final double? latitude;
  final double? longitude;
  final bool trustedExactPin;
  final DateTime? exactPinUpdatedAt;
  final String exactPinSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const VanPlace({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.postcodeArea,
    required this.deliveryNote,
    required this.warningNote,
    required this.privateInfo,
    required this.placeType,
    required this.latitude,
    required this.longitude,
    this.trustedExactPin = false,
    this.exactPinUpdatedAt,
    this.exactPinSource = '',
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasTrustedExactPin => trustedExactPin && hasCoordinates;

  String get bestLocationLabel {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isNotEmpty) {
      return trimmedAddress;
    }

    return postcodeArea.trim();
  }

  bool matchesQuery(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return _searchableText.contains(needle);
  }

  VanPlace copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? address,
    String? postcodeArea,
    String? deliveryNote,
    String? warningNote,
    String? privateInfo,
    VanPlaceType? placeType,
    double? latitude,
    double? longitude,
    bool? trustedExactPin,
    DateTime? exactPinUpdatedAt,
    String? exactPinSource,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool clearCoordinates = false,
  }) {
    return VanPlace(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      postcodeArea: postcodeArea ?? this.postcodeArea,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      warningNote: warningNote ?? this.warningNote,
      privateInfo: privateInfo ?? this.privateInfo,
      placeType: placeType ?? this.placeType,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      trustedExactPin: clearCoordinates
          ? false
          : (trustedExactPin ?? this.trustedExactPin),
      exactPinUpdatedAt: clearCoordinates
          ? null
          : (exactPinUpdatedAt ?? this.exactPinUpdatedAt),
      exactPinSource: clearCoordinates
          ? ''
          : (exactPinSource ?? this.exactPinSource),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'address': address,
      'postcodeArea': postcodeArea,
      'postcodeOrArea': postcodeArea,
      'deliveryNote': deliveryNote,
      'warningNote': warningNote,
      // Private driver notes. Do not include in future community-shared drop data.
      'privateInfo': privateInfo,
      'placeType': placeType.storageValue,
      'type': placeType.storageValue,
      'latitude': latitude,
      'longitude': longitude,
      'trustedExactPin': trustedExactPin,
      'exactPinUpdatedAt': exactPinUpdatedAt == null
          ? null
          : Timestamp.fromDate(exactPinUpdatedAt!),
      'exactPinSource': exactPinSource,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'ownerId': ownerId,
      'createdBy': createdBy,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'address': address,
      'postcodeArea': postcodeArea,
      'postcodeOrArea': postcodeArea,
      'deliveryNote': deliveryNote,
      'warningNote': warningNote,
      // Private driver notes. Do not include in future community-shared drop data.
      'privateInfo': privateInfo,
      'placeType': placeType.storageValue,
      'type': placeType.storageValue,
      'latitude': latitude,
      'longitude': longitude,
      'trustedExactPin': trustedExactPin,
      'exactPinUpdatedAt': exactPinUpdatedAt?.toIso8601String(),
      'exactPinSource': exactPinSource,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'ownerId': ownerId,
      'createdBy': createdBy,
    };
  }

  factory VanPlace.fromJson(Map<String, dynamic> json) {
    return VanPlace(
      id: _readString(json['id']),
      name: _readString(json['name']),
      address: _readString(json['address']),
      postcodeArea: _readString(
        json['postcodeArea'],
        fallback: _readString(json['postcodeOrArea']),
      ),
      deliveryNote: _readString(json['deliveryNote']),
      warningNote: _readString(json['warningNote']),
      privateInfo: _readString(json['privateInfo']),
      placeType: VanPlaceType.fromStorage(json['placeType'] ?? json['type']),
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      trustedExactPin: _readBool(
        json['trustedExactPin'] ?? json['exactPinTrusted'],
      ),
      exactPinUpdatedAt: _readDateTime(json['exactPinUpdatedAt']),
      exactPinSource: _readString(json['exactPinSource']),
      createdAt:
          _readDateTime(json['createdAt']) ??
          _readDateTime(json['updatedAt']) ??
          DateTime.now(),
      updatedAt:
          _readDateTime(json['updatedAt']) ??
          _readDateTime(json['createdAt']) ??
          DateTime.now(),
      ownerId: _readString(
        json['ownerId'],
        fallback: _readString(json['createdBy'], fallback: 'anonymous'),
      ),
      createdBy: _readString(json['createdBy'], fallback: 'anonymous'),
    );
  }

  factory VanPlace.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final updatedAt =
        _readDateTime(data['updatedAt']) ??
        _readDateTime(data['createdAt']) ??
        DateTime.now();

    return VanPlace(
      id: snapshot.id,
      name: _readString(data['name']),
      address: _readString(data['address']),
      postcodeArea: _readString(
        data['postcodeArea'],
        fallback: _readString(data['postcodeOrArea']),
      ),
      deliveryNote: _readString(data['deliveryNote']),
      warningNote: _readString(data['warningNote']),
      privateInfo: _readString(data['privateInfo']),
      placeType: VanPlaceType.fromStorage(data['placeType'] ?? data['type']),
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      trustedExactPin: _readBool(
        data['trustedExactPin'] ?? data['exactPinTrusted'],
      ),
      exactPinUpdatedAt: _readDateTime(data['exactPinUpdatedAt']),
      exactPinSource: _readString(data['exactPinSource']),
      createdAt: _readDateTime(data['createdAt']) ?? updatedAt,
      updatedAt: updatedAt,
      ownerId: _readString(
        data['ownerId'],
        fallback: _readString(data['createdBy'], fallback: 'anonymous'),
      ),
      createdBy: _readString(data['createdBy'], fallback: 'anonymous'),
    );
  }

  String get _searchableText {
    return <String>[
      name,
      address,
      postcodeArea,
      deliveryNote,
      warningNote,
      placeType.label,
      createdBy,
    ].join(' ').toLowerCase();
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final parsed = value?.toString().trim() ?? '';
    return parsed.isEmpty ? fallback : parsed;
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
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
}
