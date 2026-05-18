import 'package:cloud_firestore/cloud_firestore.dart';

class VanCommunityPlaceSubmission {
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
  final String status;
  final int verifyCount;
  final int reportCount;

  const VanCommunityPlaceSubmission({
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
    this.status = 'pending',
    this.verifyCount = 0,
    this.reportCount = 0,
  });

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'submittedBy': submittedBy,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'sourcePlaceId': sourcePlaceId,
      'placeName': placeName,
      'dropName': dropName,
      'dropType': dropType,
      'postcodeArea': postcodeArea,
      'exactLat': exactLat,
      'exactLng': exactLng,
      'deliveryNote': deliveryNote,
      'warningNote': warningNote,
      'status': status,
      'verifyCount': verifyCount,
      'reportCount': reportCount,
    };
  }
}
