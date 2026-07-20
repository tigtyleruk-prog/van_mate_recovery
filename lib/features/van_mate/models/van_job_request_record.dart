import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_job_request_state.dart';
import '../helpers/van_quote_decline.dart';
import '../helpers/van_text_formatters.dart';
import 'van_job_request_draft.dart';

const Duration vanJobRequestDefaultExpiry = Duration(days: 7);
const String vanJobRequestHostedBaseUrl = 'https://vanmate-56eac.web.app';
const String vanQuoteResponseHostedBaseUrl = 'https://vanmate-56eac.web.app';

String normalizeVanJobRequestShortCode(String value) {
  return value.trim().toUpperCase();
}

String buildVanJobRequestLink(String requestId, {String shortCode = ''}) {
  return buildVanJobRequestHostedLink(requestId, shortCode: shortCode);
}

String buildVanJobRequestHostedLink(String requestId, {String shortCode = ''}) {
  final normalizedShortCode = normalizeVanJobRequestShortCode(shortCode);
  if (normalizedShortCode.isNotEmpty) {
    return '$vanJobRequestHostedBaseUrl/r/$normalizedShortCode';
  }

  final normalizedId = requestId.trim();
  return '$vanJobRequestHostedBaseUrl/request.html?id=$normalizedId';
}

String buildVanQuoteResponseLink(String quoteId) {
  return buildVanQuoteResponseHostedLink(quoteId);
}

String buildVanQuoteResponseToken(String quoteId) {
  final normalizedId = quoteId.trim();
  if (normalizedId.isEmpty) {
    return '';
  }
  final digest = sha256.convert(
    utf8.encode('vanmate_quote_response:$normalizedId'),
  );
  return digest.toString().substring(0, 12);
}

String buildVanLegacyQuoteResponseLink(String quoteId) {
  final normalizedId = quoteId.trim();
  if (normalizedId.isEmpty) {
    return '';
  }
  return '$vanQuoteResponseHostedBaseUrl/quote_response.html?id=$normalizedId';
}

String buildVanQuoteResponseHostedLink(String quoteToken) {
  final normalizedToken = quoteToken.trim();
  if (normalizedToken.isEmpty) {
    return '';
  }
  return '$vanQuoteResponseHostedBaseUrl/quote/$normalizedToken';
}

String resolveVanQuoteResponseDisplayLink({
  String quoteResponseLink = '',
  String quoteResponseToken = '',
  String quoteId = '',
}) {
  final normalizedToken = quoteResponseToken.trim();
  if (normalizedToken.isNotEmpty) {
    return buildVanQuoteResponseHostedLink(normalizedToken);
  }

  final cleanedLink = quoteResponseLink.trim();
  if (cleanedLink.startsWith('http://') || cleanedLink.startsWith('https://')) {
    return cleanedLink;
  }

  final normalizedQuoteId = quoteId.trim();
  if (normalizedQuoteId.isNotEmpty) {
    return buildVanLegacyQuoteResponseLink(normalizedQuoteId);
  }

  return '';
}

String buildVanQuoteMessage({
  required String customerName,
  required String jobTitle,
  required String quoteAmountText,
  required String quoteResponseLink,
  String businessName = '',
  String proposedAppointmentText = '',
}) {
  final cleanedCustomerName = sanitizeVanText(customerName).trim();
  final cleanedJobTitle = sanitizeVanText(jobTitle).trim();
  final cleanedQuoteAmount = sanitizeVanText(quoteAmountText).trim();
  final cleanedBusinessName = sanitizeVanText(businessName).trim();
  final cleanedQuoteResponseLink = quoteResponseLink.trim();
  final cleanedProposedAppointmentText = sanitizeVanText(
    proposedAppointmentText,
  ).trim();

  final lines = <String>[
    cleanedCustomerName.isNotEmpty ? 'Hi $cleanedCustomerName,' : 'Hi,',
    '',
    "Here's your quote for the ${cleanedJobTitle.toLowerCase()} job.",
    '',
    'Quote: $cleanedQuoteAmount',
  ];
  if (cleanedProposedAppointmentText.isNotEmpty) {
    lines.add('Proposed appointment: $cleanedProposedAppointmentText');
  }
  if (cleanedQuoteResponseLink.isNotEmpty) {
    lines.add('');
    lines.add('Review and respond here:');
    lines.add(cleanedQuoteResponseLink);
  }
  lines.add('');
  lines.add(cleanedBusinessName.isNotEmpty ? 'Thanks,' : 'Thanks.');
  if (cleanedBusinessName.isNotEmpty) {
    lines.add(cleanedBusinessName);
  }

  return normalizeOutgoingRequestMessage(lines.join('\n'));
}

String buildVanJobRequestTestLink(String requestId) {
  final normalizedId = requestId.trim();
  return 'vanmate://customer-request/$normalizedId';
}

String extractVanJobRequestShortCodeFromLink(String requestLink) {
  final cleanedLink = requestLink.trim();
  if (cleanedLink.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(cleanedLink);
  if (uri == null) {
    return '';
  }

  final segments = uri.pathSegments;
  if (segments.length < 2 || segments.first.toLowerCase() != 'r') {
    return '';
  }

  return normalizeVanJobRequestShortCode(Uri.decodeComponent(segments[1]));
}

String resolveVanJobRequestDisplayLink({
  required String requestId,
  required String requestLink,
  String shortCode = '',
}) {
  final normalizedShortCode = normalizeVanJobRequestShortCode(shortCode);
  if (normalizedShortCode.isNotEmpty) {
    return buildVanJobRequestHostedLink(
      requestId,
      shortCode: normalizedShortCode,
    );
  }

  final cleanedLink = requestLink.trim();
  if (cleanedLink.isEmpty) {
    return buildVanJobRequestHostedLink(requestId);
  }

  if (cleanedLink.startsWith('http://') || cleanedLink.startsWith('https://')) {
    return cleanedLink;
  }

  return buildVanJobRequestHostedLink(requestId);
}

String buildVanJobRequestShareMessage({
  required String requestLink,
  String jobTitle = '',
  String customerName = '',
  String businessName = '',
  String address = '',
  bool exactPinRequested = false,
  bool exactPinRequestedAfterQuoteAccepted = false,
}) {
  return buildRequestShareMessage(
    link: requestLink,
    customerName: customerName,
    jobTitle: jobTitle,
    businessName: businessName,
    address: address,
    exactPinRequested: exactPinRequested,
    exactPinRequestedAfterQuoteAccepted: exactPinRequestedAfterQuoteAccepted,
  );
}

String buildCustomerRequestMessage({
  required String requestLink,
  String jobTitle = '',
  String customerName = '',
  String businessName = '',
  String address = '',
  bool exactPinRequested = false,
  bool exactPinRequestedAfterQuoteAccepted = false,
}) {
  return buildRequestShareMessage(
    link: requestLink,
    customerName: customerName,
    jobTitle: jobTitle,
    businessName: businessName,
    address: address,
    exactPinRequested: exactPinRequested,
    exactPinRequestedAfterQuoteAccepted: exactPinRequestedAfterQuoteAccepted,
  );
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

bool vanJobRequestIsCollectionOrder(Map<String, dynamic> data) {
  final requestType = _readVanRequestText(
    data['requestType'],
  ).trim().toLowerCase();
  final fulfilmentType = _readVanRequestText(
    data['fulfilmentType'],
  ).trim().toLowerCase();
  return requestType == 'orderrequest' && fulfilmentType == 'collection';
}

bool vanJobRequestIsDropOffPickup(Map<String, dynamic> data) =>
    _readVanRequestText(data['requestType']).trim().toLowerCase() ==
    'dropoffpickuprequest';

bool vanJobRequestRequiresExactPinAfterQuoteAccepted(
  Map<String, dynamic> data,
) {
  if (vanJobRequestIsCollectionOrder(data)) {
    return false;
  }
  return _readVanRequestBool(data['requiresExactPinAfterQuoteAccepted']) ||
      _readVanRequestBool(data['exactPinRequestedAfterQuote']) ||
      _readVanRequestBool(data['exactPinRequiredAfterQuoteAccepted']) ||
      _readVanRequestBool(data['requiresExactPinAfterQuoteAcceptance']);
}

double? _readVanRequestDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

int? _readVanRequestInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString().trim() ?? '');
}

DateTime? _readVanRequestDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString().trim() ?? '');
}

