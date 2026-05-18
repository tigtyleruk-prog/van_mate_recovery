import 'package:cloud_firestore/cloud_firestore.dart';

class VanCommunityReviewSubmission {
  final String id;
  final String submittedBy;
  final DateTime submittedAt;
  final String sourcePlaceId;
  final String placeName;
  final String dropName;
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
  final bool privateFieldDetected;

  const VanCommunityReviewSubmission({
    required this.id,
    required this.submittedBy,
    required this.submittedAt,
    required this.sourcePlaceId,
    required this.placeName,
    required this.dropName,
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
    required this.privateFieldDetected,
  });

  bool get hasExactPin => exactLat != 0 || exactLng != 0;

  factory VanCommunityReviewSubmission.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return VanCommunityReviewSubmission(
      id: snapshot.id,
      submittedBy: _readString(data['submittedBy']),
      submittedAt:
          _readDateTime(data['submittedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sourcePlaceId: _readString(data['sourcePlaceId']),
      placeName: _readString(
        data['placeName'],
        fallback: _readString(data['dropName']),
      ),
      dropName: _readString(data['dropName']),
      dropType: _readString(data['dropType']),
      postcodeArea: _readString(data['postcodeArea']),
      exactLat: _readDouble(data['exactLat']) ?? 0,
      exactLng: _readDouble(data['exactLng']) ?? 0,
      deliveryNote: _readString(data['deliveryNote']),
      warningNote: _readString(data['warningNote']),
      accessNote: _readString(data['accessNote']),
      status: _readString(data['status'], fallback: 'pending'),
      verifyCount: _readInt(data['verifyCount']),
      reportCount: _readInt(data['reportCount']),
      privateFieldDetected:
          data.containsKey('privateInfo') || data.containsKey('privateNotes'),
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

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }
}

class VanCommunityReviewDraft {
  final String placeName;
  final String dropType;
  final String postcodeArea;
  final String deliveryNote;
  final String warningNote;
  final String accessNote;

  const VanCommunityReviewDraft({
    required this.placeName,
    required this.dropType,
    required this.postcodeArea,
    required this.deliveryNote,
    required this.warningNote,
    required this.accessNote,
  });
}
