import 'package:flutter/foundation.dart';

import 'van_job_request_record.dart';

enum VanJobStatus {
  draft,
  requestSent,
  replyReceived,
  quoteSent,
  confirmed,
  completed,
  cancelled,
}

extension VanJobStatusLabel on VanJobStatus {
  String get value => name;

  String get label {
    switch (this) {
      case VanJobStatus.draft:
        return 'Draft';
      case VanJobStatus.requestSent:
        return 'Pending customer request';
      case VanJobStatus.replyReceived:
        return 'Reply received';
      case VanJobStatus.quoteSent:
        return 'Quote sent';
      case VanJobStatus.confirmed:
        return 'Confirmed';
      case VanJobStatus.completed:
        return 'Completed';
      case VanJobStatus.cancelled:
        return 'Cancelled';
    }
  }
}

VanJobStatus vanJobStatusFromString(Object? value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  switch (text) {
    case 'requestsent':
    case 'request_sent':
    case 'pending':
    case 'pending_customer_request':
      return VanJobStatus.requestSent;
    case 'replyreceived':
    case 'reply_received':
      return VanJobStatus.replyReceived;
    case 'quotesent':
    case 'quote_sent':
      return VanJobStatus.quoteSent;
    case 'confirmed':
      return VanJobStatus.confirmed;
    case 'completed':
      return VanJobStatus.completed;
    case 'cancelled':
      return VanJobStatus.cancelled;
    default:
      return VanJobStatus.draft;
  }
}

@immutable
class VanJobRequestDraft {
  const VanJobRequestDraft({
    required this.jobId,
    required this.customerName,
    required this.phoneNumber,
    required this.jobTitle,
    required this.scheduledAt,
    required this.jobDateLabel,
    required this.jobTimeLabel,
    required this.address,
    required this.requestExactPin,
    required this.requestPhotos,
    required this.requiresExactPinAfterQuoteAccepted,
    required this.selectedQuestionIds,
    required this.answers,
    required this.checklistItems,
    required this.customQuestions,
    this.customerEmail = '',
    this.postcode = '',
    this.notesMessage = '',
    this.scheduledDate = '',
    this.scheduledStartTime = '',
    this.estimatedDurationMinutes,
    this.calendarStatus = 'unscheduled',
    this.locationPending = false,
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
    this.dropOffDate,
    this.dropOffTime = '',
    this.pickUpDate,
    this.pickUpTime = '',
    this.exactPinLatitude,
    this.exactPinLongitude,
    this.exactPinSource = 'none',
  });

  final String jobId;
  final String customerName;
  final String phoneNumber;
  final String customerEmail;
  final String jobTitle;
  final DateTime scheduledAt;
  final String jobDateLabel;
  final String jobTimeLabel;
  final String address;
  final String postcode;
  final bool requestExactPin;
  final bool requestPhotos;
  final bool requiresExactPinAfterQuoteAccepted;
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
  final DateTime? dropOffDate;
  final String dropOffTime;
  final DateTime? pickUpDate;
  final String pickUpTime;
  final List<String> selectedQuestionIds;
  final List<VanJobRequestAnswer> answers;
  final List<String> checklistItems;
  final List<String> customQuestions;
  final String notesMessage;
  final String scheduledDate;
  final String scheduledStartTime;
  final int? estimatedDurationMinutes;
  final String calendarStatus;
  final bool locationPending;
  final double? exactPinLatitude;
  final double? exactPinLongitude;
  final String exactPinSource;

  bool get hasLocationDetails =>
      address.trim().isNotEmpty || postcode.trim().isNotEmpty;
}
