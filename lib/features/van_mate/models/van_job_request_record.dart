import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../helpers/van_text_formatters.dart';
import 'van_job_request_draft.dart';

const Duration vanJobRequestDefaultExpiry = Duration(days: 7);

String buildVanJobRequestLink(String requestId) {
  final normalizedId = requestId.trim();
  return 'vanmate://customer-request/$normalizedId';
}

String buildVanJobRequestShareMessage({
  required String requestLink,
  String jobTitle = '',
  String customerName = '',
  String address = '',
}) {
  final cleanedLink = requestLink.trim();
  final cleanedJobTitle = _shortRequestContext(jobTitle);
  final cleanedCustomerName = _shortRequestContext(customerName);
  final cleanedAddress = _shortRequestContext(address);

  final lines = <String>[
    'Hi, please fill in these job details for me so I can plan the job properly.',
    '',
    'It only takes a minute and helps me get the right access info and exact location/pin.',
  ];

  if (cleanedJobTitle.isNotEmpty) {
    lines.add('Job: $cleanedJobTitle');
  }
  if (cleanedCustomerName.isNotEmpty) {
    lines.add('Customer: $cleanedCustomerName');
  }
  if (cleanedAddress.isNotEmpty) {
    lines.add('Address: $cleanedAddress');
  }

  lines.add('');
  lines.add('Open request:');
  lines.add(cleanedLink);
  lines.add('');
  lines.add('Thanks.');

  return lines.join('\n');
}

String _shortRequestContext(String value, {int maxLength = 72}) {
  final cleaned = sanitizeVanText(value).trim();
  if (cleaned.length <= maxLength) {
    return cleaned;
  }

  return '${cleaned.substring(0, maxLength - 3).trimRight()}...';
}

String _readVanRequestText(dynamic value, {String fallback = ''}) {
  final parsed = value?.toString().trim() ?? '';
  return parsed.isEmpty ? fallback : parsed;
}

bool _readVanRequestBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true';
}

double? _readVanRequestDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

DateTime? _readVanRequestDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString().trim() ?? '');
}

List<String> _readVanRequestStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

@immutable
class VanJobRequestChecklistResponse {
  const VanJobRequestChecklistResponse({
    required this.question,
    required this.answer,
    this.note = '',
  });

  final String question;
  final String answer;
  final String note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question': question,
      'answer': answer,
      'note': note,
    };
  }

  factory VanJobRequestChecklistResponse.fromJson(Map<String, dynamic> json) {
    return VanJobRequestChecklistResponse(
      question: _readVanRequestText(json['question']),
      answer: _readVanRequestText(json['answer']),
      note: _readVanRequestText(json['note']),
    );
  }
}

@immutable
class VanJobRequestCustomQuestionResponse {
  const VanJobRequestCustomQuestionResponse({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question': question,
      'answer': answer,
    };
  }

  factory VanJobRequestCustomQuestionResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return VanJobRequestCustomQuestionResponse(
      question: _readVanRequestText(json['question']),
      answer: _readVanRequestText(json['answer']),
    );
  }
}

@immutable
class VanJobRequestRecord {
  const VanJobRequestRecord({
    required this.requestId,
    required this.ownerUid,
    required this.jobId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.publicJobTitle,
    required this.publicCustomerName,
    required this.publicAddressSummary,
    required this.checklistItems,
    required this.customQuestions,
    required this.exactPinRequested,
    this.scheduledAt,
    this.jobDateLabel = '',
    this.jobTimeLabel = '',
    this.publicPhoneNumber = '',
    this.publicCustomerEmail = '',
    this.driverMessagePreview = '',
    this.submittedAt,
    this.customerSubmittedAt,
    this.checklistResponses = const <VanJobRequestChecklistResponse>[],
    this.customQuestionResponses =
        const <VanJobRequestCustomQuestionResponse>[],
    this.additionalNotes = '',
    this.exactPinLat,
    this.exactPinLng,
    this.exactPinSource = '',
    this.exactPinNote = '',
    this.deleted = false,
    this.archived = false,
  });

  final String requestId;
  final String ownerUid;
  final String jobId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final DateTime? scheduledAt;
  final String jobDateLabel;
  final String jobTimeLabel;
  final String publicJobTitle;
  final String publicCustomerName;
  final String publicAddressSummary;
  final String publicPhoneNumber;
  final String publicCustomerEmail;
  final List<String> checklistItems;
  final List<String> customQuestions;
  final bool exactPinRequested;
  final String driverMessagePreview;
  final DateTime? submittedAt;
  final DateTime? customerSubmittedAt;
  final List<VanJobRequestChecklistResponse> checklistResponses;
  final List<VanJobRequestCustomQuestionResponse> customQuestionResponses;
  final String additionalNotes;
  final double? exactPinLat;
  final double? exactPinLng;
  final String exactPinSource;
  final String exactPinNote;
  final bool deleted;
  final bool archived;