DateTime? _combineVanRequestDateAndTime(DateTime? date, String time) {
  if (date == null) {
    return null;
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time.trim());
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
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
    return <String, dynamic>{'question': question, 'answer': answer};
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
class VanJobRequestAnswer {
  const VanJobRequestAnswer({
    required this.questionId,
    required this.questionText,
    required this.answerType,
    required this.category,
    required this.answerValue,
    this.order = 0,
  });

  final String questionId;
  final String questionText;
  final String answerType;
  final String category;
  final String answerValue;
  final int order;

  bool get hasAnswer => answerValue.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'questionId': questionId,
      'questionText': questionText,
      'type': answerType,
      'answerType': answerType,
      'category': category,
      'answer': answerValue,
      'answerValue': answerValue,
      'order': order,
    };
  }

  factory VanJobRequestAnswer.fromJson(Map<String, dynamic> json) {
    int readOrder(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.round();
      }
      return int.tryParse(value?.toString().trim() ?? '') ?? 0;
    }

    return VanJobRequestAnswer(
      questionId: _readVanRequestText(json['questionId']),
      questionText: _readVanRequestText(json['questionText']),
      answerType: _readVanRequestText(
        json['answerType'],
        fallback: _readVanRequestText(json['type']),
      ),
      category: _readVanRequestText(json['category']),
      answerValue: _readVanRequestText(
        json['answerValue'],
        fallback: _readVanRequestText(json['answer']),
      ),
      order: readOrder(json['order']),
    );
  }
}

@immutable
class VanJobRequestPhoto {
  const VanJobRequestPhoto({
    required this.url,
    required this.storagePath,
    required this.fileName,
    required this.uploadedAt,
  });

  final String url;
  final String storagePath;
  final String fileName;
  final DateTime? uploadedAt;

  bool get hasUrl => url.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'storagePath': storagePath,
      'fileName': fileName,
      'uploadedAt': uploadedAt?.toIso8601String(),
    };
  }

  factory VanJobRequestPhoto.fromJson(Map<String, dynamic> json) {
    return VanJobRequestPhoto(
      url: _readVanRequestText(
        json['url'],
        fallback: _readVanRequestText(
          json['downloadUrl'],
          fallback: _readVanRequestText(json['downloadURL']),
        ),
      ),
      storagePath: _readVanRequestText(
        json['storagePath'],
        fallback: _readVanRequestText(json['path']),
      ),
      fileName: _readVanRequestText(
        json['fileName'],
        fallback: _readVanRequestText(json['name']),
      ),
      uploadedAt: _readVanRequestDateTime(json['uploadedAt']),
    );
  }
}

@immutable
class VanJobRequestRecord {
  const VanJobRequestRecord({
    required this.requestId,
    required this.ownerUid,
    required this.jobId,
    required this.linkedJobId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.shortCode = '',
    required this.publicJobTitle,
    required this.publicCustomerName,
    required this.publicAddressSummary,
    required this.checklistItems,
    required this.customQuestions,
    required this.exactPinRequested,
    this.requestPhotos = false,
    this.requiresExactPinAfterQuoteAccepted = false,
    this.scheduledAt,
    this.jobDateLabel = '',
    this.jobTimeLabel = '',
    this.scheduledDate = '',
    this.scheduledStartTime = '',
    this.estimatedDurationMinutes,
    this.calendarStatus = 'unscheduled',
    this.locationPending = false,
    this.quoteTimingChoice = '',
    this.agreedDateTime,
    this.agreedStartAt,
    this.agreedEndAt,
    this.agreedDurationMinutes,
    this.acceptedProposedTime = false,
    this.timeAgreed = false,
    this.readyForCalendar = false,
    this.needsAgreedTime = false,
    this.timeStatus = '',
    this.timingStatus = '',
    this.schedulingStatus = '',
    this.declineReasonCode = '',
    this.declineReasonLabel = '',
    this.declineReasonText = '',
    this.declineNote = '',
    this.declinedAt,
    this.declinedBy = '',
    this.preferredDate,
    this.preferredTimeWindow = '',
    this.preferredIsFlexible = false,
    this.preferredTimingNote = '',
    this.preferredTimingDecision = '',
    this.suggestedDate,
    this.suggestedTimeWindow = '',
    this.publicPhoneNumber = '',
    this.publicCustomerEmail = '',
    this.customerPostcode = '',
    this.source = '',
    this.isPreview = false,
    this.sourceLabel = '',
    this.selectedServiceId = '',
    this.selectedServiceName = '',
    this.requestType = 'quoteRequest',
    this.customerJourneyType = 'quote',
    this.startHandover = '',
    this.endHandover = '',
    this.allowedStartHandoverOptions = const <String>[],
    this.allowedEndHandoverOptions = const <String>[],
    this.collectionAddress = '',
    this.returnAddress = '',
    this.returnAddressSameAsCollection = false,
    this.businessDropOffInstructions = '',
    this.businessCollectionInstructions = '',
    this.fulfilmentType = '',
    this.dropOffDate,
    this.dropOffTime = '',
    this.pickUpDate,
    this.pickUpTime = '',
    this.driverMessagePreview = '',
    this.submittedAt,
    this.customerSubmittedAt,
    this.requestSubmittedAt,
    this.replyReceivedAt,
    this.checklistResponses = const <VanJobRequestChecklistResponse>[],
    this.customQuestionResponses =
        const <VanJobRequestCustomQuestionResponse>[],
    this.answers = const <VanJobRequestAnswer>[],
    this.photos = const <VanJobRequestPhoto>[],
    this.additionalNotes = '',
    this.exactPinLat,
    this.exactPinLng,
    this.exactPinLatitude,
    this.exactPinLongitude,
    this.exactPinSource = '',
    this.exactPinNote = '',
    this.isTestData = false,
    this.testMode = false,
    this.deleted = false,
    this.archived = false,
  });

  final String requestId;
  final String ownerUid;
  final String jobId;
  final String linkedJobId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String shortCode;
  final DateTime? scheduledAt;
  final String jobDateLabel;
  final String jobTimeLabel;
  final String scheduledDate;
  final String scheduledStartTime;
  final int? estimatedDurationMinutes;
  final String calendarStatus;
  final bool locationPending;
  final String quoteTimingChoice;
  final DateTime? agreedDateTime;
  final DateTime? agreedStartAt;
  final DateTime? agreedEndAt;
  final int? agreedDurationMinutes;
  final bool acceptedProposedTime;
  final bool timeAgreed;
  final bool readyForCalendar;
  final bool needsAgreedTime;
  final String timeStatus;
  final String timingStatus;
  final String schedulingStatus;
  final String declineReasonCode;
  final String declineReasonLabel;
  final String declineReasonText;
  final String declineNote;
  final DateTime? declinedAt;
  final String declinedBy;
  final DateTime? preferredDate;
  final String preferredTimeWindow;
  final bool preferredIsFlexible;
  final String preferredTimingNote;
  final String preferredTimingDecision;
  final DateTime? suggestedDate;
  final String suggestedTimeWindow;
  final String publicJobTitle;
  final String publicCustomerName;
  final String publicAddressSummary;
  final String publicPhoneNumber;
  final String publicCustomerEmail;
  final String customerPostcode;
  final String source;
  final bool isPreview;
  final String sourceLabel;
  final String selectedServiceId;
  final String selectedServiceName;
  final String requestType;
  final String customerJourneyType;
  final String startHandover;
  final String endHandover;
  final List<String> allowedStartHandoverOptions;
  final List<String> allowedEndHandoverOptions;
  final String collectionAddress;
  final String returnAddress;
  final bool returnAddressSameAsCollection;
  final String businessDropOffInstructions;
  final String businessCollectionInstructions;
  final String fulfilmentType;
  final DateTime? dropOffDate;
  final String dropOffTime;
  final DateTime? pickUpDate;
  final String pickUpTime;
  final List<String> checklistItems;
  final List<String> customQuestions;
  final bool exactPinRequested;
  final bool requestPhotos;
  final bool requiresExactPinAfterQuoteAccepted;
  final String driverMessagePreview;
  final DateTime? submittedAt;
  final DateTime? customerSubmittedAt;
  final DateTime? requestSubmittedAt;
  final DateTime? replyReceivedAt;
  final List<VanJobRequestChecklistResponse> checklistResponses;
  final List<VanJobRequestCustomQuestionResponse> customQuestionResponses;
  final List<VanJobRequestAnswer> answers;
  final List<VanJobRequestPhoto> photos;
  final String additionalNotes;
  final double? exactPinLat;
  final double? exactPinLng;
  final double? exactPinLatitude;
  final double? exactPinLongitude;
  final String exactPinSource;
  final String exactPinNote;
  final bool isTestData;
  final bool testMode;
  final bool deleted;
  final bool archived;

