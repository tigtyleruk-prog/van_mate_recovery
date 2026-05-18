import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/van_place.dart';

class VanCommunityPlace {
  final String id;
  final String sourcePlaceId;
  final String placeName;
  final String dropType;
  final String postcodeArea;
  final double exactLat;
  final double exactLng;
  final String deliveryNote;
  final String warningNote;
  final String accessNote;
  final String status;
  final int verifyCount;
  final int reportCount;

  const VanCommunityPlace({
    required this.id,
    required this.sourcePlaceId,
    required this.placeName,
    required this.dropType,
    required this.postcodeArea,
    required this.exactLat,
    required this.exactLng,
    required this.deliveryNote,
    required this.warningNote,
    required this.accessNote,
    required this.status,
    required this.verifyCount,
    required this.reportCount,
  });

  bool get hasExactPin => exactLat != 0 || exactLng != 0;

  VanPlaceType get placeType => VanPlaceType.fromStorage(dropType);

  factory VanCommunityPlace.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return VanCommunityPlace(
      id: snapshot.id,
      sourcePlaceId: _readString(data['sourcePlaceId']),
      placeName: _readString(
        data['placeName'],
        fallback: _readString(data['dropName']),
      ),
      dropType: _readString(data['dropType'], fallback: 'other'),
      postcodeArea: _readString(
        data['postcodeArea'],
        fallback: _readString(data['postcodeOrArea']),
      ),
      exactLat: _readDouble(data['exactLat']) ?? 0,
      exactLng: _readDouble(data['exactLng']) ?? 0,
      deliveryNote: _readString(data['deliveryNote']),
      warningNote: _readString(data['warningNote']),
      accessNote: _readString(data['accessNote']),
      status: _readString(data['status'], fallback: 'approved'),
      verifyCount: _readInt(data['verifyCount']),
      reportCount: _readInt(data['reportCount']),
    );
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

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
}