  bool get isPending => status == 'pending';

  bool get isSubmitted => status == 'submitted';

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get hasReply =>
      checklistResponses.isNotEmpty ||
      customQuestionResponses.isNotEmpty ||
      additionalNotes.trim().isNotEmpty ||
      exactPinLat != null ||
      exactPinLng != null;

  bool get hasExactPin => exactPinLat != null && exactPinLng != null;

  VanJobRequestRecord copyWith({
    String? requestId,
    String? ownerUid,
    String? jobId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    DateTime? scheduledAt,
    String? jobDateLabel,
    String? jobTimeLabel,
    String? publicJobTitle,
    String? publicCustomerName,
    String? publicAddressSummary,
    String? publicPhoneNumber,
    String? publicCustomerEmail,
    List<String>? checklistItems,
    List<String>? customQuestions,
    bool? exactPinRequested,
    String? driverMessagePreview,
    DateTime? submittedAt,
    DateTime? customerSubmittedAt,
    List<VanJobRequestChecklistResponse>? checklistResponses,
    List<VanJobRequestCustomQuestionResponse>? customQuestionResponses,
    String? additionalNotes,
    double? exactPinLat,
    double? exactPinLng,
    String? exactPinSource,
    String? exactPinNote,
    bool? deleted,
    bool? archived,
  }) {
    return VanJobRequestRecord(
      requestId: requestId ?? this.requestId,
      ownerUid: ownerUid ?? this.ownerUid,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      jobDateLabel: jobDateLabel ?? this.jobDateLabel,
      jobTimeLabel: jobTimeLabel ?? this.jobTimeLabel,
      publicJobTitle: publicJobTitle ?? this.publicJobTitle,
      publicCustomerName: publicCustomerName ?? this.publicCustomerName,
      publicAddressSummary: publicAddressSummary ?? this.publicAddressSummary,
      publicPhoneNumber: publicPhoneNumber ?? this.publicPhoneNumber,
      publicCustomerEmail: publicCustomerEmail ?? this.publicCustomerEmail,
      checklistItems: checklistItems ?? this.checklistItems,
      customQuestions: customQuestions ?? this.customQuestions,
      exactPinRequested: exactPinRequested ?? this.exactPinRequested,
      driverMessagePreview: driverMessagePreview ?? this.driverMessagePreview,
      submittedAt: submittedAt ?? this.submittedAt,
      customerSubmittedAt: customerSubmittedAt ?? this.customerSubmittedAt,
      checklistResponses: checklistResponses ?? this.checklistResponses,
      customQuestionResponses:
          customQuestionResponses ?? this.customQuestionResponses,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      exactPinLat: exactPinLat ?? this.exactPinLat,
      exactPinLng: exactPinLng ?? this.exactPinLng,
      exactPinSource: exactPinSource ?? this.exactPinSource,
      exactPinNote: exactPinNote ?? this.exactPinNote,
      deleted: deleted ?? this.deleted,
      archived: archived ?? this.archived,
    );
  }

  VanJobRequestDraft toDraft() {
    return VanJobRequestDraft(
      jobId: jobId,
      customerName: publicCustomerName,
      phoneNumber: publicPhoneNumber,
      customerEmail: publicCustomerEmail,
      jobTitle: publicJobTitle,
      scheduledAt: scheduledAt ?? createdAt,
      jobDateLabel: jobDateLabel,
      jobTimeLabel: jobTimeLabel,
      address: publicAddressSummary,
      postcode: '',
      requestExactPin: exactPinRequested,
      checklistItems: List<String>.unmodifiable(checklistItems),
      customQuestions: List<String>.unmodifiable(customQuestions),
      notesMessage: driverMessagePreview,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'requestId': requestId,
      'ownerUid': ownerUid,
      'jobId': jobId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'jobDateLabel': jobDateLabel,
      'jobTimeLabel': jobTimeLabel,
      'publicJobTitle': publicJobTitle,
      'publicCustomerName': publicCustomerName,
      'publicAddressSummary': publicAddressSummary,
      'publicPhoneNumber': publicPhoneNumber,
      'publicCustomerEmail': publicCustomerEmail,
      'checklistItems': checklistItems,
      'customQuestions': customQuestions,
      'exactPinRequested': exactPinRequested,
      'driverMessagePreview': driverMessagePreview,
      'submittedAt': submittedAt == null ? null : Timestamp.fromDate(submittedAt!),
      'customerSubmittedAt': customerSubmittedAt == null
          ? null
          : Timestamp.fromDate(customerSubmittedAt!),
      'checklistResponses': checklistResponses.map((item) => item.toJson()).toList(),
      'customQuestionResponses': customQuestionResponses
          .map((item) => item.toJson())
          .toList(),
      'additionalNotes': additionalNotes,
      'exactPinLat': exactPinLat,
      'exactPinLng': exactPinLng,
      'exactPinSource': exactPinSource,
      'exactPinNote': exactPinNote,
      'deleted': deleted,
      'archived': archived,
    };
  }