  bool get isMarkedTestData => isTestData || testMode;

  bool get isHiddenFromNormalLists =>
      deleted || archived || normalizeVanJobRequestStatus(status) == 'deleted';

  String get quoteDeclineReasonCodeValue => declineReasonCode.trim();

  String get quoteDeclineReasonCode => quoteDeclineReasonCodeValue;

  String get quoteDeclineReasonValue {
    final label = declineReasonLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    final text = declineReasonText.trim();
    return text;
  }

  String get quoteDeclineReason => quoteDeclineReasonValue;

  String get quoteDeclineReasonLabelValue => declineReasonLabel.trim();

  String get quoteDeclineReasonLabel => quoteDeclineReasonLabelValue;

  String get quoteDeclineNoteValue {
    final note = declineNote.trim();
    if (note.isNotEmpty) {
      return note;
    }
    return declineReasonText.trim();
  }

  String get quoteDeclineNote => quoteDeclineNoteValue;

  String get lastQuoteDeclineReason => quoteDeclineReasonValue;

  String get lastQuoteDeclineNote => quoteDeclineNoteValue;

  bool get isPending =>
      !isHiddenFromNormalLists &&
      normalizeVanJobRequestStatus(status) == 'request_sent';

  bool get isSubmitted =>
      !isHiddenFromNormalLists &&
      normalizeVanJobRequestStatus(status) == 'reply_received';

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get hasRequestBeenSent =>
      !isHiddenFromNormalLists && vanJobRequestHasBeenSent(status);

  bool get hasReply => hasCustomerReply;

  bool get hasCustomerReply =>
      !isHiddenFromNormalLists &&
      vanJobRequestHasCustomerReply(
        status: status,
        replyReceivedAt: replyReceivedAt ?? customerSubmittedAt ?? submittedAt,
        requestSubmittedAt:
            requestSubmittedAt ?? submittedAt ?? customerSubmittedAt,
        hasChecklistResponses: checklistResponses.any(
          (item) =>
              item.answer.trim().isNotEmpty || item.note.trim().isNotEmpty,
        ),
        hasCustomQuestionResponses: customQuestionResponses.any(
          (item) => item.answer.trim().isNotEmpty,
        ),
        hasAdditionalNotes: additionalNotes.trim().isNotEmpty,
      );

  bool get hasExactPin =>
      hasCustomerReply && exactPinLat != null && exactPinLng != null;

  bool get isDropOffPickupRequest =>
      requestType.trim().toLowerCase() == 'dropoffpickuprequest';

  bool get requiresAnyExactPin => isDropOffPickupRequest
      ? requiresExactPinAfterQuoteAccepted
      : exactPinRequested || requiresExactPinAfterQuoteAccepted;

  bool get hasLocationDetails =>
      publicAddressSummary.trim().isNotEmpty ||
      customerPostcode.trim().isNotEmpty;

  bool get canCreateQuote => hasCustomerReply;

  DateTime? get agreedStartAtOrParsed => agreedStartAt ?? agreedDateTime;

  DateTime? get agreedEndAtOrParsed => agreedEndAt;

  DateTime? get dropOffDateTime =>
      _combineVanRequestDateAndTime(dropOffDate, dropOffTime);

  DateTime? get pickUpDateTime =>
      _combineVanRequestDateAndTime(pickUpDate, pickUpTime);

  int? get dropOffPickupDurationMinutes {
    final start = dropOffDateTime;
    final end = pickUpDateTime;
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    return end.difference(start).inMinutes;
  }

  bool get hasAgreedSchedulingTime {
    if (isDropOffPickupRequest &&
        dropOffDateTime != null &&
        pickUpDateTime != null) {
      return true;
    }
    final explicitAgreedTime = agreedStartAt ?? agreedDateTime;
    if (explicitAgreedTime != null) {
      return true;
    }
    final hasAcceptedProposedTime =
        acceptedProposedTime ||
        quoteTimingChoice.trim().toLowerCase() == 'accepted_proposed_time';
    if (hasAcceptedProposedTime && scheduledAt != null) {
      return true;
    }
    return false;
  }

  bool get isReadyForCalendar =>
      readyForCalendar ||
      (hasAgreedSchedulingTime &&
          !needsAgreedTime &&
          (!requiresAnyExactPin || hasExactPin) &&
          calendarStatus.trim().toLowerCase() != 'scheduled' &&
          calendarStatus.trim().toLowerCase() != 'completed');

  VanJobRequestRecord copyWith({
    String? requestId,
    String? ownerUid,
    String? jobId,
    String? linkedJobId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? shortCode,
    DateTime? scheduledAt,
    String? jobDateLabel,
    String? jobTimeLabel,
    String? scheduledDate,
    String? scheduledStartTime,
    int? estimatedDurationMinutes,
    String? calendarStatus,
    bool? locationPending,
    String? quoteTimingChoice,
    DateTime? agreedDateTime,
    DateTime? agreedStartAt,
    DateTime? agreedEndAt,
    int? agreedDurationMinutes,
    bool? acceptedProposedTime,
    bool? timeAgreed,
    bool? readyForCalendar,
    bool? needsAgreedTime,
    String? timeStatus,
    String? timingStatus,
    String? schedulingStatus,
    String? declineReasonCode,
    String? declineReasonLabel,
    String? declineReasonText,
    String? declineNote,
    DateTime? declinedAt,
    String? declinedBy,
    DateTime? preferredDate,
    String? preferredTimeWindow,
    bool? preferredIsFlexible,
    String? preferredTimingNote,
    String? preferredTimingDecision,
    DateTime? suggestedDate,
    String? suggestedTimeWindow,
    String? publicJobTitle,
    String? publicCustomerName,
    String? publicAddressSummary,
    String? publicPhoneNumber,
    String? publicCustomerEmail,
    String? customerPostcode,
    String? source,
    bool? isPreview,
    String? sourceLabel,
    String? selectedServiceId,
    String? selectedServiceName,
    String? requestType,
    String? customerJourneyType,
    String? startHandover,
    String? endHandover,
    List<String>? allowedStartHandoverOptions,
    List<String>? allowedEndHandoverOptions,
    String? collectionAddress,
    String? returnAddress,
    bool? returnAddressSameAsCollection,
    String? businessDropOffInstructions,
    String? businessCollectionInstructions,
    String? fulfilmentType,
    DateTime? dropOffDate,
    String? dropOffTime,
    DateTime? pickUpDate,
    String? pickUpTime,
    List<String>? checklistItems,
    List<String>? customQuestions,
    bool? exactPinRequested,
    bool? requestPhotos,
    bool? requiresExactPinAfterQuoteAccepted,
    String? driverMessagePreview,
    DateTime? submittedAt,
    DateTime? customerSubmittedAt,
    DateTime? requestSubmittedAt,
    DateTime? replyReceivedAt,
    List<VanJobRequestChecklistResponse>? checklistResponses,
    List<VanJobRequestCustomQuestionResponse>? customQuestionResponses,
    List<VanJobRequestAnswer>? answers,
    List<VanJobRequestPhoto>? photos,
    String? additionalNotes,
    double? exactPinLat,
    double? exactPinLng,
    double? exactPinLatitude,
    double? exactPinLongitude,
    String? exactPinSource,
    String? exactPinNote,
    bool? isTestData,
    bool? testMode,
    bool? deleted,
    bool? archived,
  }) {
    return VanJobRequestRecord(
      requestId: requestId ?? this.requestId,
      ownerUid: ownerUid ?? this.ownerUid,
      jobId: jobId ?? this.jobId,
      linkedJobId: linkedJobId ?? this.linkedJobId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      shortCode: shortCode ?? this.shortCode,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      jobDateLabel: jobDateLabel ?? this.jobDateLabel,
      jobTimeLabel: jobTimeLabel ?? this.jobTimeLabel,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      calendarStatus: calendarStatus ?? this.calendarStatus,
      locationPending: locationPending ?? this.locationPending,
      quoteTimingChoice: quoteTimingChoice ?? this.quoteTimingChoice,
      agreedDateTime: agreedDateTime ?? this.agreedDateTime,
      agreedStartAt: agreedStartAt ?? this.agreedStartAt,
      agreedEndAt: agreedEndAt ?? this.agreedEndAt,
      agreedDurationMinutes:
          agreedDurationMinutes ?? this.agreedDurationMinutes,
      acceptedProposedTime: acceptedProposedTime ?? this.acceptedProposedTime,
      timeAgreed: timeAgreed ?? this.timeAgreed,
      readyForCalendar: readyForCalendar ?? this.readyForCalendar,
      needsAgreedTime: needsAgreedTime ?? this.needsAgreedTime,
      timeStatus: timeStatus ?? this.timeStatus,
      timingStatus: timingStatus ?? this.timingStatus,
      schedulingStatus: schedulingStatus ?? this.schedulingStatus,
      declineReasonCode: declineReasonCode ?? this.declineReasonCode,
      declineReasonLabel: declineReasonLabel ?? this.declineReasonLabel,
      declineReasonText: declineReasonText ?? this.declineReasonText,
      declineNote: declineNote ?? this.declineNote,
      declinedAt: declinedAt ?? this.declinedAt,
      declinedBy: declinedBy ?? this.declinedBy,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeWindow: preferredTimeWindow ?? this.preferredTimeWindow,
      preferredIsFlexible: preferredIsFlexible ?? this.preferredIsFlexible,
      preferredTimingNote: preferredTimingNote ?? this.preferredTimingNote,
      preferredTimingDecision:
          preferredTimingDecision ?? this.preferredTimingDecision,
      suggestedDate: suggestedDate ?? this.suggestedDate,
      suggestedTimeWindow: suggestedTimeWindow ?? this.suggestedTimeWindow,
      publicJobTitle: publicJobTitle ?? this.publicJobTitle,
      publicCustomerName: publicCustomerName ?? this.publicCustomerName,
      publicAddressSummary: publicAddressSummary ?? this.publicAddressSummary,
      publicPhoneNumber: publicPhoneNumber ?? this.publicPhoneNumber,
      publicCustomerEmail: publicCustomerEmail ?? this.publicCustomerEmail,
      customerPostcode: customerPostcode ?? this.customerPostcode,
      source: source ?? this.source,
      isPreview: isPreview ?? this.isPreview,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      selectedServiceId: selectedServiceId ?? this.selectedServiceId,
      selectedServiceName: selectedServiceName ?? this.selectedServiceName,
      requestType: requestType ?? this.requestType,
      customerJourneyType: customerJourneyType ?? this.customerJourneyType,
      startHandover: startHandover ?? this.startHandover,
      endHandover: endHandover ?? this.endHandover,
      allowedStartHandoverOptions:
          allowedStartHandoverOptions ?? this.allowedStartHandoverOptions,
      allowedEndHandoverOptions:
          allowedEndHandoverOptions ?? this.allowedEndHandoverOptions,
      collectionAddress: collectionAddress ?? this.collectionAddress,
      returnAddress: returnAddress ?? this.returnAddress,
      returnAddressSameAsCollection:
          returnAddressSameAsCollection ?? this.returnAddressSameAsCollection,
      businessDropOffInstructions:
          businessDropOffInstructions ?? this.businessDropOffInstructions,
      businessCollectionInstructions:
          businessCollectionInstructions ?? this.businessCollectionInstructions,
      fulfilmentType: fulfilmentType ?? this.fulfilmentType,
      dropOffDate: dropOffDate ?? this.dropOffDate,
      dropOffTime: dropOffTime ?? this.dropOffTime,
      pickUpDate: pickUpDate ?? this.pickUpDate,
      pickUpTime: pickUpTime ?? this.pickUpTime,
      checklistItems: checklistItems ?? this.checklistItems,
      customQuestions: customQuestions ?? this.customQuestions,
      exactPinRequested: exactPinRequested ?? this.exactPinRequested,
      requestPhotos: requestPhotos ?? this.requestPhotos,
      requiresExactPinAfterQuoteAccepted:
          requiresExactPinAfterQuoteAccepted ??
          this.requiresExactPinAfterQuoteAccepted,
      driverMessagePreview: driverMessagePreview ?? this.driverMessagePreview,
      submittedAt: submittedAt ?? this.submittedAt,
      customerSubmittedAt: customerSubmittedAt ?? this.customerSubmittedAt,
      requestSubmittedAt: requestSubmittedAt ?? this.requestSubmittedAt,
      replyReceivedAt: replyReceivedAt ?? this.replyReceivedAt,
      checklistResponses: checklistResponses ?? this.checklistResponses,
      customQuestionResponses:
          customQuestionResponses ?? this.customQuestionResponses,
      answers: answers ?? this.answers,
      photos: photos ?? this.photos,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      exactPinLat: exactPinLat ?? this.exactPinLat,
      exactPinLng: exactPinLng ?? this.exactPinLng,
      exactPinLatitude: exactPinLatitude ?? this.exactPinLatitude,
      exactPinLongitude: exactPinLongitude ?? this.exactPinLongitude,
      exactPinSource: exactPinSource ?? this.exactPinSource,
      exactPinNote: exactPinNote ?? this.exactPinNote,
      isTestData: isTestData ?? this.isTestData,
      testMode: testMode ?? this.testMode,
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
      scheduledDate: scheduledDate,
      scheduledStartTime: scheduledStartTime,
      estimatedDurationMinutes: estimatedDurationMinutes,
      calendarStatus: calendarStatus,
      locationPending: locationPending,
      address: publicAddressSummary,
      postcode: customerPostcode,
      requestExactPin: exactPinRequested,
      requestPhotos: requestPhotos,
      requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
      selectedServiceId: selectedServiceId,
      selectedServiceName: selectedServiceName,
      requestType: requestType,
      customerJourneyType: customerJourneyType,
      startHandover: startHandover,
      endHandover: endHandover,
      allowedStartHandoverOptions: allowedStartHandoverOptions,
      allowedEndHandoverOptions: allowedEndHandoverOptions,
      collectionAddress: collectionAddress,
      returnAddress: returnAddress,
      returnAddressSameAsCollection: returnAddressSameAsCollection,
      businessDropOffInstructions: businessDropOffInstructions,
      businessCollectionInstructions: businessCollectionInstructions,
      dropOffDate: dropOffDate,
      dropOffTime: dropOffTime,
      pickUpDate: pickUpDate,
      pickUpTime: pickUpTime,
      selectedQuestionIds: List<String>.unmodifiable(
        answers
            .map((item) => item.questionId.trim())
            .where((id) => id.isNotEmpty)
            .toList(growable: false),
      ),
      answers: List<VanJobRequestAnswer>.unmodifiable(answers),
      checklistItems: List<String>.unmodifiable(checklistItems),
      customQuestions: List<String>.unmodifiable(customQuestions),
      notesMessage: driverMessagePreview,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'requestId': requestId,
      'ownerUid': ownerUid,
      'jobId': jobId,
      'linkedJobId': linkedJobId,
      'shortCode': normalizeVanJobRequestShortCode(shortCode),
      'status': status,
      'requestStatus': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      'jobDateLabel': jobDateLabel,
      'jobTimeLabel': jobTimeLabel,
      'scheduledDate': scheduledDate,
      'scheduledStartTime': scheduledStartTime,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'calendarStatus': calendarStatus,
      'locationPending': locationPending,
      'quoteTimingChoice': quoteTimingChoice,
      'agreedDateTime': agreedDateTime?.toIso8601String(),
      'agreedStartAt': agreedStartAt?.toIso8601String(),
      'agreedEndAt': agreedEndAt?.toIso8601String(),
      'agreedDurationMinutes': agreedDurationMinutes,
      'acceptedProposedTime': acceptedProposedTime,
      'timeAgreed': timeAgreed,
      'readyForCalendar': readyForCalendar,
      'needsAgreedTime': needsAgreedTime,
      'timeStatus': timeStatus,
      'timingStatus': timingStatus,
      'schedulingStatus': schedulingStatus,
      'declineReasonCode': declineReasonCode,
      'declineReasonLabel': declineReasonLabel,
      'declineReasonText': declineReasonText,
      'declineNote': declineNote,
      'quoteDeclineReasonCode': declineReasonCode,
      'quoteDeclineReasonLabel': declineReasonLabel,
      'quoteDeclineReason': declineReasonLabel,
      'quoteDeclineNote': declineNote,
      'quoteDeclinedReasonCode': declineReasonCode,
      'quoteDeclinedReasonLabel': declineReasonLabel,
      'quoteDeclinedReason': declineReasonLabel,
      'quoteDeclinedNote': declineNote,
      'lastQuoteDeclineReason': declineReasonLabel,
      'lastQuoteDeclineNote': declineNote,
      'quoteDecline': <String, dynamic>{
        'reasonCode': declineReasonCode,
        'reasonLabel': declineReasonLabel,
        'reason': declineReasonLabel,
        'note': declineNote,
        'reasonText': declineReasonText,
      },
      'declinedAt': declinedAt?.toIso8601String(),
      'declinedBy': declinedBy,
      if (preferredDate != null)
        'preferredDate': preferredDate!.toIso8601String(),
      'preferredTimeWindow': preferredTimeWindow,
      'preferredIsFlexible': preferredIsFlexible,
      'preferredTimingNote': preferredTimingNote,
      'preferredTimingDecision': preferredTimingDecision,
      if (suggestedDate != null)
        'suggestedDate': suggestedDate!.toIso8601String(),
      'suggestedTimeWindow': suggestedTimeWindow,
      'publicJobTitle': publicJobTitle,
      'publicCustomerName': publicCustomerName,
      'publicAddressSummary': publicAddressSummary,
      'customerPhone': publicPhoneNumber,
      'publicPhoneNumber': publicPhoneNumber,
      'phoneNumber': publicPhoneNumber,
      'phone': publicPhoneNumber,
      'publicCustomerEmail': publicCustomerEmail,
      'customerPostcode': customerPostcode,
      'source': source,
      'isPreview': isPreview,
      'sourceLabel': sourceLabel,
      'selectedServiceId': selectedServiceId,
      'selectedServiceName': selectedServiceName,
      'requestType': requestType,
      'customerJourneyType': customerJourneyType,
      'startHandover': startHandover,
      'endHandover': endHandover,
      'allowedStartHandoverOptions': allowedStartHandoverOptions,
      'allowedEndHandoverOptions': allowedEndHandoverOptions,
      'collectionAddress': collectionAddress,
      'returnAddress': returnAddress,
      'returnAddressSameAsCollection': returnAddressSameAsCollection,
      'businessDropOffInstructions': businessDropOffInstructions,
      'businessCollectionInstructions': businessCollectionInstructions,
      'fulfilmentType': fulfilmentType,
      'dropOffDate': dropOffDate?.toIso8601String(),
      'dropOffTime': dropOffTime,
      'pickUpDate': pickUpDate?.toIso8601String(),
      'pickUpTime': pickUpTime,
      'checklistItems': checklistItems,
      'customQuestions': customQuestions,
      'exactPinRequested': exactPinRequested,
      'requestPhotos': requestPhotos,
      'requiresExactPinAfterQuoteAccepted': requiresExactPinAfterQuoteAccepted,
      'exactPinRequestedAfterQuote': requiresExactPinAfterQuoteAccepted,
      'driverMessagePreview': driverMessagePreview,
      'hasReply': hasReply,
      'hasExactPin': hasExactPin,
      'submittedAt': submittedAt?.toIso8601String(),
      'customerSubmittedAt': customerSubmittedAt?.toIso8601String(),
      'requestSubmittedAt': requestSubmittedAt?.toIso8601String(),
      'replyReceivedAt': replyReceivedAt?.toIso8601String(),
      'checklistResponses': checklistResponses
          .map((item) => item.toJson())
          .toList(growable: false),
      'customQuestionResponses': customQuestionResponses
          .map((item) => item.toJson())
          .toList(growable: false),
      'answers': answers.map((item) => item.toJson()).toList(growable: false),
      'photos': photos.map((item) => item.toJson()).toList(growable: false),
      'additionalNotes': additionalNotes,
      'exactPinLat': exactPinLat,
      'exactPinLng': exactPinLng,
      'exactPinLatitude': exactPinLat,
      'exactPinLongitude': exactPinLng,
      'exactPinSource': exactPinSource,
      'exactPinNote': exactPinNote,
      'isTestData': isTestData,
      'testMode': testMode,
      'deleted': deleted,
      'archived': archived,
    };
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'requestId': requestId,
      'ownerUid': ownerUid,
      'jobId': jobId,
      'linkedJobId': linkedJobId,
      'shortCode': normalizeVanJobRequestShortCode(shortCode),
      'status': status,
      'requestStatus': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'jobDateLabel': jobDateLabel,
      'jobTimeLabel': jobTimeLabel,
      'scheduledDate': scheduledDate,
      'scheduledStartTime': scheduledStartTime,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'calendarStatus': calendarStatus,
      'locationPending': locationPending,
      'quoteTimingChoice': quoteTimingChoice,
      'agreedDateTime': agreedDateTime == null
          ? null
          : Timestamp.fromDate(agreedDateTime!),
      'agreedStartAt': agreedStartAt == null
          ? null
          : Timestamp.fromDate(agreedStartAt!),
      'agreedEndAt': agreedEndAt == null
          ? null
          : Timestamp.fromDate(agreedEndAt!),
      'agreedDurationMinutes': agreedDurationMinutes,
      'acceptedProposedTime': acceptedProposedTime,
      'timeAgreed': timeAgreed,
      'readyForCalendar': readyForCalendar,
      'needsAgreedTime': needsAgreedTime,
      'timeStatus': timeStatus,
      'timingStatus': timingStatus,
      'schedulingStatus': schedulingStatus,
      'declineReasonCode': declineReasonCode,
      'declineReasonLabel': declineReasonLabel,
      'declineReasonText': declineReasonText,
      'declineNote': declineNote,
      'quoteDeclineReasonCode': declineReasonCode,
      'quoteDeclineReasonLabel': declineReasonLabel,
      'quoteDeclineReason': declineReasonLabel,
      'quoteDeclineNote': declineNote,
      'quoteDeclinedReasonCode': declineReasonCode,
      'quoteDeclinedReasonLabel': declineReasonLabel,
      'quoteDeclinedReason': declineReasonLabel,
      'quoteDeclinedNote': declineNote,
      'lastQuoteDeclineReason': declineReasonLabel,
      'lastQuoteDeclineNote': declineNote,
      'quoteDecline': <String, dynamic>{
        'reasonCode': declineReasonCode,
        'reasonLabel': declineReasonLabel,
        'reason': declineReasonLabel,
        'note': declineNote,
        'reasonText': declineReasonText,
      },
      'declinedAt': declinedAt == null ? null : Timestamp.fromDate(declinedAt!),
      'declinedBy': declinedBy,
      if (preferredDate != null)
        'preferredDate': Timestamp.fromDate(preferredDate!),
      'preferredTimeWindow': preferredTimeWindow,
      'preferredIsFlexible': preferredIsFlexible,
      'preferredTimingNote': preferredTimingNote,
      'preferredTimingDecision': preferredTimingDecision,
      if (suggestedDate != null)
        'suggestedDate': Timestamp.fromDate(suggestedDate!),
      'suggestedTimeWindow': suggestedTimeWindow,
      'publicJobTitle': publicJobTitle,
      'publicCustomerName': publicCustomerName,
      'publicAddressSummary': publicAddressSummary,
      'customerPhone': publicPhoneNumber,
      'publicPhoneNumber': publicPhoneNumber,
      'phoneNumber': publicPhoneNumber,
      'phone': publicPhoneNumber,
      'publicCustomerEmail': publicCustomerEmail,
      'customerPostcode': customerPostcode,
      'source': source,
      'isPreview': isPreview,
      'sourceLabel': sourceLabel,
      'selectedServiceId': selectedServiceId,
      'selectedServiceName': selectedServiceName,
      'requestType': requestType,
      'customerJourneyType': customerJourneyType,
      'startHandover': startHandover,
      'endHandover': endHandover,
      'allowedStartHandoverOptions': allowedStartHandoverOptions,
      'allowedEndHandoverOptions': allowedEndHandoverOptions,
      'collectionAddress': collectionAddress,
      'returnAddress': returnAddress,
      'returnAddressSameAsCollection': returnAddressSameAsCollection,
      'businessDropOffInstructions': businessDropOffInstructions,
      'businessCollectionInstructions': businessCollectionInstructions,
      'fulfilmentType': fulfilmentType,
      'checklistItems': checklistItems,
      'dropOffDate': dropOffDate == null
          ? null
          : Timestamp.fromDate(dropOffDate!),
      'dropOffTime': dropOffTime,
      'pickUpDate': pickUpDate == null ? null : Timestamp.fromDate(pickUpDate!),
      'pickUpTime': pickUpTime,
      'customQuestions': customQuestions,
      'exactPinRequested': exactPinRequested,
      'requestPhotos': requestPhotos,
      'requiresExactPinAfterQuoteAccepted': requiresExactPinAfterQuoteAccepted,
      'exactPinRequestedAfterQuote': requiresExactPinAfterQuoteAccepted,
      'driverMessagePreview': driverMessagePreview,
      'hasReply': hasReply,
      'hasExactPin': hasExactPin,
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
      'customerSubmittedAt': customerSubmittedAt == null
          ? null
          : Timestamp.fromDate(customerSubmittedAt!),
      'requestSubmittedAt': requestSubmittedAt == null
          ? null
          : Timestamp.fromDate(requestSubmittedAt!),
      'replyReceivedAt': replyReceivedAt == null
          ? null
          : Timestamp.fromDate(replyReceivedAt!),
      'checklistResponses': checklistResponses
          .map((item) => item.toJson())
          .toList(),
      'customQuestionResponses': customQuestionResponses
          .map((item) => item.toJson())
          .toList(),
      'answers': answers.map((item) => item.toJson()).toList(),
      'photos': photos.map((item) => item.toJson()).toList(),
      'additionalNotes': additionalNotes,
      'exactPinLat': exactPinLat,
      'exactPinLng': exactPinLng,
      'exactPinLatitude': exactPinLat,
      'exactPinLongitude': exactPinLng,
      'exactPinSource': exactPinSource,
      'exactPinNote': exactPinNote,
      'isTestData': isTestData,
      'testMode': testMode,
      'deleted': deleted,
      'archived': archived,
    };
  }

  Map<String, dynamic> toPublicFirestore() {
    return <String, dynamic>{
      'requestId': requestId,
      'ownerUid': ownerUid,
      'jobId': jobId,
      'linkedJobId': linkedJobId,
      'shortCode': normalizeVanJobRequestShortCode(shortCode),
      'status': status,
      'requestStatus': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'requestExpiresAt': Timestamp.fromDate(expiresAt),
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'jobDateLabel': jobDateLabel,
      'jobTimeLabel': jobTimeLabel,
      'scheduledDate': scheduledDate,
      'scheduledStartTime': scheduledStartTime,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'calendarStatus': calendarStatus,
      'locationPending': locationPending,
      'quoteTimingChoice': quoteTimingChoice,
      'agreedDateTime': agreedDateTime == null
          ? null
          : Timestamp.fromDate(agreedDateTime!),
      'agreedStartAt': agreedStartAt == null
          ? null
          : Timestamp.fromDate(agreedStartAt!),
      'agreedEndAt': agreedEndAt == null
          ? null
          : Timestamp.fromDate(agreedEndAt!),
      'agreedDurationMinutes': agreedDurationMinutes,
      'acceptedProposedTime': acceptedProposedTime,
      'timeAgreed': timeAgreed,
      'readyForCalendar': readyForCalendar,
      'needsAgreedTime': needsAgreedTime,
      'timeStatus': timeStatus,
      'timingStatus': timingStatus,
      'schedulingStatus': schedulingStatus,
      'declineReasonCode': declineReasonCode,
      'declineReasonLabel': declineReasonLabel,
      'declineReasonText': declineReasonText,
      'declineNote': declineNote,
      'quoteDeclineReasonCode': declineReasonCode,
      'quoteDeclineReasonLabel': declineReasonLabel,
      'quoteDeclineReason': declineReasonLabel,
      'quoteDeclineNote': declineNote,
      'quoteDeclinedReasonCode': declineReasonCode,
      'quoteDeclinedReasonLabel': declineReasonLabel,
      'quoteDeclinedReason': declineReasonLabel,
      'quoteDeclinedNote': declineNote,
      'lastQuoteDeclineReason': declineReasonLabel,
      'lastQuoteDeclineNote': declineNote,
      'quoteDecline': <String, dynamic>{
        'reasonCode': declineReasonCode,
        'reasonLabel': declineReasonLabel,
        'reason': declineReasonLabel,
        'note': declineNote,
        'reasonText': declineReasonText,
      },
      'declinedAt': declinedAt == null ? null : Timestamp.fromDate(declinedAt!),
      'declinedBy': declinedBy,
      if (preferredDate != null)
        'preferredDate': Timestamp.fromDate(preferredDate!),
      'preferredTimeWindow': preferredTimeWindow,
      'preferredIsFlexible': preferredIsFlexible,
      'preferredTimingNote': preferredTimingNote,
      'preferredTimingDecision': preferredTimingDecision,
      if (suggestedDate != null)
        'suggestedDate': Timestamp.fromDate(suggestedDate!),
      'suggestedTimeWindow': suggestedTimeWindow,
      'publicJobTitle': publicJobTitle,
      'publicCustomerName': publicCustomerName,
      'publicAddressSummary': publicAddressSummary,
      'customerPhone': publicPhoneNumber,
      'publicPhoneNumber': publicPhoneNumber,
      'publicCustomerEmail': publicCustomerEmail,
      'checklistItems': checklistItems,
      'customQuestions': customQuestions,
      'customerPostcode': customerPostcode,
      'source': source,
      'isPreview': isPreview,
      'sourceLabel': sourceLabel,
      'selectedServiceId': selectedServiceId,
      'selectedServiceName': selectedServiceName,
      'requestType': requestType,
      'customerJourneyType': customerJourneyType,
      'startHandover': startHandover,
      'endHandover': endHandover,
      'allowedStartHandoverOptions': allowedStartHandoverOptions,
      'allowedEndHandoverOptions': allowedEndHandoverOptions,
      'collectionAddress': collectionAddress,
      'returnAddress': returnAddress,
      'returnAddressSameAsCollection': returnAddressSameAsCollection,
      'businessDropOffInstructions': businessDropOffInstructions,
      'businessCollectionInstructions': businessCollectionInstructions,
      'fulfilmentType': fulfilmentType,
      'dropOffDate': dropOffDate == null
          ? null
          : Timestamp.fromDate(dropOffDate!),
      'dropOffTime': dropOffTime,
      'pickUpDate': pickUpDate == null ? null : Timestamp.fromDate(pickUpDate!),
      'pickUpTime': pickUpTime,
      'exactPinRequested': exactPinRequested,
      'requestPhotos': requestPhotos,
      'requiresExactPinAfterQuoteAccepted': requiresExactPinAfterQuoteAccepted,
      'exactPinRequestedAfterQuote': requiresExactPinAfterQuoteAccepted,
      'hasReply': hasReply,
      'hasExactPin': hasExactPin,
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
      'customerSubmittedAt': customerSubmittedAt == null
          ? null
          : Timestamp.fromDate(customerSubmittedAt!),
      'requestSubmittedAt': requestSubmittedAt == null
          ? null
          : Timestamp.fromDate(requestSubmittedAt!),
      'replyReceivedAt': replyReceivedAt == null
          ? null
          : Timestamp.fromDate(replyReceivedAt!),
      'checklistResponses': checklistResponses
          .map((item) => item.toJson())
          .toList(),
      'customQuestionResponses': customQuestionResponses
          .map((item) => item.toJson())
          .toList(),
      'answers': answers.map((item) => item.toJson()).toList(),
      'photos': photos.map((item) => item.toJson()).toList(),
      'additionalNotes': additionalNotes,
      'exactPinLat': exactPinLat,
      'exactPinLng': exactPinLng,
      'exactPinLatitude': exactPinLat,
      'exactPinLongitude': exactPinLng,
      'exactPinSource': exactPinSource,
      'exactPinNote': exactPinNote,
      'isTestData': isTestData,
      'testMode': testMode,
      'deleted': deleted,
      'archived': archived,
    };
  }

  Map<String, dynamic> toPrivateFirestore() {
    return <String, dynamic>{
      'requestId': requestId,
      'ownerUid': ownerUid,
      'jobId': jobId,
      'linkedJobId': linkedJobId,
      'shortCode': normalizeVanJobRequestShortCode(shortCode),
      'status': status,
      'requestStatus': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
      'customerSubmittedAt': customerSubmittedAt == null
          ? null
          : Timestamp.fromDate(customerSubmittedAt!),
      'requestSubmittedAt': requestSubmittedAt == null
          ? null
          : Timestamp.fromDate(requestSubmittedAt!),
      'replyReceivedAt': replyReceivedAt == null
          ? null
          : Timestamp.fromDate(replyReceivedAt!),
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'scheduledDate': scheduledDate,
      'scheduledStartTime': scheduledStartTime,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'calendarStatus': calendarStatus,
      'locationPending': locationPending,
      'quoteTimingChoice': quoteTimingChoice,
      'agreedDateTime': agreedDateTime == null
          ? null
          : Timestamp.fromDate(agreedDateTime!),
      'schedulingStatus': schedulingStatus,
      'hasReply': hasReply,
      'hasExactPin': hasExactPin,
      'exactPinSource': exactPinSource,
      'publicJobTitle': publicJobTitle,
      'publicCustomerName': publicCustomerName,
      'publicAddressSummary': publicAddressSummary,
      'customerPhone': publicPhoneNumber,
      'publicPhoneNumber': publicPhoneNumber,
      'publicCustomerEmail': publicCustomerEmail,
      'customerPostcode': customerPostcode,
      'source': source,
      'isPreview': isPreview,
      'sourceLabel': sourceLabel,
      'selectedServiceId': selectedServiceId,
      'selectedServiceName': selectedServiceName,
      'requestType': requestType,
      'customerJourneyType': customerJourneyType,
      'startHandover': startHandover,
      'endHandover': endHandover,
      'allowedStartHandoverOptions': allowedStartHandoverOptions,
      'allowedEndHandoverOptions': allowedEndHandoverOptions,
      'collectionAddress': collectionAddress,
      'returnAddress': returnAddress,
      'returnAddressSameAsCollection': returnAddressSameAsCollection,
      'businessDropOffInstructions': businessDropOffInstructions,
      'businessCollectionInstructions': businessCollectionInstructions,
      'fulfilmentType': fulfilmentType,
      'exactPinRequested': exactPinRequested,
      'requestPhotos': requestPhotos,
      'dropOffDate': dropOffDate == null
          ? null
          : Timestamp.fromDate(dropOffDate!),
      'dropOffTime': dropOffTime,
      'pickUpDate': pickUpDate == null ? null : Timestamp.fromDate(pickUpDate!),
      'pickUpTime': pickUpTime,
      'requiresExactPinAfterQuoteAccepted': requiresExactPinAfterQuoteAccepted,
      'exactPinRequestedAfterQuote': requiresExactPinAfterQuoteAccepted,
      'driverMessagePreview': driverMessagePreview,
      'checklistItemCount': checklistItems.length,
      'customQuestionCount': customQuestions.length,
      'isTestData': isTestData,
      'testMode': testMode,
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
    final answersJson = data['answers'];
    final photosJson = data['photos'];
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
    final answers = answersJson is List
        ? answersJson
              .whereType<Map>()
              .map(
                (item) => VanJobRequestAnswer.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <VanJobRequestAnswer>[];
    final orderedAnswers = answers.toList(growable: true);
    if (orderedAnswers.any((item) => item.order != 0)) {
      orderedAnswers.sort((a, b) => a.order.compareTo(b.order));
    }
    final photos = photosJson is List
        ? photosJson
              .whereType<Map>()
              .map(
                (item) => VanJobRequestPhoto.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <VanJobRequestPhoto>[];

    final parsedSource = _readVanRequestText(data['source']);
    final parsedIsPreview = _readVanRequestBool(data['isPreview']);
    final parsedAgreedDateTime =
        _readVanRequestDateTime(data['agreedDateTime']) ??
        _readVanRequestDateTime(data['agreedStartAt']);
    final parsedAgreedStartAt =
        _readVanRequestDateTime(data['agreedStartAt']) ?? parsedAgreedDateTime;
    final parsedAgreedEndAt = _readVanRequestDateTime(data['agreedEndAt']);
    final parsedTimeStatus = _readVanRequestText(
      data['timeStatus'],
    ).trim().toLowerCase();
    final parsedTimingStatus = _readVanRequestText(
      data['timingStatus'],
    ).trim().toLowerCase();
    final parsedTimeAccepted =
        _readVanRequestBool(data['timeAccepted']) ||
        _readVanRequestBool(data['acceptedProposedTime']) ||
        _readVanRequestBool(data['proposedTimeAccepted']);
    final parsedTimingNeedsDecision =
        _readVanRequestBool(data['timingNeedsDecision']) ||
        _readVanRequestBool(data['timeNotAccepted']) ||
        _readVanRequestBool(data['needsAgreedTime']);
    final parsedReadyForCalendar =
        _readVanRequestBool(data['readyForCalendar']) ||
        parsedTimeStatus == 'ready_for_calendar' ||
        parsedTimingStatus == 'ready_for_calendar';
    final parsedTimeAgreed =
        _readVanRequestBool(data['timeAgreed']) ||
        parsedTimeAccepted ||
        parsedReadyForCalendar ||
        parsedTimeStatus == 'agreed' ||
        parsedTimeStatus == 'accepted' ||
        parsedTimeStatus == 'accepted_time' ||
        parsedTimeStatus == 'time_agreed' ||
        parsedTimingStatus == 'agreed' ||
        parsedTimingStatus == 'accepted' ||
        parsedTimingStatus == 'accepted_time' ||
        parsedTimingStatus == 'time_agreed';
    final parsedQuoteTimingChoice = _readVanRequestText(
      data['quoteTimingChoice'],
    );
    final parsedSchedulingStatus = _readVanRequestText(
      data['schedulingStatus'],
    );
    return VanJobRequestRecord(
      requestId: _readVanRequestText(
        data['requestId'],
        fallback: fallbackRequestId,
      ),
      ownerUid: _readVanRequestText(data['ownerUid']),
      jobId: _readVanRequestText(data['jobId']),
      linkedJobId: _readVanRequestText(
        data['linkedJobId'],
        fallback: _readVanRequestText(data['jobId']),
      ),
      shortCode: normalizeVanJobRequestShortCode(
        _readVanRequestText(data['shortCode']),
      ),
      status: normalizeVanJobRequestStatus(
        _readVanRequestText(
          data['requestStatus'],
          fallback: _readVanRequestText(data['status'], fallback: 'draft'),
        ),
      ),
      createdAt:
          _readVanRequestDateTime(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readVanRequestDateTime(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          _readVanRequestDateTime(data['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      scheduledAt: _readVanRequestDateTime(data['scheduledAt']),
      jobDateLabel: _readVanRequestText(data['jobDateLabel']),
      jobTimeLabel: _readVanRequestText(data['jobTimeLabel']),
      scheduledDate: _readVanRequestText(data['scheduledDate']),
      scheduledStartTime: _readVanRequestText(data['scheduledStartTime']),
      estimatedDurationMinutes: _readVanRequestInt(
        data['estimatedDurationMinutes'],
      ),
      calendarStatus: _readVanRequestText(
        data['calendarStatus'],
        fallback: 'unscheduled',
      ),
      locationPending:
          !vanJobRequestIsCollectionOrder(data) &&
          (!vanJobRequestIsDropOffPickup(data) ||
              vanJobRequestRequiresExactPinAfterQuoteAccepted(data)) &&
          _readVanRequestBool(data['locationPending']),
      quoteTimingChoice: parsedQuoteTimingChoice.trim().isNotEmpty
          ? parsedQuoteTimingChoice
          : parsedTimeAccepted
          ? 'accepted_proposed_time'
          : parsedTimingNeedsDecision
          ? 'arrange_another_time'
          : '',
      agreedDateTime: parsedAgreedDateTime,
      agreedStartAt: parsedAgreedStartAt,
      agreedEndAt: parsedAgreedEndAt,
      agreedDurationMinutes:
          _readVanRequestInt(data['agreedDurationMinutes']) ??
          _readVanRequestInt(data['estimatedDurationMinutes']),
      acceptedProposedTime: parsedTimeAccepted,
      timeAgreed: parsedTimeAgreed,
      readyForCalendar: parsedReadyForCalendar,
      needsAgreedTime: parsedTimingNeedsDecision,
      timeStatus: _readVanRequestText(data['timeStatus']),
      timingStatus: _readVanRequestText(data['timingStatus']),
      schedulingStatus: parsedSchedulingStatus.trim().isNotEmpty
          ? parsedSchedulingStatus
          : parsedReadyForCalendar
          ? 'ready_for_calendar'
          : parsedTimeAccepted
          ? 'accepted_time'
          : parsedTimingNeedsDecision
          ? 'awaiting_agreed_time'
          : '',
      declineReasonCode: _readVanRequestText(
        data['declineReasonCode'],
        fallback: _readVanRequestText(
          data['quoteDeclineReasonCode'],
          fallback: readVanNestedText(data['quoteDecline'], const [
            'reasonCode',
            'code',
          ]),
        ),
      ),
      declineReasonLabel: _readVanRequestText(
        data['declineReasonLabel'],
        fallback: _readVanRequestText(
          data['quoteDeclineReasonLabel'],
          fallback: _readVanRequestText(
            data['quoteDeclineReason'],
            fallback: _readVanRequestText(
              data['quoteDeclinedReason'],
              fallback: _readVanRequestText(
                data['lastQuoteDeclineReason'],
                fallback: readVanNestedText(data['quoteDecline'], const [
                  'reasonLabel',
                  'reason',
                ]),
              ),
            ),
          ),
        ),
      ),
      declineReasonText: _readVanRequestText(
        data['declineReasonText'],
        fallback: _readVanRequestText(
          data['declineNote'],
          fallback: _readVanRequestText(
            data['quoteDeclineNote'],
            fallback: _readVanRequestText(
              data['quoteDeclinedNote'],
              fallback: _readVanRequestText(
                data['lastQuoteDeclineNote'],
                fallback: readVanNestedText(data['quoteDecline'], const [
                  'reasonText',
                  'note',
                ]),
              ),
            ),
          ),
        ),
      ),
      declineNote: _readVanRequestText(
        data['declineNote'],
        fallback: _readVanRequestText(
          data['quoteDeclineNote'],
          fallback: _readVanRequestText(
            data['declineReasonText'],
            fallback: _readVanRequestText(
              data['quoteDeclinedNote'],
              fallback: _readVanRequestText(
                data['lastQuoteDeclineNote'],
                fallback: readVanNestedText(data['quoteDecline'], const [
                  'note',
                  'reasonText',
                ]),
              ),
            ),
          ),
        ),
      ),
      declinedAt:
          _readVanRequestDateTime(data['declinedAt']) ??
          _readVanRequestDateTime(data['quoteDeclinedAt']),
      declinedBy: _readVanRequestText(data['declinedBy']),
      preferredDate:
          _readVanRequestDateTime(data['preferredDate']) ??
          _readVanRequestDateTime(data['preferredDateAt']),
      preferredTimeWindow: _readVanRequestText(
        data['preferredTimeWindow'],
        fallback: _readVanRequestText(data['preferredWindow']),
      ),
      preferredIsFlexible:
          _readVanRequestBool(data['preferredIsFlexible']) ||
          _readVanRequestBool(data['timingFlexible']),
      preferredTimingNote: _readVanRequestText(
        data['preferredTimingNote'],
        fallback: _readVanRequestText(data['timingNote']),
      ),
      preferredTimingDecision: _readVanRequestText(
        data['preferredTimingDecision'],
      ),
      suggestedDate:
          _readVanRequestDateTime(data['suggestedDate']) ??
          _readVanRequestDateTime(data['suggestedDateAt']),
      suggestedTimeWindow: _readVanRequestText(data['suggestedTimeWindow']),
      publicJobTitle: _readVanRequestText(data['publicJobTitle']),
      publicCustomerName: _readVanRequestText(data['publicCustomerName']),
      publicAddressSummary: _readVanRequestText(data['publicAddressSummary']),
      publicPhoneNumber: sanitizeVanCustomerPhoneNumber(
        _readVanRequestText(
          data['customerPhone'],
          fallback: _readVanRequestText(
            data['publicPhoneNumber'],
            fallback: _readVanRequestText(
              data['phoneNumber'],
              fallback: _readVanRequestText(
                data['phone'],
                fallback: _readVanRequestText(data['mobile']),
              ),
            ),
          ),
        ),
      ),
      publicCustomerEmail: _readVanRequestText(data['publicCustomerEmail']),
      customerPostcode: _readVanRequestText(data['customerPostcode']),
      source: parsedSource,
      isPreview: parsedIsPreview || parsedSource.toLowerCase() == 'preview',
      sourceLabel: _readVanRequestText(data['sourceLabel']),
      selectedServiceId: _readVanRequestText(data['selectedServiceId']),
      selectedServiceName: _readVanRequestText(data['selectedServiceName']),
      requestType: _readVanRequestText(
        data['requestType'],
        fallback: 'quoteRequest',
      ),
      customerJourneyType: _readVanRequestText(
        data['customerJourneyType'],
        fallback: 'quote',
      ),
      startHandover: _readVanRequestText(data['startHandover']),
      endHandover: _readVanRequestText(data['endHandover']),
      allowedStartHandoverOptions: _readVanRequestStringList(
        data['allowedStartHandoverOptions'],
      ),
      allowedEndHandoverOptions: _readVanRequestStringList(
        data['allowedEndHandoverOptions'],
      ),
      collectionAddress: _readVanRequestText(
        data['collectionAddress'],
        fallback: _readVanRequestText(data['pickupAddress']),
      ),
      returnAddress: _readVanRequestText(
        data['returnAddress'],
        fallback: _readVanRequestText(data['deliveryAddress']),
      ),
      returnAddressSameAsCollection: _readVanRequestBool(
        data['returnAddressSameAsCollection'],
      ),
      businessDropOffInstructions: _readVanRequestText(
        data['businessDropOffInstructions'],
      ),
      businessCollectionInstructions: _readVanRequestText(
        data['businessCollectionInstructions'],
      ),
      fulfilmentType: _readVanRequestText(data['fulfilmentType']),
      dropOffDate: _readVanRequestDateTime(data['dropOffDate']),
      dropOffTime: _readVanRequestText(data['dropOffTime']),
      pickUpDate: _readVanRequestDateTime(data['pickUpDate']),
      pickUpTime: _readVanRequestText(data['pickUpTime']),
      checklistItems: _readVanRequestStringList(data['checklistItems']),
      customQuestions: _readVanRequestStringList(data['customQuestions']),
      exactPinRequested:
          !vanJobRequestIsCollectionOrder(data) &&
          !vanJobRequestIsDropOffPickup(data) &&
          _readVanRequestBool(data['exactPinRequested']),
      requestPhotos: _readVanRequestBool(data['requestPhotos']),
      requiresExactPinAfterQuoteAccepted:
          vanJobRequestRequiresExactPinAfterQuoteAccepted(data),
      driverMessagePreview: _readVanRequestText(data['driverMessagePreview']),
      submittedAt:
          _readVanRequestDateTime(data['submittedAt']) ??
          _readVanRequestDateTime(data['requestSubmittedAt']),
      customerSubmittedAt:
          _readVanRequestDateTime(data['customerSubmittedAt']) ??
          _readVanRequestDateTime(data['replyReceivedAt']),
      requestSubmittedAt:
          _readVanRequestDateTime(data['requestSubmittedAt']) ??
          _readVanRequestDateTime(data['submittedAt']),
      replyReceivedAt:
          _readVanRequestDateTime(data['replyReceivedAt']) ??
          _readVanRequestDateTime(data['customerSubmittedAt']),
      checklistResponses: checklistResponses,
      customQuestionResponses: customResponses,
      answers: orderedAnswers,
      photos: photos,
      additionalNotes: _readVanRequestText(data['additionalNotes']),
      exactPinLat:
          _readVanRequestDouble(data['exactPinLat']) ??
          _readVanRequestDouble(data['exactPinLatitude']),
      exactPinLng:
          _readVanRequestDouble(data['exactPinLng']) ??
          _readVanRequestDouble(data['exactPinLongitude']),
      exactPinLatitude:
          _readVanRequestDouble(data['exactPinLatitude']) ??
          _readVanRequestDouble(data['exactPinLat']),
      exactPinLongitude:
          _readVanRequestDouble(data['exactPinLongitude']) ??
          _readVanRequestDouble(data['exactPinLng']),
      exactPinSource: _readVanRequestText(data['exactPinSource']),
      exactPinNote: _readVanRequestText(data['exactPinNote']),
      isTestData: _readVanRequestBool(data['isTestData']),
      testMode: _readVanRequestBool(data['testMode']),
      deleted: _readVanRequestBool(data['deleted']),
      archived: _readVanRequestBool(data['archived']),
    );
  }
}