  Map<String, dynamic> toPrivateFirestore() {
    return <String, dynamic>{
      'requestId': requestId,
      'ownerUid': ownerUid,
      'jobId': jobId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'submittedAt': submittedAt == null ? null : Timestamp.fromDate(submittedAt!),
      'customerSubmittedAt': customerSubmittedAt == null
          ? null
          : Timestamp.fromDate(customerSubmittedAt!),
      'hasReply': hasReply,
      'hasExactPin': hasExactPin,
      'exactPinSource': exactPinSource,
      'publicJobTitle': publicJobTitle,
      'publicCustomerName': publicCustomerName,
      'publicAddressSummary': publicAddressSummary,
      'exactPinRequested': exactPinRequested,
      'driverMessagePreview': driverMessagePreview,
      'checklistItemCount': checklistItems.length,
      'customQuestionCount': customQuestions.length,
      'deleted': deleted,
      'archived': archived,
    };
  }

  factory VanJobRequestRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _fromMap(snapshot.data() ?? <String, dynamic>{}, snapshot.id);
  }

  factory VanJobRequestRecord.fromJson(
    Map<String, dynamic> json, {
    String fallbackRequestId = '',
  }) {
    return _fromMap(json, fallbackRequestId);
  }

  static VanJobRequestRecord _fromMap(
    Map<String, dynamic> json,
    String fallbackRequestId,
  ) {
    final data = Map<String, dynamic>.from(json);
    final checklistJson = data['checklistResponses'];
    final customJson = data['customQuestionResponses'];
    final checklistResponses = checklistJson is List
        ? checklistJson
            .whereType<Map>()
            .map(
              (item) => VanJobRequestChecklistResponse.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <VanJobRequestChecklistResponse>[];
    final customResponses = customJson is List
        ? customJson
            .whereType<Map>()
            .map(
              (item) => VanJobRequestCustomQuestionResponse.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <VanJobRequestCustomQuestionResponse>[];

    return VanJobRequestRecord(
      requestId: _readVanRequestText(
        data['requestId'],
        fallback: fallbackRequestId,
      ),
      ownerUid: _readVanRequestText(data['ownerUid']),
      jobId: _readVanRequestText(data['jobId']),
      status: _readVanRequestText(data['status'], fallback: 'pending'),
      createdAt: _readVanRequestDateTime(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _readVanRequestDateTime(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: _readVanRequestDateTime(data['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      scheduledAt: _readVanRequestDateTime(data['scheduledAt']),
      jobDateLabel: _readVanRequestText(data['jobDateLabel']),
      jobTimeLabel: _readVanRequestText(data['jobTimeLabel']),
      publicJobTitle: _readVanRequestText(data['publicJobTitle']),
      publicCustomerName: _readVanRequestText(data['publicCustomerName']),
      publicAddressSummary: _readVanRequestText(data['publicAddressSummary']),
      publicPhoneNumber: _readVanRequestText(data['publicPhoneNumber']),
      publicCustomerEmail: _readVanRequestText(data['publicCustomerEmail']),
      checklistItems: _readVanRequestStringList(data['checklistItems']),
      customQuestions: _readVanRequestStringList(data['customQuestions']),
      exactPinRequested: _readVanRequestBool(data['exactPinRequested']),
      driverMessagePreview: _readVanRequestText(data['driverMessagePreview']),
      submittedAt: _readVanRequestDateTime(data['submittedAt']),
      customerSubmittedAt: _readVanRequestDateTime(data['customerSubmittedAt']),
      checklistResponses: checklistResponses,
      customQuestionResponses: customResponses,
      additionalNotes: _readVanRequestText(data['additionalNotes']),
      exactPinLat: _readVanRequestDouble(data['exactPinLat']),
      exactPinLng: _readVanRequestDouble(data['exactPinLng']),
      exactPinSource: _readVanRequestText(data['exactPinSource']),
      exactPinNote: _readVanRequestText(data['exactPinNote']),
      deleted: _readVanRequestBool(data['deleted']),
      archived: _readVanRequestBool(data['archived']),
    );
  }
}
