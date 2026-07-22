import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_customer_journey_theme.dart';
import '../helpers/van_invoice_extra_suggestions.dart';
import '../helpers/van_job_request_state.dart';
import '../helpers/van_quote_decline.dart';
import '../helpers/van_quote_ui_status.dart';
import '../helpers/van_request_delete_key.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_exact_pin_source.dart';
import '../models/van_business_profile.dart';
import '../models/van_customer_journey.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_service_handover.dart';
import '../models/van_job_service.dart';
import '../models/van_job_request_draft.dart';
import '../models/van_job_request_record.dart';
import '../models/van_invoice_history_entry.dart';
import '../models/van_invoice_draft.dart';
import '../models/van_quote_extra_defaults.dart';
import '../models/van_service_template.dart';
import '../services/van_driver_mock_state_storage.dart';
import '../services/van_deleted_requests_store.dart';
import '../services/van_firebase_auth_service.dart';
import '../services/van_firebase_debug_logging.dart';
import '../services/van_business_profile_scope_storage.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_job_request_cloud_service.dart';
import '../services/van_job_services_storage.dart';
import '../services/van_jobs_cloud_service.dart';
import '../services/van_public_quote_cloud_service.dart';
import '../services/van_pickup_reminder_service.dart';
import '../services/van_quotes_cloud_service.dart';
import '../services/van_invoices_cloud_service.dart';
import '../services/van_invoice_number_storage.dart';
import '../services/van_job_deletion_service.dart';
import '../services/van_quote_extra_defaults_storage.dart';
import '../widgets/van_duration_picker_sheet.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_quote_extra_defaults_sheet.dart';

bool isVanIncomingScopeSnapshotCurrent({
  required String capturedOwnerUid,
  required String capturedBusinessProfileId,
  required int capturedGeneration,
  required String currentOwnerUid,
  required String currentBusinessProfileId,
  required int currentGeneration,
}) {
  return capturedOwnerUid == currentOwnerUid &&
      capturedBusinessProfileId == currentBusinessProfileId &&
      capturedGeneration == currentGeneration;
}

String resolveExactPinAnnouncementCustomerName({
  required String requestCustomerName,
  required String linkedJobCustomerName,
  required String existingCustomerName,
}) {
  final linkedName = linkedJobCustomerName.trim();
  if (linkedName.isNotEmpty) {
    return linkedName;
  }

  final requestName = requestCustomerName.trim();
  if (requestName.isNotEmpty) {
    return requestName;
  }

  return existingCustomerName.trim();
}

String buildVanExactPinAnnouncementStateToken({
  required bool hasExactPin,
  required double? exactPinLatitude,
  required double? exactPinLongitude,
  String exactPinSource = '',
  String exactPinNote = '',
}) {
  if (!hasExactPin || exactPinLatitude == null || exactPinLongitude == null) {
    return '';
  }

  final normalizedSource = exactPinSource.trim().toLowerCase();
  final normalizedNote = sanitizeVanText(
    exactPinNote,
  ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  return <String>[
    exactPinLatitude.toStringAsFixed(6),
    exactPinLongitude.toStringAsFixed(6),
    normalizedSource,
    normalizedNote,
  ].join('|');
}

DateTime? _addDurationToDateTime(DateTime? start, int? durationMinutes) {
  if (start == null) {
    return null;
  }
  final normalizedDuration = (durationMinutes ?? 0).clamp(1, 24 * 60);
  return start.add(Duration(minutes: normalizedDuration));
}

const Set<String> _vanMateObviousTestCustomerNames = <String>{
  'test',
  'test 1',
  'test 2',
  'test 3',
  'quote 1',
  'accept quote',
  'bob sinclair',
};

const Set<String> _vanMateObviousTestJobTitles = <String>{'test', 'tv', 'sofa'};

String _normalizeVanMateTestDataText(String value) {
  return sanitizeVanText(
    value,
  ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool isVanMateDebugTestDataCandidate({
  required bool isTestData,
  required bool testMode,
  required String customerName,
  required String jobTitle,
}) {
  if (isTestData || testMode) {
    return true;
  }

  final normalizedCustomerName = _normalizeVanMateTestDataText(customerName);
  final normalizedJobTitle = _normalizeVanMateTestDataText(jobTitle);
  return _vanMateObviousTestCustomerNames.contains(normalizedCustomerName) ||
      _vanMateObviousTestJobTitles.contains(normalizedJobTitle);
}

enum VanMateTestCleanupScope { pendingRequests, allJobs }

class VanMateTestCleanupResult {
  const VanMateTestCleanupResult({
    this.clearedJobs = 0,
    this.clearedRequests = 0,
    this.clearedQuoteDocs = 0,
    this.clearedPublicQuotes = 0,
  });

  final int clearedJobs;
  final int clearedRequests;
  final int clearedQuoteDocs;
  final int clearedPublicQuotes;

  int get totalCleared =>
      clearedJobs + clearedRequests + clearedQuoteDocs + clearedPublicQuotes;

  bool get didClearAnything => totalCleared > 0;
}

class VanMateSavedJobsClearResult {
  const VanMateSavedJobsClearResult({
    this.deletedCloudJobs = 0,
    this.deletedCloudQuotes = 0,
    this.deletedPublicQuotes = 0,
    this.deletedPublicQuoteTokens = 0,
    this.deletedPublicRequests = 0,
    this.deletedPrivateRequestMirrors = 0,
    this.deletedLegacyRequestMirrors = 0,
    this.clearedLocalJobs = 0,
    this.clearedLocalRequests = 0,
    this.clearedLocalQuoteStates = 0,
    this.clearedLocalCalendarEntries = 0,
  });

  final int deletedCloudJobs;
  final int deletedCloudQuotes;
  final int deletedPublicQuotes;
  final int deletedPublicQuoteTokens;
  final int deletedPublicRequests;
  final int deletedPrivateRequestMirrors;
  final int deletedLegacyRequestMirrors;
  final int clearedLocalJobs;
  final int clearedLocalRequests;
  final int clearedLocalQuoteStates;
  final int clearedLocalCalendarEntries;

  int get deletedCloudRecords =>
      deletedCloudJobs +
      deletedCloudQuotes +
      deletedPublicQuotes +
      deletedPublicQuoteTokens +
      deletedPublicRequests +
      deletedPrivateRequestMirrors +
      deletedLegacyRequestMirrors;

  int get clearedLocalEntries => clearedLocalJobs + clearedLocalRequests;

  int get totalCleared => deletedCloudRecords + clearedLocalEntries;

  bool get didClearAnything => totalCleared > 0;

  String get sourceSummary {
    final parts = <String>[
      if (deletedCloudJobs > 0) 'jobs $deletedCloudJobs',
      if (deletedCloudQuotes > 0) 'quotes $deletedCloudQuotes',
      if (deletedPublicQuotes > 0) 'public quotes $deletedPublicQuotes',
      if (deletedPublicQuoteTokens > 0) 'tokens $deletedPublicQuoteTokens',
      if (deletedPublicRequests > 0) 'requests $deletedPublicRequests',
      if (deletedPrivateRequestMirrors > 0)
        'private mirrors $deletedPrivateRequestMirrors',
      if (deletedLegacyRequestMirrors > 0)
        'legacy mirrors $deletedLegacyRequestMirrors',
      if (clearedLocalEntries > 0) 'local $clearedLocalEntries',
    ];
    if (parts.isEmpty) {
      return 'No saved job data found.';
    }
    return 'Deleted $totalCleared entries: ${parts.join(', ')}.';
  }
}

@immutable
class VanQuoteHistoryEntry {
  const VanQuoteHistoryEntry({
    required this.quoteResponseId,
    this.quoteResponseToken = '',
    this.quoteResponseLink = '',
    this.version = 1,
    this.quoteAmount,
    this.quoteJobDescription = '',
    this.quoteNotes = '',
    this.quotePaymentInstructions = '',
    this.quoteMessage = '',
    this.quoteExtras = const <String>[],
    this.proposedDate = '',
    this.proposedStartTime = '',
    this.proposedAppointmentNote = '',
    this.estimatedDurationMinutes,
    this.quoteStatus = '',
    this.quoteResponseStatus = '',
    this.quoteTimingChoice = '',
    this.quoteAccepted = false,
    this.quoteDeclined = false,
    this.quoteSentAt,
    this.quoteOpenedAt,
    this.quoteAcceptedAt,
    this.quoteDeclinedAt,
    this.quoteRespondedAt,
    this.declineReasonCode = '',
    this.declineReasonLabel = '',
    this.declineReasonText = '',
    this.declineNote = '',
  });

  final String quoteResponseId;
  final String quoteResponseToken;
  final String quoteResponseLink;
  final int version;
  final double? quoteAmount;
  final String quoteJobDescription;
  final String quoteNotes;
  final String quotePaymentInstructions;
  final String quoteMessage;
  final List<String> quoteExtras;
  final String proposedDate;
  final String proposedStartTime;
  final String proposedAppointmentNote;
  final int? estimatedDurationMinutes;
  final String quoteStatus;
  final String quoteResponseStatus;
  final String quoteTimingChoice;
  final bool quoteAccepted;
  final bool quoteDeclined;
  final DateTime? quoteSentAt;
  final DateTime? quoteOpenedAt;
  final DateTime? quoteAcceptedAt;
  final DateTime? quoteDeclinedAt;
  final DateTime? quoteRespondedAt;
  final String declineReasonCode;
  final String declineReasonLabel;
  final String declineReasonText;
  final String declineNote;

  bool get isDeclined =>
      quoteDeclined ||
      quoteStatus.trim().toLowerCase() == 'declined' ||
      quoteResponseStatus.trim().toLowerCase() == 'declined';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'quoteResponseId': quoteResponseId,
      'quoteResponseToken': quoteResponseToken,
      'quoteResponseLink': quoteResponseLink,
      'version': version,
      'quoteAmount': quoteAmount,
      'quoteJobDescription': quoteJobDescription,
      'quoteNotes': quoteNotes,
      'quotePaymentInstructions': quotePaymentInstructions,
      'quoteMessage': quoteMessage,
      'quoteExtras': quoteExtras,
      'proposedDate': proposedDate,
      'proposedStartTime': proposedStartTime,
      'proposedAppointmentNote': proposedAppointmentNote,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'quoteStatus': quoteStatus,
      'quoteResponseStatus': quoteResponseStatus,
      'quoteTimingChoice': quoteTimingChoice,
      'quoteAccepted': quoteAccepted,
      'quoteDeclined': quoteDeclined,
      'quoteSentAt': quoteSentAt?.toIso8601String(),
      'quoteOpenedAt': quoteOpenedAt?.toIso8601String(),
      'quoteAcceptedAt': quoteAcceptedAt?.toIso8601String(),
      'quoteDeclinedAt': quoteDeclinedAt?.toIso8601String(),
      'quoteRespondedAt': quoteRespondedAt?.toIso8601String(),
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
    };
  }

  factory VanQuoteHistoryEntry.fromJson(Map<String, dynamic> json) {
    return VanQuoteHistoryEntry(
      quoteResponseId: _jsonText(json['quoteResponseId']),
      quoteResponseToken: _jsonText(json['quoteResponseToken']),
      quoteResponseLink: resolveVanQuoteResponseDisplayLink(
        quoteResponseLink: _jsonText(json['quoteResponseLink']),
        quoteResponseToken: _jsonText(json['quoteResponseToken']),
        quoteId: _jsonText(json['quoteResponseId']),
      ),
      version: _jsonIntOrNull(json['version']) ?? 1,
      quoteAmount: _jsonDoubleOrNull(json['quoteAmount']),
      quoteJobDescription: _jsonText(json['quoteJobDescription']),
      quoteNotes: _jsonText(json['quoteNotes']),
      quotePaymentInstructions: _jsonText(json['quotePaymentInstructions']),
      quoteMessage: _jsonText(json['quoteMessage']),
      quoteExtras:
          (json['quoteExtras'] as List?)
              ?.map((item) => sanitizeVanText(item?.toString()).trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      proposedDate: _jsonIsoDateText(json['proposedDate']),
      proposedStartTime: _jsonTimeText(json['proposedStartTime']),
      proposedAppointmentNote: _jsonText(json['proposedAppointmentNote']),
      estimatedDurationMinutes: _jsonIntOrNull(
        json['estimatedDurationMinutes'],
      ),
      quoteStatus: _jsonText(json['quoteStatus']),
      quoteResponseStatus: _jsonText(json['quoteResponseStatus']),
      quoteTimingChoice: _jsonText(json['quoteTimingChoice']),
      quoteAccepted: _jsonBool(json['quoteAccepted']),
      quoteDeclined: _jsonBool(json['quoteDeclined']),
      quoteSentAt: _jsonDateTime(json['quoteSentAt']),
      quoteOpenedAt: _jsonDateTime(json['quoteOpenedAt']),
      quoteAcceptedAt: _jsonDateTime(json['quoteAcceptedAt']),
      quoteDeclinedAt: _jsonDateTime(json['quoteDeclinedAt']),
      quoteRespondedAt: _jsonDateTime(json['quoteRespondedAt']),
      declineReasonCode: _jsonText(
        json['declineReasonCode'],
        fallback: _jsonText(
          json['quoteDeclineReasonCode'],
          fallback: readVanNestedText(json['quoteDecline'], const [
            'reasonCode',
            'code',
          ]),
        ),
      ),
      declineReasonLabel: _jsonText(
        json['declineReasonLabel'],
        fallback: _jsonText(
          json['quoteDeclineReasonLabel'],
          fallback: _jsonText(
            json['quoteDeclineReason'],
            fallback: _jsonText(
              json['quoteDeclinedReason'],
              fallback: _jsonText(
                json['lastQuoteDeclineReason'],
                fallback: readVanNestedText(json['quoteDecline'], const [
                  'reasonLabel',
                  'reason',
                ]),
              ),
            ),
          ),
        ),
      ),
      declineReasonText: _jsonText(
        json['declineReasonText'],
        fallback: _jsonText(
          json['declineNote'],
          fallback: _jsonText(
            json['quoteDeclineNote'],
            fallback: _jsonText(
              json['quoteDeclinedNote'],
              fallback: _jsonText(
                json['lastQuoteDeclineNote'],
                fallback: readVanNestedText(json['quoteDecline'], const [
                  'reasonText',
                  'note',
                ]),
              ),
            ),
          ),
        ),
      ),
      declineNote: _jsonText(
        json['declineNote'],
        fallback: _jsonText(
          json['quoteDeclineNote'],
          fallback: _jsonText(
            json['declineReasonText'],
            fallback: _jsonText(
              json['quoteDeclinedNote'],
              fallback: _jsonText(
                json['lastQuoteDeclineNote'],
                fallback: readVanNestedText(json['quoteDecline'], const [
                  'note',
                  'reasonText',
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum VanCalendarJobKind {
  standard,
  collectionOrder,
  deliveryOrder,
  dropOffPickup,
  pickupDelivery,
}

@immutable
class DriverCustomerReplyMockData {
  const DriverCustomerReplyMockData({
    required this.jobId,
    required this.customerName,
    required this.jobTitle,
    required this.scheduledAt,
    required this.jobDateLabel,
    required this.jobTimeLabel,
    required this.address,
    required this.phoneNumber,
    required this.exactPinShared,
    required this.checklistResponses,
    required this.customQuestionResponses,
    required this.additionalNotes,
    this.hasReply = false,
    this.hasExactPin = false,
    this.customerEmail = '',
    this.postcode = '',
    this.notesMessage = '',
    this.requestExactPin = true,
    this.requestPhotos = false,
    this.requiresExactPinAfterQuoteAccepted = false,
    this.checklistItems = const <String>[],
    this.customQuestions = const <String>[],
    this.status = 'draft',
    this.createdAt,
    this.updatedAt,
    this.draftSavedAt,
    this.requestSentAt,
    this.replyReceivedAt,
    this.quoteSavedAt,
    this.quoteSentAt,
    this.quoteOpenedAt,
    this.quoteAcceptedAt,
    this.quoteDeclinedAt,
    this.declineReasonCode = '',
    this.declineReasonLabel = '',
    this.declineReasonText = '',
    this.declineNote = '',
    this.quoteRespondedAt,
    this.quoteResponseStatus = '',
    this.quoteTimingChoice = '',
    this.agreedDateTime,
    this.currentQuoteId = '',
    this.quoteResponseId = '',
    this.quoteResponseToken = '',
    this.quoteResponseLink = '',
    this.quoteExtras = const <String>[],
    this.quoteJobDescription = '',
    this.quoteNotes = '',
    this.quotePaymentInstructions = '',
    this.quoteMessage = '',
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.quoteAmount,
    this.quoteStatus = '',
    this.quoteAccepted = false,
    this.quoteDeclined = false,
    this.exactPinShareSource,
    this.exactPinNote,
    this.exactPinLatitude,
    this.exactPinLongitude,
    this.requestId,
    this.requestStatus = 'draft',
    this.requestCreatedAt,
    this.requestUpdatedAt,
    this.requestSubmittedAt,
    this.requestExpiresAt,
    this.requestLink = '',
    this.requestType = '',
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
    this.proposedDate = '',
    this.proposedStartTime = '',
    this.proposedAppointmentNote = '',
    this.acceptedProposedDate = '',
    this.acceptedProposedStartTime = '',
    this.schedulingStatus = '',
    this.scheduledDate = '',
    this.scheduledStartTime = '',
    this.estimatedDurationMinutes,
    this.calendarStatus = 'unscheduled',
    this.locationPending = false,
    this.exactPinSource = 'none',
    this.preferredDate,
    this.preferredTimeWindow = '',
    this.preferredIsFlexible = false,
    this.preferredTimingNote = '',
    this.preferredTimingDecision = '',
    this.suggestedDate,
    this.suggestedTimeWindow = '',
    this.quoteHistory = const <VanQuoteHistoryEntry>[],
    this.isTestData = false,
    this.testMode = false,
    this.deleted = false,
    this.archived = false,
  });

  final String jobId;
  final String customerName;
  final String jobTitle;
  final DateTime? scheduledAt;
  final String jobDateLabel;
  final String jobTimeLabel;
  final String address;
  final String phoneNumber;
  final String customerEmail;
  final String postcode;
  final String notesMessage;
  final bool requestExactPin;
  final bool requestPhotos;
  final bool requiresExactPinAfterQuoteAccepted;
  final List<String> checklistItems;
  final List<String> customQuestions;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? draftSavedAt;
  final DateTime? requestSentAt;
  final DateTime? replyReceivedAt;
  final DateTime? quoteSavedAt;
  final DateTime? quoteSentAt;
  final DateTime? quoteOpenedAt;
  final DateTime? quoteAcceptedAt;
  final DateTime? quoteDeclinedAt;
  final String declineReasonCode;
  final String declineReasonLabel;
  final String declineReasonText;
  final String declineNote;
  final DateTime? quoteRespondedAt;
  final String quoteResponseStatus;
  final String quoteTimingChoice;
  final DateTime? agreedDateTime;
  final String currentQuoteId;
  final String quoteResponseId;
  final String quoteResponseToken;
  final String quoteResponseLink;
  final List<String> quoteExtras;
  final String quoteJobDescription;
  final String quoteNotes;
  final String quotePaymentInstructions;
  final String quoteMessage;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final double? quoteAmount;
  final String quoteStatus;
  final bool quoteAccepted;
  final bool quoteDeclined;
  final bool exactPinShared;
  final List<DriverChecklistResponse> checklistResponses;
  final List<DriverCustomQuestionResponse> customQuestionResponses;
  final String additionalNotes;
  final bool hasReply;
  final bool hasExactPin;
  final VanExactPinSource? exactPinShareSource;
  final String? exactPinNote;
  final double? exactPinLatitude;
  final double? exactPinLongitude;
  final String? requestId;
  final String requestStatus;
  final DateTime? requestCreatedAt;
  final DateTime? requestUpdatedAt;
  final DateTime? requestSubmittedAt;
  final DateTime? requestExpiresAt;
  final String requestLink;
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
  final String proposedDate;
  final String proposedStartTime;
  final String proposedAppointmentNote;
  final String acceptedProposedDate;
  final String acceptedProposedStartTime;
  final String schedulingStatus;
  final String scheduledDate;
  final String scheduledStartTime;
  final int? estimatedDurationMinutes;
  final String calendarStatus;
  final bool locationPending;
  final String exactPinSource;
  final DateTime? preferredDate;
  final String preferredTimeWindow;
  final bool preferredIsFlexible;
  final String preferredTimingNote;
  final String preferredTimingDecision;
  final DateTime? suggestedDate;
  final String suggestedTimeWindow;
  final List<VanQuoteHistoryEntry> quoteHistory;
  final bool isTestData;
  final bool testMode;
  final bool deleted;
  final bool archived;

  VanCustomerJourneyType get customerJourney =>
      vanCustomerJourneyTypeFromStorage(customerJourneyType);
  VanCustomerRequestType get customerRequestType =>
      vanCustomerRequestTypeFromStorage(
        requestType,
        fallback: VanCustomerRequestType.quoteRequest,
      );
  bool get hasServiceHandover =>
      vanRequestTypeSupportsHandover(customerRequestType);
  VanServiceHandoverConfig get effectiveHandover =>
      VanServiceHandoverConfig.resolve(
        requestType: customerRequestType,
        startValue: startHandover,
        endValue: endHandover,
        allowedStartValues: allowedStartHandoverOptions,
        allowedEndValues: allowedEndHandoverOptions,
      );
  String get handoverSummary => vanBusinessHandoverSummary(
    effectiveHandover.start,
    effectiveHandover.end,
  );

  String get activeQuoteResponseLink => resolveVanQuoteResponseDisplayLink(
    quoteResponseLink: quoteResponseLink,
    quoteResponseToken: quoteResponseToken,
    quoteId: authoritativeCurrentQuoteId.isNotEmpty
        ? authoritativeCurrentQuoteId
        : jobId,
  );

  String get authoritativeCurrentQuoteId {
    final currentId = currentQuoteId.trim();
    return currentId.isNotEmpty ? currentId : quoteResponseId.trim();
  }

  DateTime? get scheduledAtOrParsed {
    final direct = scheduledAt;
    if (direct != null) {
      return direct;
    }
    final savedScheduled = _parseIsoDateAndTime(
      scheduledDate,
      scheduledStartTime,
    );
    if (savedScheduled != null) {
      return savedScheduled;
    }
    return _parseScheduledAt(jobDateLabel, jobTimeLabel);
  }

  DateTime? get proposedScheduledAt =>
      _parseIsoDateAndTime(proposedDate, proposedStartTime);

  DateTime? get acceptedProposedScheduledAt =>
      _parseIsoDateAndTime(acceptedProposedDate, acceptedProposedStartTime);

  VanBookedCalendarSlot? get bookedCalendarSlot {
    if (deleted || archived || isCancelled || isDraft) {
      return null;
    }

    final normalizedCalendarStatus = calendarStatus.trim().toLowerCase();
    final isBookedByCalendarStatus =
        normalizedCalendarStatus == 'scheduled' ||
        normalizedCalendarStatus == 'completed';
    final isBookedByJobState = isConfirmed || isCompletedJob;
    if (!isBookedByCalendarStatus && !isBookedByJobState) {
      return null;
    }

    final persistedStart = _parseIsoDateAndTime(
      scheduledDate,
      scheduledStartTime,
    );
    final fallbackStart =
        scheduledAt ??
        _parseScheduledAt(jobDateLabel, jobTimeLabel) ??
        acceptedProposedScheduledAt ??
        proposedScheduledAt;
    final start = persistedStart ?? fallbackStart;
    if (start == null) {
      return null;
    }

    final effectiveDuration =
        dropOffPickupDurationMinutes ?? estimatedDurationMinutes;
    final resolvedDuration = effectiveDuration == null
        ? 60
        : effectiveDuration.clamp(1, 24 * 60).toInt();

    return VanBookedCalendarSlot(
      start: start,
      durationMinutes: resolvedDuration,
      calendarStatus: normalizedCalendarStatus,
      schedulingStatus: schedulingStatus.trim().toLowerCase(),
      usedPersistedScheduleFields: persistedStart != null,
    );
  }

  bool get hasExactPinCoordinates =>
      exactPinLatitude != null && exactPinLongitude != null;

  bool get exactPinSaved =>
      hasExactPin || exactPinShared || hasExactPinCoordinates;

  bool get hasLocationDetails =>
      address.trim().isNotEmpty || postcode.trim().isNotEmpty;

  bool get isDropOffPickupRequest =>
      requestType.trim().toLowerCase() == 'dropoffpickuprequest';

  bool get requiresAnyExactPin => isDropOffPickupRequest
      ? requiresExactPinAfterQuoteAccepted
      : requestExactPin || requiresExactPinAfterQuoteAccepted;

  DateTime? get dropOffDateTime =>
      _combineVanJobDateAndTime(dropOffDate, dropOffTime);

  DateTime? get pickUpDateTime =>
      _combineVanJobDateAndTime(pickUpDate, pickUpTime);

  int? get dropOffPickupDurationMinutes {
    final start = dropOffDateTime;
    final end = pickUpDateTime;
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    return end.difference(start).inMinutes;
  }

  int? get effectiveCalendarDurationMinutes =>
      dropOffPickupDurationMinutes ?? estimatedDurationMinutes;

  bool get isAwaitingRequiredExactPin =>
      isQuoteAccepted && requiresAnyExactPin && !exactPinSaved;

  bool get hasAgreedSchedulingTime {
    if (isConfirmed || isCompletedJob || isScheduledInCalendarState) {
      return true;
    }
    if (agreedDateTime != null) {
      return true;
    }
    if (isDropOffPickupRequest &&
        dropOffDateTime != null &&
        pickUpDateTime != null) {
      return true;
    }
    final normalizedSchedulingStatus = schedulingStatus.trim().toLowerCase();
    final normalizedQuoteTimingChoice = quoteTimingChoice.trim().toLowerCase();
    final hasPersistedSchedule =
        scheduledAt != null ||
        scheduledDate.trim().isNotEmpty ||
        scheduledStartTime.trim().isNotEmpty;
    if (normalizedQuoteTimingChoice == 'agreed_time_saved') {
      return agreedDateTime != null || hasPersistedSchedule;
    }
    if (normalizedSchedulingStatus == 'time_agreed' ||
        normalizedSchedulingStatus == 'ready_for_calendar') {
      return hasPersistedSchedule;
    }
    if (normalizedQuoteTimingChoice == 'accepted_proposed_time' ||
        normalizedSchedulingStatus == 'accepted_time') {
      return acceptedProposedScheduledAt != null ||
          proposedScheduledAt != null ||
          hasPersistedSchedule;
    }
    return false;
  }

  bool get shouldPromptSetAgreedTime =>
      isQuoteAccepted &&
      !isConfirmed &&
      !isCompletedJob &&
      !isDeclined &&
      !hasAgreedSchedulingTime;

  bool get shouldPromptAddToCalendar =>
      isQuoteAccepted &&
      !isConfirmed &&
      !isCompletedJob &&
      !isDeclined &&
      !isAwaitingRequiredExactPin &&
      hasAgreedSchedulingTime;

  bool get isReadyToAddToCalendar => shouldPromptAddToCalendar && exactPinSaved;

  bool get isQuoteAwaitingCustomerResponse {
    if (!hasQuote) {
      return false;
    }
    final normalizedQuoteResponseStatus = quoteResponseStatus
        .trim()
        .toLowerCase();
    if (isQuoteAccepted ||
        isQuoteDeclined ||
        isConfirmed ||
        isCompletedJob ||
        normalizedQuoteResponseStatus == 'accepted' ||
        normalizedQuoteResponseStatus == 'declined' ||
        quoteRespondedAt != null) {
      return false;
    }
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedQuoteStatus = quoteStatus.trim().toLowerCase();
    return normalizedStatus == 'quotesent' ||
        normalizedQuoteStatus == 'sent' ||
        normalizedQuoteStatus == 'opened_for_sending';
  }

  bool get isDeclined =>
      status.trim().toLowerCase() == 'declined' ||
      requestStatus.trim().toLowerCase() == 'declined' ||
      quoteStatus.trim().toLowerCase() == 'declined' ||
      status.trim().toLowerCase() == 'quotedeclined' ||
      requestStatus.trim().toLowerCase() == 'quote_declined' ||
      quoteDeclined;

  bool get _hasQuoteAcceptedSignal =>
      quoteAccepted ||
      quoteResponseStatus.trim().toLowerCase() == 'accepted' ||
      quoteStatus.trim().toLowerCase() == 'accepted' ||
      status.trim().toLowerCase() == 'quoteaccepted' ||
      requestStatus.trim().toLowerCase() == 'quote_accepted';

  bool get isQuoteAccepted => hasQuote && _hasQuoteAcceptedSignal;

  bool get _hasQuoteDeclinedSignal =>
      quoteDeclined ||
      quoteResponseStatus.trim().toLowerCase() == 'declined' ||
      quoteStatus.trim().toLowerCase() == 'declined' ||
      status.trim().toLowerCase() == 'quotedeclined' ||
      requestStatus.trim().toLowerCase() == 'quote_declined';

  bool get isQuoteDeclined => hasQuote && _hasQuoteDeclinedSignal;

  String get quoteDeclineReasonCodeValue => declineReasonCode.trim();

  String get quoteDeclineReasonCode => quoteDeclineReasonCodeValue;

  String get quoteDeclineReasonValue {
    final label = declineReasonLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return declineReasonText.trim();
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

  bool get hasDeclinedQuoteHistory =>
      quoteHistory.any((entry) => entry.isDeclined);

  VanQuoteHistoryEntry? get latestDeclinedQuoteHistory {
    final declined = quoteHistory
        .where((entry) => entry.isDeclined)
        .toList(growable: false);
    if (declined.isEmpty) {
      return null;
    }
    declined.sort((a, b) {
      final aDate =
          a.quoteDeclinedAt ??
          a.quoteRespondedAt ??
          a.quoteSentAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.quoteDeclinedAt ??
          b.quoteRespondedAt ??
          b.quoteSentAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return declined.first;
  }

  bool get isAwaitingAgreedTime =>
      !hasAgreedSchedulingTime &&
      ((quoteTimingChoice.trim().toLowerCase() == 'arrange_another_time' &&
              agreedDateTime == null) ||
          schedulingStatus.trim().toLowerCase() == 'awaiting_agreed_time');

  bool get hasRequestBeenSent =>
      !isHiddenFromNormalLists && vanJobRequestHasBeenSent(requestStatus);

  bool get hasCustomerRequestAttached => hasRequest;

  bool get hasCustomerReply =>
      !isHiddenFromNormalLists &&
      vanJobRequestHasCustomerReply(
        status: requestStatus,
        replyReceivedAt: replyReceivedAt,
        requestSubmittedAt: requestSubmittedAt,
        hasChecklistResponses: checklistResponses.any(
          (response) =>
              response.answer.trim().isNotEmpty ||
              (response.note?.trim().isNotEmpty ?? false),
        ),
        hasCustomQuestionResponses: customQuestionResponses.any(
          (response) => response.answer.trim().isNotEmpty,
        ),
        hasAdditionalNotes: additionalNotes.trim().isNotEmpty,
      );

  bool get replyReceived => hasCustomerReply;

  int get checklistAnsweredCount =>
      checklistResponses.where(_isAnsweredChecklistResponse).length;

  int get customAnsweredCount => customQuestionResponses
      .where((response) => response.answer.trim().isNotEmpty)
      .length;

  String get invoiceHistoryKey => jobId.trim().isNotEmpty
      ? jobId.trim()
      : '${customerName.trim().toLowerCase()}|${jobTitle.trim().toLowerCase()}|${address.trim().toLowerCase()}';

  bool get isDraft => status == 'draft';
  bool get isRequestSent => status == 'requestSent';
  bool get isReplyReceived =>
      !isHiddenFromNormalLists &&
      (hasCustomerReply || status == 'replyReceived');
  bool get _hasQuoteSentSignal {
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(requestStatus);
    final normalizedQuoteStatus = quoteStatus.trim().toLowerCase();
    return normalizedStatus == 'quotesent' ||
        normalizedRequestStatus == 'quoted' ||
        normalizedRequestStatus == 'quote_sent' ||
        normalizedQuoteStatus == 'sent' ||
        normalizedQuoteStatus == 'opened_for_sending' ||
        quoteSentAt != null ||
        quoteOpenedAt != null;
  }

  bool get isQuoteSent => hasQuote && _hasQuoteSentSignal;
  bool get isQuoteOpenedForSending =>
      hasQuote &&
      (quoteStatus.trim().toLowerCase() == 'opened_for_sending' ||
          quoteStatus.trim().toLowerCase() == 'sent' ||
          quoteSentAt != null ||
          quoteOpenedAt != null);
  bool get isConfirmed {
    if (isHiddenFromNormalLists || isCompletedJob) {
      return false;
    }

    final normalizedStatus = status.trim().toLowerCase();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(requestStatus);
    final rawRequestStatus = requestStatus.trim().toLowerCase();

    return normalizedStatus == 'confirmed' ||
        normalizedStatus == 'scheduled' ||
        normalizedStatus == 'jobready' ||
        normalizedStatus == 'ready' ||
        normalizedStatus == 'booked' ||
        normalizedRequestStatus == 'confirmed' ||
        rawRequestStatus == 'confirmed';
  }

  bool get isScheduledInCalendarState {
    if (isHiddenFromNormalLists || isCancelled) {
      return false;
    }

    final normalizedStatus = status.trim().toLowerCase();
    final normalizedCalendarStatus = calendarStatus.trim().toLowerCase();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(requestStatus);
    final rawRequestStatus = requestStatus.trim().toLowerCase();

    return normalizedCalendarStatus == 'scheduled' ||
        normalizedCalendarStatus == 'completed' ||
        normalizedStatus == 'scheduled' ||
        normalizedStatus == 'confirmed' ||
        normalizedStatus == 'booked' ||
        normalizedStatus == 'jobready' ||
        normalizedStatus == 'ready' ||
        normalizedRequestStatus == 'confirmed' ||
        rawRequestStatus == 'confirmed';
  }

  bool get isCompletedJob {
    final normalized = status.trim().toLowerCase();
    final normalizedCalendarStatus = calendarStatus.trim().toLowerCase();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(requestStatus);
    return normalized == 'completed' ||
        normalized == 'done' ||
        normalized == 'completedjob' ||
        normalizedCalendarStatus == 'completed' ||
        normalizedRequestStatus == 'completed' ||
        completedAt != null;
  }

  bool get isCompleted => isCompletedJob;
  bool get isCancelled => status == 'cancelled';

  bool get isMarkedTestData => isTestData || testMode;

  bool get isHiddenFromNormalLists => deleted || archived;

  bool get hasRequest => requestId?.trim().isNotEmpty == true;

  VanCalendarJobKind get calendarJobKind {
    final normalizedRequestType = requestType.trim().toLowerCase();
    final normalizedFulfilmentType = fulfilmentType.trim().toLowerCase();
    if (normalizedRequestType == 'orderrequest') {
      if (normalizedFulfilmentType == 'collection') {
        return VanCalendarJobKind.collectionOrder;
      }
      if (normalizedFulfilmentType == 'delivery') {
        return VanCalendarJobKind.deliveryOrder;
      }
    }
    if (normalizedRequestType == 'dropoffpickuprequest') {
      return VanCalendarJobKind.dropOffPickup;
    }
    if (normalizedRequestType == 'pickupdeliveryrequest') {
      return VanCalendarJobKind.pickupDelivery;
    }
    return VanCalendarJobKind.standard;
  }

  bool get allowsParallelCalendarScheduling => switch (calendarJobKind) {
    VanCalendarJobKind.collectionOrder ||
    VanCalendarJobKind.dropOffPickup ||
    VanCalendarJobKind.pickupDelivery => true,
    VanCalendarJobKind.standard || VanCalendarJobKind.deliveryOrder => false,
  };

  bool get _hasExplicitQuoteResponseLink =>
      currentQuoteId.trim().isNotEmpty ||
      quoteResponseId.trim().isNotEmpty ||
      quoteResponseToken.trim().isNotEmpty ||
      quoteResponseLink.trim().isNotEmpty;

  bool get _hasQuoteArtifact =>
      quoteSavedAt != null ||
      quoteSentAt != null ||
      quoteOpenedAt != null ||
      _hasExplicitQuoteResponseLink ||
      quoteHistory.isNotEmpty;

  bool get _hasQuoteWorkflow => hasQuote;

  bool get _hasCustomerRequestWorkflow =>
      hasRequest ||
      requestStatus.trim().isNotEmpty ||
      requestLink.trim().isNotEmpty ||
      requestSentAt != null ||
      replyReceivedAt != null ||
      hasCustomerReply ||
      exactPinSaved ||
      _hasQuoteWorkflow;

  bool get isRequestExpired {
    if (isHiddenFromNormalLists) {
      return false;
    }
    final normalizedStatus = normalizeVanJobRequestStatus(requestStatus);
    if (!hasRequest ||
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'reply_received' ||
        replyReceived) {
      return false;
    }

    final expiresAt = requestExpiresAt;
    return expiresAt != null && DateTime.now().isAfter(expiresAt);
  }

  bool get isRequestPending {
    return !isHiddenFromNormalLists && _isPendingCustomerRequestWorkflow();
  }

  bool get isPendingCustomerRequest => isRequestPending;

  bool _isPendingCustomerRequestWorkflow() {
    if (isHiddenFromNormalLists || isCancelled || isCompletedJob) {
      return false;
    }

    if (isConfirmed || isScheduledInCalendarState) {
      return false;
    }

    final rawRequestStatus = requestStatus.trim().toLowerCase();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(requestStatus);
    final rawQuoteStatus = quoteStatus.trim().toLowerCase();
    final pendingRequestStatuses = <String>{
      'pending',
      'sent',
      'requestsent',
      'request_sent',
      'replied',
      'reply_received',
      'action_needed',
      'actionneeded',
      'ready_to_quote',
      'readytoquote',
      'awaiting_reply',
      'awaitingreply',
    };
    final pendingQuoteStatuses = <String>{
      'opened_for_sending',
      'waiting',
      'sent',
      'prepared',
    };

    if (pendingRequestStatuses.contains(rawRequestStatus) ||
        pendingRequestStatuses.contains(normalizedRequestStatus) ||
        pendingQuoteStatuses.contains(rawQuoteStatus)) {
      return true;
    }

    if (replyReceivedAt != null || exactPinSaved || _hasQuoteWorkflow) {
      return true;
    }

    return _hasCustomerRequestWorkflow;
  }

  bool get isRequestSubmitted {
    return !isHiddenFromNormalLists &&
        (hasCustomerReply ||
            normalizeVanJobRequestStatus(requestStatus) == 'reply_received');
  }

  bool get isRequestCancelled => requestStatus == 'cancelled';

  bool get isRequestExactPinReceived => isRequestSubmitted && exactPinSaved;

  bool get hasQuote {
    return _hasQuoteArtifact;
  }

  bool get canCreateQuoteFromCustomerReply =>
      !isHiddenFromNormalLists &&
      hasCustomerReply &&
      !hasQuote &&
      !isQuoteAccepted &&
      !isQuoteDeclined &&
      !isConfirmed &&
      !isCompletedJob &&
      !isCancelled;

  bool get canCreateQuoteFromJobInfo =>
      !isHiddenFromNormalLists &&
      !hasCustomerRequestAttached &&
      !isCancelled &&
      (!hasQuote || isQuoteDeclined);

  bool get canCreateInvoiceFromJobInfo =>
      !isHiddenFromNormalLists &&
      !isCancelled &&
      (!hasCustomerRequestAttached || isCompleted);

  VanQuoteUiStatus get quoteUiStatus => deriveVanQuoteUiStatus(
    hasRequest: hasRequest,
    hasReply: hasCustomerReply,
    hasQuote: hasQuote,
    hasRequestBeenSent: hasRequestBeenSent,
    isQuoteAccepted: isQuoteAccepted,
    isQuoteDeclined: isQuoteDeclined,
    isConfirmed: isConfirmed,
    isScheduledInCalendar: isScheduledInCalendarState,
    isQuoteAwaitingCustomerResponse: isQuoteAwaitingCustomerResponse,
    wasQuoteRevised: hasDeclinedQuoteHistory,
    hasAgreedTime: hasAgreedSchedulingTime,
    needsAgreedTime: isAwaitingAgreedTime,
    requiresExactPin: requiresAnyExactPin,
    hasExactPin: exactPinSaved,
  );

  String get requestStatusLabel {
    if (isHiddenFromNormalLists) {
      return deleted ? 'Deleted' : 'Archived';
    }
    if (isRequestCancelled) {
      return 'Cancelled';
    }
    if (isRequestExpired) {
      return 'Expired';
    }
    return quoteUiStatus.statusLabel;
  }

  String get requestBadgeLabel {
    if (isRequestCancelled) {
      return 'Cancelled';
    }
    if (isRequestExpired) {
      return 'Expired';
    }
    return quoteUiStatus.secondaryChipLabel;
  }

  String get requestStatusSummary {
    if (isRequestCancelled) {
      return 'Request cancelled.';
    }
    if (isRequestExpired) {
      return 'Request expired.';
    }
    return quoteUiStatus.summary;
  }

  VanJobRequestDraft toDraft() {
    return VanJobRequestDraft(
      jobId: jobId,
      customerName: customerName,
      phoneNumber: phoneNumber,
      customerEmail: customerEmail,
      jobTitle: jobTitle,
      scheduledAt: scheduledAtOrParsed ?? DateTime.now(),
      jobDateLabel: jobDateLabel,
      jobTimeLabel: jobTimeLabel,
      address: address,
      postcode: postcode,
      notesMessage: notesMessage,
      requestExactPin: requestExactPin,
      requestPhotos: requestPhotos,
      requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
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
      selectedQuestionIds: const <String>[],
      answers: const <VanJobRequestAnswer>[],
      checklistItems: checklistItems,
      customQuestions: customQuestions,
      scheduledDate: scheduledDate,
      scheduledStartTime: scheduledStartTime,
      estimatedDurationMinutes: estimatedDurationMinutes,
      calendarStatus: calendarStatus,
      exactPinLatitude: exactPinLatitude,
      exactPinLongitude: exactPinLongitude,
      exactPinSource: exactPinSource,
    );
  }

  VanInvoiceDraft toInvoiceDraft({
    required VanBusinessProfile businessProfile,
    required String invoiceNumber,
  }) {
    final invoiceDate = _defaultInvoiceDateLabel();
    return VanInvoiceDraft.initial(
      jobKey: invoiceHistoryKey,
      linkedJobId: jobId,
      linkedQuoteId: quoteResponseId.trim().isNotEmpty
          ? quoteResponseId.trim()
          : null,
      businessProfile: businessProfile,
      customerName: customerName,
      customerPhone: phoneNumber,
      customerEmail: customerEmail,
      billingAddress: address,
      invoiceDate: invoiceDate,
      jobReference: jobTitle,
      jobDescription: quoteJobDescription.trim().isNotEmpty
          ? quoteJobDescription.trim()
          : (notesMessage.trim().isNotEmpty ? notesMessage.trim() : jobTitle),
      invoiceNumber: invoiceNumber,
      quoteExtras: quoteExtras,
      quoteNotes: quoteNotes,
      quotePaymentInstructions: quotePaymentInstructions,
      quoteMessage: quoteMessage,
      quoteAmount: quoteAmount ?? 0,
    );
  }

  String _defaultInvoiceDateLabel() {
    final confirmedAt = _confirmedInvoiceAppointmentDateTime();
    if (confirmedAt != null) {
      return formatDateTime(confirmedAt, TimeOfDay.fromDateTime(confirmedAt));
    }
    return jobTimeLabel.trim().isEmpty
        ? jobDateLabel
        : '$jobDateLabel $jobTimeLabel'.trim();
  }

  DateTime? _confirmedInvoiceAppointmentDateTime() {
    return bookedCalendarSlot?.start ??
        agreedDateTime ??
        acceptedProposedScheduledAt ??
        proposedScheduledAt ??
        scheduledAt ??
        _parseIsoDateAndTime(scheduledDate, scheduledStartTime);
  }

  String get statusLabel {
    if (isCompletedJob) {
      return 'Completed';
    }
    if (isDeclined) {
      return 'Quote declined';
    }
    if (isConfirmed) {
      return 'Added to Calendar';
    }
    if (isQuoteAccepted) {
      return 'Quote accepted';
    }
    if (isCancelled) {
      return 'Cancelled';
    }
    if (isQuoteSent) {
      return 'Quote sent';
    }
    if (isQuoteOpenedForSending) {
      return 'Quote waiting confirmation';
    }
    if (replyReceived) {
      return 'Reply received';
    }
    switch (status) {
      case 'requestSent':
        return 'Pending customer request';
      default:
        return 'Draft';
    }
  }

  DriverCustomerReplyMockData copyWith({
    String? jobId,
    String? customerName,
    String? jobTitle,
    DateTime? scheduledAt,
    String? jobDateLabel,
    String? jobTimeLabel,
    String? address,
    String? phoneNumber,
    String? customerEmail,
    String? postcode,
    String? notesMessage,
    bool? requestExactPin,
    bool? requestPhotos,
    bool? requiresExactPinAfterQuoteAccepted,
    List<String>? checklistItems,
    List<String>? customQuestions,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? draftSavedAt,
    DateTime? requestSentAt,
    DateTime? replyReceivedAt,
    DateTime? quoteSavedAt,
    DateTime? quoteSentAt,
    DateTime? quoteOpenedAt,
    DateTime? quoteAcceptedAt,
    DateTime? quoteDeclinedAt,
    String? declineReasonCode,
    String? declineReasonLabel,
    String? declineReasonText,
    String? declineNote,
    DateTime? quoteRespondedAt,
    String? quoteResponseStatus,
    String? quoteTimingChoice,
    DateTime? agreedDateTime,
    String? currentQuoteId,
    String? quoteResponseId,
    String? quoteResponseToken,
    String? quoteResponseLink,
    List<String>? quoteExtras,
    String? quoteJobDescription,
    String? quoteNotes,
    String? quotePaymentInstructions,
    String? quoteMessage,
    DateTime? confirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    double? quoteAmount,
    String? quoteStatus,
    bool? quoteAccepted,
    bool? quoteDeclined,
    bool? exactPinShared,
    List<DriverChecklistResponse>? checklistResponses,
    List<DriverCustomQuestionResponse>? customQuestionResponses,
    String? additionalNotes,
    bool? hasReply,
    bool? hasExactPin,
    VanExactPinSource? exactPinShareSource,
    String? exactPinNote,
    double? exactPinLatitude,
    double? exactPinLongitude,
    String? requestId,
    String? requestStatus,
    DateTime? requestCreatedAt,
    DateTime? requestUpdatedAt,
    DateTime? requestSubmittedAt,
    DateTime? requestExpiresAt,
    String? requestLink,
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
    String? proposedDate,
    String? proposedStartTime,
    String? proposedAppointmentNote,
    String? acceptedProposedDate,
    String? acceptedProposedStartTime,
    String? schedulingStatus,
    String? scheduledDate,
    String? scheduledStartTime,
    int? estimatedDurationMinutes,
    String? calendarStatus,
    bool? locationPending,
    String? exactPinSource,
    DateTime? preferredDate,
    String? preferredTimeWindow,
    bool? preferredIsFlexible,
    String? preferredTimingNote,
    String? preferredTimingDecision,
    DateTime? suggestedDate,
    String? suggestedTimeWindow,
    List<VanQuoteHistoryEntry>? quoteHistory,
    bool? isTestData,
    bool? testMode,
    bool? deleted,
    bool? archived,
  }) {
    final isRequestSent = status == 'requestSent';
    return DriverCustomerReplyMockData(
      jobId: jobId ?? this.jobId,
      customerName: customerName ?? this.customerName,
      jobTitle: jobTitle ?? this.jobTitle,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      jobDateLabel: jobDateLabel ?? this.jobDateLabel,
      jobTimeLabel: jobTimeLabel ?? this.jobTimeLabel,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      customerEmail: customerEmail ?? this.customerEmail,
      postcode: postcode ?? this.postcode,
      notesMessage: notesMessage ?? this.notesMessage,
      requestExactPin: requestExactPin ?? this.requestExactPin,
      requestPhotos: requestPhotos ?? this.requestPhotos,
      requiresExactPinAfterQuoteAccepted:
          requiresExactPinAfterQuoteAccepted ??
          this.requiresExactPinAfterQuoteAccepted,
      checklistItems: checklistItems ?? this.checklistItems,
      customQuestions: customQuestions ?? this.customQuestions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      draftSavedAt: draftSavedAt ?? this.draftSavedAt,
      requestSentAt: requestSentAt ?? this.requestSentAt,
      replyReceivedAt: isRequestSent
          ? null
          : (replyReceivedAt ?? this.replyReceivedAt),
      quoteSavedAt: quoteSavedAt ?? this.quoteSavedAt,
      quoteSentAt: quoteSentAt ?? this.quoteSentAt,
      quoteOpenedAt: quoteOpenedAt ?? this.quoteOpenedAt,
      quoteAcceptedAt: quoteAcceptedAt ?? this.quoteAcceptedAt,
      quoteDeclinedAt: quoteDeclinedAt ?? this.quoteDeclinedAt,
      declineReasonCode: declineReasonCode ?? this.declineReasonCode,
      declineReasonLabel: declineReasonLabel ?? this.declineReasonLabel,
      declineReasonText: declineReasonText ?? this.declineReasonText,
      declineNote: declineNote ?? this.declineNote,
      quoteRespondedAt: quoteRespondedAt ?? this.quoteRespondedAt,
      quoteResponseStatus: quoteResponseStatus ?? this.quoteResponseStatus,
      quoteTimingChoice: quoteTimingChoice ?? this.quoteTimingChoice,
      agreedDateTime: agreedDateTime ?? this.agreedDateTime,
      currentQuoteId: currentQuoteId ?? this.currentQuoteId,
      quoteResponseId: quoteResponseId ?? this.quoteResponseId,
      quoteResponseToken: quoteResponseToken ?? this.quoteResponseToken,
      quoteResponseLink: quoteResponseLink ?? this.quoteResponseLink,
      quoteExtras: quoteExtras ?? this.quoteExtras,
      quoteJobDescription: quoteJobDescription ?? this.quoteJobDescription,
      quoteNotes: quoteNotes ?? this.quoteNotes,
      quotePaymentInstructions:
          quotePaymentInstructions ?? this.quotePaymentInstructions,
      quoteMessage: quoteMessage ?? this.quoteMessage,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      quoteAmount: quoteAmount ?? this.quoteAmount,
      quoteStatus: quoteStatus ?? this.quoteStatus,
      quoteAccepted: quoteAccepted ?? this.quoteAccepted,
      quoteDeclined: quoteDeclined ?? this.quoteDeclined,
      exactPinShared: exactPinShared ?? this.exactPinShared,
      checklistResponses: isRequestSent
          ? const <DriverChecklistResponse>[]
          : (checklistResponses ?? this.checklistResponses),
      customQuestionResponses: isRequestSent
          ? const <DriverCustomQuestionResponse>[]
          : (customQuestionResponses ?? this.customQuestionResponses),
      additionalNotes: isRequestSent
          ? ''
          : (additionalNotes ?? this.additionalNotes),
      hasReply: isRequestSent ? false : (hasReply ?? this.hasReply),
      hasExactPin: hasExactPin ?? this.hasExactPin,
      exactPinShareSource: exactPinShareSource ?? this.exactPinShareSource,
      exactPinNote: exactPinNote ?? this.exactPinNote,
      exactPinLatitude: exactPinLatitude ?? this.exactPinLatitude,
      exactPinLongitude: exactPinLongitude ?? this.exactPinLongitude,
      requestId: requestId ?? this.requestId,
      requestStatus: requestStatus ?? this.requestStatus,
      requestCreatedAt: requestCreatedAt ?? this.requestCreatedAt,
      requestUpdatedAt: requestUpdatedAt ?? this.requestUpdatedAt,
      requestSubmittedAt: isRequestSent
          ? null
          : (requestSubmittedAt ?? this.requestSubmittedAt),
      requestExpiresAt: requestExpiresAt ?? this.requestExpiresAt,
      requestLink: requestLink ?? this.requestLink,
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
      proposedDate: proposedDate ?? this.proposedDate,
      proposedStartTime: proposedStartTime ?? this.proposedStartTime,
      proposedAppointmentNote:
          proposedAppointmentNote ?? this.proposedAppointmentNote,
      acceptedProposedDate: acceptedProposedDate ?? this.acceptedProposedDate,
      acceptedProposedStartTime:
          acceptedProposedStartTime ?? this.acceptedProposedStartTime,
      schedulingStatus: schedulingStatus ?? this.schedulingStatus,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      calendarStatus: calendarStatus ?? this.calendarStatus,
      locationPending: locationPending ?? this.locationPending,
      exactPinSource: exactPinSource ?? this.exactPinSource,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeWindow: preferredTimeWindow ?? this.preferredTimeWindow,
      preferredIsFlexible: preferredIsFlexible ?? this.preferredIsFlexible,
      preferredTimingNote: preferredTimingNote ?? this.preferredTimingNote,
      preferredTimingDecision:
          preferredTimingDecision ?? this.preferredTimingDecision,
      suggestedDate: suggestedDate ?? this.suggestedDate,
      suggestedTimeWindow: suggestedTimeWindow ?? this.suggestedTimeWindow,
      quoteHistory: quoteHistory ?? this.quoteHistory,
      isTestData: isTestData ?? this.isTestData,
      testMode: testMode ?? this.testMode,
      deleted: deleted ?? this.deleted,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jobId': jobId,
      'customerName': customerName,
      'jobTitle': jobTitle,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'jobDateLabel': jobDateLabel,
      'jobTimeLabel': jobTimeLabel,
      'address': address,
      'customerPhone': phoneNumber,
      'phoneNumber': phoneNumber,
      'phone': phoneNumber,
      'customerEmail': customerEmail,
      'postcode': postcode,
      'notesMessage': notesMessage,
      'requestExactPin': requestExactPin,
      'requestPhotos': requestPhotos,
      'requiresExactPinAfterQuoteAccepted': requiresExactPinAfterQuoteAccepted,
      'checklistItems': checklistItems,
      'customQuestions': customQuestions,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'draftSavedAt': draftSavedAt?.toIso8601String(),
      'requestSentAt': requestSentAt?.toIso8601String(),
      'replyReceivedAt': replyReceivedAt?.toIso8601String(),
      'quoteSavedAt': quoteSavedAt?.toIso8601String(),
      'quoteSentAt': quoteSentAt?.toIso8601String(),
      'quoteOpenedAt': quoteOpenedAt?.toIso8601String(),
      'quoteAcceptedAt': quoteAcceptedAt?.toIso8601String(),
      'quoteDeclinedAt': quoteDeclinedAt?.toIso8601String(),
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
      'quoteRespondedAt': quoteRespondedAt?.toIso8601String(),
      'quoteResponseStatus': quoteResponseStatus,
      'quoteTimingChoice': quoteTimingChoice,
      'agreedDateTime': agreedDateTime?.toIso8601String(),
      'currentQuoteId': authoritativeCurrentQuoteId,
      'quoteResponseId': authoritativeCurrentQuoteId,
      'quoteResponseToken': quoteResponseToken,
      'quoteResponseLink': quoteResponseLink,
      'quoteExtras': quoteExtras,
      'quoteJobDescription': quoteJobDescription,
      'quoteNotes': quoteNotes,
      'quotePaymentInstructions': quotePaymentInstructions,
      'quoteMessage': quoteMessage,
      'confirmedAt': confirmedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'quoteAmount': quoteAmount,
      'quoteSent':
          isQuoteSent ||
          quoteSentAt != null ||
          quoteStatus.trim().toLowerCase() == 'sent',
      'quoteStatus': quoteStatus,
      'quoteAccepted': quoteAccepted,
      'quoteDeclined': quoteDeclined,
      'exactPinShared': exactPinShared,
      'hasReply': hasReply,
      'hasExactPin': hasExactPin,
      'checklistResponses': checklistResponses
          .map(
            (response) => <String, dynamic>{
              'question': response.question,
              'answer': response.answer,
              'note': response.note,
              'icon': response.icon.codePoint,
            },
          )
          .toList(),
      'customQuestionResponses': customQuestionResponses
          .map(
            (response) => <String, dynamic>{
              'question': response.question,
              'answer': response.answer,
            },
          )
          .toList(),
      'additionalNotes': additionalNotes,
      'exactPinShareSource': vanExactPinSourceToStorage(exactPinShareSource),
      'exactPinNote': exactPinNote,
      'exactPinLatitude': exactPinLatitude,
      'exactPinLongitude': exactPinLongitude,
      'requestId': requestId,
      'requestStatus': requestStatus,
      'requestCreatedAt': requestCreatedAt?.toIso8601String(),
      'requestUpdatedAt': requestUpdatedAt?.toIso8601String(),
      'requestSubmittedAt': requestSubmittedAt?.toIso8601String(),
      'requestExpiresAt': requestExpiresAt?.toIso8601String(),
      'requestLink': requestLink,
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
      'proposedDate': proposedDate,
      'proposedStartTime': proposedStartTime,
      'proposedAppointmentNote': proposedAppointmentNote,
      'acceptedProposedDate': acceptedProposedDate,
      'acceptedProposedStartTime': acceptedProposedStartTime,
      'schedulingStatus': schedulingStatus,
      'scheduledDate': scheduledDate,
      'scheduledStartTime': scheduledStartTime,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'calendarStatus': calendarStatus,
      'locationPending': locationPending,
      'exactPinSource': exactPinSource,
      'preferredDate': preferredDate?.toIso8601String(),
      'preferredTimeWindow': preferredTimeWindow,
      'preferredIsFlexible': preferredIsFlexible,
      'preferredTimingNote': preferredTimingNote,
      'preferredTimingDecision': preferredTimingDecision,
      'suggestedDate': suggestedDate?.toIso8601String(),
      'suggestedTimeWindow': suggestedTimeWindow,
      'quoteHistory': quoteHistory.map((entry) => entry.toJson()).toList(),
      'isTestData': isTestData,
      'testMode': testMode,
      'deleted': deleted,
      'archived': archived,
    };
  }

  factory DriverCustomerReplyMockData.fromJson(Map<String, dynamic> json) {
    final draftJson = json['draft'];
    final effectiveJson = draftJson is Map
        ? <String, dynamic>{...json, ...Map<String, dynamic>.from(draftJson)}
        : json;
    final checklistJson = effectiveJson['checklistResponses'];
    final customJson = effectiveJson['customQuestionResponses'];
    final quoteHistoryJson = effectiveJson['quoteHistory'];
    final parsedChecklistResponses = checklistJson is List
        ? checklistJson
              .whereType<Map>()
              .map((item) {
                final map = Map<String, dynamic>.from(item);
                return DriverChecklistResponse(
                  question: _jsonText(map['question']),
                  answer: _jsonText(map['answer']),
                  note: _jsonTextOrNull(map['note']),
                  icon: Icons.checklist,
                );
              })
              .toList(growable: false)
        : const <DriverChecklistResponse>[];
    final parsedCustomQuestionResponses = customJson is List
        ? customJson
              .whereType<Map>()
              .map(
                (item) => DriverCustomQuestionResponse(
                  question: _jsonText(item['question']),
                  answer: _jsonText(item['answer']),
                ),
              )
              .toList(growable: false)
        : const <DriverCustomQuestionResponse>[];
    final parsedQuoteHistory = quoteHistoryJson is List
        ? quoteHistoryJson
              .whereType<Map>()
              .map(
                (item) => VanQuoteHistoryEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.quoteResponseId.trim().isNotEmpty)
              .toList(growable: false)
        : const <VanQuoteHistoryEntry>[];
    final parsedReplyReceivedAt = _jsonDateTime(
      effectiveJson['replyReceivedAt'],
    );
    final parsedExactPinLatitude = _jsonDoubleOrNull(
      effectiveJson['exactPinLatitude'],
    );
    final parsedExactPinLongitude = _jsonDoubleOrNull(
      effectiveJson['exactPinLongitude'],
    );
    final parsedHasReply =
        normalizeVanJobRequestStatus(effectiveJson['requestStatus']) ==
            'reply_received' ||
        parsedReplyReceivedAt != null ||
        parsedChecklistResponses.any((response) {
          return response.answer.trim().isNotEmpty ||
              (response.note?.trim().isNotEmpty ?? false);
        }) ||
        parsedCustomQuestionResponses.any(
          (response) => response.answer.trim().isNotEmpty,
        ) ||
        _jsonText(effectiveJson['additionalNotes']).trim().isNotEmpty;
    final parsedExactPinShared =
        parsedHasReply &&
        (_jsonBool(effectiveJson['exactPinShared']) ||
            _jsonBool(effectiveJson['hasExactPin']) ||
            (parsedExactPinLatitude != null &&
                parsedExactPinLongitude != null));
    final parsedAgreedDateTime =
        _jsonDateTime(effectiveJson['agreedDateTime']) ??
        _jsonDateTime(effectiveJson['agreedStartAt']);
    final rawQuoteResponseStatus = _jsonText(
      effectiveJson['quoteResponseStatus'],
    );
    final rawQuoteStatus = _jsonText(effectiveJson['quoteStatus']);
    final parsedCurrentQuoteId = _jsonText(
      effectiveJson['currentQuoteId'],
      fallback: _jsonText(effectiveJson['quoteResponseId']),
    ).trim();
    final parsedQuoteResponseId = parsedCurrentQuoteId.isNotEmpty
        ? parsedCurrentQuoteId
        : _jsonText(effectiveJson['quoteResponseId']).trim();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(
      effectiveJson['requestStatus'],
    );
    final normalizedStatus = _normalizeDriverJobStatus(effectiveJson['status']);
    final parsedTimeAccepted =
        _jsonBool(effectiveJson['timeAccepted']) ||
        _jsonBool(effectiveJson['acceptedProposedTime']) ||
        _jsonBool(effectiveJson['proposedTimeAccepted']);
    final parsedTimingNeedsDecision =
        _jsonBool(effectiveJson['timingNeedsDecision']) ||
        _jsonBool(effectiveJson['timeNotAccepted']) ||
        _jsonBool(effectiveJson['needsAgreedTime']);
    final rawTimeStatus = _jsonText(
      effectiveJson['timeStatus'],
    ).trim().toLowerCase();
    final rawTimingStatus = _jsonText(
      effectiveJson['timingStatus'],
    ).trim().toLowerCase();
    final parsedReadyForCalendar =
        _jsonBool(effectiveJson['readyForCalendar']) ||
        rawTimeStatus == 'ready_for_calendar' ||
        rawTimingStatus == 'ready_for_calendar';
    final parsedTimeAgreed =
        _jsonBool(effectiveJson['timeAgreed']) ||
        parsedTimeAccepted ||
        parsedReadyForCalendar ||
        rawTimeStatus == 'agreed' ||
        rawTimeStatus == 'accepted' ||
        rawTimeStatus == 'accepted_time' ||
        rawTimeStatus == 'time_agreed' ||
        rawTimingStatus == 'agreed' ||
        rawTimingStatus == 'accepted' ||
        rawTimingStatus == 'accepted_time' ||
        rawTimingStatus == 'time_agreed';
    final parsedQuoteAccepted =
        _jsonBool(effectiveJson['quoteAccepted']) ||
        _jsonBool(effectiveJson['acceptedQuote']) ||
        rawQuoteResponseStatus.trim().toLowerCase() == 'accepted' ||
        rawQuoteStatus.trim().toLowerCase() == 'accepted' ||
        normalizedRequestStatus == 'quote_accepted' ||
        normalizedStatus.trim().toLowerCase() == 'quoteaccepted' ||
        parsedTimeAccepted ||
        parsedReadyForCalendar ||
        (parsedTimeAgreed && parsedAgreedDateTime != null);
    final acceptedProposedDateText = _jsonIsoDateText(
      effectiveJson['acceptedProposedDate'],
    );
    final agreedDateText = _jsonIsoDateText(effectiveJson['agreedDate']);
    final scheduledDateText = _jsonIsoDateText(effectiveJson['scheduledDate']);
    final parsedAcceptedProposedDate =
        acceptedProposedDateText.trim().isNotEmpty
        ? acceptedProposedDateText
        : agreedDateText.trim().isNotEmpty
        ? agreedDateText
        : parsedTimeAccepted
        ? scheduledDateText
        : '';
    final acceptedProposedStartTimeText = _jsonTimeText(
      effectiveJson['acceptedProposedStartTime'],
    );
    final agreedTimeText = _jsonTimeText(effectiveJson['agreedTime']);
    final scheduledStartTimeText = _jsonTimeText(
      effectiveJson['scheduledStartTime'],
    );
    final parsedAcceptedProposedStartTime =
        acceptedProposedStartTimeText.trim().isNotEmpty
        ? acceptedProposedStartTimeText
        : agreedTimeText.trim().isNotEmpty
        ? agreedTimeText
        : parsedTimeAccepted
        ? scheduledStartTimeText
        : '';
    final rawQuoteTimingChoice = _jsonText(effectiveJson['quoteTimingChoice']);
    final parsedQuoteTimingChoice = rawQuoteTimingChoice.trim().isNotEmpty
        ? rawQuoteTimingChoice
        : parsedTimeAccepted
        ? 'accepted_proposed_time'
        : parsedTimingNeedsDecision
        ? 'arrange_another_time'
        : '';
    final rawSchedulingStatus = _jsonText(effectiveJson['schedulingStatus']);
    final parsedSchedulingStatus = rawSchedulingStatus.trim().isNotEmpty
        ? rawSchedulingStatus
        : parsedReadyForCalendar
        ? 'ready_for_calendar'
        : parsedTimeAccepted
        ? 'accepted_time'
        : parsedTimingNeedsDecision
        ? 'awaiting_agreed_time'
        : '';
    final loadedPhone = _resolvedCustomerPhoneFromMap(effectiveJson);
    if (kDebugMode) {
      final fallbackPhone = _jsonText(effectiveJson['phoneNumber']);
      debugPrint(
        '[PhoneLoad] jobId=${_jsonText(effectiveJson['jobId'])} customerPhone=$loadedPhone phoneFallback=$fallbackPhone',
      );
    }
    return DriverCustomerReplyMockData(
      jobId: _jsonText(effectiveJson['jobId']),
      customerName: _jsonText(effectiveJson['customerName']),
      jobTitle: _jsonText(effectiveJson['jobTitle']),
      scheduledAt: _jsonDateTime(effectiveJson['scheduledAt']),
      jobDateLabel: _jsonText(effectiveJson['jobDateLabel']),
      jobTimeLabel: _jsonText(effectiveJson['jobTimeLabel']),
      address: _jsonText(effectiveJson['address']),
      phoneNumber: loadedPhone,
      customerEmail: _jsonText(effectiveJson['customerEmail']),
      postcode: _jsonText(
        effectiveJson['postcode'],
        fallback: _jsonText(effectiveJson['customerPostcode']),
      ),
      notesMessage: _jsonText(effectiveJson['notesMessage']),
      requestExactPin:
          _jsonText(effectiveJson['requestType']).trim().toLowerCase() ==
              'dropoffpickuprequest'
          ? false
          : _jsonBool(effectiveJson['requestExactPin']),
      requestPhotos: _jsonBool(effectiveJson['requestPhotos']),
      requiresExactPinAfterQuoteAccepted:
          _jsonBool(effectiveJson['requiresExactPinAfterQuoteAccepted']) ||
          _jsonBool(effectiveJson['exactPinRequiredAfterQuoteAccepted']) ||
          _jsonBool(effectiveJson['requiresExactPinAfterQuoteAcceptance']),
      checklistItems:
          (effectiveJson['checklistItems'] as List?)
              ?.map((item) => sanitizeVanText(item?.toString()).trim())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      customQuestions:
          (effectiveJson['customQuestions'] as List?)
              ?.map((item) => sanitizeVanText(item?.toString()).trim())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      status: parsedQuoteAccepted ? 'quoteAccepted' : normalizedStatus,
      createdAt: _jsonDateTime(effectiveJson['createdAt']),
      updatedAt: _jsonDateTime(effectiveJson['updatedAt']),
      draftSavedAt: _jsonDateTime(effectiveJson['draftSavedAt']),
      requestSentAt: _jsonDateTime(effectiveJson['requestSentAt']),
      replyReceivedAt: _jsonDateTime(effectiveJson['replyReceivedAt']),
      quoteSavedAt: _jsonDateTime(effectiveJson['quoteSavedAt']),
      quoteSentAt: _jsonDateTime(effectiveJson['quoteSentAt']),
      quoteOpenedAt: _jsonDateTime(effectiveJson['quoteOpenedAt']),
      quoteAcceptedAt: _jsonDateTime(effectiveJson['quoteAcceptedAt']),
      quoteDeclinedAt: _jsonDateTime(effectiveJson['quoteDeclinedAt']),
      declineReasonCode: _jsonText(
        effectiveJson['declineReasonCode'],
        fallback: _jsonText(
          effectiveJson['quoteDeclineReasonCode'],
          fallback: readVanNestedText(effectiveJson['quoteDecline'], const [
            'reasonCode',
            'code',
          ]),
        ),
      ),
      declineReasonLabel: _jsonText(
        effectiveJson['declineReasonLabel'],
        fallback: _jsonText(
          effectiveJson['quoteDeclineReasonLabel'],
          fallback: _jsonText(
            effectiveJson['quoteDeclineReason'],
            fallback: _jsonText(
              effectiveJson['quoteDeclinedReason'],
              fallback: _jsonText(
                effectiveJson['lastQuoteDeclineReason'],
                fallback: readVanNestedText(
                  effectiveJson['quoteDecline'],
                  const ['reasonLabel', 'reason'],
                ),
              ),
            ),
          ),
        ),
      ),
      declineReasonText: _jsonText(
        effectiveJson['declineReasonText'],
        fallback: _jsonText(
          effectiveJson['declineNote'],
          fallback: _jsonText(
            effectiveJson['quoteDeclineNote'],
            fallback: _jsonText(
              effectiveJson['quoteDeclinedNote'],
              fallback: _jsonText(
                effectiveJson['lastQuoteDeclineNote'],
                fallback: readVanNestedText(
                  effectiveJson['quoteDecline'],
                  const ['reasonText', 'note'],
                ),
              ),
            ),
          ),
        ),
      ),
      declineNote: _jsonText(
        effectiveJson['declineNote'],
        fallback: _jsonText(
          effectiveJson['quoteDeclineNote'],
          fallback: _jsonText(
            effectiveJson['declineReasonText'],
            fallback: _jsonText(
              effectiveJson['quoteDeclinedNote'],
              fallback: _jsonText(
                effectiveJson['lastQuoteDeclineNote'],
                fallback: readVanNestedText(
                  effectiveJson['quoteDecline'],
                  const ['note', 'reasonText'],
                ),
              ),
            ),
          ),
        ),
      ),
      quoteRespondedAt: _jsonDateTime(effectiveJson['quoteRespondedAt']),
      quoteResponseStatus: parsedQuoteAccepted
          ? 'accepted'
          : rawQuoteResponseStatus,
      quoteTimingChoice: parsedQuoteTimingChoice,
      agreedDateTime: parsedAgreedDateTime,
      currentQuoteId: parsedCurrentQuoteId,
      quoteResponseId: parsedQuoteResponseId,
      quoteResponseToken: _jsonText(effectiveJson['quoteResponseToken']),
      quoteResponseLink: resolveVanQuoteResponseDisplayLink(
        quoteResponseLink: _jsonText(effectiveJson['quoteResponseLink']),
        quoteResponseToken: _jsonText(effectiveJson['quoteResponseToken']),
        quoteId: parsedQuoteResponseId,
      ),
      quoteExtras:
          (effectiveJson['quoteExtras'] as List?)
              ?.map((item) => sanitizeVanText(item?.toString()).trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      quoteJobDescription: _jsonText(
        effectiveJson['quoteJobDescription'] ?? effectiveJson['jobDescription'],
      ),
      quoteNotes: _jsonText(effectiveJson['quoteNotes']),
      quotePaymentInstructions: _jsonText(
        effectiveJson['quotePaymentInstructions'] ??
            effectiveJson['paymentInstructions'],
      ),
      quoteMessage: _jsonText(effectiveJson['quoteMessage']),
      confirmedAt: _jsonDateTime(effectiveJson['confirmedAt']),
      completedAt: _jsonDateTime(effectiveJson['completedAt']),
      cancelledAt: _jsonDateTime(effectiveJson['cancelledAt']),
      quoteAmount: _jsonDoubleOrNull(effectiveJson['quoteAmount']),
      quoteStatus: parsedQuoteAccepted ? 'accepted' : rawQuoteStatus,
      quoteAccepted: parsedQuoteAccepted,
      quoteDeclined: _jsonBool(effectiveJson['quoteDeclined']),
      exactPinShared: parsedExactPinShared,
      checklistResponses: parsedChecklistResponses,
      customQuestionResponses: parsedCustomQuestionResponses,
      additionalNotes: _jsonText(effectiveJson['additionalNotes']),
      hasReply: parsedHasReply,
      hasExactPin: parsedExactPinShared,
      exactPinShareSource: vanExactPinSourceFromStorage(
        effectiveJson['exactPinShareSource']?.toString(),
      ),
      exactPinNote: _jsonTextOrNull(effectiveJson['exactPinNote']),
      exactPinLatitude: parsedExactPinLatitude,
      exactPinLongitude: parsedExactPinLongitude,
      requestId: _jsonTextOrNull(effectiveJson['requestId']),
      requestStatus: (() {
        if (normalizedRequestStatus == 'cancelled') {
          return 'cancelled';
        }
        if (parsedQuoteAccepted) {
          return 'quote_accepted';
        }
        if (_jsonBool(effectiveJson['quoteDeclined']) ||
            rawQuoteResponseStatus.trim().toLowerCase() == 'declined' ||
            normalizedRequestStatus == 'quote_declined') {
          return 'quote_declined';
        }
        return parsedHasReply ? 'reply_received' : normalizedRequestStatus;
      })(),
      requestCreatedAt: _jsonDateTime(effectiveJson['requestCreatedAt']),
      requestUpdatedAt: _jsonDateTime(effectiveJson['requestUpdatedAt']),
      requestSubmittedAt: _jsonDateTime(effectiveJson['requestSubmittedAt']),
      requestExpiresAt: _jsonDateTime(effectiveJson['requestExpiresAt']),
      requestLink: _jsonText(effectiveJson['requestLink']),
      requestType: _jsonText(effectiveJson['requestType']),
      customerJourneyType:
          _jsonText(effectiveJson['customerJourneyType']).trim().isEmpty
          ? 'quote'
          : _jsonText(effectiveJson['customerJourneyType']),
      startHandover: _jsonText(effectiveJson['startHandover']),
      endHandover: _jsonText(effectiveJson['endHandover']),
      allowedStartHandoverOptions:
          (effectiveJson['allowedStartHandoverOptions'] as List?)
              ?.map((item) => _jsonText(item))
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      allowedEndHandoverOptions:
          (effectiveJson['allowedEndHandoverOptions'] as List?)
              ?.map((item) => _jsonText(item))
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      collectionAddress: _jsonText(
        effectiveJson['collectionAddress'] ?? effectiveJson['pickupAddress'],
      ),
      returnAddress: _jsonText(
        effectiveJson['returnAddress'] ?? effectiveJson['deliveryAddress'],
      ),
      returnAddressSameAsCollection: _jsonBool(
        effectiveJson['returnAddressSameAsCollection'],
      ),
      businessDropOffInstructions: _jsonText(
        effectiveJson['businessDropOffInstructions'],
      ),
      businessCollectionInstructions: _jsonText(
        effectiveJson['businessCollectionInstructions'],
      ),
      fulfilmentType: _jsonText(effectiveJson['fulfilmentType']),
      dropOffDate: _jsonDateTime(effectiveJson['dropOffDate']),
      dropOffTime: _jsonText(effectiveJson['dropOffTime']),
      pickUpDate: _jsonDateTime(effectiveJson['pickUpDate']),
      pickUpTime: _jsonText(effectiveJson['pickUpTime']),
      proposedDate: _jsonIsoDateText(effectiveJson['proposedDate']),
      proposedStartTime: _jsonTimeText(effectiveJson['proposedStartTime']),
      proposedAppointmentNote: _jsonText(
        effectiveJson['proposedAppointmentNote'],
      ),
      acceptedProposedDate: parsedAcceptedProposedDate,
      acceptedProposedStartTime: parsedAcceptedProposedStartTime,
      schedulingStatus: parsedSchedulingStatus,
      scheduledDate: scheduledDateText,
      scheduledStartTime: scheduledStartTimeText,
      estimatedDurationMinutes: _jsonIntOrNull(
        effectiveJson['estimatedDurationMinutes'],
      ),
      calendarStatus:
          _jsonText(
            effectiveJson['calendarStatus'],
          ).trim().toLowerCase().isEmpty
          ? 'unscheduled'
          : _jsonText(effectiveJson['calendarStatus']).trim().toLowerCase(),
      locationPending:
          _jsonText(effectiveJson['requestType']).trim().toLowerCase() ==
              'dropoffpickuprequest'
          ? (_jsonBool(effectiveJson['requiresExactPinAfterQuoteAccepted']) &&
                _jsonBool(effectiveJson['locationPending']))
          : _jsonBool(effectiveJson['locationPending']),
      exactPinSource:
          _jsonText(
            effectiveJson['exactPinSource'],
          ).trim().toLowerCase().isEmpty
          ? 'none'
          : _jsonText(effectiveJson['exactPinSource']).trim().toLowerCase(),
      preferredDate:
          _jsonDateTime(effectiveJson['preferredDate']) ??
          _jsonDateTime(effectiveJson['preferredDateAt']),
      preferredTimeWindow: _jsonText(
        effectiveJson['preferredTimeWindow'],
      ).trim().toLowerCase(),
      preferredIsFlexible:
          _jsonBool(effectiveJson['preferredIsFlexible']) ||
          _jsonBool(effectiveJson['timingFlexible']),
      preferredTimingNote: _jsonText(effectiveJson['preferredTimingNote']),
      preferredTimingDecision: _jsonText(
        effectiveJson['preferredTimingDecision'],
      ),
      suggestedDate:
          _jsonDateTime(effectiveJson['suggestedDate']) ??
          _jsonDateTime(effectiveJson['suggestedDateAt']),
      suggestedTimeWindow: _jsonText(
        effectiveJson['suggestedTimeWindow'],
      ).trim().toLowerCase(),
      quoteHistory: parsedQuoteHistory,
      isTestData: _jsonBool(effectiveJson['isTestData']),
      testMode: _jsonBool(effectiveJson['testMode']),
      deleted: _jsonBool(json['deleted']),
      archived: _jsonBool(json['archived']),
    );
  }
}

DateTime? effectiveAgreedSchedulingTimeForJob(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  if (job.isDropOffPickupRequest &&
      job.dropOffDateTime != null &&
      job.pickUpDateTime != null) {
    return job.dropOffDateTime;
  }
  if (request?.isDropOffPickupRequest == true &&
      request?.dropOffDateTime != null &&
      request?.pickUpDateTime != null) {
    return request?.dropOffDateTime;
  }
  if (job.isConfirmed || job.isCompletedJob || job.isScheduledInCalendarState) {
    return job.bookedCalendarSlot?.start ??
        job.agreedDateTime ??
        job.acceptedProposedScheduledAt ??
        job.scheduledAtOrParsed ??
        request?.agreedStartAt ??
        request?.agreedDateTime ??
        request?.scheduledAt;
  }

  final jobTimingChoice = job.quoteTimingChoice.trim().toLowerCase();
  final jobSchedulingStatus = job.schedulingStatus.trim().toLowerCase();
  if (job.agreedDateTime != null) {
    return job.agreedDateTime;
  }
  if (jobSchedulingStatus == 'time_agreed' ||
      jobSchedulingStatus == 'ready_for_calendar') {
    return job.scheduledAtOrParsed;
  }
  if (jobTimingChoice == 'accepted_proposed_time' ||
      jobSchedulingStatus == 'accepted_time') {
    return job.acceptedProposedScheduledAt ??
        job.proposedScheduledAt ??
        job.scheduledAtOrParsed;
  }

  if (request == null) {
    return null;
  }
  final requestTimingChoice = request.quoteTimingChoice.trim().toLowerCase();
  final requestSchedulingStatus = request.schedulingStatus.trim().toLowerCase();
  if (request.agreedStartAt != null || request.agreedDateTime != null) {
    return request.agreedStartAt ?? request.agreedDateTime;
  }
  if (request.acceptedProposedTime ||
      requestTimingChoice == 'accepted_proposed_time' ||
      requestSchedulingStatus == 'accepted_time' ||
      request.timeAgreed ||
      request.readyForCalendar ||
      requestSchedulingStatus == 'time_agreed' ||
      requestSchedulingStatus == 'ready_for_calendar') {
    return request.agreedStartAt ??
        request.agreedDateTime ??
        request.scheduledAt;
  }
  return null;
}

bool hasCanonicalAgreedSchedulingTimeForJob(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  if (job.isDropOffPickupRequest &&
      job.dropOffDateTime != null &&
      job.pickUpDateTime != null) {
    return true;
  }
  if (request?.isDropOffPickupRequest == true &&
      request?.dropOffDateTime != null &&
      request?.pickUpDateTime != null) {
    return true;
  }
  if (job.isConfirmed || job.isCompletedJob || job.isScheduledInCalendarState) {
    return true;
  }
  final requestCalendarStatus =
      request?.calendarStatus.trim().toLowerCase() ?? '';
  if (requestCalendarStatus == 'scheduled' ||
      requestCalendarStatus == 'completed') {
    return true;
  }

  final jobSchedulingStatus = job.schedulingStatus.trim().toLowerCase();
  final requestSchedulingStatus =
      request?.schedulingStatus.trim().toLowerCase() ?? '';
  final jobQuoteTimingChoice = job.quoteTimingChoice.trim().toLowerCase();
  final requestQuoteTimingChoice =
      request?.quoteTimingChoice.trim().toLowerCase() ?? '';
  final effectiveScheduledAt = effectiveAgreedSchedulingTimeForJob(
    job,
    request: request,
  );

  if (effectiveScheduledAt == null) {
    return false;
  }

  final hasManualAgreedSignal =
      jobSchedulingStatus == 'agreed_manual' ||
      jobSchedulingStatus == 'time_agreed' ||
      jobSchedulingStatus == 'ready_for_calendar' ||
      requestSchedulingStatus == 'agreed_manual' ||
      requestSchedulingStatus == 'time_agreed' ||
      requestSchedulingStatus == 'ready_for_calendar' ||
      jobQuoteTimingChoice == 'agreed_time_saved' ||
      requestQuoteTimingChoice == 'agreed_time_saved';
  if (hasManualAgreedSignal) {
    return true;
  }

  return jobSchedulingStatus == 'accepted_time' ||
      requestSchedulingStatus == 'accepted_time' ||
      jobQuoteTimingChoice == 'accepted_proposed_time' ||
      requestQuoteTimingChoice == 'accepted_proposed_time';
}

bool shouldPromptSetAgreedTimeForJob(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  return job.isQuoteAccepted &&
      !job.isConfirmed &&
      !job.isCompletedJob &&
      !job.isDeclined &&
      !hasCanonicalAgreedSchedulingTimeForJob(job, request: request);
}

bool shouldPromptAddToCalendarForJob(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  return job.isQuoteAccepted &&
      !job.isConfirmed &&
      !job.isCompletedJob &&
      !job.isDeclined &&
      !job.isScheduledInCalendarState &&
      !job.isAwaitingRequiredExactPin &&
      hasCanonicalAgreedSchedulingTimeForJob(job, request: request);
}

@immutable
class VanJobActionState {
  const VanJobActionState({
    required this.hasCustomerReply,
    required this.hasRealQuote,
    required this.isQuoteAccepted,
    required this.isAwaitingExactPin,
    required this.canCreateQuote,
    required this.canReviseQuote,
    required this.canViewQuote,
    required this.canSetAgreedTime,
    required this.canAddToCalendar,
    required this.canNavigate,
    required this.canCallCustomer,
    required this.canTextCustomer,
  });

  final bool hasCustomerReply;
  final bool hasRealQuote;
  final bool isQuoteAccepted;
  final bool isAwaitingExactPin;
  final bool canCreateQuote;
  final bool canReviseQuote;
  final bool canViewQuote;
  final bool canSetAgreedTime;
  final bool canAddToCalendar;
  final bool canNavigate;
  final bool canCallCustomer;
  final bool canTextCustomer;
}

VanJobActionState deriveVanJobActionState(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
  String phoneNumberOverride = '',
  bool allowCreateQuoteFromJobInfo = true,
}) {
  final isInactive =
      job.isHiddenFromNormalLists || job.isCancelled || job.isCompletedJob;
  final hasCustomerReply =
      job.hasCustomerReply || request?.hasCustomerReply == true;
  final hasRealQuote = job.hasQuote;
  final canCreateFromReply =
      !isInactive && hasCustomerReply && !hasRealQuote && !job.isConfirmed;
  final canCreateFromJobInfo =
      allowCreateQuoteFromJobInfo &&
      !hasRealQuote &&
      job.canCreateQuoteFromJobInfo;
  final canReviseQuote = !isInactive && hasRealQuote && job.isQuoteDeclined;
  final canSetAgreedTime = shouldPromptSetAgreedTimeForJob(
    job,
    request: request,
  );
  final canAddToCalendar =
      !isInactive &&
      !job.isConfirmed &&
      shouldPromptAddToCalendarForJob(job, request: request) &&
      effectiveAgreedSchedulingTimeForJob(job, request: request) != null;
  final phoneNumber = phoneNumberOverride.trim().isNotEmpty
      ? phoneNumberOverride
      : (request?.publicPhoneNumber.trim().isNotEmpty == true
            ? request!.publicPhoneNumber
            : job.phoneNumber);
  final canContactCustomer = sanitizeVanCustomerPhoneNumber(
    phoneNumber,
  ).isNotEmpty;

  return VanJobActionState(
    hasCustomerReply: hasCustomerReply,
    hasRealQuote: hasRealQuote,
    isQuoteAccepted: job.isQuoteAccepted,
    isAwaitingExactPin: job.isAwaitingRequiredExactPin,
    canCreateQuote: canCreateFromReply || canCreateFromJobInfo,
    canReviseQuote: canReviseQuote,
    canViewQuote: hasRealQuote,
    canSetAgreedTime: canSetAgreedTime,
    canAddToCalendar: canAddToCalendar,
    canNavigate:
        !isInactive && hasUsableNavigationTargetForJob(job, request: request),
    canCallCustomer: canContactCustomer,
    canTextCustomer: canContactCustomer,
  );
}

bool hasUsableNavigationTargetForJob(
  DriverCustomerReplyMockData job, {
  VanJobRequestRecord? request,
}) {
  final hasJobExactPin =
      job.exactPinLatitude != null && job.exactPinLongitude != null;
  final hasRequestExactPin =
      (request?.exactPinLat != null && request?.exactPinLng != null) ||
      (request?.exactPinLatitude != null && request?.exactPinLongitude != null);
  if (hasJobExactPin || hasRequestExactPin) {
    return true;
  }

  return job.address.trim().isNotEmpty ||
      job.postcode.trim().isNotEmpty ||
      (request?.publicAddressSummary.trim().isNotEmpty ?? false) ||
      (request?.customerPostcode.trim().isNotEmpty ?? false);
}

bool _hasUsefulNote(String? note) {
  if (note == null) {
    return false;
  }

  final normalized = note.trim().toLowerCase().replaceAll(
    RegExp(r'[.!]+$'),
    '',
  );
  if (normalized.isEmpty) {
    return false;
  }

  const placeholders = <String>{
    'no extra note',
    'no extra notes',
    'no extra notes added',
    'none',
    'n/a',
    'na',
    'no note',
  };

  return !placeholders.contains(normalized);
}

String _preferredTimingSummaryForQuote(DriverCustomerReplyMockData reply) {
  final parts = <String>[];
  final preferredDate = reply.preferredDate;
  if (preferredDate != null) {
    parts.add(formatDate(preferredDate));
  }
  final windowLabel = _preferredTimeWindowLabel(reply.preferredTimeWindow);
  if (windowLabel.isNotEmpty) {
    parts.add(windowLabel);
  }
  if (reply.preferredIsFlexible) {
    parts.add('Flexible');
  }
  return parts.join(' • ');
}

String _preferredTimeWindowLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'morning':
      return 'Morning';
    case 'afternoon':
      return 'Afternoon';
    case 'evening':
      return 'Evening';
    case 'anytime':
      return 'Anytime';
    default:
      return '';
  }
}

String _normalizeJobRequestStatus(Object? value) {
  return normalizeVanJobRequestStatus(value);
}

String _normalizeDriverJobStatus(Object? value) {
  final text = value?.toString().trim() ?? '';
  final lower = text.toLowerCase();
  switch (lower) {
    case 'draft':
    case 'no_request':
    case 'norequest':
      return 'draft';
    case 'pending':
    case 'sent':
    case 'requestsent':
    case 'request_sent':
      return 'requestSent';
    case 'submitted':
    case 'replyreceived':
    case 'reply_received':
    case 'received_note':
    case 'receivednote':
      return 'replyReceived';
    case 'quote_sent':
    case 'quotesent':
    case 'quoted':
    case 'revised_quote_sent':
    case 'revisedquotesent':
      return 'quoteSent';
    case 'quoteaccepted':
    case 'quote_accepted':
      return 'quoteAccepted';
    case 'quotedeclined':
    case 'quote_declined':
      return 'quoteDeclined';
    case 'confirmed':
      return 'confirmed';
    case 'completed':
    case 'done':
      return 'completed';
    case 'cancelled':
    case 'canceled':
    case 'deleted':
      return 'cancelled';
    default:
      return text.isEmpty ? 'draft' : text;
  }
}

String? _displayNoteText(String? note) {
  if (note == null || note.trim().isEmpty) {
    return null;
  }

  return _hasUsefulNote(note) ? note.trim() : null;
}

DateTime? _parseScheduledAt(String dateLabel, String timeLabel) {
  final date = _parseJobDateLabel(dateLabel);
  if (date == null) {
    return null;
  }

  final time = _parseJobTimeLabel(timeLabel);
  if (time == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime? _parseIsoDateAndTime(String dateValue, String timeValue) {
  final normalizedDate = dateValue.trim();
  final normalizedTime = timeValue.trim();
  if (normalizedDate.isEmpty || normalizedTime.isEmpty) {
    return null;
  }

  final parsedDate = DateTime.tryParse(normalizedDate);
  final parsedTime = _parseJobTimeLabel(normalizedTime);
  if (parsedDate == null || parsedTime == null) {
    return null;
  }

  return DateTime(
    parsedDate.year,
    parsedDate.month,
    parsedDate.day,
    parsedTime.hour,
    parsedTime.minute,
  );
}

DateTime? _combineVanJobDateAndTime(DateTime? date, String timeValue) {
  if (date == null) {
    return null;
  }
  final time = _parseJobTimeLabel(timeValue);
  if (time == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime? _parseJobDateLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})$',
  ).firstMatch(normalized);
  if (match == null) {
    return null;
  }

  final day = int.tryParse(match.group(1) ?? '');
  final month = _monthNumberFromName(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (day == null || month == null || year == null) {
    return null;
  }

  return DateTime(year, month, day);
}

TimeOfDay? _parseJobTimeLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(normalized);
  if (match == null) {
    return null;
  }

  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null) {
    return null;
  }

  return TimeOfDay(hour: hour, minute: minute);
}

int? _monthNumberFromName(String value) {
  switch (value.trim().toLowerCase()) {
    case 'jan':
    case 'january':
      return 1;
    case 'feb':
    case 'february':
      return 2;
    case 'mar':
    case 'march':
      return 3;
    case 'apr':
    case 'april':
      return 4;
    case 'may':
      return 5;
    case 'jun':
    case 'june':
      return 6;
    case 'jul':
    case 'july':
      return 7;
    case 'aug':
    case 'august':
      return 8;
    case 'sep':
    case 'sept':
    case 'september':
      return 9;
    case 'oct':
    case 'october':
      return 10;
    case 'nov':
    case 'november':
      return 11;
    case 'dec':
    case 'december':
      return 12;
  }
  return null;
}

enum VanJobBucket {
  pendingCustomerRequest,
  actionNeededReplyReceived,
  bookedJob,
  completedJob,
  cancelledJobHistory,
  declinedQuoteHistory,
  hiddenDeletedOrDraft,
}

class VanJobBucketDecision {
  const VanJobBucketDecision({required this.bucket, required this.reason});

  final VanJobBucket bucket;
  final String reason;
}

class VanPendingRefreshResult {
  const VanPendingRefreshResult({
    required this.baseMergeSuccess,
    required this.loadedVanJobs,
    required this.loadedVanJobRequests,
    required this.visiblePending,
    required this.visibleCardUpdateFailures,
    required this.ignoredWarnings,
    this.baseError,
  });

  final bool baseMergeSuccess;
  final int loadedVanJobs;
  final int loadedVanJobRequests;
  final int visiblePending;
  final int visibleCardUpdateFailures;
  final int ignoredWarnings;
  final Object? baseError;

  bool get isPartial => baseMergeSuccess && visibleCardUpdateFailures > 0;
}

enum IncomingRequestDeleteStatus { deleted, removedFromDeviceOnly, failed }

class IncomingRequestDeleteResult {
  const IncomingRequestDeleteResult({
    required this.status,
    required this.requestId,
    required this.linkedJobId,
    required this.source,
    required this.ownerUid,
    required this.attemptedPaths,
    required this.localDeleteSucceeded,
    required this.cloudDeleteSucceeded,
    required this.cloudNotFoundOnly,
    required this.cloudPermissionDenied,
    this.errorMessage = '',
  });

  final IncomingRequestDeleteStatus status;
  final String requestId;
  final String linkedJobId;
  final String source;
  final String ownerUid;
  final List<String> attemptedPaths;
  final bool localDeleteSucceeded;
  final bool cloudDeleteSucceeded;
  final bool cloudNotFoundOnly;
  final bool cloudPermissionDenied;
  final String errorMessage;
}

class _IncomingDeleteAttemptResult {
  const _IncomingDeleteAttemptResult({
    required this.path,
    this.deleted = false,
    this.notFound = false,
    this.failed = false,
    this.permissionDenied = false,
  });

  final String path;
  final bool deleted;
  final bool notFound;
  final bool failed;
  final bool permissionDenied;
}

@immutable
class VanBlockedCustomerRecord {
  const VanBlockedCustomerRecord({
    required this.customerName,
    required this.phoneNumber,
    required this.normalizedPhone,
    required this.blockedAt,
    this.blockedByUserId = '',
    this.address = '',
    this.reason = 'Other',
    this.note = '',
    this.relatedJobId = '',
    this.relatedInvoiceId = '',
    this.relatedQuoteId = '',
  });

  final String customerName;
  final String phoneNumber;
  final String normalizedPhone;
  final String blockedByUserId;
  final String address;
  final String reason;
  final String note;
  final DateTime blockedAt;
  final String relatedJobId;
  final String relatedInvoiceId;
  final String relatedQuoteId;

  VanBlockedCustomerRecord copyWith({
    String? customerName,
    String? phoneNumber,
    String? normalizedPhone,
    String? blockedByUserId,
    String? address,
    String? reason,
    String? note,
    DateTime? blockedAt,
    String? relatedJobId,
    String? relatedInvoiceId,
    String? relatedQuoteId,
  }) {
    return VanBlockedCustomerRecord(
      customerName: customerName ?? this.customerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      normalizedPhone: normalizedPhone ?? this.normalizedPhone,
      blockedByUserId: blockedByUserId ?? this.blockedByUserId,
      address: address ?? this.address,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      blockedAt: blockedAt ?? this.blockedAt,
      relatedJobId: relatedJobId ?? this.relatedJobId,
      relatedInvoiceId: relatedInvoiceId ?? this.relatedInvoiceId,
      relatedQuoteId: relatedQuoteId ?? this.relatedQuoteId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'normalizedPhone': normalizedPhone,
      'blockedByUserId': blockedByUserId,
      'address': address,
      'reason': reason,
      'note': note,
      'blockedAt': blockedAt.toIso8601String(),
      'relatedJobId': relatedJobId,
      'relatedInvoiceId': relatedInvoiceId,
      'relatedQuoteId': relatedQuoteId,
    };
  }

  factory VanBlockedCustomerRecord.fromJson(Map<String, dynamic> json) {
    final rawPhone = _jsonText(json['phoneNumber']);
    final preferredNormalized = _jsonText(json['normalizedPhone']);
    return VanBlockedCustomerRecord(
      customerName: _jsonText(json['customerName']),
      phoneNumber: rawPhone,
      normalizedPhone: normalizeVanCustomerPhoneNumberForMatch(
        preferredNormalized.isEmpty ? rawPhone : preferredNormalized,
      ),
      blockedByUserId: _jsonText(json['blockedByUserId']),
      address: _jsonText(json['address']),
      reason: _jsonText(json['reason']).trim().isEmpty
          ? 'Other'
          : _jsonText(json['reason']).trim(),
      note: _jsonText(json['note']),
      blockedAt:
          _jsonDateTime(json['blockedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      relatedJobId: _jsonText(json['relatedJobId']),
      relatedInvoiceId: _jsonText(json['relatedInvoiceId']),
      relatedQuoteId: _jsonText(json['relatedQuoteId']),
    );
  }
}

class DriverReplyMockState extends ChangeNotifier {
  static const int completedJobCalendarRetentionDays = 180;
  // Set this temporarily during development to test calendar expiry quickly.
  // Examples: `Duration(days: 1)` or `Duration(minutes: 5)`.
  static final Duration? completedJobCalendarRetentionDebugOverride = kDebugMode
      ? null
      : null;

  DriverReplyMockState._() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        debugPrint(
          '[DriverStateAuth] authStateChanged uid=${user?.uid ?? '(none)'} '
          'watchers=${_requestWatchSubscriptions.length} requests=${_jobRequestsById.length}',
        );
        _syncRequestWatchers();
      });
    } catch (error) {
      debugPrint('[DriverStateAuth] auth listener unavailable: $error');
    }
  }

  static final DriverReplyMockState instance = DriverReplyMockState._();

  final VanDriverMockStateStorage _storage = VanDriverMockStateStorage.instance;
  final VanInvoiceNumberStorage _invoiceNumberStorage =
      VanInvoiceNumberStorage.instance;
  VanJobDeletionService _jobDeletionService = VanJobDeletionService.instance;
  final Set<String> _deletingJobIds = <String>{};

  VanInvoiceDraft? savedInvoice;
  String? _activeJobId;
  final Map<String, DriverCustomerReplyMockData> _jobsById =
      <String, DriverCustomerReplyMockData>{};
  final Map<String, String> _jobSourceById = <String, String>{};
  final Map<String, VanInvoiceHistoryEntry> _invoiceHistoryByJobKey =
      <String, VanInvoiceHistoryEntry>{};
  final Map<String, VanJobRequestRecord> _jobRequestsById =
      <String, VanJobRequestRecord>{};
  final Map<String, VanBlockedCustomerRecord> _blockedCustomersByPhone =
      <String, VanBlockedCustomerRecord>{};
  final Set<String> _deletedRequestKeys = <String>{};
  final Map<String, StreamSubscription<VanJobRequestRecord?>>
  _requestWatchSubscriptions =
      <String, StreamSubscription<VanJobRequestRecord?>>{};
  StreamSubscription<List<VanJobRequestRecord>>?
  _scopedIncomingRequestSubscription;
  String? _loadedBusinessProfileId;
  String _incomingScopeOwnerUid = '';
  String _incomingScopeBusinessProfileId = '';
  int _incomingScopeGeneration = 0;
  String? _recentRequestRefreshNotice;
  final Set<String> _announcedReplyJobIds = <String>{};
  final Set<String> _announcedExactPinJobIds = <String>{};
  final Map<String, String> _announcedExactPinStateTokens = <String, String>{};
  final Map<String, DateTime> _announcedExactPinEventTimes =
      <String, DateTime>{};
  final Map<String, String> _observedExactPinStateTokens = <String, String>{};
  final Set<String> _announcedQuoteAcceptedJobIds = <String>{};
  final Set<String> _announcedQuoteDeclinedJobIds = <String>{};
  final Set<String> _initializedWatchedRequestIds = <String>{};
  // Exact-pin snackbars are suppressed until the first cloud hydration finishes
  // so startup snapshots do not replay old pin events.
  bool _hasCompletedInitialCloudHydration = false;
  bool _loggedReplyDebugSample = false;
  Future<void>? _cloudHydrateFuture;
  bool _isHydratingCloud = false;
  Future<void>? _invoiceCloudLoadFuture;
  final Set<String> _cloudVanJobIds = <String>{};
  int _refreshJobsFromCloudCallCount = 0;
  int _hydrateFromCloudCallCount = 0;
  int _syncRequestWatchersCallCount = 0;
  int _watchedRequestUpdateCount = 0;

  Future<void> ensureLoaded() => _storage.ensureLoaded();

  int get activeRequestWatchCount => _requestWatchSubscriptions.length;

  int get jobRequestCount => _jobRequestsById.length;

  bool get isHydratingCloudForDebug => _isHydratingCloud;

  Future<void> _loadDeletedRequestKeys() async {
    final storedKeys = await VanDeletedRequestsStore.instance.loadDeletedKeys();
    _deletedRequestKeys
      ..clear()
      ..addAll(storedKeys);
    debugPrint(
      '[IncomingRequestDelete] loaded deleted keys count=${_deletedRequestKeys.length}',
    );
  }

  Future<void> _persistDeletedRequestKeys() async {
    await VanDeletedRequestsStore.instance.saveDeletedKeys(_deletedRequestKeys);
  }

  Future<void> loadFromStorage() async {
    await ensureLoaded();
    await _loadDeletedRequestKeys();
    final businessProfileId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    final scopeChanged = _loadedBusinessProfileId != businessProfileId;
    final json = await _storage.loadJson(businessProfileId: businessProfileId);
    final currentBusinessProfileId = await VanBusinessProfileScopeStorage
        .instance
        .activeBusinessId();
    if (currentBusinessProfileId != businessProfileId) {
      debugPrint(
        '[IncomingScope] local cache discarded businessProfileId=$businessProfileId '
        'currentBusinessProfileId=$currentBusinessProfileId reason=stale_scope',
      );
      return;
    }
    if (scopeChanged) {
      _clearInMemoryStateForBusinessSwitch();
      _loadedBusinessProfileId = businessProfileId;
      _incomingScopeGeneration += 1;
      _incomingScopeOwnerUid = '';
      _incomingScopeBusinessProfileId = businessProfileId;
      await _scopedIncomingRequestSubscription?.cancel();
      _scopedIncomingRequestSubscription = null;
      debugPrint(
        '[IncomingScope] local scope changed businessProfileId=$businessProfileId '
        'cache=${json == null ? 'empty' : 'loaded'} generation=$_incomingScopeGeneration',
      );
    }
    if (json == null) {
      if (scopeChanged) {
        notifyListeners();
      }
      return;
    }

    _applyJson(json);
    await _persistDeletedRequestKeys();
    _syncRequestWatchers();
  }

  Future<void> saveToStorage({bool syncCloud = true}) async {
    final businessProfileId =
        _loadedBusinessProfileId ??
        await VanBusinessProfileScopeStorage.instance.activeBusinessId();
    _loadedBusinessProfileId ??= businessProfileId;
    await _persistDeletedRequestKeys();
    await _storage.saveJson(_toJson(), businessProfileId: businessProfileId);
    if (!syncCloud) {
      return;
    }

    try {
      logVanFirebaseHydration(
        stage: 'started',
        target: 'jobs cloud sync',
        extra: 'jobs=${jobs.length} invoices=${_invoiceHistoryByJobKey.length}',
      );
      await _syncToCloud();
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'jobs cloud sync',
        extra: 'jobs=${jobs.length} invoices=${_invoiceHistoryByJobKey.length}',
      );
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'jobs cloud sync',
        extra: error.toString(),
      );
      debugPrint('[VanJobsCloud] sync failed: $error');
    }
  }

  void _clearInMemoryStateForBusinessSwitch() {
    _cancelAllRequestWatchers();
    _jobsById.clear();
    _jobSourceById.clear();
    _invoiceHistoryByJobKey.clear();
    _jobRequestsById.clear();
    _blockedCustomersByPhone.clear();
    _cloudVanJobIds.clear();
    _announcedReplyJobIds.clear();
    _announcedExactPinJobIds.clear();
    _announcedExactPinStateTokens.clear();
    _announcedExactPinEventTimes.clear();
    _observedExactPinStateTokens.clear();
    _announcedQuoteAcceptedJobIds.clear();
    _announcedQuoteDeclinedJobIds.clear();
    _initializedWatchedRequestIds.clear();
    savedInvoice = null;
    _activeJobId = null;
  }

  Future<void> loadFromCloud({
    Source source = Source.serverAndCache,
    String debugOrigin = 'driver_state',
  }) async {
    debugPrint(
      '[DriverStateCloudLoad] start origin=$debugOrigin source=$source '
      'jobs=${_jobsById.length} requests=${_jobRequestsById.length} '
      'watchers=${_requestWatchSubscriptions.length}',
    );
    logVanFirebaseHydration(stage: 'started', target: 'jobs cloud load');
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.jobs_cloud_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'jobs cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return;
    }

    try {
      final List<List<DriverCustomerReplyMockData>> results =
          await Future.wait([
            VanJobsCloudService.instance.loadJobs(
              ownerUid: ownerUid,
              source: source,
            ),
            VanQuotesCloudService.instance.loadQuotes(
              ownerUid: ownerUid,
              source: source,
            ),
          ]);
      final cloudJobs = results.first;
      final cloudQuotes = results.last;
      final publicQuotes = await VanPublicQuoteCloudService.instance.loadQuotes(
        ownerUid: ownerUid,
        source: source,
      );
      final cloudInvoices = await VanInvoicesCloudService.instance.loadInvoices(
        ownerUid: ownerUid,
      );
      _cloudVanJobIds
        ..clear()
        ..addAll(
          cloudJobs
              .map((job) => job.jobId.trim())
              .where((jobId) => jobId.isNotEmpty),
        );

      if (cloudJobs.isEmpty && cloudQuotes.isEmpty && cloudInvoices.isEmpty) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'jobs cloud load',
          extra: 'no_cloud_jobs_quotes_or_invoices',
        );
        return;
      }

      _mergeCloudJobs(
        cloudJobs,
        pruneMissing: true,
        sourceLabel: 'users/{uid}/van_jobs',
      );
      _mergeCloudJobs(
        cloudQuotes,
        pruneMissing: false,
        sourceLabel: 'users/{uid}/van_quotes',
      );
      _mergeCloudJobs(
        publicQuotes,
        pruneMissing: false,
        sourceLabel: 'public_quote_responses',
      );
      _mergeCloudInvoices(cloudInvoices);
      await saveToStorage(syncCloud: false);
      debugPrint(
        '[DriverStateCloudLoad] complete origin=$debugOrigin source=$source '
        'visibleJobs=${jobs.length} requests=${_jobRequestsById.length} '
        'watchers=${_requestWatchSubscriptions.length}',
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'jobs cloud load',
        extra:
            'jobs=${cloudJobs.length} quotes=${cloudQuotes.length} publicQuotes=${publicQuotes.length} invoices=${cloudInvoices.length} visibleJobs=${jobs.length} invoicesVisible=${savedInvoiceHistory.length}',
      );
    } catch (error) {
      debugPrint(
        '[DriverStateCloudLoad] error origin=$debugOrigin source=$source '
        'error=$error watchers=${_requestWatchSubscriptions.length}',
      );
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'jobs cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> hydrateFromCloud({
    Source source = Source.serverAndCache,
    String debugOrigin = 'driver_state',
  }) {
    final callId = ++_hydrateFromCloudCallCount;
    final existingFuture = _cloudHydrateFuture;
    if (existingFuture != null) {
      debugPrint(
        '[DriverStateHydrate] reuse call=$callId origin=$debugOrigin source=$source '
        'isHydrating=$_isHydratingCloud watchers=${_requestWatchSubscriptions.length}',
      );
      return existingFuture;
    }

    debugPrint(
      '[DriverStateHydrate] start call=$callId origin=$debugOrigin source=$source '
      'isHydrating=$_isHydratingCloud watchers=${_requestWatchSubscriptions.length}',
    );
    final future = _hydrateFromCloudInternal(
      source: source,
      debugOrigin: debugOrigin,
      callId: callId,
    );
    _cloudHydrateFuture = future;
    return future.whenComplete(() {
      debugPrint(
        '[DriverStateHydrate] complete call=$callId origin=$debugOrigin source=$source '
        'watchers=${_requestWatchSubscriptions.length}',
      );
      if (identical(_cloudHydrateFuture, future)) {
        _cloudHydrateFuture = null;
      }
    });
  }

  Future<void> refreshJobsFromCloud({
    bool forceServer = true,
    String debugOrigin = 'driver_state',
  }) async {
    final callId = ++_refreshJobsFromCloudCallCount;
    debugPrint(
      '[DriverStateRefresh] start call=$callId origin=$debugOrigin '
      'forceServer=$forceServer isHydrating=$_isHydratingCloud '
      'watchers=${_requestWatchSubscriptions.length} requests=${_jobRequestsById.length}',
    );
    logVanFirebaseHydration(
      stage: 'requested',
      target: 'jobs cloud refresh',
      extra: 'forceServer=$forceServer',
    );
    try {
      await hydrateFromCloud(
        source: forceServer ? Source.server : Source.serverAndCache,
        debugOrigin: debugOrigin,
      );
    } catch (error) {
      debugPrint(
        '[DriverStateRefresh] failed call=$callId origin=$debugOrigin '
        'error=$error',
      );
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'jobs cloud refresh',
        extra: error.toString(),
      );
      return;
    }
    _syncRequestWatchers();
    debugPrint(
      '[DriverStateRefresh] notify call=$callId origin=$debugOrigin '
      'watchers=${_requestWatchSubscriptions.length} requests=${_jobRequestsById.length}',
    );
    notifyListeners();
    debugPrint(
      '[DriverStateRefresh] complete call=$callId origin=$debugOrigin '
      'watchers=${_requestWatchSubscriptions.length} requests=${_jobRequestsById.length}',
    );
  }

  Future<void> refreshIncomingJobsFromCloud({
    bool forceServer = true,
    String debugOrigin = 'incoming_jobs',
  }) async {
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.incoming_jobs_refresh',
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    if (normalizedOwnerUid.isEmpty) {
      debugPrint(
        '[IncomingScope] refresh skipped origin=$debugOrigin reason=missing_owner',
      );
      return;
    }
    final businessProfileId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    final generation = await _activateIncomingScope(
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
    );
    debugPrint(
      '[IncomingScope] refresh start origin=$debugOrigin ownerUid=$normalizedOwnerUid '
      'businessProfileId=$businessProfileId generation=$generation',
    );
    final requests = await VanJobRequestCloudService.instance
        .loadRequestsForOwner(
          ownerUid: normalizedOwnerUid,
          businessProfileId: businessProfileId,
          source: forceServer ? Source.server : Source.serverAndCache,
        );
    if (!await _isIncomingScopeCurrent(
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    )) {
      debugPrint(
        '[IncomingScope] refresh discarded origin=$debugOrigin ownerUid=$normalizedOwnerUid '
        'businessProfileId=$businessProfileId generation=$generation reason=stale_scope',
      );
      return;
    }
    _reconcileScopedIncomingRequests(
      requests,
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
      origin: debugOrigin,
    );
    if (!await _saveIncomingScopeSnapshot(
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    )) {
      return;
    }
    _startScopedIncomingRequestListener(
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    );
    notifyListeners();
  }

  Future<VanJobRequestRecord?> refreshIncomingRequestById({
    required String requestId,
    String expectedOwnerUid = '',
    Source source = Source.server,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      return null;
    }
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.incoming_notification_refresh',
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    final normalizedExpectedOwner = expectedOwnerUid.trim();
    if (normalizedOwnerUid.isEmpty ||
        (normalizedExpectedOwner.isNotEmpty &&
            normalizedExpectedOwner != normalizedOwnerUid)) {
      debugPrint(
        '[IncomingScope] targeted excluded requestId=$normalizedRequestId '
        'reason=notification_owner_mismatch',
      );
      return null;
    }
    var businessProfileId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    if (_loadedBusinessProfileId != businessProfileId) {
      await loadFromStorage();
      businessProfileId = await VanBusinessProfileScopeStorage.instance
          .activeBusinessId();
    }
    final generation = await _activateIncomingScope(
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
    );
    final request = await VanJobRequestCloudService.instance
        .loadRequestByIdForScope(
          requestId: normalizedRequestId,
          ownerUid: normalizedOwnerUid,
          businessProfileId: businessProfileId,
          source: source,
        );
    if (request == null ||
        !await _isIncomingScopeCurrent(
          ownerUid: normalizedOwnerUid,
          businessProfileId: businessProfileId,
          generation: generation,
        )) {
      debugPrint(
        '[IncomingScope] targeted excluded requestId=$normalizedRequestId '
        'ownerUid=$normalizedOwnerUid businessProfileId=$businessProfileId '
        'reason=${request == null ? 'missing_or_out_of_scope' : 'stale_scope'}',
      );
      return null;
    }
    final previous = _jobRequestsById[normalizedRequestId];
    _mergeCloudRequests(
      <VanJobRequestRecord>[request],
      previousRequestsById: previous == null
          ? null
          : <String, VanJobRequestRecord>{normalizedRequestId: previous},
    );
    if (!await _saveIncomingScopeSnapshot(
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    )) {
      return null;
    }
    _startScopedIncomingRequestListener(
      ownerUid: normalizedOwnerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    );
    notifyListeners();
    debugPrint(
      '[IncomingScope] targeted included requestId=$normalizedRequestId '
      'ownerUid=$normalizedOwnerUid businessProfileId=$businessProfileId',
    );
    return request;
  }

  Future<int> _activateIncomingScope({
    required String ownerUid,
    required String businessProfileId,
  }) async {
    final changed =
        _incomingScopeOwnerUid != ownerUid ||
        _incomingScopeBusinessProfileId != businessProfileId;
    if (!changed) {
      return _incomingScopeGeneration;
    }
    _incomingScopeGeneration += 1;
    _incomingScopeOwnerUid = ownerUid;
    _incomingScopeBusinessProfileId = businessProfileId;
    await _scopedIncomingRequestSubscription?.cancel();
    _scopedIncomingRequestSubscription = null;
    return _incomingScopeGeneration;
  }

  Future<bool> _isIncomingScopeCurrent({
    required String ownerUid,
    required String businessProfileId,
    required int generation,
  }) async {
    if (!isVanIncomingScopeSnapshotCurrent(
      capturedOwnerUid: ownerUid,
      capturedBusinessProfileId: businessProfileId,
      capturedGeneration: generation,
      currentOwnerUid: _incomingScopeOwnerUid,
      currentBusinessProfileId: _incomingScopeBusinessProfileId,
      currentGeneration: _incomingScopeGeneration,
    )) {
      return false;
    }
    final currentOwnerUid =
        VanFirebaseAuthService.instance.currentUser?.uid.trim() ?? '';
    if (currentOwnerUid != ownerUid) {
      return false;
    }
    final activeBusinessProfileId = await VanBusinessProfileScopeStorage
        .instance
        .activeBusinessId();
    return isVanIncomingScopeSnapshotCurrent(
      capturedOwnerUid: ownerUid,
      capturedBusinessProfileId: businessProfileId,
      capturedGeneration: generation,
      currentOwnerUid: currentOwnerUid,
      currentBusinessProfileId: activeBusinessProfileId,
      currentGeneration: _incomingScopeGeneration,
    );
  }

  Future<bool> _saveIncomingScopeSnapshot({
    required String ownerUid,
    required String businessProfileId,
    required int generation,
  }) async {
    if (!await _isIncomingScopeCurrent(
      ownerUid: ownerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    )) {
      return false;
    }
    await _persistDeletedRequestKeys();
    if (!await _isIncomingScopeCurrent(
      ownerUid: ownerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    )) {
      return false;
    }
    final stateJson = _toJson();
    await _storage.saveJson(stateJson, businessProfileId: businessProfileId);
    return _isIncomingScopeCurrent(
      ownerUid: ownerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    );
  }

  void _startScopedIncomingRequestListener({
    required String ownerUid,
    required String businessProfileId,
    required int generation,
  }) {
    if (_scopedIncomingRequestSubscription != null) {
      return;
    }
    _scopedIncomingRequestSubscription = VanJobRequestCloudService.instance
        .watchRequestsForOwner(
          ownerUid: ownerUid,
          businessProfileId: businessProfileId,
        )
        .listen(
          (requests) => unawaited(
            _applyScopedIncomingRequestSnapshot(
              requests,
              ownerUid: ownerUid,
              businessProfileId: businessProfileId,
              generation: generation,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              '[IncomingScope] listener error ownerUid=$ownerUid '
              'businessProfileId=$businessProfileId generation=$generation error=$error',
            );
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  Future<void> _applyScopedIncomingRequestSnapshot(
    List<VanJobRequestRecord> requests, {
    required String ownerUid,
    required String businessProfileId,
    required int generation,
  }) async {
    if (!await _isIncomingScopeCurrent(
      ownerUid: ownerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    )) {
      debugPrint(
        '[IncomingScope] listener snapshot discarded ownerUid=$ownerUid '
        'businessProfileId=$businessProfileId generation=$generation reason=stale_scope',
      );
      return;
    }
    _reconcileScopedIncomingRequests(
      requests,
      ownerUid: ownerUid,
      businessProfileId: businessProfileId,
      origin: 'collection_listener',
    );
    if (!await _saveIncomingScopeSnapshot(
      ownerUid: ownerUid,
      businessProfileId: businessProfileId,
      generation: generation,
    )) {
      return;
    }
    notifyListeners();
  }

  void _reconcileScopedIncomingRequests(
    List<VanJobRequestRecord> requests, {
    required String ownerUid,
    required String businessProfileId,
    required String origin,
  }) {
    final canonicalById = <String, VanJobRequestRecord>{};
    var excluded = 0;
    var duplicates = 0;
    for (final request in requests) {
      final requestId = request.requestId.trim();
      if (requestId.isEmpty || request.ownerUid.trim() != ownerUid) {
        excluded += 1;
        continue;
      }
      final existing = canonicalById[requestId];
      if (existing != null) {
        duplicates += 1;
        if (!request.updatedAt.isAfter(existing.updatedAt)) {
          continue;
        }
      }
      canonicalById[requestId] = request;
    }

    final previousRequests = Map<String, VanJobRequestRecord>.from(
      _jobRequestsById,
    );
    final canonicalRequestIds = canonicalById.keys.toSet();
    final staleRequestIds = _jobRequestsById.keys
        .where((requestId) => !canonicalRequestIds.contains(requestId))
        .toSet();
    _jobRequestsById.clear();

    var prunedJobs = 0;
    for (final entry in _jobsById.entries.toList(growable: false)) {
      final job = entry.value;
      final requestId = job.requestId?.trim() ?? '';
      final isRequestDerived =
          _jobSourceById[job.jobId] == 'van_job_requests' ||
          requestId.isNotEmpty;
      final preserveWorkflow =
          job.hasQuote ||
          job.isConfirmed ||
          job.isCompletedJob ||
          job.isScheduledInCalendarState;
      if (isRequestDerived &&
          requestId.isNotEmpty &&
          !canonicalRequestIds.contains(requestId) &&
          !preserveWorkflow) {
        _jobsById.remove(entry.key);
        _jobSourceById.remove(entry.key);
        _cloudVanJobIds.remove(entry.key);
        prunedJobs += 1;
      }
    }

    _mergeCloudRequests(
      canonicalById.values.toList(growable: false),
      previousRequestsById: previousRequests,
    );
    _syncRequestWatchers();
    debugPrint(
      '[IncomingScope] reconcile origin=$origin ownerUid=$ownerUid '
      'businessProfileId=$businessProfileId included=${canonicalById.length} '
      'excluded=$excluded duplicates=$duplicates staleRequests=${staleRequestIds.length} '
      'prunedJobs=$prunedJobs visiblePending=${pendingJobs.length}',
    );
  }

  Future<VanPendingRefreshResult> refreshPendingRequestsFromCloud({
    required Source source,
  }) async {
    final currentUser = VanFirebaseAuthService.instance.currentUser;
    final ownerUid = currentUser?.uid.trim() ?? '';
    if (ownerUid.isEmpty) {
      return const VanPendingRefreshResult(
        baseMergeSuccess: false,
        loadedVanJobs: 0,
        loadedVanJobRequests: 0,
        visiblePending: 0,
        visibleCardUpdateFailures: 0,
        ignoredWarnings: 0,
        baseError: 'missing_uid',
      );
    }

    debugPrint('[PendingRefresh] start');

    var loadedVanJobs = 0;
    var loadedVanJobRequests = 0;
    var visibleCardUpdateFailures = 0;
    var ignoredWarnings = 0;
    Object? baseError;
    var baseMergeSuccess = false;

    List<DriverCustomerReplyMockData> cloudJobs =
        const <DriverCustomerReplyMockData>[];
    try {
      cloudJobs = await VanJobsCloudService.instance.loadJobs(
        ownerUid: ownerUid,
        source: source,
      );
      loadedVanJobs = cloudJobs.length;
      debugPrint('[PendingRefresh] loadedVanJobs=$loadedVanJobs');
      _mergeCloudJobs(
        cloudJobs,
        pruneMissing: true,
        sourceLabel: 'users/{uid}/van_jobs',
      );
    } catch (error) {
      baseError = error;
      debugPrint('[PendingRefresh] baseLoadError error=$error');
      final visiblePending = pendingJobs.length;
      debugPrint('[PendingRefresh] baseMergeSuccess=false');
      debugPrint('[PendingRefresh] visiblePending=$visiblePending');
      return VanPendingRefreshResult(
        baseMergeSuccess: false,
        loadedVanJobs: loadedVanJobs,
        loadedVanJobRequests: loadedVanJobRequests,
        visiblePending: visiblePending,
        visibleCardUpdateFailures: visibleCardUpdateFailures,
        ignoredWarnings: ignoredWarnings,
        baseError: baseError,
      );
    }

    try {
      final cloudQuotes = await VanQuotesCloudService.instance.loadQuotes(
        ownerUid: ownerUid,
        source: source,
      );
      if (cloudQuotes.isNotEmpty) {
        _mergeCloudJobs(
          cloudQuotes,
          pruneMissing: false,
          sourceLabel: 'users/{uid}/van_quotes',
        );
      }
    } catch (quoteError) {
      debugPrint('[PendingRefresh] quoteLoadError error=$quoteError');
    }

    try {
      final publicQuotes = await VanPublicQuoteCloudService.instance.loadQuotes(
        ownerUid: ownerUid,
        source: source,
      );
      if (publicQuotes.isNotEmpty) {
        _mergeCloudJobs(
          publicQuotes,
          pruneMissing: false,
          sourceLabel: 'public_quote_responses',
        );
      }
    } catch (publicQuoteError) {
      debugPrint(
        '[PendingRefresh] publicQuoteLoadError error=$publicQuoteError',
      );
    }

    try {
      final cloudRequests = await VanJobRequestCloudService.instance
          .loadRequestsForOwner(ownerUid: ownerUid, source: source);
      loadedVanJobRequests = cloudRequests.length;
      debugPrint('[PendingRefresh] loadedVanJobRequests=$loadedVanJobRequests');

      final previousRequestsById = Map<String, VanJobRequestRecord>.from(
        _jobRequestsById,
      );
      for (final request in cloudRequests) {
        final linkedJobId = request.linkedJobId.trim().isNotEmpty
            ? request.linkedJobId.trim()
            : request.jobId.trim();
        debugPrint(
          '[PendingRefresh] enrichmentStart requestId=${request.requestId} jobId=$linkedJobId',
        );
        try {
          final linkedJob = _jobsById[linkedJobId];
          if (_isDeletedCloudRequestCandidate(
            request,
            linkedJob: linkedJob,
            logSource: 'pendingRefresh:van_job_requests',
          )) {
            ignoredWarnings += 1;
            _jobRequestsById.remove(request.requestId);
            if (linkedJob != null) {
              _jobsById.remove(linkedJobId);
              _jobSourceById.remove(linkedJobId);
            }
            debugPrint(
              '[PendingRefresh] ignoredDeletedRequest requestId=${request.requestId} jobId=$linkedJobId',
            );
            continue;
          }
          if (linkedJobId.isEmpty ||
              linkedJob?.isHiddenFromNormalLists == true) {
            ignoredWarnings += 1;
            final orphanReason = linkedJobId.isEmpty
                ? 'missing_linked_job'
                : 'hidden_linked_job';
            debugPrint(
              '[PendingRefresh] ignoredOrphanRequest requestId=${request.requestId} reason=$orphanReason',
            );
            debugPrint(
              '[PendingRefresh] enrichmentError requestId=${request.requestId} jobId=$linkedJobId error=ignored_orphan_request',
            );
            continue;
          }
          final needsReplyUpdate =
              request.isSubmitted || request.hasCustomerReply;
          final needsPinUpdate = request.hasExactPin;
          final previousRequest = previousRequestsById[request.requestId];
          _mergeCloudRequests(
            <VanJobRequestRecord>[request],
            previousRequestsById: previousRequest == null
                ? null
                : <String, VanJobRequestRecord>{
                    request.requestId: previousRequest,
                  },
          );
          final enrichedJob = _jobsById[linkedJobId];
          final replyApplied =
              !needsReplyUpdate || (enrichedJob?.hasCustomerReply ?? false);
          final pinApplied =
              !needsPinUpdate || (enrichedJob?.exactPinSaved ?? false);
          if (replyApplied && pinApplied) {
            debugPrint(
              '[PendingRefresh] enrichmentSuccess requestId=${request.requestId} hasReply=${enrichedJob?.hasCustomerReply ?? request.hasCustomerReply} hasPin=${enrichedJob?.exactPinSaved ?? request.hasExactPin}',
            );
          } else {
            visibleCardUpdateFailures += 1;
            debugPrint(
              '[PendingRefresh] enrichmentError requestId=${request.requestId} jobId=$linkedJobId error=visible_card_update_failed',
            );
          }
        } catch (error) {
          final visibleCandidate =
              request.isSubmitted ||
              request.hasCustomerReply ||
              request.hasExactPin;
          if (visibleCandidate) {
            visibleCardUpdateFailures += 1;
          } else {
            ignoredWarnings += 1;
          }
          debugPrint(
            '[PendingRefresh] enrichmentError requestId=${request.requestId} jobId=$linkedJobId error=$error',
          );
        }
      }

      baseMergeSuccess = true;
    } catch (error) {
      baseError = error;
      debugPrint('[PendingRefresh] baseLoadError error=$error');
    }

    try {
      await saveToStorage(syncCloud: false);
    } catch (error) {
      debugPrint('[PendingRefresh] saveError error=$error');
    }

    try {
      _syncRequestWatchers();
      notifyListeners();
    } catch (error) {
      debugPrint('[PendingRefresh] notifyError error=$error');
    }

    final visiblePending = pendingJobs.length;
    debugPrint('[PendingRefresh] baseMergeSuccess=$baseMergeSuccess');
    debugPrint('[PendingRefresh] visiblePending=$visiblePending');
    debugPrint(
      '[PendingRefresh] visibleCardUpdateFailures=$visibleCardUpdateFailures',
    );
    debugPrint('[PendingRefresh] ignoredWarnings=$ignoredWarnings');
    final snackbarLabel = !baseMergeSuccess
        ? 'full_error'
        : visibleCardUpdateFailures > 0
        ? 'partial_visible_failure'
        : 'requests_refreshed';
    debugPrint('[PendingRefresh] snackbar=$snackbarLabel');
    return VanPendingRefreshResult(
      baseMergeSuccess: baseMergeSuccess,
      loadedVanJobs: loadedVanJobs,
      loadedVanJobRequests: loadedVanJobRequests,
      visiblePending: visiblePending,
      visibleCardUpdateFailures: visibleCardUpdateFailures,
      ignoredWarnings: ignoredWarnings,
      baseError: baseError,
    );
  }

  Future<void> _hydrateFromCloudInternal({
    Source source = Source.serverAndCache,
    String debugOrigin = 'driver_state',
    int? callId,
  }) async {
    if (_isHydratingCloud) {
      debugPrint(
        '[DriverStateHydrateInternal] skip origin=$debugOrigin call=${callId ?? -1} '
        'reason=already_hydrating watchers=${_requestWatchSubscriptions.length}',
      );
      return;
    }

    _isHydratingCloud = true;
    debugPrint(
      '[DriverStateHydrateInternal] entered origin=$debugOrigin call=${callId ?? -1} '
      'source=$source watchers=${_requestWatchSubscriptions.length} '
      'requests=${_jobRequestsById.length}',
    );
    final currentUser = VanFirebaseAuthService.instance.currentUser;
    debugPrint(
      '[VanFirebase][Auth] cloud hydrate uid=${currentUser?.uid ?? 'null'} email=${currentUser?.email ?? 'null'} anonymous=${currentUser?.isAnonymous ?? false}',
    );
    logVanFirebaseHydration(stage: 'started', target: 'van cloud hydrate');
    try {
      await loadFromCloud(source: source, debugOrigin: debugOrigin);
      await loadJobRequestsFromCloud(source: source, debugOrigin: debugOrigin);
      await VanBusinessProfileStorage.instance.loadFromCloud();
      debugPrint(
        '[DriverStateHydrateInternal] loaded origin=$debugOrigin call=${callId ?? -1} '
        'jobs=${jobs.length} requests=${_jobRequestsById.length} '
        'watchers=${_requestWatchSubscriptions.length}',
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'van cloud hydrate',
        extra:
            'uid=${currentUser?.uid ?? 'null'} jobs=${jobs.length} invoices=${savedInvoiceHistory.length} requests=${_jobRequestsById.length}',
      );
    } catch (error) {
      debugPrint(
        '[DriverStateHydrateInternal] error origin=$debugOrigin call=${callId ?? -1} '
        'source=$source error=$error watchers=${_requestWatchSubscriptions.length}',
      );
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'van cloud hydrate',
        extra: error.toString(),
      );
      rethrow;
    } finally {
      _hasCompletedInitialCloudHydration = true;
      _isHydratingCloud = false;
      debugPrint(
        '[DriverStateHydrateInternal] exit origin=$debugOrigin call=${callId ?? -1} '
        'watchers=${_requestWatchSubscriptions.length} requests=${_jobRequestsById.length}',
      );
    }
  }

  Future<void> loadInvoicesFromCloud() {
    final existingFuture = _invoiceCloudLoadFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _loadInvoicesFromCloudInternal();
    _invoiceCloudLoadFuture = future;
    return future.whenComplete(() {
      if (identical(_invoiceCloudLoadFuture, future)) {
        _invoiceCloudLoadFuture = null;
      }
    });
  }

  Future<void> _loadInvoicesFromCloudInternal() async {
    logVanFirebaseHydration(stage: 'started', target: 'invoice cloud load');
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.invoice_cloud_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'invoice cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return;
    }

    try {
      final cloudInvoices = await VanInvoicesCloudService.instance.loadInvoices(
        ownerUid: ownerUid,
      );
      if (cloudInvoices.isNotEmpty) {
        _mergeCloudInvoices(cloudInvoices);
        await saveToStorage(syncCloud: false);
      }
      final shownCount = savedInvoiceHistory.length;
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'invoice cloud load',
        extra:
            'uid=$ownerUid fetched=${cloudInvoices.length} showing=$shownCount',
      );
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'invoice cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> loadJobRequestsFromCloud({
    Source source = Source.serverAndCache,
    String debugOrigin = 'driver_state',
  }) async {
    debugPrint(
      '[DriverStateRequestLoad] start origin=$debugOrigin source=$source '
      'requests=${_jobRequestsById.length} watchers=${_requestWatchSubscriptions.length}',
    );
    logVanFirebaseHydration(stage: 'started', target: 'job request cloud load');
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.job_request_cloud_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'job request cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return;
    }

    try {
      final previousRequestsById = Map<String, VanJobRequestRecord>.from(
        _jobRequestsById,
      );
      final cloudRequests = await VanJobRequestCloudService.instance
          .loadRequestsForOwner(ownerUid: ownerUid, source: source);
      if (kDebugMode) {
        debugPrint('[VanRequestsRefresh] started uid=$ownerUid');
      }
      if (cloudRequests.isNotEmpty) {
        _mergeCloudRequests(
          cloudRequests,
          previousRequestsById: previousRequestsById,
        );
        await saveToStorage(syncCloud: false);
      }
      if (kDebugMode) {
        debugPrint(
          '[VanRequestsRefresh] requests=${cloudRequests.length} jobs=${jobs.length}',
        );
      }
      _syncRequestWatchers();
      debugPrint(
        '[DriverStateRequestLoad] complete origin=$debugOrigin source=$source '
        'requests=${_jobRequestsById.length} watchers=${_requestWatchSubscriptions.length}',
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'job request cloud load',
        extra: 'requests=${cloudRequests.length}',
      );
    } catch (error) {
      debugPrint(
        '[DriverStateRequestLoad] error origin=$debugOrigin source=$source '
        'error=$error watchers=${_requestWatchSubscriptions.length}',
      );
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'job request cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  String? takeRecentRequestRefreshNotice() {
    final notice = _recentRequestRefreshNotice;
    _recentRequestRefreshNotice = null;
    return notice;
  }

  DriverCustomerReplyMockData? jobByRequestId(String requestId) {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      return null;
    }

    final request = _jobRequestsById[normalizedRequestId];
    if (request == null || request.isHiddenFromNormalLists) {
      return null;
    }

    final linkedJobId = request.linkedJobId.trim().isNotEmpty
        ? request.linkedJobId.trim()
        : request.jobId.trim();
    final job = _jobsById[linkedJobId];
    return _isVisibleJob(job) ? job : null;
  }

  VanJobRequestRecord? requestById(String requestId) {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      return null;
    }

    final request = _jobRequestsById[normalizedRequestId];
    if (request == null || request.isHiddenFromNormalLists) {
      return null;
    }
    final resolvedJobId = request.linkedJobId.trim().isNotEmpty
        ? request.linkedJobId.trim()
        : request.jobId.trim();
    final job = _jobsById[resolvedJobId] ?? _placeholderJobForRequest(request);
    if (_isDeletedKeyMatch(job, request: request, logSource: 'requestById')) {
      return null;
    }
    return request;
  }

  Future<VanJobRequestRecord?> refreshRequestFromCloud(String requestId) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      return null;
    }

    debugPrint(
      '[VanJobRequestWatch] targeted refresh requested requestId=$normalizedRequestId',
    );
    final request = await VanJobRequestCloudService.instance.loadRequestById(
      normalizedRequestId,
    );
    if (request == null) {
      debugPrint(
        '[VanJobRequestWatch] targeted refresh missing requestId=$normalizedRequestId',
      );
      return null;
    }

    final previous = _jobRequestsById[normalizedRequestId];
    _mergeCloudRequests(
      <VanJobRequestRecord>[request],
      previousRequestsById: previous == null
          ? null
          : <String, VanJobRequestRecord>{normalizedRequestId: previous},
    );
    _syncRequestWatchers();
    await saveToStorage(syncCloud: false);
    notifyListeners();
    return request;
  }

  bool _matchesTestCleanupJob(
    DriverCustomerReplyMockData job,
    VanMateTestCleanupScope scope,
  ) {
    if (job.isHiddenFromNormalLists ||
        !isVanMateDebugTestDataCandidate(
          isTestData: job.isTestData,
          testMode: job.testMode,
          customerName: job.customerName,
          jobTitle: job.jobTitle,
        )) {
      return false;
    }

    if (scope == VanMateTestCleanupScope.allJobs) {
      return true;
    }

    return !job.isCompletedJob &&
        !job.isScheduledInCalendarState &&
        !job.isCancelled;
  }

  bool _matchesTestCleanupRequest(
    VanJobRequestRecord request,
    VanMateTestCleanupScope scope,
  ) {
    if (request.isHiddenFromNormalLists ||
        !isVanMateDebugTestDataCandidate(
          isTestData: request.isTestData,
          testMode: request.testMode,
          customerName: request.publicCustomerName,
          jobTitle: request.publicJobTitle,
        )) {
      return false;
    }

    if (scope == VanMateTestCleanupScope.allJobs) {
      return true;
    }

    final normalizedStatus = normalizeVanJobRequestStatus(request.status);
    return normalizedStatus != 'completed' && normalizedStatus != 'cancelled';
  }

  DriverCustomerReplyMockData _softDeletedTestCleanupJob(
    DriverCustomerReplyMockData job,
    DateTime deletedAt,
  ) {
    return job.copyWith(
      status: 'deleted',
      requestStatus: 'deleted',
      quoteStatus: 'deleted',
      quoteResponseStatus: 'deleted',
      schedulingStatus: 'cancelled',
      calendarStatus: 'cancelled',
      updatedAt: deletedAt,
      isTestData: true,
      testMode: true,
      deleted: true,
      archived: true,
    );
  }

  VanJobRequestRecord _softDeletedTestCleanupRequest(
    VanJobRequestRecord request,
    DateTime deletedAt,
  ) {
    return request.copyWith(
      status: 'deleted',
      updatedAt: deletedAt,
      isTestData: true,
      testMode: true,
      deleted: true,
      archived: true,
    );
  }

  Future<VanMateTestCleanupResult> debugClearTestData({
    required VanMateTestCleanupScope scope,
    bool syncCloud = true,
  }) async {
    if (!kDebugMode) {
      return const VanMateTestCleanupResult();
    }

    final deletedAt = DateTime.now();
    final jobsToArchive = <String, DriverCustomerReplyMockData>{};
    final requestsToArchive = <String, VanJobRequestRecord>{};

    for (final entry in _jobsById.entries) {
      final job = entry.value;
      if (!_matchesTestCleanupJob(job, scope)) {
        continue;
      }

      jobsToArchive[entry.key] = _softDeletedTestCleanupJob(job, deletedAt);
      final requestId = job.requestId?.trim() ?? '';
      final request = requestId.isEmpty ? null : _jobRequestsById[requestId];
      if (request != null) {
        requestsToArchive[request.requestId] = _softDeletedTestCleanupRequest(
          request,
          deletedAt,
        );
        _deletedRequestKeys.addAll(
          deletedKeyAliasesForJob(job, request: request),
        );
      }
    }

    for (final entry in _jobRequestsById.entries) {
      final request = entry.value;
      if (requestsToArchive.containsKey(entry.key) ||
          !_matchesTestCleanupRequest(request, scope)) {
        continue;
      }

      requestsToArchive[entry.key] = _softDeletedTestCleanupRequest(
        request,
        deletedAt,
      );
      final linkedJobId = request.linkedJobId.trim().isNotEmpty
          ? request.linkedJobId.trim()
          : request.jobId.trim();
      final linkedJob = _jobsById[linkedJobId];
      if (linkedJob != null && !jobsToArchive.containsKey(linkedJobId)) {
        jobsToArchive[linkedJobId] = _softDeletedTestCleanupJob(
          linkedJob,
          deletedAt,
        );
        _deletedRequestKeys.addAll(
          deletedKeyAliasesForJob(linkedJob, request: request),
        );
      }
    }

    if (jobsToArchive.isEmpty && requestsToArchive.isEmpty) {
      return const VanMateTestCleanupResult();
    }

    for (final entry in jobsToArchive.entries) {
      _jobsById[entry.key] = entry.value;
      _jobSourceById[entry.key] = _jobSourceById[entry.key] ?? 'local_cache';
    }
    for (final entry in requestsToArchive.entries) {
      _jobRequestsById[entry.key] = entry.value;
    }

    if (_activeJobId != null &&
        (_jobsById[_activeJobId!]?.isHiddenFromNormalLists ?? false)) {
      _activeJobId = _latestJob()?.jobId;
    }

    _syncRequestWatchers();
    await saveToStorage(syncCloud: false);
    notifyListeners();

    final clearedQuoteDocs = jobsToArchive.values
        .where((job) => job.hasQuote)
        .length;
    final clearedPublicQuotes = jobsToArchive.values
        .where((job) => job.quoteResponseId.trim().isNotEmpty)
        .length;

    if (syncCloud) {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.debug_test_cleanup',
      );
      final normalizedOwnerUid = ownerUid?.trim() ?? '';
      if (normalizedOwnerUid.isNotEmpty) {
        for (final job in jobsToArchive.values) {
          await VanJobsCloudService.instance.deleteJob(
            ownerUid: normalizedOwnerUid,
            jobId: job.jobId,
            source: 'van_mate.debug_test_cleanup',
            testCleanup: true,
          );
          await VanQuotesCloudService.instance.saveQuote(
            ownerUid: normalizedOwnerUid,
            job: job,
            source: 'van_mate.debug_test_cleanup',
          );
          final quoteResponseId = job.quoteResponseId.trim();
          if (quoteResponseId.isNotEmpty) {
            await VanPublicQuoteCloudService.instance.mergeQuoteFields(
              quoteId: quoteResponseId,
              fields: <String, dynamic>{
                'deleted': true,
                'archived': true,
                'status': 'deleted',
                'quoteStatus': 'deleted',
                'quoteResponseStatus': 'deleted',
                'deletedByDriver': true,
                'testCleanup': true,
                'deletedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'isTestData': true,
                'testMode': true,
              },
              source: 'van_mate.debug_test_cleanup',
            );
          }
        }

        for (final request in requestsToArchive.values) {
          await VanJobRequestCloudService.instance.deleteRequest(
            ownerUid: request.ownerUid.trim().isEmpty
                ? normalizedOwnerUid
                : request.ownerUid,
            requestId: request.requestId,
            source: 'van_mate.debug_test_cleanup',
            testCleanup: true,
          );
        }
      }
    }

    return VanMateTestCleanupResult(
      clearedJobs: jobsToArchive.length,
      clearedRequests: requestsToArchive.length,
      clearedQuoteDocs: clearedQuoteDocs,
      clearedPublicQuotes: clearedPublicQuotes,
    );
  }

  Future<VanMateSavedJobsClearResult> debugClearAllSavedJobFlowData({
    bool syncCloud = true,
  }) async {
    if (!kDebugMode) {
      return const VanMateSavedJobsClearResult();
    }

    final localJobs = _jobsById.length;
    final localRequests = _jobRequestsById.length;
    final localQuoteStates = _jobsById.values
        .where((job) => job.hasQuote || job.quoteHistory.isNotEmpty)
        .length;
    final localCalendarEntries = _jobsById.values.where((job) {
      final calendarStatus = job.calendarStatus.trim().toLowerCase();
      final schedulingStatus = job.schedulingStatus.trim().toLowerCase();
      return job.bookedCalendarSlot != null ||
          job.isCompletedJob ||
          calendarStatus == 'scheduled' ||
          calendarStatus == 'completed' ||
          schedulingStatus == 'scheduled';
    }).length;

    var deletedCloudJobs = 0;
    var deletedCloudQuotes = 0;
    var deletedPublicQuotes = 0;
    var deletedPublicQuoteTokens = 0;
    var deletedPublicRequests = 0;
    var deletedPrivateRequestMirrors = 0;
    var deletedLegacyRequestMirrors = 0;

    if (syncCloud) {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.debug_clear_saved_jobs',
      );
      final normalizedOwnerUid = ownerUid?.trim() ?? '';
      if (normalizedOwnerUid.isNotEmpty) {
        deletedCloudJobs = await VanJobsCloudService.instance
            .deleteAllJobsForOwner(
              ownerUid: normalizedOwnerUid,
              source: 'van_mate.debug_clear_saved_jobs',
            );
        deletedCloudQuotes = await VanQuotesCloudService.instance
            .deleteAllQuotesForOwner(
              ownerUid: normalizedOwnerUid,
              source: 'van_mate.debug_clear_saved_jobs',
            );
        final publicQuoteResult = await VanPublicQuoteCloudService.instance
            .deleteAllQuotesForOwner(
              ownerUid: normalizedOwnerUid,
              source: 'van_mate.debug_clear_saved_jobs',
            );
        deletedPublicQuotes = publicQuoteResult.deletedQuotes;
        deletedPublicQuoteTokens = publicQuoteResult.deletedTokens;
        final requestResult = await VanJobRequestCloudService.instance
            .deleteAllRequestsForOwner(
              ownerUid: normalizedOwnerUid,
              source: 'van_mate.debug_clear_saved_jobs',
            );
        deletedPublicRequests = requestResult.deletedPublicRequests;
        deletedPrivateRequestMirrors = requestResult.deletedPrivateRequests;
        deletedLegacyRequestMirrors = requestResult.deletedLegacyRequests;
      }
    }

    await _clearLocalSavedJobFlowData();
    await saveToStorage(syncCloud: false);
    notifyListeners();

    return VanMateSavedJobsClearResult(
      deletedCloudJobs: deletedCloudJobs,
      deletedCloudQuotes: deletedCloudQuotes,
      deletedPublicQuotes: deletedPublicQuotes,
      deletedPublicQuoteTokens: deletedPublicQuoteTokens,
      deletedPublicRequests: deletedPublicRequests,
      deletedPrivateRequestMirrors: deletedPrivateRequestMirrors,
      deletedLegacyRequestMirrors: deletedLegacyRequestMirrors,
      clearedLocalJobs: localJobs,
      clearedLocalRequests: localRequests,
      clearedLocalQuoteStates: localQuoteStates,
      clearedLocalCalendarEntries: localCalendarEntries,
    );
  }

  Future<void> _clearLocalSavedJobFlowData() async {
    _cancelAllRequestWatchers();
    _jobsById.clear();
    _jobSourceById.clear();
    _jobRequestsById.clear();
    _deletedRequestKeys.clear();
    _cloudVanJobIds.clear();
    _announcedReplyJobIds.clear();
    _announcedExactPinJobIds.clear();
    _announcedExactPinEventTimes.clear();
    _announcedExactPinStateTokens.clear();
    _observedExactPinStateTokens.clear();
    _announcedQuoteAcceptedJobIds.clear();
    _announcedQuoteDeclinedJobIds.clear();
    _initializedWatchedRequestIds.clear();
    _recentRequestRefreshNotice = null;
    _activeJobId = null;
    await VanDeletedRequestsStore.instance.clear();
  }

  Future<void> clearAllLocalJobData() async {
    _cancelAllRequestWatchers();
    _jobsById.clear();
    _jobSourceById.clear();
    _deletedRequestKeys.clear();
    _invoiceHistoryByJobKey.clear();
    _jobRequestsById.clear();
    _blockedCustomersByPhone.clear();
    _announcedReplyJobIds.clear();
    _announcedExactPinJobIds.clear();
    _announcedExactPinEventTimes.clear();
    _announcedQuoteAcceptedJobIds.clear();
    _announcedQuoteDeclinedJobIds.clear();
    _initializedWatchedRequestIds.clear();
    savedInvoice = null;
    _activeJobId = null;
    await _storage.clear();
    await VanDeletedRequestsStore.instance.clear();
    await _invoiceNumberStorage.resetNextNumber();
  }

  void resetTransientWorkflowState() {
    _activeJobId = null;
    savedInvoice = null;
  }

  void _scheduleSave() {
    if (_isHydratingCloud) {
      unawaited(saveToStorage(syncCloud: false));
      return;
    }
    unawaited(saveToStorage());
  }

  Future<void> _syncToCloud() async {
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.jobs_cloud_save',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'jobs cloud sync skipped',
        extra: 'uid=$ownerUid',
      );
      return;
    }

    final jobsToSync = allJobs;
    final invoiceEntries = _invoiceHistoryByJobKey.values.toList(
      growable: false,
    );
    logVanFirebaseAuthState(
      stage: 'sync owner resolved',
      user: VanFirebaseAuthService.instance.currentUser,
      extra: 'uid=$ownerUid',
    );

    await Future.wait([
      VanJobsCloudService.instance.saveJobs(
        ownerUid: ownerUid,
        jobs: jobsToSync,
        source: 'van_mate.jobs',
      ),
      VanQuotesCloudService.instance.saveQuotes(
        ownerUid: ownerUid,
        jobs: jobsToSync,
        source: 'van_mate.quotes',
      ),
      VanInvoicesCloudService.instance.saveInvoices(
        ownerUid: ownerUid,
        invoices: invoiceEntries,
        source: 'van_mate.invoices',
      ),
      VanJobRequestCloudService.instance.saveRequests(
        ownerUid: ownerUid,
        requests: _jobRequestsById.values.toList(growable: false),
        source: 'van_mate.job_requests',
      ),
    ]);
  }

  Future<void> _syncPublicQuoteForJob(
    String? jobId, {
    Map<String, dynamic> extraData = const <String, dynamic>{},
  }) async {
    final normalizedJobId = jobId?.trim() ?? '';
    final job = normalizedJobId.isNotEmpty
        ? _jobsById[normalizedJobId]
        : activeJob;
    if (job == null) {
      return;
    }

    await VanPublicQuoteCloudService.instance.saveQuote(
      job: job,
      extraData: extraData,
      source: 'van_mate.public_quote',
    );
  }

  DriverCustomerReplyMockData? _latestJob() {
    final jobs = this.jobs.toList(growable: true);
    if (jobs.isEmpty) {
      return null;
    }
    jobs.sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return jobs.first;
  }

  String stableDeleteKeyForJob(
    DriverCustomerReplyMockData job, {
    VanJobRequestRecord? request,
  }) {
    return buildVanRequestDeleteKey(
      requestId: request?.requestId,
      firestoreDocId: request?.requestId,
      docId: job.jobId,
      linkedJobId: request?.linkedJobId.isNotEmpty == true
          ? request!.linkedJobId
          : request?.jobId ?? job.jobId,
      source: request?.source.isNotEmpty == true
          ? request!.source
          : (_jobSourceById[job.jobId] ?? ''),
      title: request?.publicJobTitle.isNotEmpty == true
          ? request!.publicJobTitle
          : job.jobTitle,
      customerName: request?.publicCustomerName.isNotEmpty == true
          ? request!.publicCustomerName
          : job.customerName,
      phone: request?.publicPhoneNumber.isNotEmpty == true
          ? request!.publicPhoneNumber
          : job.phoneNumber,
      date: request?.jobDateLabel.isNotEmpty == true
          ? request!.jobDateLabel
          : job.jobDateLabel,
      createdAt: (request?.createdAt ?? job.createdAt)?.toIso8601String(),
    );
  }

  Set<String> deletedKeyAliasesForJob(
    DriverCustomerReplyMockData job, {
    VanJobRequestRecord? request,
    String? source,
  }) {
    final resolvedSource = source?.trim().isNotEmpty == true
        ? source!.trim()
        : request?.source.trim().isNotEmpty == true
        ? request!.source.trim()
        : (_jobSourceById[job.jobId] ?? '');
    final resolvedLinkedJobId = request?.linkedJobId.trim().isNotEmpty == true
        ? request!.linkedJobId.trim()
        : request?.jobId.trim().isNotEmpty == true
        ? request!.jobId.trim()
        : job.jobId.trim();
    return buildVanRequestDeleteAliases(
      requestId: request?.requestId.trim().isNotEmpty == true
          ? request!.requestId.trim()
          : job.requestId?.trim(),
      firestoreDocId: request?.requestId.trim().isNotEmpty == true
          ? request!.requestId.trim()
          : null,
      docId: job.jobId.trim(),
      linkedJobId: resolvedLinkedJobId,
      source: resolvedSource,
      title: request?.publicJobTitle.trim().isNotEmpty == true
          ? request!.publicJobTitle.trim()
          : job.jobTitle.trim(),
      customerName: request?.publicCustomerName.trim().isNotEmpty == true
          ? request!.publicCustomerName.trim()
          : job.customerName.trim(),
      phone: request?.publicPhoneNumber.trim().isNotEmpty == true
          ? request!.publicPhoneNumber.trim()
          : job.phoneNumber.trim(),
      date: request?.jobDateLabel.trim().isNotEmpty == true
          ? request!.jobDateLabel.trim()
          : job.jobDateLabel.trim(),
      createdAt: (request?.createdAt ?? job.createdAt)?.toIso8601String(),
    );
  }

  DriverCustomerReplyMockData _placeholderJobForRequest(
    VanJobRequestRecord request,
  ) {
    return DriverCustomerReplyMockData(
      jobId: request.linkedJobId.trim().isNotEmpty
          ? request.linkedJobId.trim()
          : request.jobId.trim(),
      customerName: request.publicCustomerName,
      jobTitle: request.publicJobTitle,
      scheduledAt: request.scheduledAt,
      jobDateLabel: request.jobDateLabel,
      jobTimeLabel: request.jobTimeLabel,
      address: request.publicAddressSummary,
      phoneNumber: request.publicPhoneNumber,
      customerEmail: request.publicCustomerEmail,
      requestId: request.requestId,
      requestExactPin: request.exactPinRequested,
      requestPhotos: request.requestPhotos,
      requiresExactPinAfterQuoteAccepted:
          request.requiresExactPinAfterQuoteAccepted,
      requestType: request.requestType,
      customerJourneyType: request.customerJourneyType,
      startHandover: request.startHandover,
      endHandover: request.endHandover,
      allowedStartHandoverOptions: request.allowedStartHandoverOptions,
      allowedEndHandoverOptions: request.allowedEndHandoverOptions,
      collectionAddress: request.collectionAddress,
      returnAddress: request.returnAddress,
      returnAddressSameAsCollection: request.returnAddressSameAsCollection,
      businessDropOffInstructions: request.businessDropOffInstructions,
      businessCollectionInstructions: request.businessCollectionInstructions,
      fulfilmentType: request.fulfilmentType,
      status: normalizeVanJobRequestStatus(request.status) == 'request_sent'
          ? 'requestSent'
          : 'replyReceived',
      createdAt: request.createdAt,
      updatedAt: request.updatedAt,
      requestCreatedAt: request.createdAt,
      requestUpdatedAt: request.updatedAt,
      exactPinShared: request.hasExactPin,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: request.additionalNotes,
    );
  }

  bool _isDeletedKeyMatch(
    DriverCustomerReplyMockData job, {
    VanJobRequestRecord? request,
    String? source,
    String logSource = 'runtime',
  }) {
    final aliases = deletedKeyAliasesForJob(
      job,
      request: request,
      source: source,
    );
    final matchedAlias = aliases.firstWhere(
      _deletedRequestKeys.contains,
      orElse: () => '',
    );
    final filtered = matchedAlias.isNotEmpty;
    if (kDebugMode) {
      final resolvedSource = source?.trim().isNotEmpty == true
          ? source!.trim()
          : request?.source.trim().isNotEmpty == true
          ? request!.source.trim()
          : (_jobSourceById[job.jobId] ?? 'local_cache');
      debugPrint(
        '[VanDeletedFilter] source=$logSource jobId=${job.jobId} requestId=${request?.requestId ?? job.requestId ?? '(none)'} cardSource=$resolvedSource aliases=${aliases.join(', ')} filtered=$filtered matchedAlias=${matchedAlias.isEmpty ? '(none)' : matchedAlias}',
      );
    }
    return filtered;
  }

  VanJobRequestRecord? _requestForCloudJobCandidate(
    DriverCustomerReplyMockData job,
  ) {
    final requestId = job.requestId?.trim() ?? '';
    if (requestId.isNotEmpty) {
      final request = _jobRequestsById[requestId];
      if (request != null) {
        return request;
      }
    }

    final jobId = job.jobId.trim();
    if (jobId.isEmpty) {
      return null;
    }
    final candidates = _jobRequestsById.values
        .where(
          (request) =>
              request.jobId.trim() == jobId ||
              request.linkedJobId.trim() == jobId,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return candidates.first;
  }

  bool _isDeletedCloudJobCandidate(
    DriverCustomerReplyMockData job, {
    required String sourceLabel,
  }) {
    return _isDeletedKeyMatch(
      job,
      request: _requestForCloudJobCandidate(job),
      source: sourceLabel,
      logSource: 'merge:$sourceLabel',
    );
  }

  bool _isDeletedCloudRequestCandidate(
    VanJobRequestRecord request, {
    DriverCustomerReplyMockData? linkedJob,
    String logSource = 'merge:van_job_requests',
  }) {
    final candidateJob = linkedJob ?? _placeholderJobForRequest(request);
    return _isDeletedKeyMatch(
      candidateJob,
      request: request,
      source: request.source,
      logSource: logSource,
    );
  }

  List<DriverCustomerReplyMockData> _applyDeletedFilterToJobs(
    Iterable<DriverCustomerReplyMockData> inputJobs, {
    required String logSource,
  }) {
    final jobsToFilter = inputJobs.toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[VanDeletedFilter] source=$logSource deletedKeysCount=${_deletedRequestKeys.length} allSourceCards=${jobsToFilter.length}',
      );
    }
    final visibleJobs = <DriverCustomerReplyMockData>[];
    for (final job in jobsToFilter) {
      final request = _requestForJobRaw(job.jobId);
      if (_isDeletedKeyMatch(job, request: request, logSource: logSource)) {
        continue;
      }
      visibleJobs.add(job);
    }
    if (kDebugMode) {
      debugPrint(
        '[VanDeletedFilter] source=$logSource visibleCountAfterFilter=${visibleJobs.length}',
      );
      for (final job in visibleJobs) {
        final request = _requestForJobRaw(job.jobId);
        final source = request?.source.trim().isNotEmpty == true
            ? request!.source.trim()
            : (_jobSourceById[job.jobId] ?? 'local_cache');
        debugPrint(
          '[VanDeletedFilter] source=$logSource survivor jobId=${job.jobId} sourceResponsible=$source key=${stableDeleteKeyForJob(job, request: request)}',
        );
      }
    }
    return visibleJobs;
  }

  bool isLegacyDeleteFiltered(
    DriverCustomerReplyMockData job, {
    VanJobRequestRecord? request,
  }) {
    return _isDeletedKeyMatch(job, request: request, logSource: 'visibility');
  }

  bool _isVisibleJob(DriverCustomerReplyMockData? job) {
    if (job == null || job.isHiddenFromNormalLists) {
      return false;
    }
    final request = _requestForJobRaw(job.jobId);
    return !isLegacyDeleteFiltered(job, request: request);
  }

  DateTime _jobSortDate(DriverCustomerReplyMockData job) {
    return job.bookedCalendarSlot?.start ??
        job.scheduledAtOrParsed ??
        job.updatedAt ??
        job.completedAt ??
        job.quoteSentAt ??
        job.quoteSavedAt ??
        job.replyReceivedAt ??
        job.requestSentAt ??
        job.draftSavedAt ??
        job.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Duration get _completedJobCalendarRetention =>
      completedJobCalendarRetentionDebugOverride ??
      const Duration(days: completedJobCalendarRetentionDays);

  DateTime _calendarCompletedRetentionCutoff() {
    final now = DateTime.now();
    return now.subtract(_completedJobCalendarRetention);
  }

  bool _shouldKeepCompletedJobInCalendar(DriverCustomerReplyMockData job) {
    if (!job.isCompletedJob) {
      return true;
    }
    final completedAt = job.completedAt;
    if (completedAt == null) {
      return true;
    }
    return !completedAt.isBefore(_calendarCompletedRetentionCutoff());
  }

  String? _resolveJobId([String? jobId]) {
    final candidate = jobId?.trim();
    if (candidate != null &&
        candidate.isNotEmpty &&
        _isVisibleJob(_jobsById[candidate])) {
      return candidate;
    }
    if (_activeJobId != null && _isVisibleJob(_jobsById[_activeJobId])) {
      return _activeJobId;
    }
    final latest = _latestJob();
    return latest?.jobId;
  }

  DriverCustomerReplyMockData? get activeJob {
    final id = _resolveJobId();
    if (id == null) {
      return null;
    }
    return _jobsById[id];
  }

  List<DriverCustomerReplyMockData> get jobs {
    final visibleJobs = _jobsById.values
        .where((job) => !job.isHiddenFromNormalLists)
        .toList();
    final filteredJobs = _applyDeletedFilterToJobs(
      visibleJobs,
      logSource: 'jobs.final',
    );
    filteredJobs.sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return filteredJobs;
  }

  List<DriverCustomerReplyMockData> get scheduledJobs {
    final result = jobs
        .where((job) => job.bookedCalendarSlot != null && !job.isCancelled)
        .where(_shouldKeepCompletedJobInCalendar)
        .where((job) {
          final decision = _deriveVanJobBucket(job);
          _debugLogJobClassification(job, decision, source: 'scheduledJobs');
          return decision.bucket == VanJobBucket.bookedJob ||
              decision.bucket == VanJobBucket.completedJob;
        })
        .toList(growable: false);
    return result;
  }

  List<DriverCustomerReplyMockData> jobsForDate(DateTime date) {
    final target = DateUtils.dateOnly(date);
    final matches = scheduledJobs
        .where((job) {
          final scheduledAt = job.bookedCalendarSlot?.start;
          return scheduledAt != null &&
              DateUtils.isSameDay(scheduledAt, target);
        })
        .toList(growable: true);
    matches.sort((a, b) => _jobSortDate(a).compareTo(_jobSortDate(b)));
    _logJobsForSource(
      screenSource: 'CalendarPage',
      sourceList:
          'Firestore users/{uid}/van_jobs + users/{uid}/van_quotes + public_quote_responses + public_job_requests -> provider memory',
      jobsToLog: matches,
    );
    return matches;
  }

  List<DriverCustomerReplyMockData> bookedJobsForDate(
    DateTime date, {
    String? logTag,
  }) {
    final target = DateUtils.dateOnly(date);
    final grouped = bookedJobsByDate(logTag: logTag);
    return (grouped[target] ?? const <DriverCustomerReplyMockData>[]).toList(
      growable: false,
    );
  }

  Map<DateTime, List<DriverCustomerReplyMockData>> bookedJobsByDate({
    String? logTag,
  }) {
    final grouped = <DateTime, List<DriverCustomerReplyMockData>>{};
    for (final job in jobs) {
      if (!_shouldKeepCompletedJobInCalendar(job)) {
        continue;
      }
      final scheduledAt = job.bookedCalendarSlot?.start;
      if (scheduledAt == null) {
        continue;
      }

      final decision = _bookedCalendarDecisionForJob(job);
      if (kDebugMode && logTag != null) {
        final target = DateUtils.dateOnly(scheduledAt);
        _debugLogCalendarJobSnapshot(
          '$logTag:queryCandidate',
          job,
          extra:
              'queryDate=${target.toIso8601String()} requestStatus=${job.requestStatus} quoteStatus=${job.quoteStatus} quoteAccepted=${job.quoteAccepted} isManual=${decision.isManual} counted=${decision.counted} reason=${decision.reason}',
        );
      }
      if (!decision.counted) {
        continue;
      }

      final day = DateUtils.dateOnly(scheduledAt);
      final matchesForDay = grouped.putIfAbsent(
        day,
        () => <DriverCustomerReplyMockData>[],
      );
      matchesForDay.add(job);
    }

    for (final matches in grouped.values) {
      matches.sort((a, b) => _jobSortDate(a).compareTo(_jobSortDate(b)));
    }
    return grouped;
  }

  List<DriverCustomerReplyMockData> get todayJobs {
    final result = bookedJobsForDate(DateTime.now());
    _logJobsForSource(
      screenSource: 'JobsPage',
      sourceList:
          'Firestore users/{uid}/van_jobs + users/{uid}/van_quotes + public_quote_responses + public_job_requests -> provider memory',
      jobsToLog: result,
    );
    return result;
  }

  List<DriverCustomerReplyMockData> get upcomingJobs => () {
    final result =
        jobs
            .where((job) {
              final scheduledAt = job.bookedCalendarSlot?.start;
              if (scheduledAt == null) {
                return false;
              }
              final today = DateUtils.dateOnly(DateTime.now());
              final scheduledDay = DateUtils.dateOnly(scheduledAt);
              if (!scheduledDay.isAfter(today)) {
                return false;
              }
              return _bookedCalendarDecisionForJob(job).counted;
            })
            .toList(growable: true)
          ..sort((a, b) => _jobSortDate(a).compareTo(_jobSortDate(b)));
    _logJobsForSource(
      screenSource: 'UpcomingJobs',
      sourceList:
          'Firestore users/{uid}/van_jobs + users/{uid}/van_quotes + public_quote_responses + public_job_requests -> provider memory',
      jobsToLog: result,
    );
    return result;
  }();

  List<DriverCustomerReplyMockData> jobsWithStatus(String status) {
    return jobs.where((job) => job.status == status).toList(growable: false);
  }

  List<DriverCustomerReplyMockData> get pendingJobs {
    final result = <DriverCustomerReplyMockData>[];
    for (final job in jobs) {
      final decision = _deriveVanJobBucket(job);
      final linkedRequest = _requestForJob(job.jobId);
      final hasLinkedRequest =
          linkedRequest != null && !linkedRequest.isHiddenFromNormalLists;
      final source = _jobSourceById[job.jobId] ?? '';
      final isQuoteOnlySource = source == 'public_quote_responses';
      final isAlreadyScheduled =
          job.isScheduledInCalendarState ||
          job.status.trim().toLowerCase() == 'scheduled' ||
          job.schedulingStatus.trim().toLowerCase() == 'scheduled';
      final shouldShow =
          hasLinkedRequest &&
          !isQuoteOnlySource &&
          !isAlreadyScheduled &&
          decision.bucket == VanJobBucket.pendingCustomerRequest;

      if (kDebugMode) {
        debugPrint(
          '[PendingBucket] jobId=${job.jobId} shown=$shouldShow reason=${decision.reason}',
        );
      }
      _debugLogJobClassification(job, decision, source: 'pendingJobs');

      if (shouldShow) {
        result.add(job);
      }
    }
    final visibleResult = _applyDeletedFilterToJobs(
      result,
      logSource: 'pendingJobs.final',
    );
    _logJobsForSource(
      screenSource: 'PendingRequests',
      sourceList:
          'Firestore users/{uid}/van_jobs + users/{uid}/van_quotes + public_quote_responses + public_job_requests -> provider memory',
      jobsToLog: visibleResult,
    );
    return visibleResult;
  }

  List<DriverCustomerReplyMockData> get confirmedJobs =>
      jobs.where((job) => job.status == 'confirmed').toList(growable: false);

  List<DriverCustomerReplyMockData> get completedJobs {
    final result = jobs
        .where((job) {
          final decision = _deriveVanJobBucket(job);
          _debugLogJobClassification(job, decision, source: 'completedJobs');
          return decision.bucket == VanJobBucket.completedJob;
        })
        .toList(growable: false);
    _logJobsForSource(
      screenSource: 'CompletedJobs',
      sourceList:
          'Firestore users/{uid}/van_jobs + users/{uid}/van_quotes + public_quote_responses + public_job_requests -> provider memory',
      jobsToLog: result,
    );
    return result;
  }

  List<DriverCustomerReplyMockData> get cancelledJobs {
    final result = jobs
        .where((job) {
          final decision = _deriveVanJobBucket(job);
          _debugLogJobClassification(job, decision, source: 'cancelledJobs');
          return decision.bucket == VanJobBucket.cancelledJobHistory;
        })
        .toList(growable: false);
    result.sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return result;
  }

  List<DriverCustomerReplyMockData> get declinedQuoteJobs {
    final result = jobs
        .where((job) {
          final decision = _deriveVanJobBucket(job);
          _debugLogJobClassification(
            job,
            decision,
            source: 'declinedQuoteJobs',
          );
          return decision.bucket == VanJobBucket.declinedQuoteHistory;
        })
        .toList(growable: false);
    result.sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return result;
  }

  List<VanBlockedCustomerRecord> get blockedCustomers {
    final result = _blockedCustomersByPhone.values.toList(growable: false)
      ..sort((a, b) => b.blockedAt.compareTo(a.blockedAt));
    return result;
  }

  VanJobBucketDecision debugBucketDecisionForJob(
    DriverCustomerReplyMockData job,
  ) {
    return _deriveVanJobBucket(job);
  }

  _BookedCalendarDecision _bookedCalendarDecisionForJob(
    DriverCustomerReplyMockData job,
  ) {
    final normalizedStatus = job.status.trim().toLowerCase();
    final normalizedCalendarStatus = job.calendarStatus.trim().toLowerCase();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(
      job.requestStatus,
    );
    final hasCustomerRequestSignals = job._hasCustomerRequestWorkflow;
    final isManual =
        !hasCustomerRequestSignals &&
        normalizedStatus != 'draft' &&
        normalizedStatus != 'cancelled' &&
        !job.isCompletedJob &&
        !job.deleted &&
        !job.archived;
    final isConfirmed = job.isConfirmed;

    if (job.deleted || job.archived) {
      return const _BookedCalendarDecision(
        counted: false,
        isManual: false,
        reason: 'hidden_deleted_or_archived',
      );
    }
    if (normalizedStatus == 'draft') {
      return const _BookedCalendarDecision(
        counted: false,
        isManual: false,
        reason: 'status_draft',
      );
    }
    if (normalizedStatus == 'cancelled') {
      return const _BookedCalendarDecision(
        counted: false,
        isManual: false,
        reason: 'status_cancelled',
      );
    }
    if (job.isCompletedJob) {
      return const _BookedCalendarDecision(
        counted: true,
        isManual: false,
        reason: 'status_completed',
      );
    }
    if (normalizedCalendarStatus == 'scheduled' ||
        normalizedCalendarStatus == 'completed') {
      return _BookedCalendarDecision(
        counted: true,
        isManual: isManual,
        reason: normalizedCalendarStatus == 'completed'
            ? 'calendar_status_completed'
            : 'calendar_status_scheduled',
      );
    }
    if (isConfirmed) {
      final reason = normalizedStatus == 'confirmed'
          ? 'status_confirmed'
          : normalizedStatus == 'ready'
          ? 'status_ready'
          : normalizedStatus == 'accepted'
          ? 'status_accepted'
          : normalizedRequestStatus == 'confirmed'
          ? 'request_status_confirmed'
          : normalizedRequestStatus == 'accepted'
          ? 'request_status_accepted'
          : normalizedRequestStatus == 'quote_accepted'
          ? 'request_status_quote_accepted'
          : job.quoteAccepted
          ? 'quote_accepted'
          : 'quote_status_accepted';
      return _BookedCalendarDecision(
        counted: true,
        isManual: false,
        reason: reason,
      );
    }
    if (isManual) {
      return const _BookedCalendarDecision(
        counted: true,
        isManual: true,
        reason: 'manual_direct_job',
      );
    }

    return const _BookedCalendarDecision(
      counted: false,
      isManual: false,
      reason: 'customer_request_not_confirmed',
    );
  }

  String currentUidForDebug() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '(none)';
    } catch (_) {
      return '(none)';
    }
  }

  List<DriverCustomerReplyMockData> debugAllLoadedJobs() {
    final entries = _jobsById.values.toList(growable: false)
      ..sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return entries;
  }

  int debugLoadedRequestCount() => _jobRequestsById.length;
  int debugDeletedRequestKeyCount() => _deletedRequestKeys.length;

  @visibleForTesting
  void debugResetStateForTest() {
    unawaited(_scopedIncomingRequestSubscription?.cancel());
    _scopedIncomingRequestSubscription = null;
    _loadedBusinessProfileId = null;
    _incomingScopeOwnerUid = '';
    _incomingScopeBusinessProfileId = '';
    _incomingScopeGeneration = 0;
    _cancelAllRequestWatchers();
    _jobsById.clear();
    _jobSourceById.clear();
    _invoiceHistoryByJobKey.clear();
    _jobRequestsById.clear();
    _blockedCustomersByPhone.clear();
    _deletedRequestKeys.clear();
    _cloudVanJobIds.clear();
    _deletingJobIds.clear();
    _jobDeletionService = VanJobDeletionService.instance;
    _announcedReplyJobIds.clear();
    _announcedExactPinJobIds.clear();
    _announcedExactPinEventTimes.clear();
    _announcedQuoteAcceptedJobIds.clear();
    _announcedQuoteDeclinedJobIds.clear();
    _initializedWatchedRequestIds.clear();
    savedInvoice = null;
    _activeJobId = null;
  }

  @visibleForTesting
  void debugSetJobDeletionServiceForTest(VanJobDeletionService service) {
    _jobDeletionService = service;
  }

  @visibleForTesting
  void debugAddDeletedRequestKeysForTest(Iterable<String> keys) {
    _deletedRequestKeys.addAll(
      keys.map((key) => key.trim()).where((key) => key.isNotEmpty),
    );
  }

  @visibleForTesting
  void debugAddJobForTest(
    DriverCustomerReplyMockData job, {
    String source = 'users/{uid}/van_jobs',
    bool cloudBacked = true,
  }) {
    _jobsById[job.jobId] = job;
    _jobSourceById[job.jobId] = source;
    if (cloudBacked && job.jobId.trim().isNotEmpty) {
      _cloudVanJobIds.add(job.jobId.trim());
    }
    _activeJobId ??= job.jobId;
  }

  @visibleForTesting
  void debugAddRequestForTest(VanJobRequestRecord request) {
    if (request.requestId.trim().isEmpty) {
      return;
    }
    _jobRequestsById[request.requestId] = request;
  }

  @visibleForTesting
  VanJobRequestRecord debugBuildRequestRecordForJobForTest(
    DriverCustomerReplyMockData job,
  ) {
    return _requestRecordFromJob(
      job,
      ownerUid: 'debug-owner',
      requestId: job.requestId?.trim().isNotEmpty == true
          ? job.requestId!.trim()
          : 'debug-request-${job.jobId}',
      requestStatus: job.requestStatus,
      submittedAt: job.requestSubmittedAt,
      customerSubmittedAt: job.replyReceivedAt,
      checklistResponses: const <VanJobRequestChecklistResponse>[],
      customQuestionResponses: const <VanJobRequestCustomQuestionResponse>[],
      additionalNotes: job.additionalNotes,
      exactPinSource: job.exactPinSource,
      exactPinNote: job.exactPinNote ?? '',
      exactPinLat: job.exactPinLatitude,
      exactPinLng: job.exactPinLongitude,
    );
  }

  @visibleForTesting
  DriverCustomerReplyMockData debugBuildReplyFromRequestForTest(
    VanJobRequestRecord request, {
    DriverCustomerReplyMockData? existing,
  }) {
    return _replyFromRequestRecord(request, existing: existing);
  }

  @visibleForTesting
  void debugAddInvoiceHistoryForTest(VanInvoiceHistoryEntry entry) {
    if (entry.jobKey.trim().isEmpty) {
      return;
    }
    _invoiceHistoryByJobKey[entry.jobKey] = entry;
    savedInvoice = entry.draft;
  }

  @visibleForTesting
  void debugMergeCloudJobsForTest(
    List<DriverCustomerReplyMockData> cloudJobs, {
    bool pruneMissing = false,
    String sourceLabel = 'users/{uid}/van_jobs',
  }) {
    if (sourceLabel == 'users/{uid}/van_jobs') {
      _cloudVanJobIds
        ..clear()
        ..addAll(
          cloudJobs
              .map((job) => job.jobId.trim())
              .where((jobId) => jobId.isNotEmpty),
        );
    }
    _mergeCloudJobs(
      cloudJobs,
      pruneMissing: pruneMissing,
      sourceLabel: sourceLabel,
    );
  }

  @visibleForTesting
  void debugMergeCloudRequestsForTest(List<VanJobRequestRecord> requests) {
    _mergeCloudRequests(
      requests,
      previousRequestsById: Map<String, VanJobRequestRecord>.from(
        _jobRequestsById,
      ),
    );
  }

  @visibleForTesting
  void debugReconcileScopedIncomingRequestsForTest(
    List<VanJobRequestRecord> requests, {
    String ownerUid = 'debug-owner',
    String businessProfileId = 'debug-business',
  }) {
    _reconcileScopedIncomingRequests(
      requests,
      ownerUid: ownerUid,
      businessProfileId: businessProfileId,
      origin: 'test',
    );
  }

  void _logJobsForSource({
    required String screenSource,
    required String sourceList,
    required List<DriverCustomerReplyMockData> jobsToLog,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[VanJobDebug][$screenSource] query=$sourceList returnedCount=${jobsToLog.length}',
    );
    for (final job in jobsToLog) {
      final decision = _deriveVanJobBucket(job);
      final hasPin =
          job.exactPinShared ||
          job.exactPinLatitude != null ||
          job.exactPinLongitude != null ||
          job.exactPinSaved;
      debugPrint(
        '[VanJobDebug][$screenSource] '
        'source=$sourceList '
        'jobId=${job.jobId} '
        'status=${job.status} '
        'requestStatus=${job.requestStatus} '
        'quoteStatus=${job.quoteStatus} '
        'quoteAccepted=${job.quoteAccepted} '
        'ready=${job.isConfirmed} '
        'jobReady=${job.isConfirmed} '
        'hasReply=${job.hasCustomerReply} '
        'hasPin=$hasPin '
        'deleted=${job.deleted} '
        'archived=${job.archived} '
        'bucket=${decision.bucket.name} '
        'reason=${decision.reason} '
        'date=${job.scheduledAtOrParsed?.toIso8601String() ?? '(none)'} '
        'requestId=${job.requestId ?? '(none)'}',
      );
    }
  }

  DriverCustomerReplyMockData? jobById(String jobId) {
    final job = _jobsById[jobId.trim()];
    return _isVisibleJob(job) ? job : null;
  }

  String debugSourceForJob(String jobId) {
    final normalized = jobId.trim();
    if (normalized.isEmpty) {
      return 'mock';
    }
    return _jobSourceById[normalized] ?? 'local_cache';
  }

  DriverCustomerReplyMockData _withDefaultsFromDraft(
    VanJobRequestDraft draft, {
    String status = 'draft',
    DriverCustomerReplyMockData? existing,
    bool? exactPinShared,
    VanExactPinSource? exactPinShareSource,
    String? exactPinNote,
    List<DriverChecklistResponse>? checklistResponses,
    List<DriverCustomQuestionResponse>? customQuestionResponses,
    String? additionalNotes,
    double? quoteAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? draftSavedAt,
    DateTime? requestSentAt,
    DateTime? replyReceivedAt,
    DateTime? quoteSavedAt,
    DateTime? quoteSentAt,
    DateTime? confirmedAt,
    DateTime? completedAt,
    double? exactPinLatitude,
    double? exactPinLongitude,
  }) {
    final now = DateTime.now();
    final markAsTestData = existing?.isMarkedTestData ?? kDebugMode;
    final markAsTestMode = existing?.testMode ?? kDebugMode;
    return DriverCustomerReplyMockData(
      jobId: draft.jobId,
      customerName: draft.customerName,
      jobTitle: draft.jobTitle,
      scheduledAt: draft.scheduledAt,
      jobDateLabel: draft.jobDateLabel,
      jobTimeLabel: draft.jobTimeLabel,
      address: draft.address,
      phoneNumber: sanitizeVanCustomerPhoneNumber(draft.phoneNumber),
      customerEmail: draft.customerEmail,
      postcode: draft.postcode,
      notesMessage: draft.notesMessage,
      requestExactPin: draft.requestExactPin,
      requestPhotos: draft.requestPhotos,
      requiresExactPinAfterQuoteAccepted:
          draft.requiresExactPinAfterQuoteAccepted,
      checklistItems: draft.checklistItems,
      customQuestions: draft.customQuestions,
      status: status,
      createdAt: createdAt ?? existing?.createdAt ?? now,
      updatedAt: updatedAt ?? now,
      draftSavedAt: draftSavedAt ?? existing?.draftSavedAt,
      requestSentAt: requestSentAt ?? existing?.requestSentAt,
      replyReceivedAt: replyReceivedAt ?? existing?.replyReceivedAt,
      quoteSavedAt: quoteSavedAt ?? existing?.quoteSavedAt,
      quoteSentAt: quoteSentAt ?? existing?.quoteSentAt,
      confirmedAt: confirmedAt ?? existing?.confirmedAt,
      completedAt: completedAt ?? existing?.completedAt,
      quoteAmount: quoteAmount ?? existing?.quoteAmount,
      exactPinShared:
          exactPinShared ??
          existing?.exactPinShared ??
          (draft.exactPinLatitude != null && draft.exactPinLongitude != null),
      checklistResponses:
          checklistResponses ??
          existing?.checklistResponses ??
          const <DriverChecklistResponse>[],
      customQuestionResponses:
          customQuestionResponses ??
          existing?.customQuestionResponses ??
          const <DriverCustomQuestionResponse>[],
      additionalNotes: additionalNotes ?? existing?.additionalNotes ?? '',
      exactPinShareSource: exactPinShareSource ?? existing?.exactPinShareSource,
      exactPinNote: exactPinNote ?? existing?.exactPinNote,
      exactPinLatitude:
          exactPinLatitude ??
          draft.exactPinLatitude ??
          existing?.exactPinLatitude,
      exactPinLongitude:
          exactPinLongitude ??
          draft.exactPinLongitude ??
          existing?.exactPinLongitude,
      requestId: existing?.requestId,
      requestStatus: _normalizeJobRequestStatus(
        existing?.requestStatus ?? 'draft',
      ),
      requestCreatedAt: existing?.requestCreatedAt,
      requestUpdatedAt: existing?.requestUpdatedAt,
      requestSubmittedAt: existing?.requestSubmittedAt,
      requestExpiresAt: existing?.requestExpiresAt,
      requestLink: existing?.requestLink ?? '',
      requestType: draft.requestType,
      customerJourneyType: draft.customerJourneyType,
      startHandover: draft.startHandover,
      endHandover: draft.endHandover,
      allowedStartHandoverOptions: draft.allowedStartHandoverOptions,
      allowedEndHandoverOptions: draft.allowedEndHandoverOptions,
      collectionAddress: draft.collectionAddress,
      returnAddress: draft.returnAddress,
      returnAddressSameAsCollection: draft.returnAddressSameAsCollection,
      businessDropOffInstructions: draft.businessDropOffInstructions,
      businessCollectionInstructions: draft.businessCollectionInstructions,
      fulfilmentType: existing?.fulfilmentType ?? '',
      scheduledDate: draft.scheduledDate,
      scheduledStartTime: draft.scheduledStartTime,
      estimatedDurationMinutes: draft.estimatedDurationMinutes,
      calendarStatus: draft.calendarStatus,
      locationPending: draft.locationPending,
      exactPinSource: draft.exactPinSource,
      isTestData: markAsTestData,
      testMode: markAsTestMode,
    );
  }

  DriverCustomerReplyMockData upsertDraftJob(VanJobRequestDraft draft) {
    final existing = _jobsById[draft.jobId];
    if (existing != null && existing.isHiddenFromNormalLists) {
      return existing;
    }
    final status = existing == null
        ? 'draft'
        : (existing.isCompletedJob
              ? 'completed'
              : existing.status == 'confirmed'
              ? 'confirmed'
              : existing.status == 'quoteSent'
              ? 'quoteSent'
              : existing.status == 'replyReceived'
              ? 'replyReceived'
              : existing.status == 'requestSent'
              ? 'requestSent'
              : 'draft');
    final updated = _withDefaultsFromDraft(
      draft,
      status: status,
      existing: existing,
      draftSavedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _jobsById[updated.jobId] = updated;
    _jobSourceById[updated.jobId] = 'local_cache';
    _activeJobId = updated.jobId;
    _scheduleSave();
    return updated;
  }

  DriverCustomerReplyMockData saveDraftJob(VanJobRequestDraft draft) {
    final existing = _jobsById[draft.jobId];
    if (existing != null && existing.isHiddenFromNormalLists) {
      return existing;
    }
    final updated = _withDefaultsFromDraft(
      draft,
      status: 'draft',
      existing: existing,
      draftSavedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _jobsById[updated.jobId] = updated;
    _jobSourceById[updated.jobId] = 'local_cache';
    _activeJobId = updated.jobId;
    _scheduleSave();
    return updated;
  }

  Future<DriverCustomerReplyMockData> sendJobRequest(
    VanJobRequestDraft draft, {
    bool forceNewRequest = false,
  }) async {
    _throwIfScheduledInPast(draft.scheduledAt);
    final existing = _jobsById[draft.jobId];
    if (existing != null && existing.isHiddenFromNormalLists) {
      return existing;
    }
    final existingRequest = forceNewRequest
        ? null
        : _requestForJob(draft.jobId);
    if (existingRequest != null &&
        !existingRequest.isHiddenFromNormalLists &&
        existingRequest.status != 'cancelled' &&
        !existingRequest.isExpired) {
      final merged = _replyFromRequestRecord(
        existingRequest,
        existing: existing,
      );
      _jobsById[merged.jobId] = merged;
      _jobSourceById[merged.jobId] = 'local_cache';
      _activeJobId = merged.jobId;
      debugPrint(
        '[VanJobRequestSync] request link reused jobId=${merged.jobId} requestId=${merged.requestId ?? '(none)'} requestStatus=${merged.requestStatus}',
      );
      debugPrint(
        '[VanJobRequestSync] send request linked jobId=${merged.jobId} requestId=${merged.requestId ?? '(none)'} request.linkedJobId=${existingRequest.jobId} job.requestId=${merged.requestId ?? '(none)'}',
      );
      final savedJob = await _saveJobDocToCloud(
        merged,
        source: 'van_mate.job_request_send',
      );
      if (savedJob) {
        debugPrint('SEND REQUEST saved job doc success');
      }
      _scheduleSave();
      return merged;
    }

    final now = DateTime.now();
    final requestId =
        forceNewRequest ||
            existingRequest == null ||
            existingRequest.isHiddenFromNormalLists ||
            existingRequest.status == 'cancelled' ||
            existingRequest.isExpired
        ? VanJobRequestCloudService.instance.createRequestId()
        : existingRequest.requestId;
    final requestLink = buildVanJobRequestLink(requestId);
    debugPrint('SEND REQUEST jobId=${draft.jobId}');
    debugPrint('SEND REQUEST requestId=$requestId');
    debugPrint('SEND REQUEST linkedJobId=${draft.jobId}');
    final updated =
        _withDefaultsFromDraft(
          draft,
          status: 'requestSent',
          existing: existing,
          requestSentAt: now,
          updatedAt: now,
        ).copyWith(
          requestId: requestId,
          requestStatus: 'request_sent',
          requestCreatedAt: now,
          requestUpdatedAt: now,
          requestExpiresAt: now.add(vanJobRequestDefaultExpiry),
          requestLink: requestLink,
        );
    _jobsById[updated.jobId] = updated;
    _jobSourceById[updated.jobId] = 'local_cache';
    _activeJobId = updated.jobId;
    _jobRequestsById[requestId] = _requestRecordFromJob(
      updated,
      ownerUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      requestId: requestId,
      requestStatus: 'request_sent',
      submittedAt: null,
      customerSubmittedAt: null,
      checklistResponses: const <VanJobRequestChecklistResponse>[],
      customQuestionResponses: const <VanJobRequestCustomQuestionResponse>[],
      additionalNotes: '',
      exactPinSource: updated.exactPinSource,
      exactPinNote: '',
      exactPinLat: null,
      exactPinLng: null,
    );
    _syncRequestWatchers();
    _scheduleSave();
    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.job_request_send',
      );
      if (ownerUid != null && ownerUid.trim().isNotEmpty) {
        final savedJob = await _saveJobDocToCloud(
          updated,
          source: 'van_mate.job_request_send',
        );
        if (!savedJob) {
          debugPrint(
            '[VanJobRequestSync] SEND REQUEST aborted: job doc not saved jobId=${updated.jobId} requestId=$requestId',
          );
          return _jobsById[updated.jobId] ?? updated;
        }
        debugPrint('SEND REQUEST saved job doc success');
        final record = await VanJobRequestCloudService.instance
            .createOrUpdateFromDraft(
              ownerUid: ownerUid,
              jobId: updated.jobId,
              draft: draft,
              requestId: requestId,
              source: 'van_mate.job_request',
            );
        debugPrint('SEND REQUEST saved request doc success');
        debugPrint(
          '[VanJobRequestSync] send request created jobId=${updated.jobId} requestId=${record.requestId} request.linkedJobId=${record.jobId} job.requestId=${updated.requestId ?? '(none)'}',
        );
        _jobRequestsById[record.requestId] = record;
        _syncRequestWatchers();
        _jobsById[updated.jobId] = _replyFromRequestRecord(
          record,
          existing: updated,
        );
        _jobSourceById[updated.jobId] = 'van_job_requests';
        await _saveJobDocToCloud(
          _jobsById[updated.jobId]!,
          source: 'van_mate.job_request_send',
        );
        await saveToStorage(syncCloud: false);
      }
    } catch (error) {
      debugPrint('[VanJobRequestCloud] create request failed: $error');
    }
    return _jobsById[updated.jobId] ?? updated;
  }

  Future<DriverCustomerReplyMockData> saveCustomerReplyForJob(
    String jobId,
    DriverCustomerReplyMockData reply,
  ) async {
    final existing = _jobsById[jobId];
    if (existing != null && existing.isHiddenFromNormalLists) {
      return existing;
    }
    final updated = (existing ?? reply).copyWith(
      jobId: jobId,
      customerName: reply.customerName,
      jobTitle: reply.jobTitle,
      jobDateLabel: reply.jobDateLabel,
      jobTimeLabel: reply.jobTimeLabel,
      address: reply.address,
      phoneNumber: sanitizeVanCustomerPhoneNumber(reply.phoneNumber),
      customerEmail: reply.customerEmail,
      postcode: reply.postcode,
      notesMessage: reply.notesMessage,
      requestExactPin: reply.requestExactPin,
      requestPhotos: reply.requestPhotos,
      checklistItems: reply.checklistItems,
      customQuestions: reply.customQuestions,
      status: existing?.isCompletedJob == true
          ? 'completed'
          : existing?.status == 'confirmed'
          ? 'confirmed'
          : existing?.status == 'quoteSent'
          ? 'quoteSent'
          : 'replyReceived',
      updatedAt: DateTime.now(),
      replyReceivedAt: DateTime.now(),
      exactPinShared: reply.exactPinShared,
      exactPinShareSource: reply.exactPinShareSource,
      exactPinNote: reply.exactPinNote,
      exactPinLatitude: reply.exactPinLatitude,
      exactPinLongitude: reply.exactPinLongitude,
      checklistResponses: reply.checklistResponses,
      customQuestionResponses: reply.customQuestionResponses,
      additionalNotes: reply.additionalNotes,
      quoteAmount: existing?.quoteAmount ?? reply.quoteAmount,
      requestId: existing?.requestId ?? reply.requestId,
      requestStatus: 'reply_received',
      requestCreatedAt: existing?.requestCreatedAt ?? reply.requestCreatedAt,
      requestUpdatedAt: DateTime.now(),
      requestSubmittedAt:
          existing?.requestSubmittedAt ??
          reply.requestSubmittedAt ??
          DateTime.now(),
      requestExpiresAt: existing?.requestExpiresAt ?? reply.requestExpiresAt,
      requestLink: existing?.requestLink ?? reply.requestLink,
      requestType: existing?.requestType ?? reply.requestType,
      customerJourneyType:
          existing?.customerJourneyType ?? reply.customerJourneyType,
      startHandover: existing?.startHandover ?? reply.startHandover,
      endHandover: existing?.endHandover ?? reply.endHandover,
      allowedStartHandoverOptions:
          existing?.allowedStartHandoverOptions ??
          reply.allowedStartHandoverOptions,
      allowedEndHandoverOptions:
          existing?.allowedEndHandoverOptions ??
          reply.allowedEndHandoverOptions,
      collectionAddress: existing?.collectionAddress ?? reply.collectionAddress,
      returnAddress: existing?.returnAddress ?? reply.returnAddress,
      returnAddressSameAsCollection:
          existing?.returnAddressSameAsCollection ??
          reply.returnAddressSameAsCollection,
      businessDropOffInstructions:
          existing?.businessDropOffInstructions ??
          reply.businessDropOffInstructions,
      businessCollectionInstructions:
          existing?.businessCollectionInstructions ??
          reply.businessCollectionInstructions,
      fulfilmentType: existing?.fulfilmentType ?? reply.fulfilmentType,
    );
    _jobsById[jobId] = updated;
    _jobSourceById[jobId] = 'local_cache';
    final requestId = updated.requestId?.trim();
    if (requestId != null && requestId.isNotEmpty) {
      _jobRequestsById[requestId] = _requestRecordFromJob(
        updated,
        ownerUid:
            _jobRequestsById[requestId]?.ownerUid ??
            FirebaseAuth.instance.currentUser?.uid ??
            '',
        requestId: requestId,
        requestStatus: 'reply_received',
        submittedAt: updated.requestSubmittedAt ?? DateTime.now(),
        customerSubmittedAt: updated.requestSubmittedAt ?? DateTime.now(),
        checklistResponses: updated.checklistResponses
            .map(
              (response) => VanJobRequestChecklistResponse(
                question: response.question,
                answer: response.answer,
                note: response.note ?? '',
              ),
            )
            .toList(growable: false),
        customQuestionResponses: updated.customQuestionResponses
            .map(
              (response) => VanJobRequestCustomQuestionResponse(
                question: response.question,
                answer: response.answer,
              ),
            )
            .toList(growable: false),
        additionalNotes: updated.additionalNotes,
        exactPinSource: updated.exactPinSource.isNotEmpty
            ? updated.exactPinSource
            : (vanExactPinSourceToStorage(updated.exactPinShareSource) ?? ''),
        exactPinNote: updated.exactPinNote ?? '',
        exactPinLat: updated.exactPinLatitude,
        exactPinLng: updated.exactPinLongitude,
      );
      _syncRequestWatchers();
      final notificationMessage = _maybeAnnounceNewCustomerUpdate(
        jobId: updated.jobId,
        requestId: requestId,
        previousHasReply: existing?.hasCustomerReply ?? false,
        currentHasReply: updated.hasCustomerReply,
        previousHasExactPin: existing?.exactPinSaved ?? false,
        currentHasExactPin: updated.exactPinSaved,
        previousQuoteAccepted: existing?.isQuoteAccepted ?? false,
        currentQuoteAccepted: updated.isQuoteAccepted,
        previousQuoteDeclined: existing?.isQuoteDeclined ?? false,
        currentQuoteDeclined: updated.isQuoteDeclined,
        jobTitle: updated.jobTitle,
        customerName: updated.customerName,
        exactPinStateToken: _exactPinStateTokenForJob(updated),
        allowExactPinAnnouncement: _hasCompletedInitialCloudHydration,
      );
      if (notificationMessage != null && notificationMessage.isNotEmpty) {
        _recentRequestRefreshNotice = notificationMessage;
      }
    }
    _activeJobId = jobId;
    await _saveJobDocToCloud(updated, source: 'van_mate.job_reply_sync');
    _scheduleSave();
    return updated;
  }

  Future<VanJobRequestRecord?> cancelRequestForJob({
    required String jobId,
    bool scheduleSave = true,
  }) async {
    final request = _requestForJob(jobId);
    if (request == null || request.requestId.trim().isEmpty) {
      return null;
    }

    final ownerUid = request.ownerUid.trim().isNotEmpty
        ? request.ownerUid.trim()
        : (await VanFirebaseAuthService.instance.ensureCurrentUid(
                source: 'van_mate.job_request_cancel',
              ) ??
              '');
    final cloudUpdated = await VanJobRequestCloudService.instance.cancelRequest(
      requestId: request.requestId,
      ownerUid: ownerUid,
      source: 'van_mate.job_request_cancel',
    );
    final updatedRequest =
        cloudUpdated ??
        request.copyWith(status: 'cancelled', updatedAt: DateTime.now());
    _jobRequestsById[updatedRequest.requestId] = updatedRequest;
    final existingJob = _jobsById[jobId];
    final nextStatus =
        existingJob == null ||
            existingJob.status == 'draft' ||
            existingJob.status == 'requestSent'
        ? 'cancelled'
        : existingJob.status;
    final updatedJob = (existingJob ?? _replyFromRequestRecord(updatedRequest))
        .copyWith(
          status: nextStatus,
          requestId: updatedRequest.requestId,
          requestStatus: 'cancelled',
          requestCreatedAt: updatedRequest.createdAt,
          requestUpdatedAt: updatedRequest.updatedAt,
          requestSubmittedAt: updatedRequest.submittedAt,
          requestExpiresAt: updatedRequest.expiresAt,
          requestLink: buildVanJobRequestLink(
            updatedRequest.requestId,
            shortCode: updatedRequest.shortCode,
          ),
        );
    _jobsById[jobId] = updatedJob;
    _jobSourceById[jobId] = 'local_cache';
    _activeJobId = jobId;
    if (scheduleSave) {
      _scheduleSave();
    }
    _syncRequestWatchers();
    return updatedRequest;
  }

  DriverCustomerReplyMockData? _updateJob(
    String? jobId,
    DriverCustomerReplyMockData Function(DriverCustomerReplyMockData job)
    update,
  ) {
    final resolvedId = _resolveJobId(jobId);
    if (resolvedId == null) {
      return null;
    }
    final current = _jobsById[resolvedId];
    if (current == null || current.isHiddenFromNormalLists) {
      return null;
    }
    final updated = update(current).copyWith(updatedAt: DateTime.now());
    _jobsById[resolvedId] = updated;
    _jobSourceById[resolvedId] = 'local_cache';
    _syncRequestRecordFromJob(updated);
    _activeJobId = resolvedId;
    _scheduleSave();
    return updated;
  }

  bool _shouldScheduleHandoverReminder(
    DriverCustomerReplyMockData job,
    DateTime? handoverAt,
  ) {
    return shouldScheduleVanPickupReminder(
      isDropOffPickup: job.hasServiceHandover,
      isScheduled: job.isScheduledInCalendarState,
      isCompleted: job.isCompletedJob,
      isCancelled: job.isCancelled,
      isHidden: job.isHiddenFromNormalLists,
      pickUpAt: handoverAt,
    );
  }

  Future<void> _syncPickupReminderForJob(
    DriverCustomerReplyMockData job,
  ) async {
    final startAt = job.dropOffDateTime;
    final endAt = job.pickUpDateTime;
    final schedulesStart = _shouldScheduleHandoverReminder(job, startAt);
    final schedulesEnd = _shouldScheduleHandoverReminder(job, endAt);
    if (!schedulesStart && !schedulesEnd) {
      await VanPickupReminderService.instance.cancel(job.jobId);
      return;
    }
    if (schedulesStart) {
      await VanPickupReminderService.instance.scheduleStart(
        jobId: job.jobId,
        customerName: job.customerName,
        serviceName: job.jobTitle,
        startAt: startAt!,
        customerJourneyType: job.customerJourneyType,
        startHandover: job.effectiveHandover.start.storageKey,
      );
    } else {
      await VanPickupReminderService.instance.cancelStart(job.jobId);
    }
    if (schedulesEnd) {
      await VanPickupReminderService.instance.schedule(
        jobId: job.jobId,
        customerName: job.customerName,
        serviceName: job.jobTitle,
        pickUpAt: endAt!,
        customerJourneyType: job.customerJourneyType,
        endHandover: job.effectiveHandover.end.storageKey,
      );
    } else {
      await VanPickupReminderService.instance.cancelEnd(job.jobId);
    }
  }

  Future<void> syncPickupReminders() async {
    for (final job in _jobsById.values) {
      await _syncPickupReminderForJob(job);
    }
  }

  void _debugLogCalendarJobSnapshot(
    String tag,
    DriverCustomerReplyMockData job, {
    String? extra,
  }) {
    if (!kDebugMode) {
      return;
    }

    final slot = job.bookedCalendarSlot;
    final start = slot?.start;
    final durationMinutes =
        slot?.durationMinutes ?? job.estimatedDurationMinutes ?? 60;
    final end = start?.add(Duration(minutes: durationMinutes));
    final customerName = job.customerName.trim().isEmpty
        ? 'Booked job'
        : job.customerName.trim();
    final jobTitle = job.jobTitle.trim().isEmpty
        ? 'Booked job'
        : job.jobTitle.trim();

    debugPrint(
      '[$tag] docId=${job.jobId} status=${job.status} scheduledDate=${job.scheduledDate} scheduledTime=${job.scheduledStartTime} startDateTime=${start?.toIso8601String() ?? '(none)'} endDateTime=${end?.toIso8601String() ?? '(none)'} durationMinutes=$durationMinutes calendarStatus=${job.calendarStatus} schedulingStatus=${job.schedulingStatus} customerName=$customerName jobTitle=$jobTitle${extra == null || extra.isEmpty ? '' : ' $extra'}',
    );
  }

  void _syncRequestRecordFromJob(DriverCustomerReplyMockData job) {
    final request = _requestForJob(job.jobId);
    if (request == null || request.requestId.trim().isEmpty) {
      return;
    }

    final nextRequestStatus = _requestRecordStatusForJob(
      job,
      existing: request,
    );
    _jobRequestsById[request.requestId] = request.copyWith(
      status: nextRequestStatus,
      publicCustomerName: job.customerName,
      publicJobTitle: job.jobTitle,
      publicAddressSummary: job.address,
      publicPhoneNumber: sanitizeVanCustomerPhoneNumber(job.phoneNumber),
      publicCustomerEmail: job.customerEmail,
      scheduledAt: job.scheduledAtOrParsed,
      jobDateLabel: job.jobDateLabel,
      jobTimeLabel: job.jobTimeLabel,
      scheduledDate: job.scheduledDate,
      scheduledStartTime: job.scheduledStartTime,
      estimatedDurationMinutes: job.estimatedDurationMinutes,
      calendarStatus: job.calendarStatus,
      locationPending: job.locationPending,
      quoteTimingChoice: job.quoteTimingChoice,
      agreedDateTime: job.agreedDateTime,
      agreedStartAt: job.agreedDateTime,
      agreedEndAt: _addDurationToDateTime(
        job.agreedDateTime,
        job.estimatedDurationMinutes,
      ),
      agreedDurationMinutes: job.estimatedDurationMinutes,
      acceptedProposedTime: job.acceptedProposedScheduledAt != null,
      timeAgreed: job.hasAgreedSchedulingTime,
      readyForCalendar:
          job.isQuoteAccepted &&
          job.hasAgreedSchedulingTime &&
          !job.isAwaitingRequiredExactPin &&
          !job.isScheduledInCalendarState,
      needsAgreedTime: job.isQuoteAccepted && !job.hasAgreedSchedulingTime,
      timeStatus: job.hasAgreedSchedulingTime
          ? (job.isAwaitingRequiredExactPin
                ? 'time_agreed'
                : 'ready_for_calendar')
          : 'needs_agreed_time',
      timingStatus: job.hasAgreedSchedulingTime
          ? (job.isAwaitingRequiredExactPin
                ? 'time_agreed'
                : 'ready_for_calendar')
          : 'needs_agreed_time',
      schedulingStatus: job.schedulingStatus,
      declineReasonCode: job.declineReasonCode,
      declineReasonLabel: job.declineReasonLabel,
      declineReasonText: job.declineReasonText,
      declinedAt: job.quoteDeclinedAt,
      declinedBy: job.quoteDeclined ? 'customer' : '',
      driverMessagePreview: job.notesMessage,
      exactPinLat: job.exactPinLatitude,
      exactPinLng: job.exactPinLongitude,
      exactPinSource: job.exactPinSource,
      updatedAt: job.updatedAt,
    );
  }

  String _requestRecordStatusForJob(
    DriverCustomerReplyMockData job, {
    VanJobRequestRecord? existing,
  }) {
    final normalizedStatus = job.status.trim().toLowerCase();
    final normalizedRequestStatus = normalizeVanJobRequestStatus(
      job.requestStatus,
    );
    final rawRequestStatus = job.requestStatus.trim().toLowerCase();
    final normalizedQuoteStatus = job.quoteStatus.trim().toLowerCase();

    if (job.deleted || job.archived) {
      return existing?.status ?? normalizedRequestStatus;
    }

    if (job.isCompletedJob) {
      return 'completed';
    }

    if (job.isScheduledInCalendarState || job.isConfirmed) {
      return 'confirmed';
    }

    if (normalizedStatus == 'cancelled' ||
        normalizedRequestStatus == 'cancelled' ||
        rawRequestStatus == 'cancelled') {
      return 'cancelled';
    }

    if (normalizedStatus == 'declined' ||
        normalizedStatus == 'quotedeclined' ||
        normalizedRequestStatus == 'declined' ||
        normalizedRequestStatus == 'quote_declined' ||
        normalizedQuoteStatus == 'declined' ||
        job.isQuoteDeclined) {
      return 'quote_declined';
    }

    if (normalizedStatus == 'quoteaccepted' ||
        normalizedRequestStatus == 'quote_accepted' ||
        normalizedQuoteStatus == 'accepted' ||
        job.isQuoteAccepted) {
      return 'quote_accepted';
    }
    if (normalizedStatus == 'quotesent' ||
        normalizedStatus == 'quote_sent' ||
        normalizedStatus == 'sent' ||
        normalizedRequestStatus == 'quoted' ||
        normalizedQuoteStatus == 'sent' ||
        normalizedQuoteStatus == 'opened_for_sending' ||
        normalizedQuoteStatus == 'waiting' ||
        normalizedQuoteStatus == 'prepared' ||
        job.quoteSavedAt != null ||
        job.quoteSentAt != null) {
      return 'sent';
    }

    if (job.hasCustomerReply ||
        job.replyReceivedAt != null ||
        job.exactPinShared ||
        job.hasExactPin) {
      return 'reply_received';
    }

    if (normalizedStatus == 'requestsent' ||
        normalizedStatus == 'request_sent') {
      return 'request_sent';
    }

    if (normalizedRequestStatus.isNotEmpty &&
        normalizedRequestStatus != 'draft') {
      return normalizedRequestStatus;
    }

    return existing?.status ?? 'draft';
  }

  DriverCustomerReplyMockData? updateJobDetails({
    String? jobId,
    String? customerName,
    String? phoneNumber,
    String? customerEmail,
    String? jobTitle,
    String? address,
    String? postcode,
    String? notesMessage,
    DateTime? scheduledAt,
  }) {
    return _updateJob(jobId, (job) {
      final nextScheduledAt = scheduledAt ?? job.scheduledAtOrParsed;
      if (nextScheduledAt != null) {
        _throwIfScheduledInPast(nextScheduledAt);
        _throwIfScheduleOverlap(
          jobId: job.jobId,
          scheduledAt: nextScheduledAt,
          estimatedDurationMinutes: job.estimatedDurationMinutes ?? 60,
        );
      }
      return job.copyWith(
        customerName: customerName ?? job.customerName,
        phoneNumber: sanitizeVanCustomerPhoneNumber(
          phoneNumber ?? job.phoneNumber,
        ),
        customerEmail: customerEmail ?? job.customerEmail,
        jobTitle: jobTitle ?? job.jobTitle,
        address: address ?? job.address,
        postcode: postcode ?? job.postcode,
        notesMessage: notesMessage ?? job.notesMessage,
        scheduledAt: nextScheduledAt,
        jobDateLabel: nextScheduledAt == null
            ? job.jobDateLabel
            : _formatJobDate(DateUtils.dateOnly(nextScheduledAt)),
        jobTimeLabel: nextScheduledAt == null
            ? job.jobTimeLabel
            : _formatJobTime(TimeOfDay.fromDateTime(nextScheduledAt)),
        scheduledDate: nextScheduledAt == null
            ? job.scheduledDate
            : _formatScheduledDate(DateUtils.dateOnly(nextScheduledAt)),
        scheduledStartTime: nextScheduledAt == null
            ? job.scheduledStartTime
            : _formatJobTime(TimeOfDay.fromDateTime(nextScheduledAt)),
      );
    });
  }

  DriverCustomerReplyMockData? updateJobDateTime({
    String? jobId,
    required DateTime scheduledAt,
  }) {
    return _updateJob(jobId, (job) {
      _throwIfScheduledInPast(scheduledAt);
      _throwIfScheduleOverlap(
        jobId: job.jobId,
        scheduledAt: scheduledAt,
        estimatedDurationMinutes: job.estimatedDurationMinutes ?? 60,
      );
      return job.copyWith(
        scheduledAt: scheduledAt,
        jobDateLabel: _formatJobDate(DateUtils.dateOnly(scheduledAt)),
        jobTimeLabel: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
        scheduledDate: _formatScheduledDate(DateUtils.dateOnly(scheduledAt)),
        scheduledStartTime: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
      );
    });
  }

  DriverCustomerReplyMockData? updateJobSchedule({
    String? jobId,
    required DateTime scheduledAt,
    int? estimatedDurationMinutes,
    double? exactPinLatitude,
    double? exactPinLongitude,
    String? exactPinSource,
    String? schedulingStatus,
    bool markQuoteAccepted = false,
    bool addToCalendar = true,
  }) {
    final updated = _updateJob(jobId, (job) {
      final resolvedPinSource = exactPinSource?.trim().toLowerCase();
      final hasNewPin = exactPinLatitude != null && exactPinLongitude != null;
      final nextDurationMinutes =
          estimatedDurationMinutes ?? job.estimatedDurationMinutes ?? 60;
      _throwIfScheduledInPast(scheduledAt);
      _throwIfScheduleOverlap(
        jobId: job.jobId,
        scheduledAt: scheduledAt,
        estimatedDurationMinutes: nextDurationMinutes,
      );
      return job.copyWith(
        scheduledAt: scheduledAt,
        jobDateLabel: _formatJobDate(DateUtils.dateOnly(scheduledAt)),
        jobTimeLabel: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
        scheduledDate: _formatScheduledDate(DateUtils.dateOnly(scheduledAt)),
        scheduledStartTime: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
        estimatedDurationMinutes: nextDurationMinutes,
        calendarStatus: addToCalendar ? 'scheduled' : job.calendarStatus,
        quoteResponseStatus: job.quoteResponseStatus.trim().isNotEmpty
            ? job.quoteResponseStatus
            : (markQuoteAccepted || job.isQuoteAccepted
                  ? 'accepted'
                  : job.quoteResponseStatus),
        quoteTimingChoice: 'agreed_time_saved',
        agreedDateTime: scheduledAt,
        quoteAccepted: markQuoteAccepted ? true : job.quoteAccepted,
        quoteAcceptedAt: markQuoteAccepted
            ? (job.quoteAcceptedAt ?? DateTime.now())
            : job.quoteAcceptedAt,
        quoteDeclined: markQuoteAccepted ? false : job.quoteDeclined,
        quoteDeclinedAt: markQuoteAccepted ? null : job.quoteDeclinedAt,
        declineReasonCode: markQuoteAccepted ? '' : job.declineReasonCode,
        declineReasonLabel: markQuoteAccepted ? '' : job.declineReasonLabel,
        declineReasonText: markQuoteAccepted ? '' : job.declineReasonText,
        quoteRespondedAt: markQuoteAccepted
            ? (job.quoteRespondedAt ?? DateTime.now())
            : job.quoteRespondedAt,
        quoteStatus: markQuoteAccepted ? 'accepted' : job.quoteStatus,
        status: markQuoteAccepted ? 'quoteAccepted' : job.status,
        requestStatus: markQuoteAccepted ? 'quote_accepted' : job.requestStatus,
        requestUpdatedAt: markQuoteAccepted
            ? DateTime.now()
            : job.requestUpdatedAt,
        exactPinLatitude: exactPinLatitude ?? job.exactPinLatitude,
        exactPinLongitude: exactPinLongitude ?? job.exactPinLongitude,
        exactPinSource: resolvedPinSource?.isNotEmpty == true
            ? resolvedPinSource
            : (hasNewPin ? 'driver' : job.exactPinSource),
        exactPinShared: hasNewPin ? true : job.exactPinShared,
        schedulingStatus: schedulingStatus ?? job.schedulingStatus,
      );
    });
    if (updated != null) {
      _debugLogCalendarJobSnapshot(
        'AddToCalendarSave:updateJobSchedule',
        updated,
      );
    }
    return updated;
  }

  void _throwIfScheduleOverlap({
    required String jobId,
    required DateTime scheduledAt,
    required int estimatedDurationMinutes,
  }) {
    final overlap = findScheduleOverlap(
      ignoringJobId: jobId,
      scheduledAt: scheduledAt,
      estimatedDurationMinutes: estimatedDurationMinutes,
    );
    if (overlap == null) {
      return;
    }
    throw VanScheduleOverlapException(
      overlap,
      formatScheduleOverlapMessage(overlap),
    );
  }

  void _throwIfScheduledInPast(DateTime scheduledAt) {
    final message = validateVanMateScheduledAt(scheduledAt);
    if (message == null) {
      return;
    }
    throw VanPastScheduleException(message);
  }

  VanScheduleOverlap? findScheduleOverlap({
    String? ignoringJobId,
    required DateTime scheduledAt,
    required int estimatedDurationMinutes,
  }) {
    final normalizedIgnoredJobId = ignoringJobId?.trim() ?? '';
    final normalizedDuration = estimatedDurationMinutes.clamp(1, 24 * 60);
    final proposedStart = scheduledAt;
    final proposedEnd = scheduledAt.add(Duration(minutes: normalizedDuration));
    final proposedJob = normalizedIgnoredJobId.isEmpty
        ? null
        : _jobsById[normalizedIgnoredJobId];

    for (final job in _jobsById.values) {
      if (normalizedIgnoredJobId.isNotEmpty &&
          job.jobId == normalizedIgnoredJobId) {
        continue;
      }
      if (job.isHiddenFromNormalLists || job.isCancelled || job.isCompleted) {
        continue;
      }

      final slot = job.bookedCalendarSlot;
      if (slot == null) {
        continue;
      }
      final existingStart = slot.start;
      final existingEnd = existingStart.add(
        Duration(minutes: slot.durationMinutes),
      );
      final overlaps =
          proposedStart.isBefore(existingEnd) &&
          proposedEnd.isAfter(existingStart);
      if (!overlaps) {
        continue;
      }
      if (proposedJob?.allowsParallelCalendarScheduling == true &&
          job.allowsParallelCalendarScheduling) {
        continue;
      }

      return VanScheduleOverlap(
        jobId: job.jobId,
        start: existingStart,
        end: existingEnd,
        customerName: job.customerName.trim(),
        jobTitle: job.jobTitle.trim(),
      );
    }

    return null;
  }

  String formatScheduleOverlapMessage(VanScheduleOverlap overlap) {
    final startLabel = _formatJobTime(TimeOfDay.fromDateTime(overlap.start));
    final endLabel = _formatJobTime(TimeOfDay.fromDateTime(overlap.end));
    return 'This booking overlaps with an existing booking from $startLabel to $endLabel.';
  }

  Future<bool> persistScheduledJob({
    String? jobId,
    required DateTime scheduledAt,
    required int estimatedDurationMinutes,
    String? schedulingStatus,
  }) async {
    final resolvedId = _resolveJobId(jobId);
    if (resolvedId == null) {
      debugPrintSynchronously(
        'CONFIRM_SCHEDULE_FIRESTORE_ERROR error=unresolved_job_id rawJobId=$jobId',
      );
      return false;
    }
    final existingJob = _jobsById[resolvedId];
    if (existingJob == null) {
      debugPrintSynchronously(
        'CONFIRM_SCHEDULE_FIRESTORE_ERROR error=missing_local_job jobId=$resolvedId',
      );
      return false;
    }
    final existingRequest = _requestForJobRaw(resolvedId);
    final normalizedDuration = estimatedDurationMinutes.clamp(1, 24 * 60);
    final scheduledJobId = resolvedId;
    final scheduledEndAt = scheduledAt.add(
      Duration(minutes: normalizedDuration),
    );
    _throwIfScheduledInPast(scheduledAt);
    final overlap = findScheduleOverlap(
      ignoringJobId: resolvedId,
      scheduledAt: scheduledAt,
      estimatedDurationMinutes: normalizedDuration,
    );
    if (overlap != null) {
      debugPrintSynchronously(
        'CONFIRM_SCHEDULE_FIRESTORE_ERROR error=schedule_overlap jobId=$resolvedId '
        'conflictJobId=${overlap.jobId} conflictStart=${overlap.start.toIso8601String()} '
        'conflictEnd=${overlap.end.toIso8601String()}',
      );
      throw VanScheduleOverlapException(
        overlap,
        formatScheduleOverlapMessage(overlap),
      );
    }
    const nextSchedulingStatus = 'scheduled';

    final updated = _updateJob(resolvedId, (job) {
      return job.copyWith(
        scheduledAt: scheduledAt,
        jobDateLabel: _formatJobDate(DateUtils.dateOnly(scheduledAt)),
        jobTimeLabel: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
        scheduledDate: _formatScheduledDate(DateUtils.dateOnly(scheduledAt)),
        scheduledStartTime: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
        estimatedDurationMinutes: normalizedDuration,
        calendarStatus: job.isCompletedJob ? 'completed' : 'scheduled',
        status: job.isCompletedJob ? 'completed' : 'scheduled',
        requestStatus: job.isCompletedJob ? job.requestStatus : 'confirmed',
        quoteStatus: 'accepted',
        quoteAccepted: true,
        quoteAcceptedAt: job.quoteAcceptedAt ?? DateTime.now(),
        quoteResponseStatus: 'accepted',
        quoteTimingChoice: job.acceptedProposedScheduledAt != null
            ? 'accepted_proposed_time'
            : 'agreed_time_saved',
        agreedDateTime: scheduledAt,
        confirmedAt: job.isCompletedJob
            ? job.confirmedAt
            : (job.confirmedAt ?? DateTime.now()),
        requestUpdatedAt: DateTime.now(),
        schedulingStatus: nextSchedulingStatus,
      );
    });
    if (updated == null) {
      return false;
    }

    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.persist_scheduled_job',
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    if (normalizedOwnerUid.isEmpty) {
      debugPrintSynchronously(
        'CONFIRM_SCHEDULE_FIRESTORE_ERROR error=missing_owner_uid jobId=$resolvedId',
      );
      return false;
    }

    try {
      await saveToStorage(syncCloud: false);
      final jobFields = <String, dynamic>{
        'calendarAdded': true,
        'scheduled': true,
        'calendarJobId': scheduledJobId,
        'status': updated.status,
        'calendarStatus': updated.calendarStatus,
        'requestStatus': updated.requestStatus,
        'quoteStatus': updated.quoteStatus,
        'quoteResponseStatus': updated.quoteResponseStatus,
        'quoteTimingChoice': updated.quoteTimingChoice,
        'agreedDateTime': scheduledAt.toIso8601String(),
        'agreedStartAt': scheduledAt.toIso8601String(),
        'agreedEndAt': scheduledEndAt.toIso8601String(),
        'scheduledAt': scheduledAt.toIso8601String(),
        'scheduledDate': updated.scheduledDate,
        'scheduledStartTime': updated.scheduledStartTime,
        'estimatedDurationMinutes': normalizedDuration,
        'agreedDurationMinutes': normalizedDuration,
        'jobDateLabel': updated.jobDateLabel,
        'jobTimeLabel': updated.jobTimeLabel,
        'acceptedQuote': true,
        'quoteAccepted': true,
        'quoteAcceptedAt': (updated.quoteAcceptedAt ?? DateTime.now())
            .toIso8601String(),
        'acceptedProposedTime': updated.acceptedProposedScheduledAt != null,
        'timeAgreed': true,
        'awaitingAgreedTime': false,
        'needsAgreedTime': false,
        'readyForCalendar': false,
        'schedulingStatus': 'scheduled',
        'confirmedAt': (updated.confirmedAt ?? DateTime.now())
            .toIso8601String(),
        'customerName': updated.customerName,
        'jobTitle': updated.jobTitle,
        'phoneNumber': updated.phoneNumber,
        'address': updated.address,
        'exactPinShared': updated.exactPinSaved,
        'hasExactPin': updated.exactPinSaved,
        'exactPinLatitude': updated.exactPinLatitude,
        'exactPinLongitude': updated.exactPinLongitude,
        'exactPinLat': updated.exactPinLatitude,
        'exactPinLng': updated.exactPinLongitude,
        'quoteAmount': updated.quoteAmount,
        'quoteResponseId': updated.quoteResponseId,
        'requestId': updated.requestId,
      };
      debugPrintSynchronously(
        'CONFIRM_SCHEDULE_FIRESTORE_START path=users/$normalizedOwnerUid/van_jobs/${updated.jobId} '
        'jobId=${updated.jobId} requestId=${updated.requestId ?? '(none)'} '
        'calendarJobId=$scheduledJobId source=${debugSourceForJob(updated.jobId)} '
        'status=${updated.status} calendarStatus=${updated.calendarStatus} '
        'scheduledDate=${updated.scheduledDate} scheduledStartTime=${updated.scheduledStartTime} '
        'estimatedDurationMinutes=$normalizedDuration fields=${jobFields.keys.join(',')}',
      );
      await VanJobsCloudService.instance.mergeJobFields(
        ownerUid: normalizedOwnerUid,
        jobId: updated.jobId,
        source: 'van_mate.add_to_calendar',
        fields: jobFields,
      );
      final request = _requestForJobRaw(updated.jobId);
      if (request != null && request.requestId.trim().isNotEmpty) {
        try {
          final requestFields = <String, dynamic>{
            'status': 'confirmed',
            'calendarAdded': true,
            'scheduled': true,
            'calendarJobId': scheduledJobId,
            'calendarStatus': 'scheduled',
            'schedulingStatus': 'scheduled',
            'scheduledAt': scheduledAt.toIso8601String(),
            'scheduledDate': updated.scheduledDate,
            'scheduledStartTime': updated.scheduledStartTime,
            'estimatedDurationMinutes': normalizedDuration,
            'agreedDateTime': scheduledAt.toIso8601String(),
            'agreedStartAt': scheduledAt.toIso8601String(),
            'agreedEndAt': scheduledEndAt.toIso8601String(),
          };
          debugPrintSynchronously(
            'CONFIRM_SCHEDULE_REQUEST_WRITE path=public_job_requests/${request.requestId} '
            'requestId=${request.requestId} linkedJobId=${updated.jobId} '
            'fields=${requestFields.keys.join(',')}',
          );
          await VanJobRequestCloudService.instance.mergeRequestFields(
            ownerUid: normalizedOwnerUid,
            requestId: request.requestId,
            fields: requestFields,
            source: 'van_mate.add_to_calendar',
          );
        } catch (error, stackTrace) {
          debugPrint(
            '[CONFIRM_SCHEDULE_REQUEST_SYNC_ERROR] path=public_job_requests/${request.requestId} '
            'linkedJobId=${updated.jobId} error=$error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      final quoteResponseId = updated.quoteResponseId.trim();
      if (quoteResponseId.isNotEmpty) {
        final quoteFields = <String, dynamic>{
          'calendarAdded': true,
          'scheduled': true,
          'calendarJobId': scheduledJobId,
          'status': 'scheduled',
          'schedulingStatus': 'scheduled',
          'calendarStatus': 'scheduled',
          'readyForCalendar': false,
          'agreedDateTime': scheduledAt.toIso8601String(),
          'agreedStartAt': scheduledAt.toIso8601String(),
          'agreedEndAt': scheduledEndAt.toIso8601String(),
          'scheduledAt': scheduledAt.toIso8601String(),
          'scheduledDate': updated.scheduledDate,
          'scheduledStartTime': updated.scheduledStartTime,
          'agreedDurationMinutes': normalizedDuration,
          'estimatedDurationMinutes': normalizedDuration,
        };
        debugPrintSynchronously(
          'CONFIRM_SCHEDULE_QUOTE_WRITE path=public_quote_responses/$quoteResponseId '
          'requestId=${updated.requestId ?? '(none)'} jobId=${updated.jobId} '
          'fields=${quoteFields.keys.join(',')}',
        );
        await VanPublicQuoteCloudService.instance.mergeQuoteFields(
          quoteId: quoteResponseId,
          fields: quoteFields,
          source: 'van_mate.add_to_calendar',
        );
      }
      debugPrintSynchronously(
        'CONFIRM_SCHEDULE_FIRESTORE_SUCCESS path=users/$normalizedOwnerUid/van_jobs/${updated.jobId} '
        'jobId=${updated.jobId} requestId=${updated.requestId ?? '(none)'} '
        'calendarJobId=$scheduledJobId',
      );
      await saveToStorage(syncCloud: false);
      await _syncPickupReminderForJob(updated);
      _debugLogCalendarJobSnapshot(
        'AddToCalendarSave:persistScheduledJob',
        updated,
      );
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrintSynchronously(
        'CONFIRM_SCHEDULE_FIRESTORE_ERROR path=users/$normalizedOwnerUid/van_jobs/$resolvedId '
        'jobId=$resolvedId source=${debugSourceForJob(resolvedId)} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _jobsById[resolvedId] = existingJob;
      if (existingRequest != null &&
          existingRequest.requestId.trim().isNotEmpty) {
        _jobRequestsById[existingRequest.requestId] = existingRequest;
      }
      _jobSourceById[resolvedId] = _jobSourceById[resolvedId] ?? 'local_cache';
      _syncRequestWatchers();
      await saveToStorage(syncCloud: false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> persistAgreedTime({
    String? jobId,
    required DateTime scheduledAt,
    required int estimatedDurationMinutes,
    String? schedulingStatus,
    bool markQuoteAccepted = false,
  }) async {
    final resolvedId = _resolveJobId(jobId);
    if (resolvedId == null) {
      debugPrintSynchronously(
        'AGREED_TIME_FIRESTORE_ERROR error=unresolved_job_id rawJobId=$jobId',
      );
      return false;
    }
    final existingJob = _jobsById[resolvedId];
    if (existingJob == null) {
      debugPrintSynchronously(
        'AGREED_TIME_FIRESTORE_ERROR error=missing_local_job jobId=$resolvedId',
      );
      return false;
    }
    final existingRequest = _requestForJobRaw(resolvedId);
    final existingJobSource = _jobSourceById[resolvedId];
    final normalizedDuration = estimatedDurationMinutes.clamp(1, 24 * 60);
    _throwIfScheduledInPast(scheduledAt);
    final overlap = findScheduleOverlap(
      ignoringJobId: resolvedId,
      scheduledAt: scheduledAt,
      estimatedDurationMinutes: normalizedDuration,
    );
    if (overlap != null) {
      debugPrintSynchronously(
        'AGREED_TIME_FIRESTORE_ERROR error=schedule_overlap jobId=$resolvedId '
        'conflictJobId=${overlap.jobId} conflictStart=${overlap.start.toIso8601String()} '
        'conflictEnd=${overlap.end.toIso8601String()}',
      );
      throw VanScheduleOverlapException(
        overlap,
        formatScheduleOverlapMessage(overlap),
      );
    }

    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.persist_agreed_time',
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    if (normalizedOwnerUid.isEmpty) {
      debugPrintSynchronously(
        'AGREED_TIME_FIRESTORE_ERROR error=missing_owner_uid jobId=$resolvedId',
      );
      return false;
    }

    final nextSchedulingStatus = 'ready_for_calendar';
    final agreedEndAt = _addDurationToDateTime(scheduledAt, normalizedDuration);
    final now = DateTime.now();
    final updated = existingJob.copyWith(
      scheduledAt: scheduledAt,
      jobDateLabel: _formatJobDate(DateUtils.dateOnly(scheduledAt)),
      jobTimeLabel: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
      scheduledDate: _formatScheduledDate(DateUtils.dateOnly(scheduledAt)),
      scheduledStartTime: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
      estimatedDurationMinutes: normalizedDuration,
      quoteTimingChoice: existingJob.quoteTimingChoice.trim().isNotEmpty
          ? existingJob.quoteTimingChoice
          : (existingJob.acceptedProposedScheduledAt != null
                ? 'accepted_proposed_time'
                : 'agreed_time_saved'),
      agreedDateTime: scheduledAt,
      schedulingStatus: nextSchedulingStatus,
      quoteAccepted: markQuoteAccepted ? true : existingJob.quoteAccepted,
      quoteAcceptedAt: markQuoteAccepted
          ? (existingJob.quoteAcceptedAt ?? now)
          : existingJob.quoteAcceptedAt,
      quoteDeclined: markQuoteAccepted ? false : existingJob.quoteDeclined,
      quoteDeclinedAt: markQuoteAccepted ? null : existingJob.quoteDeclinedAt,
      quoteRespondedAt: markQuoteAccepted
          ? (existingJob.quoteRespondedAt ?? now)
          : existingJob.quoteRespondedAt,
      quoteStatus: markQuoteAccepted ? 'accepted' : existingJob.quoteStatus,
      quoteResponseStatus: markQuoteAccepted
          ? 'accepted'
          : existingJob.quoteResponseStatus,
      status: markQuoteAccepted ? 'quoteAccepted' : existingJob.status,
      requestStatus: markQuoteAccepted
          ? 'quote_accepted'
          : existingJob.requestStatus,
      requestUpdatedAt: now,
      updatedAt: now,
    );
    final readyForCalendar =
        updated.isQuoteAccepted &&
        !updated.isAwaitingRequiredExactPin &&
        !updated.isScheduledInCalendarState;

    _jobsById[resolvedId] = updated;
    _jobSourceById[resolvedId] = 'local_cache';
    _activeJobId = resolvedId;
    _syncRequestRecordFromJob(updated);

    try {
      await saveToStorage(syncCloud: false);
      final jobFields = <String, dynamic>{
        'agreedDateTime': scheduledAt.toIso8601String(),
        'agreedStartAt': scheduledAt.toIso8601String(),
        'agreedEndAt': agreedEndAt?.toIso8601String(),
        'agreedDurationMinutes': normalizedDuration,
        'acceptedProposedTime': updated.acceptedProposedScheduledAt != null,
        'timeAgreed': true,
        'readyForCalendar': readyForCalendar,
        'needsAgreedTime': false,
        'timeStatus': 'ready_for_calendar',
        'timingStatus': 'ready_for_calendar',
        'quoteTimingChoice': updated.quoteTimingChoice,
        'schedulingStatus': nextSchedulingStatus,
        'requestStatus': updated.requestStatus,
        'quoteStatus': updated.quoteStatus,
        'quoteResponseStatus': updated.quoteResponseStatus,
        'quoteAccepted': updated.quoteAccepted,
        'quoteAcceptedAt': updated.quoteAcceptedAt?.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      debugPrintSynchronously(
        'AGREED_TIME_FIRESTORE_START path=users/$normalizedOwnerUid/van_jobs/${updated.jobId} '
        'jobId=${updated.jobId} source=${debugSourceForJob(updated.jobId)} '
        'status=${updated.status} calendarStatus=${updated.calendarStatus} '
        'scheduledDate=${updated.scheduledDate} scheduledStartTime=${updated.scheduledStartTime} '
        'estimatedDurationMinutes=$normalizedDuration schedulingStatus=$nextSchedulingStatus '
        'readyForCalendar=$readyForCalendar',
      );
      await VanJobsCloudService.instance.saveJob(
        ownerUid: normalizedOwnerUid,
        job: updated,
        source: 'van_mate.persist_agreed_time',
      );
      await VanJobsCloudService.instance.mergeJobFields(
        ownerUid: normalizedOwnerUid,
        jobId: updated.jobId,
        fields: jobFields,
        source: 'van_mate.persist_agreed_time',
      );
      final request = _requestForJobRaw(updated.jobId);
      if (request != null && request.requestId.trim().isNotEmpty) {
        final requestFields = <String, dynamic>{
          'status': updated.requestStatus,
          'scheduledAt': scheduledAt.toIso8601String(),
          'scheduledDate': updated.scheduledDate,
          'scheduledStartTime': updated.scheduledStartTime,
          'estimatedDurationMinutes': normalizedDuration,
          'agreedDateTime': scheduledAt.toIso8601String(),
          'agreedStartAt': scheduledAt.toIso8601String(),
          'agreedEndAt': agreedEndAt?.toIso8601String(),
          'agreedDurationMinutes': normalizedDuration,
          'acceptedProposedTime': updated.acceptedProposedScheduledAt != null,
          'timeAgreed': true,
          'readyForCalendar': readyForCalendar,
          'needsAgreedTime': false,
          'timeStatus': 'ready_for_calendar',
          'timingStatus': 'ready_for_calendar',
          'quoteTimingChoice': updated.quoteTimingChoice,
          'schedulingStatus': nextSchedulingStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        debugPrintSynchronously(
          'AGREED_TIME_REQUEST_WRITE path=public_job_requests/${request.requestId} '
          'jobId=${updated.jobId} requestId=${request.requestId} '
          'fields=${requestFields.keys.join(',')}',
        );
        await VanJobRequestCloudService.instance.saveRequests(
          ownerUid: normalizedOwnerUid,
          requests: <VanJobRequestRecord>[
            request.copyWith(
              status: updated.requestStatus,
              scheduledAt: scheduledAt,
              scheduledDate: updated.scheduledDate,
              scheduledStartTime: updated.scheduledStartTime,
              estimatedDurationMinutes: normalizedDuration,
              agreedDateTime: scheduledAt,
              agreedStartAt: scheduledAt,
              agreedEndAt: agreedEndAt,
              agreedDurationMinutes: normalizedDuration,
              acceptedProposedTime: updated.acceptedProposedScheduledAt != null,
              timeAgreed: true,
              readyForCalendar: readyForCalendar,
              needsAgreedTime: false,
              timeStatus: 'ready_for_calendar',
              timingStatus: 'ready_for_calendar',
              quoteTimingChoice: updated.quoteTimingChoice,
              schedulingStatus: nextSchedulingStatus,
              updatedAt: DateTime.now(),
            ),
          ],
          source: 'van_mate.persist_agreed_time',
        );
      }
      debugPrintSynchronously(
        'AGREED_TIME_FIRESTORE_SUCCESS path=users/$normalizedOwnerUid/van_jobs/${updated.jobId} '
        'jobId=${updated.jobId}',
      );
      await saveToStorage(syncCloud: false);
      _debugLogCalendarJobSnapshot('AgreedTimeSave:persistAgreedTime', updated);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrintSynchronously(
        'AGREED_TIME_FIRESTORE_ERROR path=users/$normalizedOwnerUid/van_jobs/$resolvedId '
        'jobId=$resolvedId source=${debugSourceForJob(resolvedId)} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _jobsById[resolvedId] = existingJob;
      if (existingRequest != null &&
          existingRequest.requestId.trim().isNotEmpty) {
        _jobRequestsById[existingRequest.requestId] = existingRequest;
      }
      _jobSourceById[resolvedId] = existingJobSource ?? 'local_cache';
      _syncRequestWatchers();
      await saveToStorage(syncCloud: false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> persistCompletedJob({
    String? jobId,
    DateTime? completedAt,
  }) async {
    final resolvedId = _resolveJobId(jobId);
    if (resolvedId == null) {
      debugPrintSynchronously(
        'COMPLETE_JOB_FIRESTORE_ERROR error=unresolved_job_id rawJobId=$jobId',
      );
      return false;
    }
    final existingJob = _jobsById[resolvedId];
    if (existingJob == null) {
      debugPrintSynchronously(
        'COMPLETE_JOB_FIRESTORE_ERROR error=missing_local_job jobId=$resolvedId',
      );
      return false;
    }
    if (existingJob.isCancelled) {
      debugPrintSynchronously(
        'COMPLETE_JOB_FIRESTORE_ERROR error=cancelled_job jobId=$resolvedId',
      );
      return false;
    }
    final existingRequest = _requestForJobRaw(resolvedId);
    final completedAtValue = completedAt ?? DateTime.now();
    final updated = _updateJob(resolvedId, (job) {
      return job.copyWith(
        completedAt: completedAtValue,
        cancelledAt: null,
        status: 'completed',
        calendarStatus: 'completed',
      );
    });
    if (updated == null) {
      return false;
    }

    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.persist_completed_job',
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    if (normalizedOwnerUid.isEmpty) {
      debugPrintSynchronously(
        'COMPLETE_JOB_FIRESTORE_ERROR error=missing_owner_uid jobId=$resolvedId',
      );
      return false;
    }

    try {
      await saveToStorage(syncCloud: false);
      final jobFields = <String, dynamic>{
        'status': 'completed',
        'calendarStatus': 'completed',
        'completedAt': completedAtValue.toIso8601String(),
      };
      debugPrintSynchronously(
        'COMPLETE_JOB_FIRESTORE_START path=users/$normalizedOwnerUid/van_jobs/${updated.jobId} '
        'jobId=${updated.jobId} requestId=${updated.requestId ?? '(none)'} '
        'fields=${jobFields.keys.join(',')}',
      );
      await VanJobsCloudService.instance.mergeJobFields(
        ownerUid: normalizedOwnerUid,
        jobId: updated.jobId,
        fields: jobFields,
        source: 'van_mate.complete_job',
      );
      final request = _requestForJobRaw(updated.jobId);
      if (request != null && request.requestId.trim().isNotEmpty) {
        await VanJobRequestCloudService.instance.mergeRequestFields(
          ownerUid: normalizedOwnerUid,
          requestId: request.requestId,
          fields: <String, dynamic>{
            'status': 'completed',
            'calendarStatus': 'completed',
            'completedAt': completedAtValue.toIso8601String(),
          },
          source: 'van_mate.complete_job',
        );
      }
      final quoteResponseId = updated.quoteResponseId.trim();
      if (quoteResponseId.isNotEmpty) {
        await VanPublicQuoteCloudService.instance.mergeQuoteFields(
          quoteId: quoteResponseId,
          fields: <String, dynamic>{
            'status': 'completed',
            'calendarStatus': 'completed',
            'completedAt': completedAtValue.toIso8601String(),
          },
          source: 'van_mate.complete_job',
        );
      }
      debugPrintSynchronously(
        'COMPLETE_JOB_FIRESTORE_SUCCESS path=users/$normalizedOwnerUid/van_jobs/${updated.jobId} '
        'jobId=${updated.jobId}',
      );
      await saveToStorage(syncCloud: false);
      await VanPickupReminderService.instance.cancel(updated.jobId);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrintSynchronously(
        'COMPLETE_JOB_FIRESTORE_ERROR path=users/$normalizedOwnerUid/van_jobs/$resolvedId '
        'jobId=$resolvedId error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _jobsById[resolvedId] = existingJob;
      if (existingRequest != null &&
          existingRequest.requestId.trim().isNotEmpty) {
        _jobRequestsById[existingRequest.requestId] = existingRequest;
      }
      await saveToStorage(syncCloud: false);
      notifyListeners();
      return false;
    }
  }

  DriverCustomerReplyMockData? cancelJob({String? jobId}) {
    final updated = _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      final now = DateTime.now();
      return job.copyWith(
        status: 'cancelled',
        requestStatus: 'cancelled',
        requestUpdatedAt: now,
        cancelledAt: job.cancelledAt ?? now,
        completedAt: null,
        calendarStatus: 'cancelled',
      );
    });
    if (updated != null && updated.requestId?.trim().isNotEmpty == true) {
      unawaited(cancelRequestForJob(jobId: updated.jobId, scheduleSave: false));
    }
    if (updated != null) {
      unawaited(VanPickupReminderService.instance.cancel(updated.jobId));
    }
    return updated;
  }

  Future<bool> deleteJob({String? jobId, bool refreshCloud = true}) async {
    final resolvedId = _resolveJobId(jobId);
    if (resolvedId == null || _deletingJobIds.contains(resolvedId)) {
      return false;
    }
    final existing = _jobsById[resolvedId];
    if (existing == null) return false;
    _deletingJobIds.add(resolvedId);
    notifyListeners();
    try {
      final request = _requestForJob(resolvedId);
      final execution = await _jobDeletionService.deleteOne(
        jobId: resolvedId,
        requestId: request?.requestId ?? existing.requestId ?? '',
      );
      VanJobDeletionTargetResult? result;
      for (final candidate in execution.results) {
        if (candidate.jobId == resolvedId) {
          result = candidate;
          break;
        }
      }
      if (result == null || !result.completed) return false;
      await applyConfirmedJobDeletionResults(<VanJobDeletionTargetResult>[
        result,
      ], refreshCloud: refreshCloud);
      return true;
    } on VanJobDeletionException catch (error) {
      debugPrint(
        '[JobDeletion] failed jobId=$resolvedId error=${error.message}',
      );
      return false;
    } catch (error, stackTrace) {
      debugPrint('[JobDeletion] failed jobId=$resolvedId error=$error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      _deletingJobIds.remove(resolvedId);
      notifyListeners();
    }
  }

  Future<void> applyConfirmedJobDeletionResults(
    Iterable<VanJobDeletionTargetResult> results, {
    bool refreshCloud = true,
  }) async {
    final completed = results.where((result) => result.completed).toList();
    if (completed.isEmpty) return;
    final deletedJobIds = <String>{};
    for (final result in completed) {
      final jobId = result.jobId.trim();
      if (jobId.isEmpty) continue;
      deletedJobIds.add(jobId);
      final requestIds = _jobRequestsById.values
          .where(
            (candidate) =>
                candidate.jobId.trim() == jobId ||
                candidate.linkedJobId.trim() == jobId ||
                candidate.requestId.trim() == result.requestId,
          )
          .map((candidate) => candidate.requestId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (result.requestId.isNotEmpty) requestIds.add(result.requestId);
      _jobsById.remove(jobId);
      _jobSourceById.remove(jobId);
      _cloudVanJobIds.remove(jobId);
      _jobRequestsById.removeWhere((id, _) => requestIds.contains(id));
      _deletedRequestKeys.addAll(<String>{
        jobId,
        'job:$jobId',
        for (final requestId in requestIds) requestId,
        for (final requestId in requestIds) 'request:$requestId',
      });
      await VanPickupReminderService.instance.cancel(jobId);
    }
    if (deletedJobIds.contains(_activeJobId)) {
      _activeJobId = _latestJob()?.jobId;
    }
    _syncRequestWatchers();
    await saveToStorage(syncCloud: false);
    await _persistDeletedRequestKeys();
    notifyListeners();
    if (refreshCloud) {
      unawaited(refreshJobsFromCloud(debugOrigin: 'job_bulk_delete_complete'));
    }
  }

  @Deprecated('Use the canonical server-authoritative deleteJob flow.')
  Future<bool> legacyDeleteJob({String? jobId}) async {
    final resolvedId = _resolveJobId(jobId);
    if (resolvedId == null) {
      debugPrint('DELETE JOB aborted reason=unresolved_job_id rawJobId=$jobId');
      return false;
    }

    final existing = _jobsById[resolvedId];
    if (existing == null) {
      debugPrint(
        'DELETE JOB aborted reason=missing_local_job jobId=$resolvedId',
      );
      return false;
    }

    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.job_delete',
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    debugPrint(
      'DELETE JOB uid=${normalizedOwnerUid.isEmpty ? '(null)' : normalizedOwnerUid}',
    );
    debugPrint('DELETE JOB jobId=$resolvedId');
    debugPrint('DELETE JOB firestoreDocId=$resolvedId');
    debugPrint('DELETE JOB requestId=${existing.requestId ?? '(none)'}');
    debugPrint('DELETE JOB uidNull=${normalizedOwnerUid.isEmpty}');
    debugPrint(
      'DELETE JOB path=users/$normalizedOwnerUid/van_jobs/$resolvedId',
    );
    if (normalizedOwnerUid.isEmpty) {
      debugPrint(
        '[VanJobDelete] delete blocked jobId=$resolvedId reason=no_owner_uid',
      );
      return false;
    }

    final requestCandidates = _jobRequestsById.values
        .where((request) => request.jobId.trim() == resolvedId)
        .toList(growable: false);
    requestCandidates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final request = requestCandidates.isNotEmpty
        ? requestCandidates.first
        : _requestForJob(resolvedId);
    final jobBackup = existing;
    final requestBackup = request;
    final activeJobBackup = _activeJobId;

    try {
      try {
        await VanJobsCloudService.instance.deleteJob(
          ownerUid: normalizedOwnerUid,
          jobId: resolvedId,
          source: 'van_mate.job_delete',
        );
        final deletedAt = DateTime.now();
        _jobsById[resolvedId] = existing.copyWith(
          deleted: true,
          archived: true,
          status: 'deleted',
          requestStatus: 'deleted',
          quoteStatus: 'deleted',
          quoteResponseStatus: 'deleted',
          schedulingStatus: 'cancelled',
          calendarStatus: 'cancelled',
          updatedAt: deletedAt,
        );
        _jobSourceById[resolvedId] = _jobSourceById[resolvedId] ?? '';
        if (requestBackup != null &&
            requestBackup.requestId.trim().isNotEmpty) {
          _jobRequestsById.remove(requestBackup.requestId);
        }
        if (_activeJobId == resolvedId) {
          _activeJobId = _latestJob()?.jobId;
        }
        _syncRequestWatchers();
        try {
          await saveToStorage(syncCloud: false);
        } catch (error) {
          debugPrint(
            '[VanJobDelete] local persistence after soft delete failed jobId=$resolvedId error=$error',
          );
        }
        notifyListeners();
        final visibleAfterLocalUpdate = jobs.any(
          (job) => job.jobId == resolvedId,
        );
        debugPrint(
          '[VanJobDelete] soft delete applied jobId=$resolvedId ownerUid=$normalizedOwnerUid path=users/$normalizedOwnerUid/van_jobs/$resolvedId visibleAfterUpdate=$visibleAfterLocalUpdate requestDeleted=${requestBackup != null} deletedAt=${deletedAt.toIso8601String()}',
        );
      } on FirebaseException catch (error, stackTrace) {
        debugPrint(
          'DELETE JOB FirebaseException code=${error.code} message=${error.message}',
        );
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      } catch (error, stackTrace) {
        debugPrint('DELETE JOB unknown error=$error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }

      if (requestBackup != null && requestBackup.requestId.trim().isNotEmpty) {
        final requestId = requestBackup.requestId.trim();
        debugPrint(
          'DELETE JOB request cleanup start requestId=$requestId ownerUid=$normalizedOwnerUid',
        );
        try {
          await VanJobRequestCloudService.instance.deleteRequest(
            ownerUid: normalizedOwnerUid,
            requestId: requestId,
            source: 'van_mate.job_delete_cleanup',
          );
          debugPrint('DELETE JOB request cleanup success requestId=$requestId');
        } on FirebaseException catch (error, stackTrace) {
          debugPrint(
            'DELETE JOB request cleanup FirebaseException code=${error.code} message=${error.message}',
          );
          debugPrintStack(stackTrace: stackTrace);
        } catch (error, stackTrace) {
          debugPrint('DELETE JOB request cleanup unknown error=$error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      try {
        await saveToStorage(syncCloud: false);
      } catch (error) {
        debugPrint(
          '[VanJobDelete] local persistence after firestore delete failed jobId=$resolvedId error=$error',
        );
      }
      debugPrint(
        '[VanJobDelete] firestore soft delete success jobId=$resolvedId ownerUid=$normalizedOwnerUid requestDeleted=${requestBackup != null} invoicesRetained=${savedInvoiceHistory.where((entry) => entry.jobKey.trim() == resolvedId).length}',
      );
      await VanPickupReminderService.instance.cancel(resolvedId);
      return true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[VanJobDelete] firestore delete failed jobId=$resolvedId ownerUid=$normalizedOwnerUid code=${error.code} message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _jobsById[resolvedId] = jobBackup;
      _jobSourceById[resolvedId] = 'local_cache';
      if (requestBackup != null && requestBackup.requestId.trim().isNotEmpty) {
        _jobRequestsById[requestBackup.requestId] = requestBackup;
      }
      _activeJobId = activeJobBackup;
      _syncRequestWatchers();
      try {
        await saveToStorage(syncCloud: false);
      } catch (restoreError) {
        debugPrint(
          '[VanJobDelete] local restore persistence failed jobId=$resolvedId error=$restoreError',
        );
      }
      notifyListeners();
      return false;
    } catch (error, stackTrace) {
      debugPrint(
        '[VanJobDelete] firestore delete failed jobId=$resolvedId ownerUid=$normalizedOwnerUid error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _jobsById[resolvedId] = jobBackup;
      _jobSourceById[resolvedId] = 'local_cache';
      if (requestBackup != null && requestBackup.requestId.trim().isNotEmpty) {
        _jobRequestsById[requestBackup.requestId] = requestBackup;
      }
      _activeJobId = activeJobBackup;
      _syncRequestWatchers();
      try {
        await saveToStorage(syncCloud: false);
      } catch (restoreError) {
        debugPrint(
          '[VanJobDelete] local restore persistence failed jobId=$resolvedId error=$restoreError',
        );
      }
      notifyListeners();
      return false;
    }
  }

  Future<IncomingRequestDeleteResult> deleteIncomingRequest({
    String? requestId,
    required String localJobId,
    String source = '',
  }) async {
    final request = requestId?.trim() ?? '';
    final deleted = await deleteJob(jobId: localJobId);
    return IncomingRequestDeleteResult(
      status: deleted
          ? IncomingRequestDeleteStatus.deleted
          : IncomingRequestDeleteStatus.failed,
      requestId: request,
      linkedJobId: localJobId.trim(),
      source: source.trim(),
      ownerUid: '',
      attemptedPaths: const <String>['deleteBusinessMateJobs'],
      localDeleteSucceeded: deleted,
      cloudDeleteSucceeded: deleted,
      cloudNotFoundOnly: false,
      cloudPermissionDenied: false,
      errorMessage: deleted ? '' : 'Could not delete request.',
    );
  }

  @Deprecated(
    'Use the canonical server-authoritative deleteIncomingRequest flow.',
  )
  Future<IncomingRequestDeleteResult> legacyDeleteIncomingRequest({
    String? requestId,
    required String localJobId,
    String source = '',
  }) async {
    final visibleCountBeforeDelete = pendingJobs.length;
    final normalizedRequestId = requestId?.trim() ?? '';
    final normalizedLocalJobId = localJobId.trim();
    final requestBackup = normalizedRequestId.isEmpty
        ? null
        : _jobRequestsById[normalizedRequestId];
    DriverCustomerReplyMockData? jobBackup;

    if (requestBackup != null) {
      final requestLinkedJobId = requestBackup.linkedJobId.trim().isNotEmpty
          ? requestBackup.linkedJobId.trim()
          : requestBackup.jobId.trim();
      jobBackup = _jobsById[requestLinkedJobId];
    }

    if (jobBackup == null && normalizedLocalJobId.isNotEmpty) {
      jobBackup = _jobsById[normalizedLocalJobId];
    }

    if (jobBackup == null && normalizedRequestId.isNotEmpty) {
      for (final job in _jobsById.values) {
        if (job.requestId?.trim() == normalizedRequestId) {
          jobBackup = job;
          break;
        }
      }
    }

    final resolvedSource = requestBackup?.source.trim().isNotEmpty == true
        ? requestBackup!.source.trim()
        : source.trim();
    final ownerUid = requestBackup?.ownerUid.trim().isNotEmpty == true
        ? requestBackup!.ownerUid.trim()
        : (await VanFirebaseAuthService.instance.ensureCurrentUid(
                    source: 'van_mate.incoming_request_delete',
                  ) ??
                  '')
              .trim();
    final linkedJobId = requestBackup?.linkedJobId.trim().isNotEmpty == true
        ? requestBackup!.linkedJobId.trim()
        : requestBackup?.jobId.trim().isNotEmpty == true
        ? requestBackup!.jobId.trim()
        : jobBackup?.jobId.trim() ?? normalizedLocalJobId;
    final localOnlyLegacy =
        normalizedRequestId.isEmpty ||
        requestBackup == null ||
        ((resolvedSource.isEmpty ||
                resolvedSource == 'manual' ||
                resolvedSource == 'new_job' ||
                resolvedSource == 'create_job' ||
                resolvedSource == 'old_request') &&
            !_cloudVanJobIds.contains(linkedJobId));

    debugPrint(
      '[IncomingRequestDelete] tapped requestId=${normalizedRequestId.isEmpty ? '(none)' : normalizedRequestId} linkedJobId=${linkedJobId.isEmpty ? '(none)' : linkedJobId} source=${resolvedSource.isEmpty ? '(none)' : resolvedSource} ownerUid=${ownerUid.isEmpty ? '(none)' : ownerUid}',
    );
    debugPrint(
      '[IncomingRequestDelete] visibleCountBeforeDelete=$visibleCountBeforeDelete title=${jobBackup?.jobTitle.trim().isNotEmpty == true ? jobBackup!.jobTitle.trim() : '(none)'} customer=${jobBackup?.customerName.trim().isNotEmpty == true ? jobBackup!.customerName.trim() : '(none)'}',
    );
    final deleteAliases = deletedKeyAliasesForJob(
      jobBackup ??
          DriverCustomerReplyMockData(
            jobId: normalizedLocalJobId,
            customerName: '',
            jobTitle: '',
            scheduledAt: null,
            jobDateLabel: '',
            jobTimeLabel: '',
            address: '',
            phoneNumber: '',
            exactPinShared: false,
            checklistResponses: const <DriverChecklistResponse>[],
            customQuestionResponses: const <DriverCustomQuestionResponse>[],
            additionalNotes: '',
          ),
      request: requestBackup,
      source: resolvedSource,
    );
    final deleteKey = buildVanRequestDeleteKey(
      requestId: requestBackup?.requestId,
      firestoreDocId: requestBackup?.requestId,
      docId: normalizedLocalJobId,
      linkedJobId: linkedJobId,
      source: resolvedSource,
      title: requestBackup?.publicJobTitle ?? jobBackup?.jobTitle,
      customerName:
          requestBackup?.publicCustomerName ?? jobBackup?.customerName,
      phone: requestBackup?.publicPhoneNumber ?? jobBackup?.phoneNumber,
      date: requestBackup?.jobDateLabel ?? jobBackup?.jobDateLabel,
      createdAt: (requestBackup?.createdAt ?? jobBackup?.createdAt)
          ?.toIso8601String(),
    );
    debugPrint('[IncomingRequestDelete] deleteKeyUsed=$deleteKey');

    final attemptedPaths = <String>[];
    var cloudDeleteSucceeded = false;
    var cloudNotFoundOnly = false;
    var cloudPermissionDenied = false;
    var sawCloudDeleteFailure = false;

    if (normalizedRequestId.isNotEmpty) {
      final cloudResults = await Future.wait<_IncomingDeleteAttemptResult>([
        _attemptIncomingDeletePath(
          path: 'public_job_requests/$normalizedRequestId',
          ref: FirebaseFirestore.instance
              .collection('public_job_requests')
              .doc(normalizedRequestId),
        ),
        _attemptIncomingDeletePath(
          path: 'van_job_requests/$normalizedRequestId',
          ref: FirebaseFirestore.instance
              .collection('van_job_requests')
              .doc(normalizedRequestId),
        ),
        if (ownerUid.isNotEmpty)
          _attemptIncomingDeletePath(
            path: 'users/$ownerUid/van_job_requests/$normalizedRequestId',
            ref: FirebaseFirestore.instance
                .collection('users')
                .doc(ownerUid)
                .collection('van_job_requests')
                .doc(normalizedRequestId),
          ),
      ]);
      for (final result in cloudResults) {
        attemptedPaths.add(result.path);
        cloudDeleteSucceeded = cloudDeleteSucceeded || result.deleted;
        cloudNotFoundOnly = cloudNotFoundOnly || result.notFound;
        cloudPermissionDenied =
            cloudPermissionDenied || result.permissionDenied;
        sawCloudDeleteFailure = sawCloudDeleteFailure || result.failed;
      }
    }

    if (ownerUid.isNotEmpty && linkedJobId.isNotEmpty) {
      final jobDeleteResult = await _attemptIncomingDeletePath(
        path: 'users/$ownerUid/van_jobs/$linkedJobId',
        ref: FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .collection('van_jobs')
            .doc(linkedJobId),
      );
      attemptedPaths.add(jobDeleteResult.path);
      cloudDeleteSucceeded = cloudDeleteSucceeded || jobDeleteResult.deleted;
      cloudNotFoundOnly = cloudNotFoundOnly || jobDeleteResult.notFound;
      cloudPermissionDenied =
          cloudPermissionDenied || jobDeleteResult.permissionDenied;
      sawCloudDeleteFailure = sawCloudDeleteFailure || jobDeleteResult.failed;
    }

    final removedJobs = <String, DriverCustomerReplyMockData>{};
    final removedJobSources = <String, String>{};
    final removedRequests = <String, VanJobRequestRecord>{};

    if (requestBackup != null && normalizedRequestId.isNotEmpty) {
      removedRequests[normalizedRequestId] = requestBackup;
      _jobRequestsById.remove(normalizedRequestId);
    }
    if (jobBackup != null && jobBackup.jobId.trim().isNotEmpty) {
      removedJobs[jobBackup.jobId] = jobBackup;
      removedJobSources[jobBackup.jobId] =
          _jobSourceById[jobBackup.jobId] ?? '';
      _jobsById.remove(jobBackup.jobId);
      _jobSourceById.remove(jobBackup.jobId);
      if (_activeJobId == jobBackup.jobId) {
        _activeJobId = _latestJob()?.jobId;
      }
    }

    if (removedJobs.isEmpty &&
        normalizedLocalJobId.isNotEmpty &&
        _jobsById.containsKey(normalizedLocalJobId)) {
      final fallbackRemoved = _jobsById.remove(normalizedLocalJobId);
      if (fallbackRemoved != null) {
        removedJobs[normalizedLocalJobId] = fallbackRemoved;
        removedJobSources[normalizedLocalJobId] =
            _jobSourceById[normalizedLocalJobId] ?? '';
        _jobSourceById.remove(normalizedLocalJobId);
      }
    }

    _deletedRequestKeys.addAll(deleteAliases);
    debugPrint(
      '[IncomingRequestDelete] deleted keys updated count=${_deletedRequestKeys.length} key=$deleteKey aliases=${deleteAliases.join(', ')}',
    );

    _syncRequestWatchers();
    var localDeleteSucceeded = false;
    try {
      await saveToStorage(syncCloud: false);
      localDeleteSucceeded =
          removedJobs.isNotEmpty ||
          removedRequests.isNotEmpty ||
          deleteAliases.any(_deletedRequestKeys.contains);
      notifyListeners();
      debugPrint(
        '[IncomingRequestDelete] local delete success requestId=${normalizedRequestId.isEmpty ? '(none)' : normalizedRequestId} localDeleteSucceeded=$localDeleteSucceeded',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[IncomingRequestDelete] local delete failed requestId=${normalizedRequestId.isEmpty ? '(none)' : normalizedRequestId} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (cloudDeleteSucceeded) {
        localDeleteSucceeded =
            removedJobs.isNotEmpty || removedRequests.isNotEmpty;
        notifyListeners();
        debugPrint(
          '[IncomingRequestDelete] local persistence failed but keeping in-memory removal requestId=${normalizedRequestId.isEmpty ? '(none)' : normalizedRequestId}',
        );
      } else {
        for (final entry in removedRequests.entries) {
          _jobRequestsById[entry.key] = entry.value;
        }
        for (final entry in removedJobs.entries) {
          _jobsById[entry.key] = entry.value;
          _jobSourceById[entry.key] = removedJobSources[entry.key] ?? '';
        }
        _deletedRequestKeys.removeAll(deleteAliases);
        _syncRequestWatchers();
        notifyListeners();
      }
    }

    final visibleCountAfterDelete = pendingJobs.length;
    final stillVisible = pendingJobs.any((job) {
      final request = _requestForJobRaw(job.jobId);
      final aliases = deletedKeyAliasesForJob(job, request: request);
      return aliases.any(deleteAliases.contains);
    });
    final allCloudAttemptsWereBenign =
        attemptedPaths.isEmpty ||
        (!sawCloudDeleteFailure && !cloudPermissionDenied);

    final effectiveLocalSuccess =
        localDeleteSucceeded &&
        !stillVisible &&
        visibleCountAfterDelete <= visibleCountBeforeDelete;
    final status = effectiveLocalSuccess
        ? (cloudDeleteSucceeded || allCloudAttemptsWereBenign || localOnlyLegacy
              ? IncomingRequestDeleteStatus.deleted
              : IncomingRequestDeleteStatus.removedFromDeviceOnly)
        : IncomingRequestDeleteStatus.failed;

    if (status != IncomingRequestDeleteStatus.failed &&
        linkedJobId.isNotEmpty) {
      await VanPickupReminderService.instance.cancel(linkedJobId);
    }

    debugPrint(
      '[IncomingRequestDelete] result requestId=${normalizedRequestId.isEmpty ? '(none)' : normalizedRequestId} linkedJobId=${linkedJobId.isEmpty ? '(none)' : linkedJobId} source=${resolvedSource.isEmpty ? '(none)' : resolvedSource} ownerUid=${ownerUid.isEmpty ? '(none)' : ownerUid} deleteKey=$deleteKey attemptedPaths=${attemptedPaths.isEmpty ? '(none)' : attemptedPaths.join(', ')} cloudDeleteSucceeded=$cloudDeleteSucceeded cloudNotFoundOnly=$cloudNotFoundOnly cloudPermissionDenied=$cloudPermissionDenied localDeleteSucceeded=$localDeleteSucceeded stillVisible=$stillVisible visibleCountBefore=$visibleCountBeforeDelete visibleCountAfter=$visibleCountAfterDelete finalStatus=${status.name}',
    );

    return IncomingRequestDeleteResult(
      status: status,
      requestId: normalizedRequestId,
      linkedJobId: linkedJobId,
      source: resolvedSource,
      ownerUid: ownerUid,
      attemptedPaths: attemptedPaths,
      localDeleteSucceeded: localDeleteSucceeded,
      cloudDeleteSucceeded: cloudDeleteSucceeded,
      cloudNotFoundOnly: cloudNotFoundOnly,
      cloudPermissionDenied: cloudPermissionDenied,
      errorMessage: status == IncomingRequestDeleteStatus.failed
          ? 'Could not delete request.'
          : '',
    );
  }

  void setJobReady(bool value, {String? jobId}) {
    final updated = _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      if (!value) {
        return job.copyWith(status: 'draft');
      }
      final nextStatus = job.isCompletedJob ? 'completed' : 'scheduled';
      return job.copyWith(
        status: nextStatus,
        requestStatus: job.isCompletedJob ? job.requestStatus : 'confirmed',
        confirmedAt: job.isCompletedJob
            ? job.confirmedAt
            : (job.confirmedAt ?? DateTime.now()),
        requestUpdatedAt: DateTime.now(),
        calendarStatus: job.isCompletedJob ? 'completed' : 'scheduled',
      );
    });
    if (updated != null) {
      _debugLogCalendarJobSnapshot('AddToCalendarSave:setJobReady', updated);
    }
  }

  Future<_IncomingDeleteAttemptResult> _attemptIncomingDeletePath({
    required String path,
    required DocumentReference<Map<String, dynamic>> ref,
  }) async {
    debugPrint('[IncomingRequestDelete] attempt path=$path');
    try {
      final isVanJobPath = path.contains('/van_jobs/');
      final payload = <String, dynamic>{
        'deleted': true,
        'archived': true,
        'deletedByDriver': true,
        'status': 'deleted',
        'requestStatus': 'deleted',
        'quoteStatus': 'deleted',
        'quoteResponseStatus': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (isVanJobPath) ...<String, dynamic>{
          'schedulingStatus': 'cancelled',
          'calendarStatus': 'cancelled',
        },
      };
      debugPrint(
        '[IncomingRequestDelete] soft delete path=$path fields=${payload.keys.join(', ')}',
      );
      await ref.set(payload, SetOptions(merge: true));
      debugPrint('[IncomingRequestDelete] soft deleted path=$path');
      return _IncomingDeleteAttemptResult(path: path, deleted: true);
    } on FirebaseException catch (error, stackTrace) {
      final code = error.code.trim().toLowerCase();
      if (code == 'not-found') {
        debugPrint('[IncomingRequestDelete] not_found path=$path');
        return _IncomingDeleteAttemptResult(path: path, notFound: true);
      }
      if (code == 'permission-denied') {
        debugPrint(
          '[IncomingRequestDelete] permission_denied path=$path message=${error.message}',
        );
        debugPrintStack(stackTrace: stackTrace);
        return _IncomingDeleteAttemptResult(
          path: path,
          failed: true,
          permissionDenied: true,
        );
      }
      debugPrint(
        '[IncomingRequestDelete] failed path=$path code=${error.code} message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      return _IncomingDeleteAttemptResult(path: path, failed: true);
    } catch (error, stackTrace) {
      debugPrint('[IncomingRequestDelete] failed path=$path error=$error');
      debugPrintStack(stackTrace: stackTrace);
      return _IncomingDeleteAttemptResult(path: path, failed: true);
    }
  }

  void setPinSavedToJob(bool value, {String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(exactPinShared: value || job.exactPinShared);
    });
  }

  void setQuoteSaved(bool value, {String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(
        quoteSavedAt: value
            ? (job.quoteSavedAt ?? DateTime.now())
            : job.quoteSavedAt,
        status: job.isCompletedJob
            ? 'completed'
            : job.status == 'confirmed'
            ? 'confirmed'
            : job.status == 'quoteSent' || value
            ? 'quoteSent'
            : job.status,
      );
    });
  }

  int _quoteVersionFromId(String quoteResponseId) {
    final normalized = quoteResponseId.trim();
    if (normalized.isEmpty) {
      return 0;
    }
    final match = RegExp(r'_q(\d+)$').firstMatch(normalized);
    if (match == null) {
      return 1;
    }
    return int.tryParse(match.group(1) ?? '') ?? 1;
  }

  int _nextQuoteVersion(DriverCustomerReplyMockData job) {
    final versions = <int>[
      for (final entry in job.quoteHistory) entry.version,
      _quoteVersionFromId(job.authoritativeCurrentQuoteId),
    ].where((value) => value > 0).toList(growable: false);
    if (versions.isEmpty) {
      return 1;
    }
    versions.sort();
    return versions.last + 1;
  }

  String _buildRevisedQuoteResponseId(DriverCustomerReplyMockData job) {
    final baseId = job.jobId.trim();
    final nextVersion = _nextQuoteVersion(job);
    return '${baseId}_q$nextVersion';
  }

  String resolveQuoteResponseIdForJob(
    DriverCustomerReplyMockData job, {
    bool creatingFreshQuote = false,
  }) {
    if (creatingFreshQuote && job.isQuoteDeclined) {
      return _buildRevisedQuoteResponseId(job);
    }

    final quoteResponseId = job.authoritativeCurrentQuoteId;
    return quoteResponseId.isNotEmpty ? quoteResponseId : job.jobId.trim();
  }

  String resolveQuoteResponseLinkForJob(
    DriverCustomerReplyMockData job, {
    bool creatingFreshQuote = false,
  }) {
    final resolvedQuoteResponseId = resolveQuoteResponseIdForJob(
      job,
      creatingFreshQuote: creatingFreshQuote,
    );
    if (resolvedQuoteResponseId.isEmpty) {
      return '';
    }

    return resolveVanQuoteResponseDisplayLink(
      quoteResponseToken: buildVanQuoteResponseToken(resolvedQuoteResponseId),
      quoteId: resolvedQuoteResponseId,
    );
  }

  VanQuoteHistoryEntry? _buildCurrentQuoteHistoryEntry(
    DriverCustomerReplyMockData job,
  ) {
    final quoteResponseId = job.authoritativeCurrentQuoteId;
    if (quoteResponseId.isEmpty) {
      return null;
    }
    final existingVersion = job.quoteHistory
        .where((entry) => entry.quoteResponseId.trim() == quoteResponseId)
        .map((entry) => entry.version)
        .fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
    return VanQuoteHistoryEntry(
      quoteResponseId: quoteResponseId,
      quoteResponseToken: job.quoteResponseToken,
      quoteResponseLink: job.quoteResponseLink,
      version: existingVersion > 0
          ? existingVersion
          : _quoteVersionFromId(quoteResponseId),
      quoteAmount: job.quoteAmount,
      quoteJobDescription: job.quoteJobDescription,
      quoteNotes: job.quoteNotes,
      quotePaymentInstructions: job.quotePaymentInstructions,
      quoteMessage: job.quoteMessage,
      quoteExtras: job.quoteExtras,
      proposedDate: job.proposedDate,
      proposedStartTime: job.proposedStartTime,
      proposedAppointmentNote: job.proposedAppointmentNote,
      estimatedDurationMinutes: job.estimatedDurationMinutes,
      quoteStatus: job.quoteStatus,
      quoteResponseStatus: job.quoteResponseStatus,
      quoteTimingChoice: job.quoteTimingChoice,
      quoteAccepted: job.quoteAccepted,
      quoteDeclined: job.quoteDeclined,
      quoteSentAt: job.quoteSentAt,
      quoteOpenedAt: job.quoteOpenedAt,
      quoteAcceptedAt: job.quoteAcceptedAt,
      quoteDeclinedAt: job.quoteDeclinedAt,
      quoteRespondedAt: job.quoteRespondedAt,
      declineReasonCode: job.declineReasonCode,
      declineReasonLabel: job.declineReasonLabel,
      declineReasonText: job.declineReasonText,
    );
  }

  Future<void> setQuoteSent(
    bool value, {
    String? jobId,
    double? amount,
    Map<String, dynamic> publicQuoteData = const <String, dynamic>{},
    String proposedDate = '',
    String proposedStartTime = '',
    int? estimatedDurationMinutes,
    String proposedAppointmentNote = '',
    String schedulingStatus = '',
  }) async {
    final resolvedJobId = _resolveJobId(jobId);
    final existingJob = resolvedJobId == null ? null : _jobsById[resolvedJobId];
    final shouldCreateFreshQuote =
        value && existingJob != null && existingJob.isQuoteDeclined;
    final supersedesQuoteId = shouldCreateFreshQuote
        ? existingJob.authoritativeCurrentQuoteId
        : '';
    final normalizedQuoteResponseId = existingJob == null
        ? ((jobId?.trim().isNotEmpty ?? false) ? jobId!.trim() : '')
        : resolveQuoteResponseIdForJob(
            existingJob,
            creatingFreshQuote: value && shouldCreateFreshQuote,
          );
    final normalizedQuoteResponseLink = existingJob == null
        ? (normalizedQuoteResponseId.isEmpty
              ? ''
              : resolveVanQuoteResponseDisplayLink(
                  quoteResponseToken: buildVanQuoteResponseToken(
                    normalizedQuoteResponseId,
                  ),
                  quoteId: normalizedQuoteResponseId,
                ))
        : resolveQuoteResponseLinkForJob(
            existingJob,
            creatingFreshQuote: value && shouldCreateFreshQuote,
          );
    final normalizedQuoteResponseToken = normalizedQuoteResponseId.isEmpty
        ? ''
        : buildVanQuoteResponseToken(normalizedQuoteResponseId);
    final generatedQuoteMessage = value
        ? buildVanQuoteMessage(
            customerName: existingJob?.customerName ?? '',
            jobTitle:
                publicQuoteData['jobDescription']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? publicQuoteData['jobDescription'].toString().trim()
                : (existingJob?.jobTitle ?? ''),
            quoteAmountText: formatCurrency(
              amount ?? existingJob?.quoteAmount ?? 0,
            ),
            quoteResponseLink: normalizedQuoteResponseLink,
            businessName: sanitizeVanText(
              publicQuoteData['businessName']?.toString() ?? '',
            ).trim(),
            proposedAppointmentText: proposedAppointmentNote.isNotEmpty
                ? proposedAppointmentNote
                : (proposedDate.isNotEmpty && proposedStartTime.isNotEmpty
                      ? '$proposedDate at $proposedStartTime'
                      : ''),
          )
        : (existingJob?.quoteMessage ?? '');
    debugPrint(
      '[QuoteSend] jobId=${jobId ?? '(active)'} quoteId=${normalizedQuoteResponseId.isEmpty ? '(none)' : normalizedQuoteResponseId} requestId=${activeJob?.requestId ?? _jobsById[jobId ?? '']?.requestId ?? '(none)'} requiresExactPinAfterQuoteAccepted=${activeJob?.requiresExactPinAfterQuoteAccepted ?? _jobsById[jobId ?? '']?.requiresExactPinAfterQuoteAccepted ?? false}',
    );
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      var nextQuoteHistory = job.quoteHistory;
      if (value && shouldCreateFreshQuote) {
        final priorEntry = _buildCurrentQuoteHistoryEntry(job);
        if (priorEntry != null &&
            !nextQuoteHistory.any(
              (entry) => entry.quoteResponseId == priorEntry.quoteResponseId,
            )) {
          nextQuoteHistory = <VanQuoteHistoryEntry>[
            ...nextQuoteHistory,
            priorEntry,
          ];
        }
      }
      return job.copyWith(
        quoteAmount: amount ?? job.quoteAmount,
        quoteSavedAt: job.quoteSavedAt ?? DateTime.now(),
        quoteSentAt: value ? DateTime.now() : job.quoteSentAt,
        quoteOpenedAt: value ? DateTime.now() : job.quoteOpenedAt,
        currentQuoteId: value ? normalizedQuoteResponseId : job.currentQuoteId,
        quoteResponseId: value
            ? normalizedQuoteResponseId
            : job.quoteResponseId,
        quoteResponseToken: value
            ? normalizedQuoteResponseToken
            : job.quoteResponseToken,
        quoteResponseLink: value
            ? normalizedQuoteResponseLink
            : job.quoteResponseLink,
        quoteExtras: value
            ? ((publicQuoteData['quoteExtras'] as List?)
                      ?.map((item) => item?.toString().trim() ?? '')
                      .where((item) => item.isNotEmpty)
                      .toList(growable: false) ??
                  job.quoteExtras)
            : job.quoteExtras,
        quoteJobDescription: value
            ? (publicQuoteData['jobDescription']
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? publicQuoteData['jobDescription'].toString().trim()
                  : job.quoteJobDescription)
            : job.quoteJobDescription,
        quoteNotes: value
            ? publicQuoteData['quoteNotes']?.toString().trim() ?? job.quoteNotes
            : job.quoteNotes,
        quotePaymentInstructions: value
            ? publicQuoteData['paymentInstructions']?.toString().trim() ??
                  job.quotePaymentInstructions
            : job.quotePaymentInstructions,
        quoteMessage: value ? generatedQuoteMessage : job.quoteMessage,
        quoteStatus: value ? 'sent' : job.quoteStatus,
        quoteAccepted: value ? false : job.quoteAccepted,
        quoteAcceptedAt: value ? null : job.quoteAcceptedAt,
        quoteDeclined: value ? false : job.quoteDeclined,
        quoteDeclinedAt: value ? null : job.quoteDeclinedAt,
        declineReasonCode: value ? '' : job.declineReasonCode,
        declineReasonLabel: value ? '' : job.declineReasonLabel,
        declineReasonText: value ? '' : job.declineReasonText,
        declineNote: value ? '' : job.declineNote,
        quoteRespondedAt: value ? null : job.quoteRespondedAt,
        quoteResponseStatus: value ? '' : job.quoteResponseStatus,
        quoteTimingChoice: value ? '' : job.quoteTimingChoice,
        agreedDateTime: value ? null : job.agreedDateTime,
        requestStatus: value ? 'quote_sent' : job.requestStatus,
        requestUpdatedAt: value ? DateTime.now() : job.requestUpdatedAt,
        proposedDate: value ? proposedDate : job.proposedDate,
        proposedStartTime: value ? proposedStartTime : job.proposedStartTime,
        acceptedProposedDate: value ? '' : job.acceptedProposedDate,
        acceptedProposedStartTime: value ? '' : job.acceptedProposedStartTime,
        proposedAppointmentNote: value
            ? proposedAppointmentNote
            : job.proposedAppointmentNote,
        estimatedDurationMinutes:
            estimatedDurationMinutes ?? job.estimatedDurationMinutes,
        schedulingStatus: value ? schedulingStatus : job.schedulingStatus,
        status: value
            ? (job.isCompletedJob
                  ? 'completed'
                  : job.status == 'confirmed'
                  ? 'confirmed'
                  : 'quoteSent')
            : job.status,
        quoteHistory: nextQuoteHistory,
      );
    });
    if (value) {
      await _syncPublicQuoteForJob(
        jobId,
        extraData: <String, dynamic>{
          ...publicQuoteData,
          'quoteSent': true,
          'quoteResponse': 'pending',
          'quoteAccepted': false,
          'quoteDeclined': false,
          'quoteRespondedAt': null,
          'quoteAcceptedAt': null,
          'quoteDeclinedAt': null,
          'quoteResponseStatus': '',
          'quoteTimingChoice': '',
          'agreedDateTime': null,
          'acceptedProposedDate': '',
          'acceptedProposedStartTime': '',
          'status': 'quote_sent',
          'requestStatus': 'quote_sent',
          'quoteStatus': 'sent',
          'supersedesQuoteId': supersedesQuoteId,
        },
      );
    }
    return;
  }

  Future<bool> archiveIncomingRequest({
    String? requestId,
    required String localJobId,
  }) async {
    final normalizedRequestId = requestId?.trim() ?? '';
    final normalizedLocalJobId = localJobId.trim();
    if (normalizedRequestId.isEmpty && normalizedLocalJobId.isEmpty) {
      return false;
    }

    var didArchive = false;
    if (normalizedRequestId.isNotEmpty) {
      final existingRequest = _jobRequestsById[normalizedRequestId];
      if (existingRequest != null && !existingRequest.archived) {
        _jobRequestsById[normalizedRequestId] = existingRequest.copyWith(
          archived: true,
          updatedAt: DateTime.now(),
        );
        didArchive = true;
      }
    }

    final requestEntry = normalizedRequestId.isEmpty
        ? null
        : _jobRequestsById[normalizedRequestId];
    final resolvedJobId = normalizedLocalJobId.isNotEmpty
        ? normalizedLocalJobId
        : (requestEntry?.linkedJobId.trim().isNotEmpty == true
              ? requestEntry!.linkedJobId.trim()
              : requestEntry?.jobId.trim() ?? '');
    if (resolvedJobId.isNotEmpty) {
      final existingJob = _jobsById[resolvedJobId];
      if (existingJob != null && !existingJob.archived) {
        _jobsById[resolvedJobId] = existingJob.copyWith(
          archived: true,
          updatedAt: DateTime.now(),
        );
        didArchive = true;
      }
    }

    if (!didArchive) {
      return false;
    }

    _syncRequestWatchers();
    notifyListeners();
    await saveToStorage();
    return true;
  }

  void setJobConfirmed(
    bool value, {
    String? jobId,
    String? requestStatus,
    String? status,
  }) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      final nextStatus =
          status ??
          (value
              ? (job.isCompletedJob ? 'completed' : 'confirmed')
              : job.status);
      final nextRequestStatus =
          requestStatus ?? (value ? 'confirmed' : job.requestStatus);
      final shouldMarkConfirmedAt =
          value && nextStatus.trim().toLowerCase() == 'confirmed';
      return job.copyWith(
        quoteAccepted: value ? true : job.quoteAccepted,
        quoteAcceptedAt: value
            ? (job.quoteAcceptedAt ?? DateTime.now())
            : job.quoteAcceptedAt,
        quoteDeclined: value ? false : job.quoteDeclined,
        quoteDeclinedAt: value ? null : job.quoteDeclinedAt,
        quoteStatus: value ? 'accepted' : job.quoteStatus,
        confirmedAt: shouldMarkConfirmedAt
            ? (job.confirmedAt ?? DateTime.now())
            : job.confirmedAt,
        status: nextStatus,
        requestStatus: nextRequestStatus,
        requestUpdatedAt: value ? DateTime.now() : job.requestUpdatedAt,
        calendarStatus: value ? 'scheduled' : job.calendarStatus,
      );
    });
  }

  void setQuoteAccepted({String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      final hasAcceptedProposedTime =
          job.proposedDate.trim().isNotEmpty &&
          job.proposedStartTime.trim().isNotEmpty;
      return job.copyWith(
        quoteAccepted: true,
        quoteAcceptedAt: job.quoteAcceptedAt ?? DateTime.now(),
        quoteDeclined: false,
        quoteDeclinedAt: null,
        quoteRespondedAt: job.quoteRespondedAt ?? DateTime.now(),
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteTimingChoice: hasAcceptedProposedTime
            ? 'accepted_proposed_time'
            : 'arrange_another_time',
        agreedDateTime: hasAcceptedProposedTime
            ? job.proposedScheduledAt
            : null,
        acceptedProposedDate: hasAcceptedProposedTime ? job.proposedDate : '',
        acceptedProposedStartTime: hasAcceptedProposedTime
            ? job.proposedStartTime
            : '',
        schedulingStatus: hasAcceptedProposedTime
            ? 'accepted_time'
            : 'awaiting_agreed_time',
        status: 'quoteAccepted',
        requestStatus: 'quote_accepted',
        requestUpdatedAt: DateTime.now(),
      );
    });
  }

  void setQuoteDeclined({
    String? jobId,
    String? declineReasonCode,
    String? declineReasonLabel,
    String? declineReasonText,
  }) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(
        quoteAccepted: false,
        quoteAcceptedAt: null,
        quoteDeclined: true,
        quoteDeclinedAt: job.quoteDeclinedAt ?? DateTime.now(),
        declineReasonCode: declineReasonCode ?? job.declineReasonCode,
        declineReasonLabel: declineReasonLabel ?? job.declineReasonLabel,
        declineReasonText: declineReasonText ?? job.declineReasonText,
        quoteRespondedAt: job.quoteRespondedAt ?? DateTime.now(),
        quoteStatus: 'declined',
        quoteResponseStatus: 'declined',
        quoteTimingChoice: 'declined',
        agreedDateTime: null,
        status: 'quoteDeclined',
        requestStatus: 'quote_declined',
        requestUpdatedAt: DateTime.now(),
      );
    });
  }

  void setJobCompleted(bool value, {DateTime? completedAt, String? jobId}) {
    final updated = _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(
        completedAt: value
            ? (completedAt ?? job.completedAt ?? DateTime.now())
            : job.completedAt,
        cancelledAt: value ? null : job.cancelledAt,
        status: value ? 'completed' : job.status,
        calendarStatus: value ? 'completed' : job.calendarStatus,
      );
    });
    if (value && updated != null) {
      unawaited(VanPickupReminderService.instance.cancel(updated.jobId));
    }
  }

  void setInvoiceCreated(bool value, {String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(updatedAt: DateTime.now());
    });
  }

  void setInvoiceSent(bool value, {String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(updatedAt: DateTime.now());
    });
  }

  void setExactPinDetails({
    VanExactPinSource? source,
    String? note,
    double? latitude,
    double? longitude,
    String? jobId,
  }) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(
        exactPinShareSource: source ?? job.exactPinShareSource,
        exactPinNote: note ?? job.exactPinNote,
        exactPinLatitude: latitude ?? job.exactPinLatitude,
        exactPinLongitude: longitude ?? job.exactPinLongitude,
        exactPinShared: source != null ? true : job.exactPinShared,
        exactPinSource: source == null ? job.exactPinSource : 'driver',
        status: job.isCompletedJob
            ? 'completed'
            : job.status == 'confirmed'
            ? 'confirmed'
            : job.status == 'quoteSent'
            ? 'quoteSent'
            : job.status == 'requestSent'
            ? 'requestSent'
            : job.status,
      );
    });
  }

  String _formatJobDate(DateTime date) {
    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatJobTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatScheduledDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, dynamic> _toJson() {
    final active = activeJob;
    return <String, dynamic>{
      'activeJobId': _activeJobId,
      'jobs': allJobs.map((job) => job.toJson()).toList(),
      'jobReady': active?.isConfirmed ?? false,
      'pinSavedToJob': active?.exactPinShared ?? false,
      'quoteSaved': active?.quoteAmount != null,
      'quoteSent': active?.isQuoteSent ?? false,
      'jobConfirmed': active?.isConfirmed ?? false,
      'jobCompleted': active?.isCompleted ?? false,
      'jobCompletedAt': active?.completedAt?.toIso8601String(),
      'invoiceCreated': _invoiceHistoryByJobKey.isNotEmpty,
      'invoiceSent': active?.isCompleted ?? false,
      'exactPinShareSource': vanExactPinSourceToStorage(
        active?.exactPinShareSource,
      ),
      'exactPinNote': active?.exactPinNote,
      'jobRequests': _jobRequestsById.values
          .map((request) => request.toJson())
          .toList(),
      'blockedCustomers': _blockedCustomersByPhone.values
          .map((record) => record.toJson())
          .toList(),
      'deletedLegacyRequestIds': _deletedRequestKeys.toList(growable: false),
      'invoiceHistory': _invoiceHistoryByJobKey.values
          .map((entry) => entry.toJson())
          .toList(),
    };
  }

  void _applyJson(Map<String, dynamic> json) {
    _activeJobId = json['activeJobId']?.toString();
    _jobsById.clear();
    _jobSourceById.clear();
    final jobsJson = json['jobs'];
    if (jobsJson is List) {
      for (final item in jobsJson) {
        if (item is Map) {
          final job = DriverCustomerReplyMockData.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (job.jobId.trim().isNotEmpty) {
            _jobsById[job.jobId] = job;
            _jobSourceById[job.jobId] = 'local_cache';
          }
        }
      }
    }

    _invoiceHistoryByJobKey.clear();
    final history = json['invoiceHistory'];
    if (history is List) {
      for (final item in history) {
        if (item is Map) {
          final entry = VanInvoiceHistoryEntry.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (entry.jobKey.trim().isNotEmpty) {
            _invoiceHistoryByJobKey[entry.jobKey] = entry;
          }
        }
      }
    }

    _jobRequestsById.clear();
    final requestsJson = json['jobRequests'];
    if (requestsJson is List) {
      for (final item in requestsJson) {
        if (item is Map) {
          final data = Map<String, dynamic>.from(item);
          final request = VanJobRequestRecord.fromJson(
            data,
            fallbackRequestId: data['requestId']?.toString() ?? '',
          );
          if (request.requestId.trim().isNotEmpty) {
            _jobRequestsById[request.requestId] = request;
          }
        }
      }
    }

    _blockedCustomersByPhone.clear();
    final blockedCustomersJson = json['blockedCustomers'];
    if (blockedCustomersJson is List) {
      for (final item in blockedCustomersJson) {
        if (item is Map) {
          final record = VanBlockedCustomerRecord.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (record.normalizedPhone.isNotEmpty) {
            _blockedCustomersByPhone[record.normalizedPhone] = record;
          }
        }
      }
    }

    final deletedLegacyJson = json['deletedLegacyRequestIds'];
    if (deletedLegacyJson is List) {
      for (final item in deletedLegacyJson) {
        final key = item?.toString().trim() ?? '';
        if (key.isNotEmpty) {
          _deletedRequestKeys.add(key);
        }
      }
    }
    debugPrint(
      '[IncomingRequestDelete] deleted keys merged count=${_deletedRequestKeys.length}',
    );

    _seedKnownCustomerUpdateAnnouncementsFromState();

    // Intentionally do not seed legacy/demo fallback jobs into runtime state.
    debugPrint('[IncomingRequests] mock/demo seeding ran=false');

    savedInvoice = savedInvoiceHistory.isEmpty
        ? null
        : savedInvoiceHistory.first.draft;
  }

  void _seedKnownCustomerUpdateAnnouncementsFromState() {
    for (final job in _jobsById.values) {
      if (job.hasCustomerReply) {
        _rememberAnnouncement(
          _announcedReplyJobIds,
          jobId: job.jobId,
          requestId: job.requestId,
        );
      }
      if (_hasExactPinSignal(job)) {
        _rememberExactPinAnnouncement(
          jobId: job.jobId,
          requestId: job.requestId,
          eventAt: _exactPinEventTimeForJob(job),
          stateToken: _exactPinStateTokenForJob(job),
        );
      }
      if (job.isQuoteAccepted) {
        _rememberAnnouncement(
          _announcedQuoteAcceptedJobIds,
          jobId: job.jobId,
          requestId: job.requestId,
        );
      }
      if (job.isQuoteDeclined) {
        _rememberAnnouncement(
          _announcedQuoteDeclinedJobIds,
          jobId: job.jobId,
          requestId: job.requestId,
        );
      }
    }

    for (final request in _jobRequestsById.values) {
      if (request.hasCustomerReply) {
        _rememberAnnouncement(
          _announcedReplyJobIds,
          jobId: request.jobId,
          requestId: request.requestId,
        );
      }
      if (request.hasExactPin) {
        _rememberExactPinAnnouncement(
          jobId: request.jobId,
          requestId: request.requestId,
          eventAt: _exactPinEventTimeForRequest(request),
          stateToken: _exactPinStateTokenForRequest(request),
        );
      }
    }
  }

  bool _hasExactPinSignal(DriverCustomerReplyMockData job) {
    return job.exactPinShared ||
        job.exactPinSaved ||
        job.exactPinLatitude != null ||
        job.exactPinLongitude != null;
  }

  DateTime? _exactPinEventTimeForJob(DriverCustomerReplyMockData job) {
    return job.replyReceivedAt ??
        job.requestUpdatedAt ??
        job.updatedAt ??
        job.requestSubmittedAt;
  }

  DateTime? _exactPinEventTimeForRequest(VanJobRequestRecord request) {
    return request.replyReceivedAt ??
        request.customerSubmittedAt ??
        request.updatedAt;
  }

  Iterable<String> _announcementKeys({
    required String jobId,
    String? requestId,
  }) sync* {
    final normalizedJobId = jobId.trim();
    if (normalizedJobId.isNotEmpty) {
      yield 'job:$normalizedJobId';
    }

    final normalizedRequestId = requestId?.trim() ?? '';
    if (normalizedRequestId.isNotEmpty) {
      yield 'request:$normalizedRequestId';
    }
  }

  void _rememberAnnouncement(
    Set<String> announcedIds, {
    required String jobId,
    String? requestId,
  }) {
    announcedIds.addAll(_announcementKeys(jobId: jobId, requestId: requestId));
  }

  void _rememberExactPinAnnouncement({
    required String jobId,
    String? requestId,
    DateTime? eventAt,
    String stateToken = '',
  }) {
    _rememberAnnouncement(
      _announcedExactPinJobIds,
      jobId: jobId,
      requestId: requestId,
    );
    _rememberObservedExactPinState(
      jobId: jobId,
      requestId: requestId,
      stateToken: stateToken,
    );
    if (stateToken.isNotEmpty) {
      for (final key in _announcementKeys(jobId: jobId, requestId: requestId)) {
        _announcedExactPinStateTokens[key] = stateToken;
      }
    }
    if (eventAt == null) {
      return;
    }
    for (final key in _announcementKeys(jobId: jobId, requestId: requestId)) {
      final previous = _announcedExactPinEventTimes[key];
      if (previous == null || eventAt.isAfter(previous)) {
        _announcedExactPinEventTimes[key] = eventAt;
      }
    }
  }

  bool _wasAnnouncementSeen(
    Set<String> announcedIds, {
    required String jobId,
    String? requestId,
  }) {
    return _announcementKeys(
      jobId: jobId,
      requestId: requestId,
    ).any(announcedIds.contains);
  }

  bool _wasExactPinAnnouncementSeen({
    required String jobId,
    String? requestId,
    DateTime? eventAt,
    String stateToken = '',
  }) {
    final keys = _announcementKeys(
      jobId: jobId,
      requestId: requestId,
    ).toList(growable: false);
    if (keys.isEmpty) {
      return true;
    }
    if (stateToken.isNotEmpty) {
      return keys.any(
        (key) => _announcedExactPinStateTokens[key] == stateToken,
      );
    }
    if (eventAt == null) {
      return keys.any(_announcedExactPinJobIds.contains);
    }
    for (final key in keys) {
      final previous = _announcedExactPinEventTimes[key];
      if (previous != null && !eventAt.isAfter(previous)) {
        return true;
      }
    }
    return false;
  }

  String _exactPinStateTokenForJob(DriverCustomerReplyMockData job) {
    return buildVanExactPinAnnouncementStateToken(
      hasExactPin: _hasExactPinSignal(job),
      exactPinLatitude: job.exactPinLatitude,
      exactPinLongitude: job.exactPinLongitude,
      exactPinSource: job.exactPinSource,
      exactPinNote: job.exactPinNote ?? '',
    );
  }

  String _exactPinStateTokenForRequest(VanJobRequestRecord request) {
    return buildVanExactPinAnnouncementStateToken(
      hasExactPin: request.hasExactPin,
      exactPinLatitude: request.exactPinLat ?? request.exactPinLatitude,
      exactPinLongitude: request.exactPinLng ?? request.exactPinLongitude,
      exactPinSource: request.exactPinSource,
      exactPinNote: request.exactPinNote,
    );
  }

  void _rememberObservedExactPinState({
    required String jobId,
    String? requestId,
    required String stateToken,
  }) {
    for (final key in _announcementKeys(jobId: jobId, requestId: requestId)) {
      _observedExactPinStateTokens[key] = stateToken;
    }
  }

  bool _shouldAnnounceExactPinStateChange({
    required String jobId,
    String? requestId,
    required String currentStateToken,
    required bool allowExactPinAnnouncement,
  }) {
    final keys = _announcementKeys(
      jobId: jobId,
      requestId: requestId,
    ).toList(growable: false);
    if (keys.isEmpty) {
      return false;
    }

    String? previousStateToken;
    var hasPreviousObservation = false;
    for (final key in keys) {
      if (_observedExactPinStateTokens.containsKey(key)) {
        previousStateToken = _observedExactPinStateTokens[key] ?? '';
        hasPreviousObservation = true;
        break;
      }
    }

    _rememberObservedExactPinState(
      jobId: jobId,
      requestId: requestId,
      stateToken: currentStateToken,
    );

    if (!allowExactPinAnnouncement ||
        !hasPreviousObservation ||
        currentStateToken.isEmpty) {
      return false;
    }

    return previousStateToken != currentStateToken;
  }

  bool _shouldAllowExactPinAnnouncementForJob(DriverCustomerReplyMockData job) {
    if (job.isHiddenFromNormalLists ||
        job.deleted ||
        job.archived ||
        job.isCompleted ||
        job.isCompletedJob ||
        job.isCancelled) {
      return false;
    }
    return true;
  }

  bool _shouldAllowExactPinAnnouncementForRequest(
    VanJobRequestRecord request, {
    DriverCustomerReplyMockData? linkedJob,
  }) {
    if (request.isHiddenFromNormalLists) {
      return false;
    }
    if (linkedJob == null) {
      return false;
    }
    return _shouldAllowExactPinAnnouncementForJob(linkedJob);
  }

  String? _maybeAnnounceNewCustomerUpdate({
    required String jobId,
    String? requestId,
    required bool previousHasReply,
    required bool currentHasReply,
    required bool previousHasExactPin,
    required bool currentHasExactPin,
    required bool previousQuoteAccepted,
    required bool currentQuoteAccepted,
    required bool previousQuoteDeclined,
    required bool currentQuoteDeclined,
    required String jobTitle,
    required String customerName,
    DateTime? exactPinEventAt,
    String exactPinStateToken = '',
    bool allowExactPinAnnouncement = true,
  }) {
    final displayJobTitle = jobTitle.trim().isNotEmpty
        ? jobTitle.trim()
        : 'this job';
    final displayCustomerName = customerName.trim().isNotEmpty
        ? customerName.trim()
        : displayJobTitle;

    if (currentQuoteAccepted &&
        !previousQuoteAccepted &&
        !_wasAnnouncementSeen(
          _announcedQuoteAcceptedJobIds,
          jobId: jobId,
          requestId: requestId,
        )) {
      _rememberAnnouncement(
        _announcedQuoteAcceptedJobIds,
        jobId: jobId,
        requestId: requestId,
      );
      return displayCustomerName == displayJobTitle
          ? 'Quote accepted'
          : 'Quote accepted from $displayCustomerName';
    }

    if (currentQuoteDeclined &&
        !previousQuoteDeclined &&
        !_wasAnnouncementSeen(
          _announcedQuoteDeclinedJobIds,
          jobId: jobId,
          requestId: requestId,
        )) {
      _rememberAnnouncement(
        _announcedQuoteDeclinedJobIds,
        jobId: jobId,
        requestId: requestId,
      );
      return displayCustomerName == displayJobTitle
          ? 'Quote declined'
          : 'Quote declined from $displayCustomerName';
    }

    if (currentHasExactPin &&
        _shouldAnnounceExactPinStateChange(
          jobId: jobId,
          requestId: requestId,
          currentStateToken: exactPinStateToken,
          allowExactPinAnnouncement: allowExactPinAnnouncement,
        ) &&
        !_wasExactPinAnnouncementSeen(
          jobId: jobId,
          requestId: requestId,
          eventAt: exactPinEventAt,
          stateToken: exactPinStateToken,
        )) {
      _rememberExactPinAnnouncement(
        jobId: jobId,
        requestId: requestId,
        eventAt: exactPinEventAt,
        stateToken: exactPinStateToken,
      );
      return customerName.trim().isNotEmpty
          ? 'Exact pin received for ${customerName.trim()}'
          : 'Exact pin received';
    }

    if (currentHasReply &&
        !previousHasReply &&
        !_wasAnnouncementSeen(
          _announcedReplyJobIds,
          jobId: jobId,
          requestId: requestId,
        )) {
      _rememberAnnouncement(
        _announcedReplyJobIds,
        jobId: jobId,
        requestId: requestId,
      );
      return 'Customer reply received for $displayJobTitle';
    }

    return null;
  }

  void _recordJobChangeNotification({
    required DriverCustomerReplyMockData previous,
    required DriverCustomerReplyMockData current,
  }) {
    if (!_shouldAllowExactPinAnnouncementForJob(current)) {
      return;
    }
    final previousHasPin = _hasExactPinSignal(previous);
    final currentHasPin = _hasExactPinSignal(current);
    final previousHasReply = previous.hasCustomerReply;
    final currentHasReply = current.hasCustomerReply;
    final previousQuoteAccepted = previous.isQuoteAccepted;
    final currentQuoteAccepted = current.isQuoteAccepted;

    final notificationMessage = _maybeAnnounceNewCustomerUpdate(
      jobId: current.jobId,
      requestId: current.requestId,
      previousHasReply: previousHasReply,
      currentHasReply: currentHasReply,
      previousHasExactPin: previousHasPin,
      currentHasExactPin: currentHasPin,
      previousQuoteAccepted: previousQuoteAccepted,
      currentQuoteAccepted: currentQuoteAccepted,
      previousQuoteDeclined: previous.quoteDeclined,
      currentQuoteDeclined: current.quoteDeclined,
      jobTitle: current.jobTitle,
      customerName: current.customerName,
      exactPinEventAt: _exactPinEventTimeForJob(current),
      exactPinStateToken: _exactPinStateTokenForJob(current),
      allowExactPinAnnouncement: _hasCompletedInitialCloudHydration,
    );
    _rememberObservedExactPinState(
      jobId: current.jobId,
      requestId: current.requestId,
      stateToken: _exactPinStateTokenForJob(current),
    );

    if (kDebugMode) {
      debugPrint(
        '[JobChangeDetect] jobId=${current.jobId} previousQuoteStatus=${previous.quoteStatus} currentQuoteStatus=${current.quoteStatus}',
      );
      debugPrint(
        '[JobChangeDetect] previousHasPin=$previousHasPin currentHasPin=$currentHasPin',
      );
      debugPrint(
        '[JobChangeDetect] notificationMessage=${notificationMessage ?? '(none)'}',
      );
    }

    if (notificationMessage != null && notificationMessage.isNotEmpty) {
      _recentRequestRefreshNotice = notificationMessage;
    }
  }

  void _mergeCloudJobs(
    List<DriverCustomerReplyMockData> cloudJobs, {
    required bool pruneMissing,
    required String sourceLabel,
  }) {
    final isPublicQuoteSource = sourceLabel == 'public_quote_responses';
    if (kDebugMode) {
      debugPrint(
        '[VanJobMerge] source=$sourceLabel pruneMissing=$pruneMissing returnedCount=${cloudJobs.length}',
      );
    }
    if (pruneMissing) {
      final cloudJobIds = cloudJobs
          .map((job) => job.jobId.trim())
          .where((jobId) => jobId.isNotEmpty)
          .toSet();
      _jobsById.removeWhere((jobId, _) => !cloudJobIds.contains(jobId.trim()));
      _jobSourceById.removeWhere(
        (jobId, _) => !cloudJobIds.contains(jobId.trim()),
      );
    }
    if (isPublicQuoteSource) {
      final fetchedPublicQuoteIds = cloudJobs
          .map((job) => job.jobId.trim())
          .where((jobId) => jobId.isNotEmpty)
          .toSet();
      final stalePublicQuoteOnlyIds = _jobSourceById.entries
          .where((entry) => entry.value == sourceLabel)
          .map((entry) => entry.key.trim())
          .where((jobId) => !fetchedPublicQuoteIds.contains(jobId))
          .toList(growable: false);
      for (final staleId in stalePublicQuoteOnlyIds) {
        _jobsById.remove(staleId);
        _jobSourceById.remove(staleId);
        if (kDebugMode) {
          debugPrint(
            '[VanJobMerge] source=$sourceLabel prunedStaleQuoteOnly jobId=$staleId',
          );
        }
      }
    }

    for (final cloudJob in cloudJobs) {
      if (_isDeletedCloudJobCandidate(cloudJob, sourceLabel: sourceLabel)) {
        _jobsById.remove(cloudJob.jobId);
        _jobSourceById.remove(cloudJob.jobId);
        final requestId = cloudJob.requestId?.trim() ?? '';
        if (requestId.isNotEmpty) {
          _jobRequestsById.remove(requestId);
        }
        if (kDebugMode) {
          debugPrint(
            '[VanJobMerge] source=$sourceLabel ignoredDeletedLocalMatch jobId=${cloudJob.jobId} requestId=${cloudJob.requestId ?? '(none)'}',
          );
        }
        continue;
      }
      if (cloudJob.isHiddenFromNormalLists) {
        _jobsById.remove(cloudJob.jobId);
        _jobSourceById.remove(cloudJob.jobId);
        continue;
      }

      final existing = _jobsById[cloudJob.jobId];
      if (isPublicQuoteSource &&
          existing == null &&
          !_cloudVanJobIds.contains(cloudJob.jobId)) {
        if (kDebugMode) {
          debugPrint(
            '[VanJobMerge] source=$sourceLabel ignoredQuoteOnly jobId=${cloudJob.jobId} requestId=${cloudJob.requestId ?? '(none)'} status=${cloudJob.status} requestStatus=${cloudJob.requestStatus}',
          );
        }
        continue;
      }
      if (existing == null) {
        _jobsById[cloudJob.jobId] = cloudJob;
        _jobSourceById[cloudJob.jobId] = sourceLabel;
        if (cloudJob.hasCustomerReply) {
          _rememberAnnouncement(
            _announcedReplyJobIds,
            jobId: cloudJob.jobId,
            requestId: cloudJob.requestId,
          );
        }
        if (_hasExactPinSignal(cloudJob)) {
          _rememberExactPinAnnouncement(
            jobId: cloudJob.jobId,
            requestId: cloudJob.requestId,
            eventAt: _exactPinEventTimeForJob(cloudJob),
            stateToken: _exactPinStateTokenForJob(cloudJob),
          );
        } else {
          _rememberObservedExactPinState(
            jobId: cloudJob.jobId,
            requestId: cloudJob.requestId,
            stateToken: '',
          );
        }
        if (cloudJob.isQuoteAccepted) {
          _rememberAnnouncement(
            _announcedQuoteAcceptedJobIds,
            jobId: cloudJob.jobId,
            requestId: cloudJob.requestId,
          );
        }
        continue;
      }

      if (existing.isHiddenFromNormalLists &&
          !cloudJob.isHiddenFromNormalLists) {
        continue;
      }

      final mergedCloudJob = preserveQuoteWorkflowState(
        existing,
        cloudJob,
        candidateIsAuthoritativeQuoteSource: isPublicQuoteSource,
      );
      final existingUpdated =
          existing.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cloudUpdated =
          cloudJob.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final scheduledDowngradeFromQuoteSource =
          isPublicQuoteSource &&
          existing.isScheduledInCalendarState &&
          !cloudJob.isScheduledInCalendarState;
      if (scheduledDowngradeFromQuoteSource) {
        if (kDebugMode) {
          debugPrint(
            '[VanJobMerge] source=$sourceLabel preservedScheduledJob jobId=${existing.jobId} '
            'existingStatus=${existing.status} existingCalendarStatus=${existing.calendarStatus} '
            'incomingStatus=${cloudJob.status} incomingCalendarStatus=${cloudJob.calendarStatus}',
          );
        }
        continue;
      }
      final existingQuoteEventAt =
          existing.quoteRespondedAt ??
          existing.quoteAcceptedAt ??
          existing.quoteDeclinedAt ??
          existing.quoteSentAt ??
          existing.quoteSavedAt ??
          existingUpdated;
      final cloudQuoteEventAt =
          cloudJob.quoteRespondedAt ??
          cloudJob.quoteAcceptedAt ??
          cloudJob.quoteDeclinedAt ??
          cloudJob.quoteSentAt ??
          cloudJob.quoteSavedAt ??
          cloudUpdated;
      final sameAuthoritativeQuote =
          existing.authoritativeCurrentQuoteId.isNotEmpty &&
          cloudJob.authoritativeCurrentQuoteId ==
              existing.authoritativeCurrentQuoteId;
      final existingCurrentQuoteIsIncomplete =
          existing.hasQuote &&
          (existing.quoteSentAt == null || existing.quoteAmount == null);
      final shouldApplyAuthoritativeQuote =
          isPublicQuoteSource &&
          cloudJob.hasQuote &&
          (!existing.hasQuote ||
              (sameAuthoritativeQuote &&
                  (existingCurrentQuoteIsIncomplete ||
                      !cloudQuoteEventAt.isBefore(existingQuoteEventAt))) ||
              (!sameAuthoritativeQuote &&
                  cloudQuoteEventAt.isAfter(existingQuoteEventAt)));
      if (shouldApplyAuthoritativeQuote ||
          cloudUpdated.isAfter(existingUpdated) ||
          (mergedCloudJob.isHiddenFromNormalLists &&
              existing.isHiddenFromNormalLists)) {
        _recordJobChangeNotification(
          previous: existing,
          current: mergedCloudJob,
        );
        _jobsById[cloudJob.jobId] = mergedCloudJob;
        if (!isPublicQuoteSource) {
          _jobSourceById[cloudJob.jobId] = sourceLabel;
        }
      }
    }

    if (_activeJobId != null && !_jobsById.containsKey(_activeJobId)) {
      _activeJobId = null;
    }
    _activeJobId ??= jobs.isNotEmpty ? jobs.first.jobId : null;
    savedInvoice = savedInvoiceHistory.isEmpty
        ? null
        : savedInvoiceHistory.first.draft;
  }

  void _mergeCloudInvoices(List<VanInvoiceHistoryEntry> cloudInvoices) {
    for (final entry in cloudInvoices) {
      final existing = _invoiceHistoryByJobKey[entry.jobKey];
      if (existing == null || entry.savedAt.isAfter(existing.savedAt)) {
        _invoiceHistoryByJobKey[entry.jobKey] = entry;
      }
    }
  }

  void _mergeCloudRequests(
    List<VanJobRequestRecord> cloudRequests, {
    Map<String, VanJobRequestRecord>? previousRequestsById,
  }) {
    for (final request in cloudRequests) {
      if (kDebugMode) {
        final normalizedRequestStatus = normalizeVanJobRequestStatus(
          request.status,
        );
        final rawRequestStatus = request.status.trim().toLowerCase();
        final requestReady =
            normalizedRequestStatus == 'confirmed' ||
            normalizedRequestStatus == 'accepted' ||
            rawRequestStatus == 'accepted';
        final requestBucket = request.isHiddenFromNormalLists
            ? 'hidden_deleted_or_archived'
            : requestReady
            ? 'bookedJob'
            : 'pendingCustomerRequest';
        debugPrint(
          '[VanRequestsRefresh] requestId=${request.requestId} source=van_job_requests jobId=${request.jobId} linkedJobId=${request.linkedJobId} status=${request.status} requestStatus=$normalizedRequestStatus quoteStatus=(n/a) quoteAccepted=(n/a) ready=$requestReady jobReady=$requestReady hasReply=${request.hasCustomerReply || request.isSubmitted} hasPin=${request.hasExactPin} finalBucket=$requestBucket preferredDate=${request.preferredDate?.toIso8601String() ?? '(none)'} preferredTimeWindow=${request.preferredTimeWindow.isEmpty ? '(none)' : request.preferredTimeWindow} preferredIsFlexible=${request.preferredIsFlexible} preferredTimingNote=${request.preferredTimingNote.isEmpty ? '(none)' : request.preferredTimingNote}',
        );
      }
      final existing = _jobRequestsById[request.requestId];
      final resolvedLinkedJobId = request.linkedJobId.trim().isNotEmpty
          ? request.linkedJobId.trim()
          : request.jobId.trim();
      final linkedJob = _jobsById[resolvedLinkedJobId];
      final existingUpdated =
          existing?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (_isDeletedCloudRequestCandidate(request, linkedJob: linkedJob)) {
        _jobRequestsById.remove(request.requestId);
        if (linkedJob != null) {
          _jobsById.remove(resolvedLinkedJobId);
          _jobSourceById.remove(resolvedLinkedJobId);
        }
        if (kDebugMode) {
          debugPrint(
            '[VanRequestsRefresh] ignoredDeletedLocalMatch requestId=${request.requestId} jobId=$resolvedLinkedJobId',
          );
        }
        continue;
      }

      if (existing != null &&
          existing.isHiddenFromNormalLists &&
          !request.isHiddenFromNormalLists) {
        continue;
      }

      if (request.isHiddenFromNormalLists) {
        _jobRequestsById.remove(request.requestId);
        if (linkedJob != null) {
          _jobsById.remove(request.jobId);
          _jobSourceById.remove(request.jobId);
        }
        continue;
      }

      if (existing == null || request.updatedAt.isAfter(existingUpdated)) {
        _jobRequestsById[request.requestId] = request;
      }

      final previous = previousRequestsById?[request.requestId];
      final previousHasReply = previous?.hasCustomerReply ?? false;
      final previousHasExactPin = previous?.hasExactPin ?? false;
      if (previous == null) {
        if (request.hasCustomerReply) {
          _rememberAnnouncement(
            _announcedReplyJobIds,
            jobId: request.jobId,
            requestId: request.requestId,
          );
        }
        if (request.hasExactPin) {
          _rememberExactPinAnnouncement(
            jobId: request.jobId,
            requestId: request.requestId,
            eventAt: _exactPinEventTimeForRequest(request),
            stateToken: _exactPinStateTokenForRequest(request),
          );
        } else {
          _rememberObservedExactPinState(
            jobId: request.jobId,
            requestId: request.requestId,
            stateToken: '',
          );
        }
      } else {
        final notificationMessage = _maybeAnnounceNewCustomerUpdate(
          jobId: request.jobId,
          requestId: request.requestId,
          previousHasReply: previousHasReply,
          currentHasReply: request.hasCustomerReply,
          previousHasExactPin: previousHasExactPin,
          currentHasExactPin: request.hasExactPin,
          previousQuoteAccepted: false,
          currentQuoteAccepted: false,
          previousQuoteDeclined: false,
          currentQuoteDeclined: false,
          jobTitle: request.publicJobTitle,
          customerName: resolveExactPinAnnouncementCustomerName(
            requestCustomerName: request.publicCustomerName,
            linkedJobCustomerName: linkedJob?.customerName ?? '',
            existingCustomerName: existing?.publicCustomerName ?? '',
          ),
          exactPinEventAt: _exactPinEventTimeForRequest(request),
          exactPinStateToken: _exactPinStateTokenForRequest(request),
          allowExactPinAnnouncement:
              _hasCompletedInitialCloudHydration &&
              _shouldAllowExactPinAnnouncementForRequest(
                request,
                linkedJob: linkedJob,
              ),
        );
        _rememberObservedExactPinState(
          jobId: request.jobId,
          requestId: request.requestId,
          stateToken: _exactPinStateTokenForRequest(request),
        );
        if (notificationMessage != null && notificationMessage.isNotEmpty) {
          _recentRequestRefreshNotice = notificationMessage;
        }
      }

      final requestReply = _replyFromRequestRecord(
        request,
        existing: linkedJob,
      );
      if (linkedJob == null) {
        if (resolvedLinkedJobId.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[VanJobRequestSync] request ignored without job id requestId=${request.requestId}',
            );
          }
          continue;
        }
        _jobsById[resolvedLinkedJobId] = requestReply.copyWith(
          jobId: resolvedLinkedJobId,
        );
        _jobSourceById[resolvedLinkedJobId] = 'van_job_requests';
        _cloudVanJobIds.add(resolvedLinkedJobId);
        if (kDebugMode) {
          debugPrint(
            '[VanJobRequestSync] request-only job created requestId=${request.requestId} jobId=$resolvedLinkedJobId source=public_job_requests/private_request_mirror',
          );
        }
        continue;
      }
      if (linkedJob.isHiddenFromNormalLists) {
        continue;
      }
      if (linkedJob.isConfirmed || linkedJob.isCompletedJob) {
        if (kDebugMode) {
          debugPrint(
            '[VanRequestsRefresh] preserved final jobId=${linkedJob.jobId} requestId=${request.requestId} jobStatus=${linkedJob.status} requestStatus=${request.status}',
          );
        }
        continue;
      }
      final requestWouldDowngradeAcceptedQuote =
          linkedJob.isQuoteAccepted &&
          !requestReply.isQuoteAccepted &&
          !requestReply.isQuoteDeclined;
      if (requestWouldDowngradeAcceptedQuote) {
        if (kDebugMode) {
          debugPrint(
            '[VanRequestsRefresh] preserved accepted quote jobId=${linkedJob.jobId} requestId=${request.requestId} '
            'existingStatus=${linkedJob.status} existingRequestStatus=${linkedJob.requestStatus} '
            'incomingRequestStatus=${request.status} incomingSchedulingStatus=${request.schedulingStatus}',
          );
        }
        continue;
      }
      final shouldApply =
          request.isSubmitted ||
          request.hasCustomerReply ||
          linkedJob.status == 'requestSent' ||
          linkedJob.status == 'draft';
      if (!shouldApply) {
        continue;
      }

      _jobsById[resolvedLinkedJobId] = requestReply.copyWith(
        jobId: resolvedLinkedJobId,
      );
      _jobSourceById[resolvedLinkedJobId] = 'van_job_requests';
      if (kDebugMode) {
        debugPrint(
          '[VanRequestsRefresh] merged reply into jobId=$resolvedLinkedJobId',
        );
      }
    }

    if (kDebugMode && !_loggedReplyDebugSample) {
      final sample =
          _jobsById.values
              .where((job) => job.hasCustomerReply || job.isRequestSubmitted)
              .toList(growable: false)
            ..sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
      final job = sample.isNotEmpty ? sample.first : null;
      if (job != null) {
        _loggedReplyDebugSample = true;
        final pinReady =
            job.exactPinLatitude != null && job.exactPinLongitude != null;
        debugPrint(
          '[VanReplyDebug] jobId=${job.jobId} requestStatus=${job.requestStatus} hasReply=${job.hasCustomerReply} replyReceivedAt=${job.replyReceivedAt?.toIso8601String() ?? '(none)'} checklistResponses length=${job.checklistResponses.length} customQuestionResponses length=${job.customQuestionResponses.length} exactPinLatitude=${job.exactPinLatitude?.toString() ?? '(none)'} exactPinLongitude=${job.exactPinLongitude?.toString() ?? '(none)'} exactPinPresent=$pinReady',
        );
      }
    }
  }

  bool _shouldWatchRequestRecord(VanJobRequestRecord request) {
    if (request.isHiddenFromNormalLists) {
      return false;
    }

    String currentUid;
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    } catch (_) {
      return false;
    }
    if (currentUid.isEmpty) {
      return false;
    }
    final ownerUid = request.ownerUid.trim();
    if (ownerUid.isEmpty || ownerUid != currentUid) {
      return false;
    }

    return normalizeVanJobRequestStatus(request.status) == 'request_sent';
  }

  void _syncRequestWatchers() {
    final callId = ++_syncRequestWatchersCallCount;
    final desiredRequestIds = _jobRequestsById.values
        .where(_shouldWatchRequestRecord)
        .map((request) => request.requestId.trim())
        .where((requestId) => requestId.isNotEmpty)
        .toSet();

    final existingRequestIds = _requestWatchSubscriptions.keys.toSet();
    debugPrint(
      '[DriverStateWatchSync] call=$callId desired=${desiredRequestIds.length} '
      'existing=${existingRequestIds.length} add=${desiredRequestIds.difference(existingRequestIds).length} '
      'remove=${existingRequestIds.difference(desiredRequestIds).length}',
    );
    for (final requestId in existingRequestIds.difference(desiredRequestIds)) {
      final subscription = _requestWatchSubscriptions.remove(requestId);
      if (subscription != null) {
        debugPrint(
          '[DriverStateWatchSync] call=$callId cancel requestId=$requestId',
        );
        unawaited(subscription.cancel());
      }
    }

    for (final requestId in desiredRequestIds.difference(existingRequestIds)) {
      _watchRequest(requestId);
    }
  }

  void _cancelAllRequestWatchers() {
    final subscriptions = _requestWatchSubscriptions.values.toList(
      growable: false,
    );
    _requestWatchSubscriptions.clear();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  void _watchRequest(String requestId) {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty ||
        _requestWatchSubscriptions.containsKey(normalizedRequestId)) {
      return;
    }

    debugPrint(
      '[DriverStateWatch] subscribe requestId=$normalizedRequestId '
      'beforeCount=${_requestWatchSubscriptions.length}',
    );
    final subscription = VanJobRequestCloudService.instance
        .watchRequestById(
          normalizedRequestId,
          debugOrigin: 'driver_state_watch',
        )
        .listen(
          (request) {
            if (request == null) {
              debugPrint(
                '[DriverStateWatch] nullEvent requestId=$normalizedRequestId',
              );
              return;
            }
            debugPrint(
              '[DriverStateWatch] event requestId=$normalizedRequestId '
              'status=${request.status} hasReply=${request.hasCustomerReply} '
              'hasExactPin=${request.hasExactPin}',
            );
            unawaited(_applyWatchedRequestUpdate(request));
          },
          onError: (error, stackTrace) {
            debugPrint(
              '[DriverStateWatch] error requestId=$normalizedRequestId error=$error',
            );
            debugPrintStack(stackTrace: stackTrace);
          },
        );
    _requestWatchSubscriptions[normalizedRequestId] = subscription;
    debugPrint(
      '[DriverStateWatch] subscribed requestId=$normalizedRequestId '
      'afterCount=${_requestWatchSubscriptions.length}',
    );
  }

  Future<void> _applyWatchedRequestUpdate(VanJobRequestRecord request) async {
    final normalizedRequestId = request.requestId.trim();
    if (normalizedRequestId.isEmpty) {
      return;
    }

    final updateCount = ++_watchedRequestUpdateCount;
    final hasExactPin = request.hasExactPin;
    debugPrint(
      '[VanJobRequestWatch] update=$updateCount requestId=$normalizedRequestId '
      'ownerUid=${request.ownerUid} jobId=${request.jobId} status=${request.status} '
      'hasReply=${request.hasCustomerReply} exactPin=$hasExactPin '
      'checklistResponses=${request.checklistResponses.length} '
      'customQuestionResponses=${request.customQuestionResponses.length} '
      'watchers=${_requestWatchSubscriptions.length}',
    );

    final previous = _jobRequestsById[normalizedRequestId];
    final linkedJobId = request.linkedJobId.trim().isNotEmpty
        ? request.linkedJobId.trim()
        : request.jobId.trim();
    final linkedJob = _jobsById[linkedJobId];
    if (_isDeletedCloudRequestCandidate(
      request,
      linkedJob: linkedJob,
      logSource: 'watch:van_job_requests',
    )) {
      _jobRequestsById.remove(normalizedRequestId);
      if (linkedJob != null) {
        _jobsById.remove(linkedJobId);
        _jobSourceById.remove(linkedJobId);
      }
      _syncRequestWatchers();
      await saveToStorage(syncCloud: false);
      notifyListeners();
      return;
    }

    final isInitialWatcherEvent = _initializedWatchedRequestIds.add(
      normalizedRequestId,
    );
    if (isInitialWatcherEvent) {
      if (request.hasCustomerReply) {
        _rememberAnnouncement(
          _announcedReplyJobIds,
          jobId: request.jobId,
          requestId: request.requestId,
        );
      }
      if (request.hasExactPin) {
        _rememberExactPinAnnouncement(
          jobId: request.jobId,
          requestId: request.requestId,
          eventAt: _exactPinEventTimeForRequest(request),
          stateToken: _exactPinStateTokenForRequest(request),
        );
      } else {
        _rememberObservedExactPinState(
          jobId: request.jobId,
          requestId: request.requestId,
          stateToken: '',
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[VanJobRequestWatch] baseline requestId=$normalizedRequestId '
          'hasReply=${request.hasCustomerReply} hasExactPin=${request.hasExactPin}',
        );
      }
    }
    _mergeCloudRequests(
      <VanJobRequestRecord>[request],
      previousRequestsById: isInitialWatcherEvent
          ? <String, VanJobRequestRecord>{normalizedRequestId: request}
          : previous == null
          ? null
          : <String, VanJobRequestRecord>{normalizedRequestId: previous},
    );
    _syncRequestWatchers();
    await saveToStorage(syncCloud: false);
    notifyListeners();
  }

  VanJobRequestRecord? _requestForJobRaw(String jobId) {
    final normalizedJobId = jobId.trim();
    if (normalizedJobId.isEmpty) {
      return null;
    }

    final job = _jobsById[normalizedJobId];
    if (job == null || job.isHiddenFromNormalLists) {
      return null;
    }
    final requestId = job.requestId?.trim() ?? '';
    if (requestId.isNotEmpty) {
      final request = _jobRequestsById[requestId];
      if (request != null && !request.isHiddenFromNormalLists) {
        return request;
      }
    }

    final candidates = _jobRequestsById.values
        .where(
          (request) =>
              request.jobId.trim() == normalizedJobId ||
              request.linkedJobId.trim() == normalizedJobId,
        )
        .where((request) => !request.isHiddenFromNormalLists)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return candidates.first;
  }

  VanJobRequestRecord? _requestForJob(String jobId) {
    final request = _requestForJobRaw(jobId);
    if (request == null || request.isHiddenFromNormalLists) {
      return null;
    }

    final job = _jobsById[jobId.trim()];
    if (job != null && isLegacyDeleteFiltered(job, request: request)) {
      return null;
    }
    return request;
  }

  Future<bool> _saveJobDocToCloud(
    DriverCustomerReplyMockData job, {
    required String source,
  }) async {
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: source,
    );
    final normalizedOwnerUid = ownerUid?.trim() ?? '';
    final checklistKeys = job.checklistResponses
        .map((response) => response.question.trim())
        .where((question) => question.isNotEmpty)
        .join(', ');
    final customKeys = job.customQuestionResponses
        .map((response) => response.question.trim())
        .where((question) => question.isNotEmpty)
        .join(', ');

    debugPrint(
      '[VanJobRequestSync] job doc sync start source=$source ownerUid=${normalizedOwnerUid.isEmpty ? '(none)' : normalizedOwnerUid} jobId=${job.jobId} requestId=${job.requestId?.trim().isNotEmpty == true ? job.requestId : '(none)'} requestStatus=${job.requestStatus} checklistResponses keys=${checklistKeys.isEmpty ? '(none)' : checklistKeys} customQuestionResponses keys=${customKeys.isEmpty ? '(none)' : customKeys} exactPinShared=${job.exactPinShared}',
    );
    debugPrint(
      '[PhoneSave] jobId=${job.jobId} customerPhone=${sanitizeVanCustomerPhoneNumber(job.phoneNumber)}',
    );

    if (normalizedOwnerUid.isEmpty) {
      debugPrint(
        '[VanJobRequestSync] job doc sync skipped source=$source jobId=${job.jobId} reason=no_owner_uid',
      );
      return false;
    }

    try {
      await VanJobsCloudService.instance.saveJob(
        ownerUid: normalizedOwnerUid,
        job: job,
        source: source,
      );
      debugPrint(
        '[VanJobRequestSync] job doc sync success source=$source ownerUid=$normalizedOwnerUid jobId=${job.jobId} requestId=${job.requestId?.trim().isNotEmpty == true ? job.requestId : '(none)'}',
      );
      return true;
    } catch (error) {
      debugPrint(
        '[VanJobRequestSync] job doc sync failed source=$source ownerUid=$normalizedOwnerUid jobId=${job.jobId} error=$error',
      );
      return false;
    }
  }

  VanJobRequestRecord _requestRecordFromJob(
    DriverCustomerReplyMockData job, {
    required String ownerUid,
    required String requestId,
    required String requestStatus,
    required DateTime? submittedAt,
    required DateTime? customerSubmittedAt,
    required List<VanJobRequestChecklistResponse> checklistResponses,
    required List<VanJobRequestCustomQuestionResponse> customQuestionResponses,
    required String additionalNotes,
    required String exactPinSource,
    required String exactPinNote,
    required double? exactPinLat,
    required double? exactPinLng,
  }) {
    final now = job.updatedAt ?? DateTime.now();
    return VanJobRequestRecord(
      requestId: requestId,
      ownerUid: ownerUid,
      jobId: job.jobId,
      linkedJobId: job.jobId,
      shortCode: extractVanJobRequestShortCodeFromLink(job.requestLink),
      status: _requestRecordStatusForJob(job),
      createdAt: job.requestCreatedAt ?? job.createdAt ?? now,
      updatedAt: job.requestUpdatedAt ?? now,
      expiresAt: job.requestExpiresAt ?? now.add(vanJobRequestDefaultExpiry),
      scheduledAt: job.scheduledAtOrParsed,
      jobDateLabel: job.jobDateLabel,
      jobTimeLabel: job.jobTimeLabel,
      scheduledDate: job.scheduledDate,
      scheduledStartTime: job.scheduledStartTime,
      estimatedDurationMinutes: job.estimatedDurationMinutes,
      calendarStatus: job.calendarStatus,
      quoteTimingChoice: job.quoteTimingChoice,
      agreedDateTime: job.agreedDateTime,
      agreedStartAt: job.agreedDateTime,
      agreedEndAt: _addDurationToDateTime(
        job.agreedDateTime,
        job.estimatedDurationMinutes,
      ),
      agreedDurationMinutes: job.estimatedDurationMinutes,
      acceptedProposedTime: job.acceptedProposedScheduledAt != null,
      timeAgreed: job.hasAgreedSchedulingTime,
      readyForCalendar:
          job.isQuoteAccepted &&
          job.hasAgreedSchedulingTime &&
          !job.isAwaitingRequiredExactPin &&
          !job.isScheduledInCalendarState,
      needsAgreedTime: job.isQuoteAccepted && !job.hasAgreedSchedulingTime,
      timeStatus: job.hasAgreedSchedulingTime
          ? (job.isAwaitingRequiredExactPin
                ? 'time_agreed'
                : 'ready_for_calendar')
          : 'needs_agreed_time',
      timingStatus: job.hasAgreedSchedulingTime
          ? (job.isAwaitingRequiredExactPin
                ? 'time_agreed'
                : 'ready_for_calendar')
          : 'needs_agreed_time',
      schedulingStatus: job.schedulingStatus,
      declineReasonCode: job.declineReasonCode,
      declineReasonLabel: job.declineReasonLabel,
      declineReasonText: job.declineReasonText,
      declinedAt: job.quoteDeclinedAt,
      declinedBy: job.quoteDeclined ? 'customer' : '',
      publicJobTitle: job.jobTitle,
      publicCustomerName: job.customerName,
      publicAddressSummary: job.address,
      publicPhoneNumber: sanitizeVanCustomerPhoneNumber(job.phoneNumber),
      publicCustomerEmail: job.customerEmail,
      customerPostcode: job.postcode,
      checklistItems: job.checklistItems,
      customQuestions: job.customQuestions,
      source: 'new_job',
      sourceLabel: 'New Job',
      exactPinRequested: job.requestExactPin,
      requestPhotos: job.requestPhotos,
      requiresExactPinAfterQuoteAccepted:
          job.requiresExactPinAfterQuoteAccepted,
      requestType: job.requestType,
      customerJourneyType: job.customerJourneyType,
      fulfilmentType: job.fulfilmentType,
      dropOffDate: job.dropOffDate,
      dropOffTime: job.dropOffTime,
      pickUpDate: job.pickUpDate,
      pickUpTime: job.pickUpTime,
      driverMessagePreview: job.notesMessage,
      submittedAt: submittedAt,
      customerSubmittedAt: customerSubmittedAt,
      requestSubmittedAt: submittedAt,
      replyReceivedAt: customerSubmittedAt,
      preferredDate: job.preferredDate,
      preferredTimeWindow: job.preferredTimeWindow,
      preferredIsFlexible: job.preferredIsFlexible,
      preferredTimingNote: job.preferredTimingNote,
      preferredTimingDecision: job.preferredTimingDecision,
      suggestedDate: job.suggestedDate,
      suggestedTimeWindow: job.suggestedTimeWindow,
      checklistResponses: checklistResponses,
      customQuestionResponses: customQuestionResponses,
      additionalNotes: additionalNotes,
      exactPinLat: exactPinLat,
      exactPinLng: exactPinLng,
      exactPinSource: exactPinSource,
      exactPinNote: exactPinNote,
      isTestData: job.isTestData,
      testMode: job.testMode,
      deleted: job.deleted,
      archived: job.archived,
    );
  }

  DriverCustomerReplyMockData _replyFromRequestRecord(
    VanJobRequestRecord request, {
    DriverCustomerReplyMockData? existing,
  }) {
    final checklistResponses = request.checklistResponses
        .map(
          (response) => DriverChecklistResponse(
            question: response.question,
            answer: response.answer,
            note: response.note,
          ),
        )
        .toList(growable: false);
    final customResponses = request.customQuestionResponses.isNotEmpty
        ? request.customQuestionResponses
              .map(
                (response) => DriverCustomQuestionResponse(
                  question: response.question,
                  answer: response.answer,
                ),
              )
              .toList(growable: false)
        : request.answers
              .where((item) => item.hasAnswer)
              .map(
                (answer) => DriverCustomQuestionResponse(
                  question: answer.questionText.trim().isEmpty
                      ? 'Question'
                      : answer.questionText.trim(),
                  answer: answer.answerValue.trim(),
                ),
              )
              .toList(growable: false);

    final hasReply = request.hasCustomerReply;
    final normalizedRequestStatus = normalizeVanJobRequestStatus(
      request.status,
    );
    final rawRequestStatus = request.status.trim().toLowerCase();
    final requestImpliesQuoteAccepted =
        normalizedRequestStatus == 'quote_accepted' ||
        request.acceptedProposedTime ||
        request.timeAgreed ||
        request.readyForCalendar ||
        request.quoteTimingChoice.trim().toLowerCase() ==
            'accepted_proposed_time' ||
        request.schedulingStatus.trim().toLowerCase() == 'accepted_time' ||
        request.schedulingStatus.trim().toLowerCase() == 'time_agreed' ||
        request.schedulingStatus.trim().toLowerCase() == 'ready_for_calendar' ||
        request.hasAgreedSchedulingTime;
    final requestImpliesQuoteDeclined =
        normalizedRequestStatus == 'quote_declined' ||
        request.quoteTimingChoice.trim().toLowerCase() == 'declined';
    final existingIsCompleted =
        existing?.isCompletedJob == true ||
        existing?.completedAt != null ||
        request.calendarStatus.trim().toLowerCase() == 'completed' ||
        normalizedRequestStatus == 'completed';
    final existingIsFinalBooked =
        !existingIsCompleted && (existing?.isConfirmed ?? false);
    final isCancelled =
        existing?.isCancelled == true ||
        normalizedRequestStatus == 'cancelled' ||
        rawRequestStatus == 'cancelled';
    final status = isCancelled
        ? 'cancelled'
        : existingIsCompleted
        ? 'completed'
        : hasReply
        ? (existingIsFinalBooked
              ? 'confirmed'
              : requestImpliesQuoteDeclined
              ? 'quoteDeclined'
              : requestImpliesQuoteAccepted
              ? 'quoteAccepted'
              : existing?.isQuoteDeclined == true
              ? 'quoteDeclined'
              : existing?.isQuoteAccepted == true
              ? 'quoteAccepted'
              : existing?.status == 'confirmed'
              ? 'confirmed'
              : existing?.status == 'quoteSent'
              ? 'quoteSent'
              : 'replyReceived')
        : (existing?.status ?? 'requestSent');

    final requestPhone = sanitizeVanCustomerPhoneNumber(
      request.publicPhoneNumber,
    );
    final mergedPhone = requestPhone.isNotEmpty
        ? requestPhone
        : sanitizeVanCustomerPhoneNumber(existing?.phoneNumber ?? '');

    return (existing ??
            DriverCustomerReplyMockData(
              jobId: request.jobId,
              customerName: request.publicCustomerName,
              jobTitle: request.publicJobTitle,
              scheduledAt: request.scheduledAt,
              jobDateLabel: request.jobDateLabel,
              jobTimeLabel: request.jobTimeLabel,
              address: request.publicAddressSummary,
              phoneNumber: mergedPhone,
              customerEmail: request.publicCustomerEmail,
              postcode: request.customerPostcode,
              requestExactPin: request.exactPinRequested,
              requestPhotos: request.requestPhotos,
              requiresExactPinAfterQuoteAccepted:
                  request.requiresExactPinAfterQuoteAccepted,
              requestType: request.requestType,
              customerJourneyType: request.customerJourneyType,
              startHandover: request.startHandover,
              endHandover: request.endHandover,
              allowedStartHandoverOptions: request.allowedStartHandoverOptions,
              allowedEndHandoverOptions: request.allowedEndHandoverOptions,
              collectionAddress: request.collectionAddress,
              returnAddress: request.returnAddress,
              returnAddressSameAsCollection:
                  request.returnAddressSameAsCollection,
              businessDropOffInstructions: request.businessDropOffInstructions,
              businessCollectionInstructions:
                  request.businessCollectionInstructions,
              fulfilmentType: request.fulfilmentType,
              dropOffDate: request.dropOffDate,
              dropOffTime: request.dropOffTime,
              pickUpDate: request.pickUpDate,
              pickUpTime: request.pickUpTime,
              checklistItems: request.checklistItems,
              customQuestions: request.customQuestions,
              status: status,
              createdAt: request.createdAt,
              updatedAt: request.updatedAt,
              cancelledAt: isCancelled
                  ? (existing?.cancelledAt ?? request.updatedAt)
                  : existing?.cancelledAt,
              exactPinShared: request.hasExactPin,
              checklistResponses: checklistResponses,
              customQuestionResponses: customResponses,
              additionalNotes: request.additionalNotes,
              hasReply: hasReply,
              hasExactPin: request.hasExactPin,
              exactPinShareSource: vanExactPinSourceFromStorage(
                request.exactPinSource,
              ),
              exactPinNote: request.exactPinNote,
              exactPinLatitude: request.exactPinLat,
              exactPinLongitude: request.exactPinLng,
              requestId: request.requestId,
              requestStatus: normalizedRequestStatus,
              quoteStatus: requestImpliesQuoteAccepted
                  ? 'accepted'
                  : requestImpliesQuoteDeclined
                  ? 'declined'
                  : (existing?.quoteStatus ?? ''),
              quoteAccepted: requestImpliesQuoteAccepted,
              quoteDeclined: requestImpliesQuoteDeclined,
              quoteResponseStatus: requestImpliesQuoteAccepted
                  ? 'accepted'
                  : requestImpliesQuoteDeclined
                  ? 'declined'
                  : (existing?.quoteResponseStatus ?? ''),
              quoteAcceptedAt: requestImpliesQuoteAccepted
                  ? (existing?.quoteAcceptedAt ?? request.updatedAt)
                  : existing?.quoteAcceptedAt,
              quoteDeclinedAt: requestImpliesQuoteDeclined
                  ? (existing?.quoteDeclinedAt ?? request.updatedAt)
                  : existing?.quoteDeclinedAt,
              declineReasonCode: request.declineReasonCode,
              declineReasonLabel: request.declineReasonLabel,
              declineReasonText: request.declineReasonText,
              quoteRespondedAt:
                  requestImpliesQuoteAccepted || requestImpliesQuoteDeclined
                  ? (existing?.quoteRespondedAt ?? request.updatedAt)
                  : existing?.quoteRespondedAt,
              requestCreatedAt: request.createdAt,
              requestUpdatedAt: request.updatedAt,
              requestSubmittedAt:
                  request.requestSubmittedAt ?? request.submittedAt,
              requestExpiresAt: request.expiresAt,
              requestLink: buildVanJobRequestLink(
                request.requestId,
                shortCode: request.shortCode,
              ),
              scheduledDate: request.scheduledDate,
              scheduledStartTime: request.scheduledStartTime,
              estimatedDurationMinutes:
                  request.dropOffPickupDurationMinutes ??
                  request.estimatedDurationMinutes,
              calendarStatus: isCancelled
                  ? 'cancelled'
                  : existingIsCompleted
                  ? 'completed'
                  : request.calendarStatus,
              locationPending: request.locationPending,
              quoteTimingChoice: request.quoteTimingChoice,
              agreedDateTime:
                  request.dropOffDateTime ??
                  request.agreedStartAtOrParsed ??
                  request.agreedDateTime,
              schedulingStatus: request.schedulingStatus,
              exactPinSource: request.exactPinSource,
              preferredDate: request.preferredDate,
              preferredTimeWindow: request.preferredTimeWindow,
              preferredIsFlexible: request.preferredIsFlexible,
              preferredTimingNote: request.preferredTimingNote,
              preferredTimingDecision: request.preferredTimingDecision,
              suggestedDate: request.suggestedDate,
              suggestedTimeWindow: request.suggestedTimeWindow,
              isTestData:
                  request.isMarkedTestData ||
                  (existing?.isMarkedTestData ?? false),
              testMode: request.testMode || (existing?.testMode ?? false),
              deleted: request.deleted || (existing?.deleted ?? false),
              archived: request.archived || (existing?.archived ?? false),
            ))
        .copyWith(
          jobId: request.jobId,
          customerName: request.publicCustomerName,
          jobTitle: request.publicJobTitle,
          scheduledAt: request.scheduledAt,
          jobDateLabel: request.jobDateLabel,
          jobTimeLabel: request.jobTimeLabel,
          address: request.publicAddressSummary,
          phoneNumber: mergedPhone,
          customerEmail: request.publicCustomerEmail,
          postcode: request.customerPostcode,
          requestExactPin: request.exactPinRequested,
          requestPhotos: request.requestPhotos,
          requiresExactPinAfterQuoteAccepted:
              request.requiresExactPinAfterQuoteAccepted,
          requestType: request.requestType,
          customerJourneyType: request.customerJourneyType,
          startHandover: request.startHandover,
          endHandover: request.endHandover,
          allowedStartHandoverOptions: request.allowedStartHandoverOptions,
          allowedEndHandoverOptions: request.allowedEndHandoverOptions,
          collectionAddress: request.collectionAddress,
          returnAddress: request.returnAddress,
          returnAddressSameAsCollection: request.returnAddressSameAsCollection,
          businessDropOffInstructions: request.businessDropOffInstructions,
          businessCollectionInstructions:
              request.businessCollectionInstructions,
          fulfilmentType: request.fulfilmentType,
          dropOffDate: request.dropOffDate,
          dropOffTime: request.dropOffTime,
          pickUpDate: request.pickUpDate,
          pickUpTime: request.pickUpTime,
          checklistItems: request.checklistItems,
          customQuestions: request.customQuestions,
          status: status,
          updatedAt: request.updatedAt,
          cancelledAt: isCancelled
              ? (existing?.cancelledAt ?? request.updatedAt)
              : existing?.cancelledAt,
          replyReceivedAt: hasReply
              ? (request.replyReceivedAt ??
                    request.customerSubmittedAt ??
                    request.submittedAt)
              : existing?.replyReceivedAt,
          exactPinShared: request.hasExactPin,
          checklistResponses: checklistResponses,
          customQuestionResponses: customResponses,
          additionalNotes: request.additionalNotes,
          hasReply: hasReply,
          hasExactPin: request.hasExactPin,
          exactPinShareSource: vanExactPinSourceFromStorage(
            request.exactPinSource,
          ),
          exactPinNote: request.exactPinNote,
          exactPinLatitude: request.exactPinLat,
          exactPinLongitude: request.exactPinLng,
          requestId: request.requestId,
          requestStatus: normalizedRequestStatus,
          quoteStatus: requestImpliesQuoteAccepted
              ? 'accepted'
              : requestImpliesQuoteDeclined
              ? 'declined'
              : existing?.quoteStatus,
          quoteAccepted: requestImpliesQuoteAccepted
              ? true
              : requestImpliesQuoteDeclined
              ? false
              : existing?.quoteAccepted,
          quoteDeclined: requestImpliesQuoteDeclined
              ? true
              : requestImpliesQuoteAccepted
              ? false
              : existing?.quoteDeclined,
          quoteResponseStatus: requestImpliesQuoteAccepted
              ? 'accepted'
              : requestImpliesQuoteDeclined
              ? 'declined'
              : existing?.quoteResponseStatus,
          quoteAcceptedAt: requestImpliesQuoteAccepted
              ? (existing?.quoteAcceptedAt ?? request.updatedAt)
              : existing?.quoteAcceptedAt,
          quoteDeclinedAt: requestImpliesQuoteDeclined
              ? (existing?.quoteDeclinedAt ?? request.updatedAt)
              : existing?.quoteDeclinedAt,
          declineReasonCode: request.declineReasonCode,
          declineReasonLabel: request.declineReasonLabel,
          declineReasonText: request.declineReasonText,
          quoteRespondedAt:
              requestImpliesQuoteAccepted || requestImpliesQuoteDeclined
              ? (existing?.quoteRespondedAt ?? request.updatedAt)
              : existing?.quoteRespondedAt,
          requestCreatedAt: request.createdAt,
          requestUpdatedAt: request.updatedAt,
          requestSubmittedAt: request.requestSubmittedAt ?? request.submittedAt,
          requestExpiresAt: request.expiresAt,
          requestLink: buildVanJobRequestLink(
            request.requestId,
            shortCode: request.shortCode,
          ),
          scheduledDate: request.scheduledDate,
          scheduledStartTime: request.scheduledStartTime,
          estimatedDurationMinutes:
              request.dropOffPickupDurationMinutes ??
              request.estimatedDurationMinutes,
          calendarStatus: isCancelled
              ? 'cancelled'
              : existingIsCompleted
              ? 'completed'
              : request.calendarStatus,
          locationPending: request.locationPending,
          quoteTimingChoice: request.quoteTimingChoice,
          agreedDateTime:
              request.dropOffDateTime ??
              request.agreedStartAtOrParsed ??
              request.agreedDateTime,
          schedulingStatus: request.schedulingStatus,
          exactPinSource: request.exactPinSource,
          preferredDate: request.preferredDate,
          preferredTimeWindow: request.preferredTimeWindow,
          preferredIsFlexible: request.preferredIsFlexible,
          preferredTimingNote: request.preferredTimingNote,
          preferredTimingDecision: request.preferredTimingDecision,
          suggestedDate: request.suggestedDate,
          suggestedTimeWindow: request.suggestedTimeWindow,
          isTestData:
              request.isMarkedTestData || (existing?.isMarkedTestData ?? false),
          testMode: request.testMode || (existing?.testMode ?? false),
          deleted: request.deleted || (existing?.deleted ?? false),
          archived: request.archived || (existing?.archived ?? false),
        );
  }

  bool get jobReady => activeJob?.isConfirmed ?? false;
  bool get pinSavedToJob => activeJob?.exactPinShared ?? false;
  bool get quoteSaved => activeJob?.quoteAmount != null;
  bool get quoteSent => activeJob?.isQuoteSent ?? false;
  bool get jobConfirmed => activeJob?.isConfirmed ?? false;
  bool get jobCompleted => activeJob?.isCompleted ?? false;
  DateTime? get jobCompletedAt => activeJob?.completedAt;
  bool get invoiceCreated => savedInvoiceHistory.isNotEmpty;
  bool get invoiceSent => activeJob?.isCompleted ?? false;
  VanExactPinSource? get exactPinShareSource => activeJob?.exactPinShareSource;
  String? get exactPinNote => activeJob?.exactPinNote;

  List<DriverCustomerReplyMockData> get allJobs {
    final jobs = _jobsById.values
        .where((job) => !job.isHiddenFromNormalLists)
        .toList();
    final filteredJobs = _applyDeletedFilterToJobs(
      jobs,
      logSource: 'allJobs.final',
    );
    filteredJobs.sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return filteredJobs;
  }

  List<VanInvoiceHistoryEntry> get savedInvoiceHistory {
    final entries = _invoiceHistoryByJobKey.values.toList()
      ..removeWhere((entry) => entry.deleted || entry.archived)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return entries;
  }

  VanInvoiceHistoryEntry? invoiceHistoryEntryForJob(String jobKey) {
    return _invoiceHistoryByJobKey[jobKey];
  }

  VanInvoiceDraft? invoiceForJob(String jobKey) {
    return _invoiceHistoryByJobKey[jobKey]?.draft;
  }

  VanBlockedCustomerRecord? blockedCustomerForPhone(String phoneNumber) {
    final normalizedPhone = normalizeVanCustomerPhoneNumberForMatch(
      phoneNumber,
    );
    if (normalizedPhone.isEmpty) {
      return null;
    }
    return _blockedCustomersByPhone[normalizedPhone];
  }

  VanBlockedCustomerRecord? blockedCustomerForJob(
    DriverCustomerReplyMockData job, {
    VanJobRequestRecord? request,
  }) {
    final requestPhone = normalizeVanCustomerPhoneNumberForMatch(
      request?.publicPhoneNumber ?? '',
    );
    if (requestPhone.isNotEmpty) {
      return _blockedCustomersByPhone[requestPhone];
    }
    final jobPhone = normalizeVanCustomerPhoneNumberForMatch(job.phoneNumber);
    if (jobPhone.isEmpty) {
      return null;
    }
    return _blockedCustomersByPhone[jobPhone];
  }

  bool isBlockedPhone(String phoneNumber) {
    return blockedCustomerForPhone(phoneNumber) != null;
  }

  VanJobRequestRecord? requestForJob(String jobId) {
    final request = _requestForJob(jobId);
    return request == null || request.isHiddenFromNormalLists ? null : request;
  }

  VanJobRequestRecord? requestForId(String requestId) {
    final request = _jobRequestsById[requestId.trim()];
    if (request == null || request.isHiddenFromNormalLists) {
      return null;
    }
    final job =
        _jobsById[request.linkedJobId.trim().isNotEmpty
            ? request.linkedJobId.trim()
            : request.jobId.trim()] ??
        _placeholderJobForRequest(request);
    if (isLegacyDeleteFiltered(job, request: request)) {
      return null;
    }
    return request;
  }

  DriverCustomerReplyMockData? realReplyForJob(String jobId) {
    final request = _requestForJob(jobId);
    if (request == null ||
        request.isHiddenFromNormalLists ||
        !request.hasCustomerReply) {
      return null;
    }

    final existing = _jobsById[jobId.trim()];
    return _isVisibleJob(existing)
        ? _replyFromRequestRecord(request, existing: existing)
        : null;
  }

  bool blockCustomerForJob({
    required DriverCustomerReplyMockData job,
    VanJobRequestRecord? request,
    required String reason,
    String note = '',
  }) {
    final requestPhone = normalizeVanCustomerPhoneNumberForMatch(
      request?.publicPhoneNumber ?? '',
    );
    final normalizedPhone = requestPhone.isNotEmpty
        ? requestPhone
        : normalizeVanCustomerPhoneNumberForMatch(job.phoneNumber);
    if (normalizedPhone.isEmpty) {
      return false;
    }

    final displayPhone = requestPhone.isNotEmpty
        ? (request?.publicPhoneNumber.trim().isNotEmpty == true
              ? request!.publicPhoneNumber.trim()
              : normalizedPhone)
        : (job.phoneNumber.trim().isNotEmpty
              ? job.phoneNumber.trim()
              : normalizedPhone);
    final customerName = request?.publicCustomerName.trim().isNotEmpty == true
        ? request!.publicCustomerName.trim()
        : (job.customerName.trim().isNotEmpty
              ? job.customerName.trim()
              : 'Customer');
    final address = request?.publicAddressSummary.trim().isNotEmpty == true
        ? request!.publicAddressSummary.trim()
        : job.address.trim();
    final existing = _blockedCustomersByPhone[normalizedPhone];
    final invoice = invoiceForJob(job.invoiceHistoryKey);
    final blockedByUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    _blockedCustomersByPhone[normalizedPhone] = VanBlockedCustomerRecord(
      customerName: customerName,
      phoneNumber: displayPhone,
      normalizedPhone: normalizedPhone,
      blockedByUserId: blockedByUserId,
      address: address,
      reason: reason.trim().isEmpty ? 'Other' : reason.trim(),
      note: note.trim(),
      blockedAt: existing?.blockedAt ?? DateTime.now(),
      relatedJobId: job.jobId.trim(),
      relatedInvoiceId: invoice?.invoiceNumber.trim() ?? '',
      relatedQuoteId: job.quoteResponseId.trim(),
    );
    _scheduleSave();
    notifyListeners();
    return true;
  }

  bool unblockCustomerByPhone(String phoneNumber) {
    final normalizedPhone = normalizeVanCustomerPhoneNumberForMatch(
      phoneNumber,
    );
    if (normalizedPhone.isEmpty) {
      return false;
    }
    final removed = _blockedCustomersByPhone.remove(normalizedPhone) != null;
    if (removed) {
      _scheduleSave();
      notifyListeners();
    }
    return removed;
  }

  void upsertInvoiceForJob(String jobKey, VanInvoiceDraft draft) {
    final existing = _invoiceHistoryByJobKey[jobKey];
    final savedDraft = draft.copyWith(jobKey: jobKey);
    final now = DateTime.now();
    _invoiceHistoryByJobKey[jobKey] = VanInvoiceHistoryEntry(
      jobKey: jobKey,
      draft: savedDraft,
      savedAt: existing?.savedAt ?? DateTime.now(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      deleted: existing?.deleted ?? false,
      archived: existing?.archived ?? false,
      linkedJobDeleted: existing?.linkedJobDeleted ?? false,
    );
    savedInvoice = savedDraft;
    _scheduleSave();
    notifyListeners();
  }

  VanInvoiceDraft? markInvoicePaidForJob(String jobKey) {
    final entry = _invoiceHistoryByJobKey[jobKey];
    if (entry == null) {
      return null;
    }

    final updatedDraft = entry.draft.copyWith(
      paymentStatus: 'paid',
      paidAt: DateTime.now(),
      jobKey: jobKey,
    );
    final now = DateTime.now();

    _invoiceHistoryByJobKey[jobKey] = VanInvoiceHistoryEntry(
      jobKey: jobKey,
      draft: updatedDraft,
      savedAt: entry.savedAt,
      createdAt: entry.createdAt,
      updatedAt: now,
      deleted: entry.deleted,
      archived: entry.archived,
      linkedJobDeleted: entry.linkedJobDeleted,
    );

    if (savedInvoice?.jobKey == jobKey ||
        savedInvoice?.invoiceNumber == entry.draft.invoiceNumber) {
      savedInvoice = updatedDraft;
    }

    _scheduleSave();
    notifyListeners();
    return updatedDraft;
  }

  VanInvoiceDraft? markInvoicePaidForDraft(VanInvoiceDraft draft) {
    final jobKey = draft.jobKey?.trim() ?? '';
    if (jobKey.isEmpty) {
      return null;
    }

    if (!_invoiceHistoryByJobKey.containsKey(jobKey)) {
      upsertInvoiceForJob(jobKey, draft.copyWith(jobKey: jobKey));
    }

    return markInvoicePaidForJob(jobKey);
  }

  VanInvoiceDraft? markInvoiceUnpaidForJob(String jobKey) {
    final entry = _invoiceHistoryByJobKey[jobKey];
    if (entry == null) {
      return null;
    }

    final updatedDraft = entry.draft.copyWith(
      paymentStatus: 'unpaid',
      paidAt: null,
      jobKey: jobKey,
    );
    final now = DateTime.now();

    _invoiceHistoryByJobKey[jobKey] = VanInvoiceHistoryEntry(
      jobKey: jobKey,
      draft: updatedDraft,
      savedAt: entry.savedAt,
      createdAt: entry.createdAt,
      updatedAt: now,
      deleted: entry.deleted,
      archived: entry.archived,
      linkedJobDeleted: entry.linkedJobDeleted,
    );

    if (savedInvoice?.jobKey == jobKey ||
        savedInvoice?.invoiceNumber == entry.draft.invoiceNumber) {
      savedInvoice = updatedDraft;
    }

    _scheduleSave();
    notifyListeners();
    return updatedDraft;
  }

  VanInvoiceHistoryEntry? markInvoiceReminderSentForJob(
    String jobKey, {
    required int stageDays,
    DateTime? sentAt,
  }) {
    final entry = _invoiceHistoryByJobKey[jobKey];
    if (entry == null) {
      return null;
    }

    final reminderSentAt = sentAt ?? DateTime.now();
    final updatedDraft = entry.draft
        .copyWith(jobKey: jobKey)
        .markReminderStagesSentUpTo(
          stageDays: stageDays,
          sentAt: reminderSentAt,
        );
    final updatedEntry = VanInvoiceHistoryEntry(
      jobKey: jobKey,
      draft: updatedDraft,
      savedAt: entry.savedAt,
      createdAt: entry.createdAt,
      updatedAt: reminderSentAt,
      deleted: entry.deleted,
      archived: entry.archived,
      linkedJobDeleted: entry.linkedJobDeleted,
    );

    _invoiceHistoryByJobKey[jobKey] = updatedEntry;

    if (savedInvoice?.jobKey == jobKey ||
        savedInvoice?.invoiceNumber == entry.draft.invoiceNumber) {
      savedInvoice = updatedDraft;
    }

    _scheduleSave();
    notifyListeners();
    return updatedEntry;
  }
}

class _BookedCalendarDecision {
  const _BookedCalendarDecision({
    required this.counted,
    required this.isManual,
    required this.reason,
  });

  final bool counted;
  final bool isManual;
  final String reason;
}

@immutable
class VanBookedCalendarSlot {
  const VanBookedCalendarSlot({
    required this.start,
    required this.durationMinutes,
    required this.calendarStatus,
    required this.schedulingStatus,
    required this.usedPersistedScheduleFields,
  });

  final DateTime start;
  final int durationMinutes;
  final String calendarStatus;
  final String schedulingStatus;
  final bool usedPersistedScheduleFields;
}

class VanScheduleOverlap {
  const VanScheduleOverlap({
    required this.jobId,
    required this.start,
    required this.end,
    required this.customerName,
    required this.jobTitle,
  });

  final String jobId;
  final DateTime start;
  final DateTime end;
  final String customerName;
  final String jobTitle;
}

class VanScheduleOverlapException implements Exception {
  const VanScheduleOverlapException(this.overlap, this.message);

  final VanScheduleOverlap overlap;
  final String message;

  @override
  String toString() => message;
}

class VanPastScheduleException implements Exception {
  const VanPastScheduleException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _jsonBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

DateTime? _jsonDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String _jsonIsoDateText(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String().split('T').first;
  }
  if (value is DateTime) {
    return value.toIso8601String().split('T').first;
  }
  final text = sanitizeVanText(value?.toString()).trim();
  if (text.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    ).toIso8601String().split('T').first;
  }
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(text);
  if (match != null) {
    return match.group(1) ?? text;
  }
  return text;
}

String _jsonTimeText(Object? value) {
  String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  if (value is Timestamp) {
    return formatTime(value.toDate());
  }
  if (value is DateTime) {
    return formatTime(value);
  }
  final text = sanitizeVanText(value?.toString()).trim();
  if (text.isEmpty) {
    return '';
  }
  final parsedDateTime = DateTime.tryParse(text);
  if (parsedDateTime != null && text.contains('T')) {
    return formatTime(parsedDateTime);
  }
  final parsedTime = _parseJobTimeLabel(text);
  if (parsedTime != null) {
    final hour = parsedTime.hour.toString().padLeft(2, '0');
    final minute = parsedTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  return text;
}

double? _jsonDoubleOrNull(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final cleaned = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
    return null;
  }
  return double.tryParse(cleaned);
}

int? _jsonIntOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final cleaned = text.replaceAll(RegExp(r'[^0-9\-]'), '');
  if (cleaned.isEmpty || cleaned == '-') {
    return null;
  }
  return int.tryParse(cleaned);
}

String _jsonText(Object? value, {String fallback = ''}) {
  final text = sanitizeVanText(value?.toString()).trim();
  return text.isEmpty ? fallback : text;
}

String _resolvedCustomerPhoneFromMap(Map<String, dynamic> json) {
  final candidates = <Object?>[
    json['customerPhone'],
    json['phoneNumber'],
    json['phone'],
    json['customerNumber'],
    json['contactPhone'],
    json['mobile'],
  ];
  for (final candidate in candidates) {
    final cleaned = sanitizeVanCustomerPhoneNumber(candidate?.toString() ?? '');
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return '';
}

String? _jsonTextOrNull(Object? value) {
  final text = sanitizeVanText(value?.toString()).trim();
  return text.isEmpty ? null : text;
}

class DriverChecklistResponse {
  const DriverChecklistResponse({
    required this.question,
    required this.answer,
    this.note,
    this.icon = Icons.checklist,
  });

  final String question;
  final String answer;
  final String? note;
  final IconData icon;
}

class DriverCustomQuestionResponse {
  const DriverCustomQuestionResponse({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

String vanJobChecklistDisplayLabel(String question) {
  final normalized = sanitizeVanText(question).trim().toLowerCase();
  switch (normalized) {
    case 'parking available?':
      return 'Parking';
    case 'any access restrictions?':
      return 'Access';
    case 'stairs or lift?':
      return 'Stairs/lift';
    case 'help loading/unloading?':
      return 'Loading help';
    case 'large or heavy items?':
      return 'Heavy items';
    case 'fragile items?':
      return 'Fragile items';
    case 'photos needed?':
      return 'Photos';
  }

  final cleaned = sanitizeVanText(
    question,
  ).trim().replaceAll(RegExp(r'\?+$'), '');
  return cleaned.isEmpty ? 'Other' : cleaned;
}

bool _isPhotoChecklistQuestion(String question) {
  final normalized = sanitizeVanText(question).trim().toLowerCase();
  return normalized == 'photos needed?' || normalized == 'photos';
}

bool _isAnsweredChecklistResponse(DriverChecklistResponse response) {
  return response.answer.trim().isNotEmpty &&
      !_isPhotoChecklistQuestion(response.question);
}

bool vanJobReplyHasContent({
  required List<DriverChecklistResponse> checklistResponses,
  required List<DriverCustomQuestionResponse> customQuestionResponses,
  required String additionalNotes,
  required bool replyReceivedAtPresent,
  required bool exactPinShared,
  required bool hasExactPinCoordinates,
}) {
  return checklistResponses.any(
        (response) => response.answer.trim().isNotEmpty,
      ) ||
      customQuestionResponses.any(
        (response) => response.answer.trim().isNotEmpty,
      ) ||
      additionalNotes.trim().isNotEmpty ||
      replyReceivedAtPresent ||
      exactPinShared ||
      hasExactPinCoordinates;
}

bool vanJobHasExactPinContent({
  required bool hasExactPin,
  required bool exactPinShared,
  required bool hasExactPinCoordinates,
}) {
  return hasExactPin || exactPinShared || hasExactPinCoordinates;
}

final DriverCustomerReplyMockData driverCustomerReplySample =
    DriverCustomerReplyMockData(
      jobId: '',
      customerName: '',
      jobTitle: '',
      scheduledAt: null,
      jobDateLabel: '',
      jobTimeLabel: '',
      address: '',
      phoneNumber: '',
      quoteAmount: null,
      status: 'draft',
      exactPinShared: false,
      exactPinShareSource: VanExactPinSource.currentLocation,
      exactPinNote: '',
      exactPinLatitude: null,
      exactPinLongitude: null,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
    );

Future<void> openDriverCustomerReplyMockPage(
  BuildContext context, {
  String? jobId,
}) {
  final reply = jobId != null
      ? DriverReplyMockState.instance.jobById(jobId) ??
            driverCustomerReplySample
      : DriverReplyMockState.instance.activeJob ?? driverCustomerReplySample;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DriverCustomerReplyPage(reply: reply),
    ),
  );
}

Future<void> openDriverQuoteMockPage(
  BuildContext context,
  DriverCustomerReplyMockData reply,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => CreateQuotePage(reply: reply)),
  );
}

bool shouldPreserveDeclinedQuoteWorkflowState(
  DriverCustomerReplyMockData original,
  DriverCustomerReplyMockData candidate,
) {
  if (!original.hasQuote || !original.isQuoteDeclined) {
    return false;
  }
  if (candidate.isQuoteDeclined) {
    return false;
  }

  final originalQuoteId = original.authoritativeCurrentQuoteId;
  final candidateQuoteId = candidate.authoritativeCurrentQuoteId;
  final originalDeclinedAt = original.quoteDeclinedAt;
  final candidateSentAt = candidate.quoteSentAt;
  final candidateRespondedAt = candidate.quoteRespondedAt;
  final hasReplacementQuoteVersion =
      candidateQuoteId.isNotEmpty &&
      originalQuoteId.isNotEmpty &&
      candidateQuoteId != originalQuoteId;
  final sentAfterDecline =
      originalDeclinedAt != null &&
      candidateSentAt != null &&
      candidateSentAt.isAfter(originalDeclinedAt);
  final respondedAfterDecline =
      originalDeclinedAt != null &&
      candidateRespondedAt != null &&
      candidateRespondedAt.isAfter(originalDeclinedAt);

  final candidateHasReplacementQuoteState =
      candidate.isQuoteAccepted ||
      candidate.isQuoteAwaitingCustomerResponse ||
      hasReplacementQuoteVersion ||
      sentAfterDecline ||
      respondedAfterDecline;
  return !candidateHasReplacementQuoteState;
}

DriverCustomerReplyMockData preserveDeclinedQuoteWorkflowState(
  DriverCustomerReplyMockData original,
  DriverCustomerReplyMockData candidate,
) {
  if (!shouldPreserveDeclinedQuoteWorkflowState(original, candidate)) {
    return candidate;
  }

  return candidate.copyWith(
    status: original.status.trim().isNotEmpty
        ? original.status
        : candidate.status,
    requestStatus:
        normalizeVanJobRequestStatus(original.requestStatus) == 'quote_declined'
        ? original.requestStatus
        : candidate.requestStatus,
    quoteStatus: 'declined',
    quoteAccepted: false,
    quoteAcceptedAt: null,
    quoteDeclined: true,
    quoteDeclinedAt: original.quoteDeclinedAt ?? candidate.quoteDeclinedAt,
    declineReasonCode: original.declineReasonCode.trim().isNotEmpty
        ? original.declineReasonCode
        : candidate.declineReasonCode,
    declineReasonLabel: original.declineReasonLabel.trim().isNotEmpty
        ? original.declineReasonLabel
        : candidate.declineReasonLabel,
    declineReasonText: original.declineReasonText.trim().isNotEmpty
        ? original.declineReasonText
        : candidate.declineReasonText,
    declineNote: original.declineNote.trim().isNotEmpty
        ? original.declineNote
        : candidate.declineNote,
    quoteRespondedAt: original.quoteRespondedAt ?? candidate.quoteRespondedAt,
    quoteResponseStatus: 'declined',
    quoteTimingChoice: original.quoteTimingChoice.trim().isNotEmpty
        ? original.quoteTimingChoice
        : 'declined',
    agreedDateTime: null,
  );
}

bool shouldPreserveAcceptedQuoteWorkflowState(
  DriverCustomerReplyMockData original,
  DriverCustomerReplyMockData candidate,
) {
  if (!original.hasQuote || !original.isQuoteAccepted) {
    return false;
  }
  if (candidate.isQuoteAccepted ||
      candidate.isQuoteDeclined ||
      candidate.isConfirmed ||
      candidate.isCompletedJob ||
      candidate.isScheduledInCalendarState) {
    return false;
  }

  return candidate.isQuoteAwaitingCustomerResponse ||
      candidate.isQuoteSent ||
      candidate.status.trim().toLowerCase() == 'quotesent' ||
      candidate.requestStatus.trim().toLowerCase() == 'quote_sent' ||
      candidate.requestStatus.trim().toLowerCase() == 'quoted';
}

DriverCustomerReplyMockData preserveAcceptedQuoteWorkflowState(
  DriverCustomerReplyMockData original,
  DriverCustomerReplyMockData candidate,
) {
  if (!shouldPreserveAcceptedQuoteWorkflowState(original, candidate)) {
    return candidate;
  }

  return candidate.copyWith(
    status: original.status.trim().isNotEmpty
        ? original.status
        : 'quoteAccepted',
    requestStatus:
        normalizeVanJobRequestStatus(original.requestStatus) == 'quote_accepted'
        ? original.requestStatus
        : 'quote_accepted',
    quoteStatus: 'accepted',
    quoteAccepted: true,
    quoteAcceptedAt: original.quoteAcceptedAt ?? candidate.quoteAcceptedAt,
    quoteDeclined: false,
    quoteRespondedAt: original.quoteRespondedAt ?? candidate.quoteRespondedAt,
    quoteResponseStatus: 'accepted',
    quoteTimingChoice: original.quoteTimingChoice.trim().isNotEmpty
        ? original.quoteTimingChoice
        : candidate.quoteTimingChoice,
    agreedDateTime: original.agreedDateTime ?? candidate.agreedDateTime,
    proposedDate: original.proposedDate.trim().isNotEmpty
        ? original.proposedDate
        : candidate.proposedDate,
    proposedStartTime: original.proposedStartTime.trim().isNotEmpty
        ? original.proposedStartTime
        : candidate.proposedStartTime,
    acceptedProposedDate: original.acceptedProposedDate.trim().isNotEmpty
        ? original.acceptedProposedDate
        : original.proposedDate.trim().isNotEmpty
        ? original.proposedDate
        : candidate.acceptedProposedDate,
    acceptedProposedStartTime:
        original.acceptedProposedStartTime.trim().isNotEmpty
        ? original.acceptedProposedStartTime
        : original.proposedStartTime.trim().isNotEmpty
        ? original.proposedStartTime
        : candidate.acceptedProposedStartTime,
    schedulingStatus: original.schedulingStatus.trim().isNotEmpty
        ? original.schedulingStatus
        : candidate.schedulingStatus,
    scheduledDate: original.scheduledDate.trim().isNotEmpty
        ? original.scheduledDate
        : candidate.scheduledDate,
    scheduledStartTime: original.scheduledStartTime.trim().isNotEmpty
        ? original.scheduledStartTime
        : candidate.scheduledStartTime,
    exactPinShared: original.exactPinShared || candidate.exactPinShared,
    hasExactPin: original.hasExactPin || candidate.hasExactPin,
    exactPinLatitude: original.exactPinLatitude ?? candidate.exactPinLatitude,
    exactPinLongitude:
        original.exactPinLongitude ?? candidate.exactPinLongitude,
    exactPinNote: original.exactPinNote ?? candidate.exactPinNote,
    exactPinSource: original.exactPinSource.trim().isNotEmpty
        ? original.exactPinSource
        : candidate.exactPinSource,
  );
}

DriverCustomerReplyMockData preserveQuoteWorkflowState(
  DriverCustomerReplyMockData original,
  DriverCustomerReplyMockData candidate, {
  bool candidateIsAuthoritativeQuoteSource = false,
}) {
  final candidateWithCurrentQuote = preserveAuthoritativeCurrentQuoteState(
    original,
    candidate,
    candidateIsAuthoritativeQuoteSource: candidateIsAuthoritativeQuoteSource,
  );
  return preserveDeclinedQuoteWorkflowState(
    original,
    preserveAcceptedQuoteWorkflowState(original, candidateWithCurrentQuote),
  );
}

bool shouldPreserveAuthoritativeCurrentQuoteState(
  DriverCustomerReplyMockData original,
  DriverCustomerReplyMockData candidate, {
  bool candidateIsAuthoritativeQuoteSource = false,
}) {
  if (!original.hasQuote || candidateIsAuthoritativeQuoteSource) {
    return false;
  }

  final originalQuoteId = original.authoritativeCurrentQuoteId;
  final candidateQuoteId = candidate.authoritativeCurrentQuoteId;
  if (candidateQuoteId.isNotEmpty &&
      originalQuoteId.isNotEmpty &&
      candidateQuoteId != originalQuoteId) {
    return false;
  }

  if (!candidate.hasQuote) {
    return originalQuoteId.isNotEmpty || original.quoteSentAt != null;
  }

  final sameCurrentQuote =
      originalQuoteId.isNotEmpty && candidateQuoteId == originalQuoteId;
  if (!sameCurrentQuote) {
    return false;
  }

  return (original.quoteSentAt != null && candidate.quoteSentAt == null) ||
      (original.quoteAmount != null && candidate.quoteAmount == null) ||
      (original.quoteExtras.isNotEmpty && candidate.quoteExtras.isEmpty) ||
      (original.proposedDate.trim().isNotEmpty &&
          candidate.proposedDate.trim().isEmpty) ||
      (original.proposedStartTime.trim().isNotEmpty &&
          candidate.proposedStartTime.trim().isEmpty);
}

DriverCustomerReplyMockData preserveAuthoritativeCurrentQuoteState(
  DriverCustomerReplyMockData original,
  DriverCustomerReplyMockData candidate, {
  bool candidateIsAuthoritativeQuoteSource = false,
}) {
  if (!shouldPreserveAuthoritativeCurrentQuoteState(
    original,
    candidate,
    candidateIsAuthoritativeQuoteSource: candidateIsAuthoritativeQuoteSource,
  )) {
    return candidate;
  }

  final candidateHasLaterWorkflowState =
      candidate.quoteAccepted ||
      candidate.quoteDeclined ||
      candidate.isConfirmed ||
      candidate.isCompletedJob ||
      candidate.isScheduledInCalendarState ||
      candidate.isCancelled;
  return candidate.copyWith(
    status: candidateHasLaterWorkflowState ? candidate.status : original.status,
    requestStatus: candidateHasLaterWorkflowState
        ? candidate.requestStatus
        : original.requestStatus,
    quoteSavedAt: original.quoteSavedAt,
    quoteSentAt: original.quoteSentAt,
    quoteOpenedAt: original.quoteOpenedAt,
    currentQuoteId: original.authoritativeCurrentQuoteId,
    quoteResponseId: original.authoritativeCurrentQuoteId,
    quoteResponseToken: original.quoteResponseToken,
    quoteResponseLink: original.quoteResponseLink,
    quoteAmount: original.quoteAmount,
    quoteExtras: original.quoteExtras,
    quoteJobDescription: original.quoteJobDescription,
    quoteNotes: original.quoteNotes,
    quotePaymentInstructions: original.quotePaymentInstructions,
    quoteMessage: original.quoteMessage,
    quoteStatus: candidateHasLaterWorkflowState
        ? candidate.quoteStatus
        : original.quoteStatus,
    quoteAccepted: candidateHasLaterWorkflowState
        ? candidate.quoteAccepted
        : original.quoteAccepted,
    quoteAcceptedAt: candidateHasLaterWorkflowState
        ? candidate.quoteAcceptedAt
        : original.quoteAcceptedAt,
    quoteDeclined: candidateHasLaterWorkflowState
        ? candidate.quoteDeclined
        : original.quoteDeclined,
    quoteDeclinedAt: candidateHasLaterWorkflowState
        ? candidate.quoteDeclinedAt
        : original.quoteDeclinedAt,
    quoteRespondedAt: candidateHasLaterWorkflowState
        ? candidate.quoteRespondedAt
        : original.quoteRespondedAt,
    quoteResponseStatus: candidateHasLaterWorkflowState
        ? candidate.quoteResponseStatus
        : original.quoteResponseStatus,
    quoteTimingChoice: candidateHasLaterWorkflowState
        ? candidate.quoteTimingChoice
        : original.quoteTimingChoice,
    agreedDateTime: candidateHasLaterWorkflowState
        ? candidate.agreedDateTime
        : original.agreedDateTime,
    proposedDate: original.proposedDate,
    proposedStartTime: original.proposedStartTime,
    proposedAppointmentNote: original.proposedAppointmentNote,
    estimatedDurationMinutes: original.estimatedDurationMinutes,
    quoteHistory: original.quoteHistory,
  );
}

DriverCustomerReplyMockData resolveVanQuoteWorkflowReply(
  DriverCustomerReplyMockData reply,
) {
  final realReply = DriverReplyMockState.instance.realReplyForJob(reply.jobId);
  if (realReply != null) {
    return preserveQuoteWorkflowState(reply, realReply);
  }

  final liveJob = DriverReplyMockState.instance.jobById(reply.jobId);
  if (liveJob == null) {
    return reply;
  }

  if (reply.hasCustomerReply && !liveJob.hasCustomerReply) {
    return reply;
  }

  if ((reply.checklistResponses.isNotEmpty &&
          liveJob.checklistResponses.isEmpty) ||
      (reply.customQuestionResponses.isNotEmpty &&
          liveJob.customQuestionResponses.isEmpty)) {
    return preserveQuoteWorkflowState(
      reply,
      liveJob.copyWith(
        checklistResponses: liveJob.checklistResponses.isNotEmpty
            ? liveJob.checklistResponses
            : reply.checklistResponses,
        customQuestionResponses: liveJob.customQuestionResponses.isNotEmpty
            ? liveJob.customQuestionResponses
            : reply.customQuestionResponses,
        additionalNotes: liveJob.additionalNotes.trim().isNotEmpty
            ? liveJob.additionalNotes
            : reply.additionalNotes,
        replyReceivedAt: liveJob.replyReceivedAt ?? reply.replyReceivedAt,
      ),
    );
  }

  return preserveQuoteWorkflowState(reply, liveJob);
}

Future<void> openVanQuoteWorkflowForJob(
  BuildContext context,
  DriverCustomerReplyMockData reply,
) {
  return openDriverQuoteMockPage(context, resolveVanQuoteWorkflowReply(reply));
}

class DriverCustomerReplyPage extends StatefulWidget {
  const DriverCustomerReplyPage({super.key, required this.reply});

  final DriverCustomerReplyMockData reply;

  @override
  State<DriverCustomerReplyPage> createState() =>
      _DriverCustomerReplyPageState();
}

class _DriverCustomerReplyPageState extends State<DriverCustomerReplyPage> {
  DriverCustomerReplyMockData get reply =>
      resolveVanQuoteWorkflowReply(widget.reply);

  String get _jobId => widget.reply.jobId;

  VanJobRequestRecord? get _requestRecord =>
      DriverReplyMockState.instance.requestForJob(_jobId);

  VanJobActionState get _actionState =>
      deriveVanJobActionState(reply, request: _requestRecord);

  String get _contactPhone {
    final requestPhone = _requestRecord?.publicPhoneNumber.trim() ?? '';
    return requestPhone.isNotEmpty ? requestPhone : reply.phoneNumber;
  }

  @override
  void initState() {
    super.initState();
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(forceServer: true),
      );
    });
  }

  @override
  void dispose() {
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    super.dispose();
  }

  void _handleDriverStateChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _callCustomer() async {
    final phone = sanitizeVanCustomerPhoneNumber(_contactPhone);
    if (phone.isEmpty) {
      _showSnack('No customer phone number saved.');
      return;
    }
    await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _textCustomer() async {
    final phone = sanitizeVanCustomerPhoneNumber(_contactPhone);
    if (phone.isEmpty) {
      _showSnack('No customer phone number saved.');
      return;
    }
    await launchUrl(
      Uri(scheme: 'sms', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _markReady() async {
    final actionState = _actionState;
    if (!actionState.canAddToCalendar) {
      if (actionState.isAwaitingExactPin) {
        _showSnack(
          'Wait for the exact pickup or drop-off pin before adding this job to the calendar.',
        );
      } else {
        _showSnack(
          'Set an exact agreed time before adding this job to the calendar.',
        );
      }
      return;
    }
    final scheduledAt = effectiveAgreedSchedulingTimeForJob(
      reply,
      request: _requestRecord,
    );
    if (reply.isQuoteAccepted &&
        reply.requiresAnyExactPin &&
        !reply.exactPinSaved) {
      _showSnack(
        'Wait for the exact pickup or drop-off pin before adding this job to the calendar.',
      );
      return;
    }
    if (scheduledAt == null || reply.isAwaitingAgreedTime) {
      _showSnack(
        'Set an exact agreed time before adding this job to the calendar.',
      );
      return;
    }
    debugPrintSynchronously(
      'CONFIRM_SCHEDULE_TAPPED path=reply_screen.actions jobId=$_jobId '
      'source=${DriverReplyMockState.instance.debugSourceForJob(_jobId)}',
    );
    final bool persisted;
    try {
      persisted = await DriverReplyMockState.instance.persistScheduledJob(
        jobId: _jobId,
        scheduledAt: scheduledAt,
        estimatedDurationMinutes: reply.estimatedDurationMinutes ?? 60,
        schedulingStatus: reply.schedulingStatus.trim().isNotEmpty
            ? reply.schedulingStatus
            : 'accepted_time',
      );
    } on VanScheduleOverlapException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message);
      return;
    }
    if (!persisted) {
      if (!mounted) {
        return;
      }
      _showSnack('Could not save this job to Calendar. Please try again.');
      return;
    }
    try {
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[CONFIRM_SCHEDULE_REFRESH_ERROR] error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    _showSnack('Job added to calendar.');
  }

  void _createQuote() {
    unawaited(openVanQuoteWorkflowForJob(context, reply));
  }

  Widget _buildStatusChip(
    String label, {
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled
            ? color.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.96),
                fontSize: 11.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeutralChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.64),
          fontSize: 11.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildAnswerCard({
    required IconData icon,
    required String question,
    required String answer,
    String? note,
  }) {
    final answerText = answer.trim().isEmpty ? 'No answer added.' : answer;
    final noteText = _displayNoteText(note);
    final hasUsefulNote = _hasUsefulNote(note);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (answerText == 'No answer added.')
                _buildNeutralChip(answerText)
              else
                _buildStatusChip(
                  answerText,
                  color: const Color(0xFF4A7DFF),
                  icon: Icons.check_circle_outline,
                  filled: true,
                ),
              if (hasUsefulNote)
                _buildStatusChip(
                  'Note added',
                  color: const Color(0xFFB48CFF),
                  icon: Icons.notes,
                ),
            ],
          ),
          if (noteText != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                noteText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: hasUsefulNote
                      ? Colors.white.withValues(alpha: 0.78)
                      : Colors.white.withValues(alpha: 0.56),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _cleanBookingLinkNotes(String rawNotes) {
    if (rawNotes.trim().isEmpty) {
      return '';
    }
    final lines = rawNotes
        .split('\n')
        .map((line) => line.trim())
        .where((line) {
          final normalized = line.toLowerCase();
          if (normalized.startsWith('source:')) {
            return false;
          }
          if (normalized.startsWith('photos attached:')) {
            return false;
          }
          return line.isNotEmpty;
        })
        .toList(growable: false);
    return lines.join('\n').trim();
  }

  String _normalizeReplyNoteForComparison(String value) {
    return sanitizeVanText(
      value,
    ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _looksLikeTimingSpecificReplyNote(String value) {
    final normalized = _normalizeReplyNoteForComparison(value);
    if (normalized.isEmpty) {
      return false;
    }

    const timingKeywords = <String>[
      'time',
      'timing',
      'morning',
      'afternoon',
      'evening',
      'flexible',
      'availability',
      'available',
      'arrive',
      'arrival',
      'collect',
      'collection',
      'pickup',
      'pick up',
      'pick-up',
      'drop off',
      'drop-off',
      'before ',
      'after ',
      'between ',
      'around ',
      'slot',
      'schedule',
      'scheduled',
      'date',
      'today',
      'tomorrow',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    if (timingKeywords.any(normalized.contains)) {
      return true;
    }

    return RegExp(
      r'\b\d{1,2}(:\d{2})?\s?(am|pm)\b|\b\d{1,2}(:\d{2})\b',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  String _resolveDisplayedPreferredTimingNote({
    required DriverCustomerReplyMockData reply,
    required VanJobRequestRecord? requestRecord,
    required bool isBookingLinkSubmission,
  }) {
    final preferredTimingNote =
        requestRecord?.preferredTimingNote.trim().isNotEmpty == true
        ? requestRecord!.preferredTimingNote.trim()
        : reply.preferredTimingNote.trim();
    if (preferredTimingNote.isEmpty) {
      return '';
    }

    final additionalNotes =
        requestRecord?.additionalNotes.trim().isNotEmpty == true
        ? requestRecord!.additionalNotes.trim()
        : reply.additionalNotes.trim();
    final normalizedTiming = _normalizeReplyNoteForComparison(
      preferredTimingNote,
    );
    final normalizedAdditional = _normalizeReplyNoteForComparison(
      additionalNotes,
    );
    final shouldTreatAsGeneralNote =
        (normalizedAdditional.isNotEmpty &&
            normalizedAdditional == normalizedTiming) ||
        (isBookingLinkSubmission && normalizedAdditional.isEmpty) ||
        (normalizedAdditional.isEmpty &&
            !_looksLikeTimingSpecificReplyNote(preferredTimingNote));
    return shouldTreatAsGeneralNote ? '' : preferredTimingNote;
  }

  String _resolveDisplayedAdditionalNotes({
    required DriverCustomerReplyMockData reply,
    required VanJobRequestRecord? requestRecord,
    required bool isBookingLinkSubmission,
  }) {
    final requestNotes = requestRecord?.additionalNotes.trim() ?? '';
    final replyNotes = reply.additionalNotes.trim();
    if (requestNotes.isNotEmpty) {
      return isBookingLinkSubmission
          ? _cleanBookingLinkNotes(requestNotes)
          : requestNotes;
    }
    if (replyNotes.isNotEmpty) {
      return isBookingLinkSubmission
          ? _cleanBookingLinkNotes(replyNotes)
          : replyNotes;
    }

    final preferredTimingNote =
        requestRecord?.preferredTimingNote.trim().isNotEmpty == true
        ? requestRecord!.preferredTimingNote.trim()
        : reply.preferredTimingNote.trim();
    if (preferredTimingNote.isEmpty) {
      return '';
    }

    final displayedTimingNote = _resolveDisplayedPreferredTimingNote(
      reply: reply,
      requestRecord: requestRecord,
      isBookingLinkSubmission: isBookingLinkSubmission,
    );
    if (displayedTimingNote.isNotEmpty) {
      return '';
    }
    return isBookingLinkSubmission
        ? _cleanBookingLinkNotes(preferredTimingNote)
        : preferredTimingNote;
  }

  Future<void> _openBookingPhotosDialog(
    List<VanJobRequestPhoto> photos, {
    int initialIndex = 0,
  }) {
    if (photos.isEmpty) {
      return Future<void>.value();
    }
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var current = initialIndex.clamp(0, photos.length - 1);
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: const Color(0xFF0E1B2D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 620, maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Photo ${current + 1} of ${photos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photos[current].url,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.white.withValues(alpha: 0.06),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 28,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: current == 0
                                  ? null
                                  : () => setDialogState(() {
                                      current -= 1;
                                    }),
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('Previous'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: current >= photos.length - 1
                                  ? null
                                  : () => setDialogState(() {
                                      current += 1;
                                    }),
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: const Text('Next'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final requestRecord = DriverReplyMockState.instance.requestForJob(_jobId);
    final actionState = deriveVanJobActionState(reply, request: requestRecord);
    final hasExactPin =
        reply.exactPinSaved || (requestRecord?.hasExactPin ?? false);
    final readyToQuote = actionState.canCreateQuote;
    final replyAccent = reply.customerJourney.journeyTheme.accent;
    final scheduledAt = reply.scheduledAtOrParsed;
    final dateTimeLabel = scheduledAt != null
        ? formatDateTime(scheduledAt, TimeOfDay.fromDateTime(scheduledAt))
        : [
            sanitizeVanText(reply.jobDateLabel).trim(),
            sanitizeVanText(reply.jobTimeLabel).trim(),
          ].where((value) => value.isNotEmpty).join(' | ');
    final addressLabel = sanitizeVanText(reply.address).trim();
    final phoneLabel = sanitizeVanCustomerPhoneNumber(_contactPhone).trim();
    final requestSource = requestRecord?.source.trim().toLowerCase() ?? '';
    final preferredDate = requestRecord?.preferredDate ?? reply.preferredDate;
    final preferredTimeWindowRaw =
        requestRecord?.preferredTimeWindow.trim().isNotEmpty == true
        ? requestRecord!.preferredTimeWindow
        : reply.preferredTimeWindow;
    final preferredTimeLabel = _preferredTimeWindowLabel(
      preferredTimeWindowRaw,
    );
    final notesSummary = [
      sanitizeVanText(reply.notesMessage).trim().toLowerCase(),
      sanitizeVanText(reply.additionalNotes).trim().toLowerCase(),
    ].where((text) => text.isNotEmpty).join('\n');
    final hasBookingLinkSignalsFromRecord =
        requestRecord != null &&
        (requestRecord.answers.any((answer) => answer.hasAnswer) ||
            requestRecord.photos.any((photo) => photo.hasUrl) ||
            requestRecord.selectedServiceName.trim().isNotEmpty);
    final isBookingLinkSubmission =
        requestRecord?.isPreview == true ||
        requestSource == 'booking_link' ||
        requestSource == 'preview' ||
        hasBookingLinkSignalsFromRecord ||
        notesSummary.contains('source: booking link');
    final preferredIsFlexible =
        (requestRecord?.preferredIsFlexible ?? false) ||
        reply.preferredIsFlexible;
    final preferredTimingNote = _resolveDisplayedPreferredTimingNote(
      reply: reply,
      requestRecord: requestRecord,
      isBookingLinkSubmission: isBookingLinkSubmission,
    );
    final additionalCustomerNotes = _resolveDisplayedAdditionalNotes(
      reply: reply,
      requestRecord: requestRecord,
      isBookingLinkSubmission: isBookingLinkSubmission,
    );
    final hasPreferredTiming =
        preferredDate != null ||
        preferredTimeLabel.isNotEmpty ||
        preferredIsFlexible ||
        preferredTimingNote.isNotEmpty;
    if (kDebugMode) {
      debugPrint(
        '[IncomingRequestDetail.live] jobId=$_jobId requestId=${requestRecord?.requestId ?? '(none)'} source=${requestSource.isEmpty ? '(none)' : requestSource} isBookingLink=$isBookingLinkSubmission preferredDate=${preferredDate?.toIso8601String() ?? '(none)'} preferredTimeWindow=${preferredTimeLabel.isEmpty ? '(none)' : preferredTimeLabel} preferredIsFlexible=$preferredIsFlexible preferredTimingNote=${preferredTimingNote.isEmpty ? '(none)' : preferredTimingNote} hasPreferredTiming=$hasPreferredTiming',
      );
    }
    final visibleChecklistResponses = reply.checklistResponses
        .where(_isAnsweredChecklistResponse)
        .toList(growable: false);
    final bookingPhotos =
        (requestRecord?.photos ?? const <VanJobRequestPhoto>[])
            .where((photo) => photo.hasUrl)
            .toList(growable: false);
    final bookingAnswerCards = <Widget>[];
    if (isBookingLinkSubmission) {
      final selectedService = requestRecord?.selectedServiceName.trim() ?? '';
      final selectedServiceAnswer = selectedService.isNotEmpty
          ? selectedService
          : sanitizeVanText(reply.jobTitle).trim();
      if (selectedServiceAnswer.isNotEmpty) {
        bookingAnswerCards.add(
          _buildAnswerCard(
            icon: Icons.build_circle_outlined,
            question: 'Selected service',
            answer: selectedServiceAnswer,
          ),
        );
      }
      final requestAnswers =
          requestRecord?.answers
              .where((answer) => answer.hasAnswer)
              .toList(growable: false) ??
          const <VanJobRequestAnswer>[];
      if (requestAnswers.isNotEmpty) {
        for (final answer in requestAnswers) {
          bookingAnswerCards.add(
            _buildAnswerCard(
              icon: Icons.question_answer,
              question: answer.questionText.trim().isEmpty
                  ? 'Question'
                  : answer.questionText.trim(),
              answer: answer.answerValue.trim(),
            ),
          );
        }
      } else {
        final fallbackResponses = reply.customQuestionResponses
            .where((response) => response.answer.trim().isNotEmpty)
            .toList(growable: false);
        for (final response in fallbackResponses) {
          bookingAnswerCards.add(
            _buildAnswerCard(
              icon: Icons.question_answer,
              question: response.question.trim().isEmpty
                  ? 'Question'
                  : response.question.trim(),
              answer: response.answer.trim(),
            ),
          );
        }
      }
      if (additionalCustomerNotes.isNotEmpty) {
        bookingAnswerCards.add(
          _buildAnswerCard(
            icon: Icons.notes_outlined,
            question: 'Additional notes',
            answer: additionalCustomerNotes,
          ),
        );
      }
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + bottomPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReplyBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isBookingLinkSubmission
                            ? reply.customerJourney.copy.receivedHeading
                            : 'Customer reply received',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review the customer\'s answers before quoting or starting the job.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: replyAccent.withValues(alpha: 0.18),
                                    border: Border.all(
                                      color: replyAccent.withValues(
                                        alpha: 0.30,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.mark_email_read_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reply.customerName,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reply.jobTitle,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.92,
                                              ),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (isBookingLinkSubmission)
                                            _buildStatusChip(
                                              reply
                                                  .customerJourney
                                                  .copy
                                                  .receivedHeading,
                                              color: replyAccent,
                                              icon: reply
                                                  .customerJourney
                                                  .journeyTheme
                                                  .icon,
                                              filled: true,
                                            ),
                                          if (hasExactPin)
                                            _buildStatusChip(
                                              'Exact pin saved',
                                              color: const Color(0xFF58D0A4),
                                              icon: Icons.location_on,
                                              filled: true,
                                            ),
                                          if (readyToQuote)
                                            _buildStatusChip(
                                              'Ready to quote',
                                              color: const Color(0xFF58D0A4),
                                              icon:
                                                  Icons.request_quote_outlined,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (dateTimeLabel.isNotEmpty)
                                  _MiniInfoPill(
                                    icon: Icons.schedule,
                                    label: dateTimeLabel,
                                  ),
                                if (addressLabel.isNotEmpty)
                                  _MiniInfoPill(
                                    icon: Icons.location_on,
                                    label: addressLabel,
                                  ),
                                if (phoneLabel.isNotEmpty)
                                  _MiniInfoPill(
                                    icon: Icons.phone,
                                    label: phoneLabel,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isBookingLinkSubmission && hasPreferredTiming) ...[
                        const SizedBox(height: 12),
                        _ReplyGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ReplySectionHeader(
                                icon: Icons.schedule_outlined,
                                title: 'Preferred timing',
                              ),
                              const SizedBox(height: 12),
                              if (preferredDate != null)
                                _buildAnswerCard(
                                  icon: Icons.event_outlined,
                                  question: 'Preferred date',
                                  answer: formatDate(preferredDate),
                                ),
                              if (preferredTimeLabel.isNotEmpty) ...[
                                if (preferredDate != null)
                                  const SizedBox(height: 12),
                                _buildAnswerCard(
                                  icon: Icons.access_time_outlined,
                                  question: 'Preferred time',
                                  answer: preferredTimeLabel,
                                ),
                              ],
                              if (preferredDate != null ||
                                  preferredTimeLabel.isNotEmpty ||
                                  preferredIsFlexible) ...[
                                if (preferredDate != null ||
                                    preferredTimeLabel.isNotEmpty)
                                  const SizedBox(height: 12),
                                _buildAnswerCard(
                                  icon: Icons.swap_horiz_outlined,
                                  question: 'Flexible',
                                  answer: preferredIsFlexible ? 'Yes' : 'No',
                                ),
                              ],
                              if (preferredTimingNote.isNotEmpty) ...[
                                if (preferredDate != null ||
                                    preferredTimeLabel.isNotEmpty ||
                                    preferredIsFlexible)
                                  const SizedBox(height: 12),
                                _buildAnswerCard(
                                  icon: Icons.notes_outlined,
                                  question: 'Notes',
                                  answer: preferredTimingNote,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ReplySectionHeader(
                              icon: Icons.checklist,
                              title: 'Customer answers',
                            ),
                            const SizedBox(height: 12),
                            if (isBookingLinkSubmission &&
                                bookingAnswerCards.isEmpty)
                              Text(
                                'No answers submitted.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.45,
                                ),
                              )
                            else if (isBookingLinkSubmission)
                              for (
                                var index = 0;
                                index < bookingAnswerCards.length;
                                index++
                              ) ...[
                                bookingAnswerCards[index],
                                if (index < bookingAnswerCards.length - 1)
                                  const SizedBox(height: 12),
                              ]
                            else ...[
                              if (visibleChecklistResponses.isEmpty &&
                                  additionalCustomerNotes.isEmpty)
                                Text(
                                  'No checklist answers recorded yet.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    height: 1.45,
                                  ),
                                ),
                              for (
                                var index = 0;
                                index < visibleChecklistResponses.length;
                                index++
                              ) ...[
                                _buildAnswerCard(
                                  icon: visibleChecklistResponses[index].icon,
                                  question:
                                      visibleChecklistResponses[index].question,
                                  answer:
                                      visibleChecklistResponses[index].answer,
                                  note: visibleChecklistResponses[index].note,
                                ),
                                if (index <
                                        visibleChecklistResponses.length - 1 ||
                                    additionalCustomerNotes.isNotEmpty)
                                  const SizedBox(height: 12),
                              ],
                              if (additionalCustomerNotes.isNotEmpty)
                                _buildAnswerCard(
                                  icon: Icons.notes_outlined,
                                  question: 'Additional notes',
                                  answer: additionalCustomerNotes,
                                ),
                            ],
                          ],
                        ),
                      ),
                      if (!isBookingLinkSubmission &&
                          reply.customQuestionResponses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReplyGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ReplySectionHeader(
                                icon: Icons.question_answer,
                                title: 'Custom questions',
                              ),
                              const SizedBox(height: 12),
                              for (
                                var index = 0;
                                index < reply.customQuestionResponses.length;
                                index++
                              ) ...[
                                _buildAnswerCard(
                                  icon: Icons.question_answer,
                                  question: reply
                                      .customQuestionResponses[index]
                                      .question,
                                  answer: reply
                                      .customQuestionResponses[index]
                                      .answer,
                                ),
                                if (index <
                                    reply.customQuestionResponses.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (isBookingLinkSubmission &&
                          bookingPhotos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReplyGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ReplySectionHeader(
                                icon: Icons.photo_camera_outlined,
                                title: 'Photos',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bookingPhotos.length == 1
                                    ? '1 photo attached'
                                    : '${bookingPhotos.length} photos attached',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: bookingPhotos.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 1,
                                    ),
                                itemBuilder: (context, index) => InkWell(
                                  onTap: () => _openBookingPhotosDialog(
                                    bookingPhotos,
                                    initialIndex: index,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      bookingPhotos[index].url,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final buttons = <Widget>[
                            if (actionState.canCreateQuote)
                              FilledButton.icon(
                                onPressed: _createQuote,
                                icon: Icon(
                                  reply.customerJourney.journeyTheme.icon,
                                ),
                                label: Text(
                                  reply.customerJourney.copy.businessAction,
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A7DFF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              )
                            else if (actionState.canViewQuote)
                              FilledButton.icon(
                                onPressed: _createQuote,
                                icon: const Icon(Icons.request_quote_outlined),
                                label: const Text('View quote'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFF4A7DFF,
                                  ).withValues(alpha: 0.20),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            if (actionState.canAddToCalendar)
                              FilledButton.icon(
                                onPressed: () => unawaited(_markReady()),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Add to calendar'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF58D0A4),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            if (actionState.canCallCustomer)
                              OutlinedButton.icon(
                                onPressed: () => unawaited(_callCustomer()),
                                icon: const Icon(Icons.phone),
                                label: const Text('Call customer'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4A7DFF),
                                  side: BorderSide(
                                    color: const Color(
                                      0xFF4A7DFF,
                                    ).withValues(alpha: 0.42),
                                  ),
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            if (actionState.canTextCustomer)
                              OutlinedButton.icon(
                                onPressed: () => unawaited(_textCustomer()),
                                icon: const Icon(Icons.sms_outlined),
                                label: const Text('Text customer'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4A7DFF),
                                  side: BorderSide(
                                    color: const Color(
                                      0xFF4A7DFF,
                                    ).withValues(alpha: 0.42),
                                  ),
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                          ];

                          final buttonWidth = constraints.maxWidth < 520
                              ? constraints.maxWidth
                              : 220.0;

                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final button in buttons)
                                SizedBox(width: buttonWidth, child: button),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyBackButton extends StatelessWidget {
  const _ReplyBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ReplyGlassCard extends StatelessWidget {
  const _ReplyGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ReplySectionHeader extends StatelessWidget {
  const _ReplySectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  const _MiniInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverQuoteMockPage extends StatefulWidget {
  const DriverQuoteMockPage({super.key, required this.reply});

  final DriverCustomerReplyMockData reply;

  @override
  State<DriverQuoteMockPage> createState() => _DriverQuoteMockPageState();
}

class CreateQuotePage extends StatefulWidget {
  const CreateQuotePage({super.key, required this.reply});

  final DriverCustomerReplyMockData reply;

  @override
  State<CreateQuotePage> createState() => _CreateQuotePageState();
}

class _CreateQuotePageState extends State<CreateQuotePage>
    with WidgetsBindingObserver {
  late final TextEditingController _amountController;
  late final FocusNode _amountFocusNode;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quoteNotesController;
  late final TextEditingController _paymentInstructionsController;
  late final TextEditingController _proposedAppointmentNoteController;

  VanQuoteExtraSelections _selectedQuoteExtras =
      VanQuoteExtraSelections.empty();
  DateTime? _proposedAppointmentDate;
  TimeOfDay? _proposedAppointmentTime;
  int? _estimatedDurationSelection;

  late final bool _isRevisingQuote;
  String _businessName = '';
  String _lastValidAmountInput = '';
  String _quoteAmountInputError = '';
  bool _saved = false;
  bool _sent = false;
  bool _customerRequestExpanded = false;
  bool _messagePreviewExpanded = false;
  bool _openingSendChannel = false;
  bool _updatingAmountText = false;
  VanQuoteExtraDefaults _quoteExtraDefaults = VanQuoteExtraDefaults.defaults();
  VanJobService? _selectedQuoteService;
  String _activeQuoteExtraDefaultsScopeKey = '';

  DriverCustomerReplyMockData get reply =>
      resolveVanQuoteWorkflowReply(widget.reply);
  String get _jobId => widget.reply.jobId;
  VanJobRequestRecord? get _requestRecord =>
      DriverReplyMockState.instance.requestForJob(_jobId);
  bool get _isAlreadyInCalendar {
    final normalizedCalendarStatus = reply.calendarStatus.trim().toLowerCase();
    return reply.isConfirmed ||
        normalizedCalendarStatus == 'scheduled' ||
        normalizedCalendarStatus == 'completed';
  }

  bool get _hasRealRequestReply {
    if (reply.hasCustomerReply) {
      return true;
    }

    final request = _requestRecord;
    return request?.hasCustomerReply ?? false;
  }

  bool get _isBookingLinkQuote {
    final request = _requestRecord;
    final source = request?.source.trim().toLowerCase() ?? '';
    return request?.isPreview == true ||
        source == 'booking_link' ||
        source == 'preview';
  }

  bool get _requiresProposedAppointment => _isBookingLinkQuote;

  Iterable<VanInvoiceReplyAnswer> _suggestionChecklistResponses() {
    if (reply.checklistResponses.isNotEmpty) {
      return reply.checklistResponses.map(
        (response) => VanInvoiceReplyAnswer(
          question: response.question,
          answer: response.answer,
          note: response.note ?? '',
        ),
      );
    }

    final request = _requestRecord;
    if (request == null) {
      return const <VanInvoiceReplyAnswer>[];
    }

    return request.checklistResponses.map(
      (response) => VanInvoiceReplyAnswer(
        question: response.question,
        answer: response.answer,
        note: response.note,
      ),
    );
  }

  Iterable<VanInvoiceReplyAnswer> _suggestionCustomResponses() {
    if (reply.customQuestionResponses.isNotEmpty) {
      return reply.customQuestionResponses.map(
        (response) => VanInvoiceReplyAnswer(
          question: response.question,
          answer: response.answer,
        ),
      );
    }

    final request = _requestRecord;
    if (request == null) {
      return const <VanInvoiceReplyAnswer>[];
    }

    if (request.answers.isNotEmpty) {
      return request.answers
          .where((item) => item.hasAnswer)
          .map(
            (answer) => VanInvoiceReplyAnswer(
              question: answer.questionText.trim().isEmpty
                  ? 'Question'
                  : answer.questionText.trim(),
              answer: answer.answerValue.trim(),
            ),
          );
    }

    return request.customQuestionResponses.map(
      (response) => VanInvoiceReplyAnswer(
        question: response.question,
        answer: response.answer,
      ),
    );
  }

  Set<String> get _suggestedExtraKeys {
    return buildSuggestedInvoiceExtraKeys(
      checklistResponses: _suggestionChecklistResponses(),
      customQuestionResponses: _suggestionCustomResponses(),
      jobTitle: reply.jobTitle,
      jobDescription: _descriptionController.text,
      additionalNotes: reply.additionalNotes,
      quoteNotes: _quoteNotesController.text,
      quoteMessage: _quotePreviewText(),
    );
  }

  @override
  void initState() {
    super.initState();
    _isRevisingQuote = reply.isQuoteDeclined;
    WidgetsBinding.instance.addObserver(this);
    DriverReplyMockState.instance.addListener(_handleDriverStateChanged);
    VanQuoteExtraDefaultsStorage.instance.addListener(
      _handleQuoteExtraDefaultsChanged,
    );
    VanJobServicesStorage.instance.addListener(
      _handleQuoteExtraDefaultsChanged,
    );
    _saved = _deriveSavedQuoteFlag(reply);
    _sent = _deriveSentQuoteFlag(reply);
    _amountController = TextEditingController(
      text: reply.quoteAmount?.toStringAsFixed(2) ?? '',
    );
    _lastValidAmountInput = normalizeCurrencyInput(_amountController.text);
    _amountController.addListener(_enforceQuoteAmountEditingRules);
    _amountFocusNode = FocusNode()..addListener(_handleAmountFocusChanged);
    _descriptionController = TextEditingController(
      text: reply.quoteJobDescription.trim().isNotEmpty
          ? reply.quoteJobDescription
          : reply.jobTitle,
    );
    _quoteNotesController = TextEditingController(text: reply.quoteNotes);
    _paymentInstructionsController = TextEditingController(
      text: reply.quotePaymentInstructions.trim().isNotEmpty
          ? reply.quotePaymentInstructions
          : kVanMatePaymentInstructionsFallback,
    );
    _proposedAppointmentNoteController = TextEditingController(
      text: reply.proposedAppointmentNote,
    );
    final existingProposedAt =
        reply.proposedScheduledAt ??
        _parseIsoDateAndTime(reply.proposedDate, reply.proposedStartTime) ??
        _parseIsoDateAndTime(
          reply.acceptedProposedDate,
          reply.acceptedProposedStartTime,
        ) ??
        reply.scheduledAtOrParsed;
    if (existingProposedAt != null) {
      _proposedAppointmentDate = DateUtils.dateOnly(existingProposedAt);
      _proposedAppointmentTime = TimeOfDay.fromDateTime(existingProposedAt);
    } else if (_requiresProposedAppointment) {
      final now = DateTime.now();
      final preferredDate =
          _requestRecord?.preferredDate ?? reply.preferredDate;
      _proposedAppointmentDate = DateUtils.dateOnly(preferredDate ?? now);
      _proposedAppointmentTime = _defaultProposedTime();
    }
    _estimatedDurationSelection = reply.estimatedDurationMinutes ?? 60;
    unawaited(_loadSavedPaymentInstructions());
    unawaited(_loadQuoteExtraDefaults());
  }

  @override
  void dispose() {
    VanQuoteExtraDefaultsStorage.instance.removeListener(
      _handleQuoteExtraDefaultsChanged,
    );
    VanJobServicesStorage.instance.removeListener(
      _handleQuoteExtraDefaultsChanged,
    );
    DriverReplyMockState.instance.removeListener(_handleDriverStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _amountController.removeListener(_enforceQuoteAmountEditingRules);
    _amountController.dispose();
    _amountFocusNode
      ..removeListener(_handleAmountFocusChanged)
      ..dispose();
    _descriptionController.dispose();
    _quoteNotesController.dispose();
    _paymentInstructionsController.dispose();
    _proposedAppointmentNoteController.dispose();
    super.dispose();
  }

  void _handleDriverStateChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _saved = _deriveSavedQuoteFlag(reply);
      _sent = _deriveSentQuoteFlag(reply);
    });
  }

  void _handleQuoteExtraDefaultsChanged() {
    unawaited(_loadQuoteExtraDefaults(preferLocal: true));
  }

  bool _deriveSavedQuoteFlag(DriverCustomerReplyMockData value) {
    return value.hasQuote &&
        !value.isQuoteSent &&
        !value.isQuoteAccepted &&
        !value.isQuoteDeclined;
  }

  bool _deriveSentQuoteFlag(DriverCustomerReplyMockData value) {
    return value.hasQuote &&
        (value.isQuoteSent ||
            value.isQuoteAwaitingCustomerResponse ||
            value.isQuoteAccepted ||
            value.isQuoteDeclined);
  }

  Future<void> _loadSavedPaymentInstructions() async {
    try {
      final profile = await VanBusinessProfileStorage.instance
          .loadCanonicalProfile();
      if (!mounted) {
        return;
      }

      setState(() {
        _businessName = sanitizeVanText(profile.businessName).trim();
        _paymentInstructionsController.text = resolveVanMatePaymentInstructions(
          profile.paymentInstructions,
        );
      });
    } catch (error) {
      debugPrint('[QuotePaymentInstructions] profile load failed: $error');
    }
  }

  Future<VanQuoteExtraDefaults?> _loadQuoteExtraDefaultsFromStorage({
    bool preferLocal = false,
    String serviceKey = '',
    String serviceName = '',
  }) async {
    try {
      if (serviceKey.trim().isNotEmpty || serviceName.trim().isNotEmpty) {
        return await VanQuoteExtraDefaultsStorage.instance.loadForService(
          serviceKey: serviceKey,
          serviceName: serviceName,
          preferLocal: preferLocal,
        );
      }
      return await VanQuoteExtraDefaultsStorage.instance.load(
        preferLocal: preferLocal,
      );
    } catch (error) {
      debugPrint('[QuoteExtras] load failed: $error');
      return null;
    }
  }

  Future<void> _loadQuoteExtraDefaults({bool preferLocal = false}) async {
    final request = _requestRecord;
    final selectedServiceId = request?.selectedServiceId.trim() ?? '';
    final selectedServiceName = request?.selectedServiceName.trim() ?? '';
    final selectedService = await _loadSelectedQuoteService();
    if (selectedService != null) {
      if (!mounted) {
        return;
      }
      _applyLoadedQuoteExtraDefaults(
        defaults: selectedService.quoteExtraDefaults,
        selectedService: selectedService,
        scopeKey: _quoteExtraDefaultsScopeKey(
          serviceKey: selectedService.id,
          serviceName: selectedService.name,
        ),
      );
      return;
    }

    if (selectedServiceId.isNotEmpty || selectedServiceName.isNotEmpty) {
      final defaults = await _loadQuoteExtraDefaultsFromStorage(
        preferLocal: preferLocal,
        serviceKey: selectedServiceId,
        serviceName: selectedServiceName,
      );
      if (!mounted) {
        return;
      }
      _applyLoadedQuoteExtraDefaults(
        defaults:
            defaults ??
            VanQuoteExtraDefaults.starterForServiceName(selectedServiceName),
        selectedService: null,
        scopeKey: _quoteExtraDefaultsScopeKey(
          serviceKey: selectedServiceId,
          serviceName: selectedServiceName,
        ),
      );
      return;
    }

    final defaults = await _loadQuoteExtraDefaultsFromStorage(
      preferLocal: preferLocal,
    );
    if (defaults == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    _applyLoadedQuoteExtraDefaults(
      defaults: defaults,
      selectedService: null,
      scopeKey: _quoteExtraDefaultsScopeKey(),
    );
  }

  void _applyLoadedQuoteExtraDefaults({
    required VanQuoteExtraDefaults defaults,
    required VanJobService? selectedService,
    required String scopeKey,
  }) {
    final scopeChanged = _activeQuoteExtraDefaultsScopeKey != scopeKey;
    setState(() {
      _selectedQuoteService = selectedService;
      _quoteExtraDefaults = defaults;
      _activeQuoteExtraDefaultsScopeKey = scopeKey;
      if (scopeChanged) {
        _selectedQuoteExtras = VanQuoteExtraSelections.empty();
      }
    });
  }

  Future<VanJobService?> _loadSelectedQuoteService() async {
    final request = _requestRecord;
    final selectedServiceId = request?.selectedServiceId.trim() ?? '';
    final selectedServiceName = request?.selectedServiceName.trim() ?? '';
    if (selectedServiceId.isEmpty && selectedServiceName.isEmpty) {
      return null;
    }

    try {
      final services = await VanJobServicesStorage.instance.loadAll();
      if (selectedServiceId.isNotEmpty) {
        final match = services
            .where((service) => service.id.trim() == selectedServiceId)
            .firstOrNull;
        if (match != null) {
          return match;
        }
        return null;
      }

      final normalizedServiceName = _normalizeQuoteServiceName(
        selectedServiceName,
      );
      if (normalizedServiceName.isEmpty) {
        return null;
      }
      return services
          .where(
            (service) =>
                _normalizeQuoteServiceName(service.name) ==
                normalizedServiceName,
          )
          .firstOrNull;
    } catch (error) {
      debugPrint('[QuoteExtras] service lookup failed: $error');
      return null;
    }
  }

  String _normalizeQuoteServiceName(String value) {
    return sanitizeVanText(
      value,
    ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _quoteExtraDefaultsScopeKey({
    String serviceKey = '',
    String serviceName = '',
  }) {
    final rawKey = serviceKey.trim().isNotEmpty
        ? serviceKey.trim()
        : serviceName.trim();
    if (rawKey.isEmpty) {
      return 'global';
    }
    final normalized = rawKey
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'global' : 'service:$normalized';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        DriverReplyMockState.instance.refreshJobsFromCloud(forceServer: true),
      );
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _handleAmountFocusChanged() {
    if (_amountFocusNode.hasFocus) {
      return;
    }
    _applyFormattedQuoteAmountIfValid();
  }

  void _enforceQuoteAmountEditingRules() {
    if (_updatingAmountText) {
      return;
    }

    final normalized = normalizeCurrencyInput(_amountController.text);
    if (normalized.isEmpty) {
      _lastValidAmountInput = '';
      _setQuoteAmountInputError('');
      _clearQuoteExtrasIfDisabled();
      return;
    }

    if (RegExp(r'^\d{0,5}(\.\d{0,2})?$').hasMatch(normalized)) {
      _lastValidAmountInput = normalized;
      _setQuoteAmountInputError('');
      if (normalized != _amountController.text) {
        _replaceAmountText(normalized);
      }
      if (!_canUseQuoteExtras) {
        _clearQuoteExtrasIfDisabled();
      }
      return;
    }

    final numericValue = double.tryParse(normalized) ?? 0;
    _setQuoteAmountInputError(
      numericValue > kVanMateMaxQuoteAmount ||
              RegExp(r'^\d{6,}').hasMatch(normalized)
          ? 'Quote amount is too high.'
          : 'Enter a valid quote amount.',
    );
    _replaceAmountText(_lastValidAmountInput);
    _clearQuoteExtrasIfDisabled();
  }

  void _replaceAmountText(String value) {
    _updatingAmountText = true;
    _amountController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _updatingAmountText = false;
  }

  void _setQuoteAmountInputError(String value) {
    if (_quoteAmountInputError == value) {
      return;
    }
    setState(() {
      _quoteAmountInputError = value;
    });
  }

  void _applyFormattedQuoteAmountIfValid() {
    final error = validateVanMateQuoteAmountInput(
      _amountController.text,
      allowEmpty: true,
    );
    if (error != null) {
      return;
    }
    final amount = parseCurrencyValue(_amountController.text);
    if (amount <= 0) {
      return;
    }
    final formatted = formatCurrencyInputValue(amount);
    if (_amountController.text == formatted) {
      return;
    }
    _lastValidAmountInput = normalizeCurrencyInput(formatted);
    _replaceAmountText(formatted);
  }

  TimeOfDay _defaultProposedTime() {
    final preferredWindow =
        (_requestRecord?.preferredTimeWindow.isNotEmpty == true
                ? _requestRecord!.preferredTimeWindow
                : reply.preferredTimeWindow)
            .trim()
            .toLowerCase();
    switch (preferredWindow) {
      case 'morning':
        return const TimeOfDay(hour: 9, minute: 0);
      case 'afternoon':
        return const TimeOfDay(hour: 13, minute: 0);
      case 'evening':
        return const TimeOfDay(hour: 18, minute: 0);
      default:
        return const TimeOfDay(hour: 10, minute: 0);
    }
  }

  String _formatIsoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTwentyFourHour(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _proposedDateLabel() {
    final date = _proposedAppointmentDate;
    if (date == null) {
      return 'Choose date';
    }
    return formatDate(date);
  }

  String _proposedTimeLabel() {
    final time = _proposedAppointmentTime;
    if (time == null) {
      return 'Choose time';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _estimatedDurationLabel() {
    return _durationLabel(_estimatedDurationSelection);
  }

  String _durationLabel(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return 'Not set';
    }
    switch (minutes) {
      case 30:
        return '30m';
      case 60:
        return '1h';
      case 120:
        return '2h';
      case 240:
        return 'Half day';
      default:
        return '${minutes}m';
    }
  }

  DateTime? _proposedAppointmentDateTime() {
    final date = _proposedAppointmentDate;
    final time = _proposedAppointmentTime;
    if (date == null || time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  VanScheduleOverlap? _proposedAppointmentOverlap() {
    final proposedAt = _proposedAppointmentDateTime();
    if (proposedAt == null) {
      return null;
    }
    return DriverReplyMockState.instance.findScheduleOverlap(
      ignoringJobId: _jobId,
      scheduledAt: proposedAt,
      estimatedDurationMinutes: _estimatedDurationSelection ?? 60,
    );
  }

  String _quoteOverlapWarning(VanScheduleOverlap overlap) {
    final startLabel = DriverReplyMockState.instance._formatJobTime(
      TimeOfDay.fromDateTime(overlap.start),
    );
    final endLabel = DriverReplyMockState.instance._formatJobTime(
      TimeOfDay.fromDateTime(overlap.end),
    );
    final conflictLabel = overlap.customerName.trim().isNotEmpty
        ? overlap.customerName.trim()
        : (overlap.jobTitle.trim().isNotEmpty
              ? overlap.jobTitle.trim()
              : 'existing booking');
    return 'This appointment overlaps an existing booking. Choose another time before sending the quote. Overlaps $conflictLabel from $startLabel to $endLabel.';
  }

  bool _blockIfProposedAppointmentOverlaps() {
    final overlap = _proposedAppointmentOverlap();
    if (overlap == null) {
      return false;
    }
    _showSnack(_quoteOverlapWarning(overlap));
    return true;
  }

  bool _blockIfProposedAppointmentIsInPast() {
    final proposedAt = _proposedAppointmentDateTime();
    if (proposedAt == null) {
      return false;
    }
    final message = validateVanMateScheduledAt(proposedAt);
    if (message == null) {
      return false;
    }
    _showSnack(message);
    return true;
  }

  Future<void> _pickProposedDate() async {
    final now = DateTime.now();
    final initialDate =
        _proposedAppointmentDate ?? _requestRecord?.preferredDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _proposedAppointmentDate = DateUtils.dateOnly(picked);
    });
  }

  Future<void> _pickProposedTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _proposedAppointmentTime ?? _defaultProposedTime(),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _proposedAppointmentTime = picked;
    });
  }

  Future<void> _pickEstimatedDuration() async {
    final picked = await showVanDurationPickerSheet(
      context: context,
      initialMinutes: _estimatedDurationSelection ?? 60,
      durationLabel: _durationLabel,
      title: 'Choose duration',
    );
    if (picked == null || picked <= 0 || !mounted) {
      return;
    }
    setState(() {
      _estimatedDurationSelection = picked;
    });
  }

  Future<void> _sendQuote() async {
    if (_openingSendChannel) {
      return;
    }
    _applyFormattedQuoteAmountIfValid();
    final amountError = _quoteAmountValidationMessage();
    if (amountError != null) {
      _showSnack(amountError);
      return;
    }
    setState(() {
      _openingSendChannel = true;
    });
    final amount = _currentQuoteAmount();
    if (amount >= kVanMateHighQuoteAmountWarningThreshold) {
      final confirmed = await _confirmHighQuoteAmount(amount);
      if (!confirmed) {
        if (mounted) {
          setState(() => _openingSendChannel = false);
        }
        return;
      }
    }
    if (_requiresProposedAppointment &&
        (_proposedAppointmentDate == null ||
            _proposedAppointmentTime == null)) {
      _showSnack('Choose an exact proposed appointment before sending.');
      setState(() => _openingSendChannel = false);
      return;
    }
    if (_blockIfProposedAppointmentIsInPast()) {
      setState(() => _openingSendChannel = false);
      return;
    }
    if (_blockIfProposedAppointmentOverlaps()) {
      setState(() => _openingSendChannel = false);
      return;
    }

    final customerQuoteLink = DriverReplyMockState.instance
        .resolveQuoteResponseLinkForJob(
          reply,
          creatingFreshQuote: reply.isQuoteDeclined,
        );
    if (!isCompleteVanQuoteResponseLink(customerQuoteLink)) {
      _showSnack(
        'Could not create a valid customer quote link. Quote was not sent.',
      );
      setState(() => _openingSendChannel = false);
      return;
    }
    final message = _quotePreviewText(quoteResponseLink: customerQuoteLink);
    final notes = _quoteNotesController.text.trim();
    final instructions = resolveVanMatePaymentInstructions(
      _paymentInstructionsController.text,
    );
    final extraItems = _quoteExtraItemsForPayload();
    final proposedDate = _proposedAppointmentDate == null
        ? ''
        : _formatIsoDate(_proposedAppointmentDate!);
    final proposedStartTime = _proposedAppointmentTime == null
        ? ''
        : _formatTwentyFourHour(_proposedAppointmentTime!);
    final durationMinutes = _estimatedDurationSelection;
    final proposedAppointmentNote = _proposedAppointmentNoteController.text
        .trim();
    final quotePublishKey =
        '${_jobId.trim()}:${DateTime.now().microsecondsSinceEpoch}';
    final publicQuoteData = <String, dynamic>{
      'jobDescription': _descriptionController.text.trim(),
      'quoteMessage': message,
      'quoteResponseLink': customerQuoteLink,
      'quoteNotes': notes,
      'paymentInstructions': instructions,
      'businessName': _businessName,
      'quoteExtras': extraItems,
      'quoteAmountText': formatCurrency(amount),
      'proposedDate': proposedDate,
      'proposedStartTime': proposedStartTime,
      'estimatedDurationMinutes': durationMinutes,
      'proposedAppointmentNote': proposedAppointmentNote,
      'quotePublishKey': quotePublishKey,
      'schedulingStatus':
          proposedDate.isNotEmpty && proposedStartTime.isNotEmpty
          ? 'proposed_time'
          : '',
    };
    final cleanedPhone = sanitizeVanCustomerPhoneNumber(reply.phoneNumber);
    final cleanedEmail = reply.customerEmail.trim();
    final mode = cleanedPhone.isNotEmpty
        ? 'sms'
        : (cleanedEmail.isNotEmpty ? 'email' : 'share');
    debugPrint(
      '[QuoteSend] customerPhone=$cleanedPhone customerEmail=$cleanedEmail mode=$mode',
    );
    var quotePublished = false;
    try {
      await DriverReplyMockState.instance.setQuoteSent(
        true,
        jobId: _jobId,
        amount: amount,
        publicQuoteData: publicQuoteData,
        proposedDate: proposedDate,
        proposedStartTime: proposedStartTime,
        estimatedDurationMinutes: durationMinutes,
        proposedAppointmentNote: proposedAppointmentNote,
        schedulingStatus:
            proposedDate.isNotEmpty && proposedStartTime.isNotEmpty
            ? 'proposed_time'
            : '',
      );
      quotePublished = true;
      if (!mounted) {
        return;
      }
      final publishedQuote = DriverReplyMockState.instance.jobById(_jobId);
      final publishedQuoteLink = publishedQuote?.activeQuoteResponseLink ?? '';
      if (!isCompleteVanQuoteResponseLink(publishedQuoteLink) ||
          publishedQuoteLink != customerQuoteLink) {
        _showSnack(
          'Could not verify the customer quote link. Messages was not opened.',
        );
        return;
      }
      setState(() {
        _saved = true;
        _sent = true;
      });

      var handoffOpened = false;
      if (cleanedPhone.isNotEmpty) {
        final smsUri = Uri(
          scheme: 'sms',
          path: cleanedPhone,
          queryParameters: <String, String>{'body': message},
        );
        handoffOpened = await launchUrl(
          smsUri,
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) {
          return;
        }
        if (handoffOpened) {
          _showSnack('Quote opened for sending.');
        }
      } else if (cleanedEmail.isNotEmpty) {
        final emailUri = Uri.parse(
          'mailto:$cleanedEmail?subject=${Uri.encodeComponent('Van Mate quote')}&body=${Uri.encodeComponent(message)}',
        );
        handoffOpened = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) {
          return;
        }
        if (handoffOpened) {
          _showSnack('Quote opened for sending.');
        }
      } else {
        await shareRequestMessage(message);
        if (!mounted) {
          return;
        }
        handoffOpened = true;
        _showSnack('Quote shared.');
      }

      if (!handoffOpened &&
          (cleanedPhone.isNotEmpty || cleanedEmail.isNotEmpty)) {
        if (!mounted) {
          return;
        }
        _showSnack('Could not open quote in Messages or email.');
      }
    } catch (error, stackTrace) {
      debugPrint('[QuoteSend] publish or handoff failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showSnack(
          quotePublished
              ? 'Quote published, but the message could not be opened. Please try again.'
              : 'Could not publish the customer quote link. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingSendChannel = false;
        });
      }
    }
  }

  Future<void> _openQuoteLink() async {
    final link = reply.activeQuoteResponseLink;
    final uri = Uri.tryParse(link);
    if (uri == null) {
      _showSnack('Could not open the quote.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) {
      return;
    }
    _showSnack('Could not open the quote.');
  }

  void _copyQuoteLink() {
    final link = DriverReplyMockState.instance.resolveQuoteResponseLinkForJob(
      reply,
      creatingFreshQuote: reply.isQuoteDeclined,
    );
    Clipboard.setData(ClipboardData(text: link));
    _showSnack('Quote link copied.');
  }

  Future<void> _shareQuoteMessage(String message) async {
    if (_blockIfProposedAppointmentIsInPast()) {
      return;
    }
    if (_blockIfProposedAppointmentOverlaps()) {
      return;
    }
    await shareRequestMessage(message);
    if (!mounted) {
      return;
    }
    _showSnack('Quote message shared.');
  }

  Future<void> _addAcceptedQuoteToCalendar() async {
    if (_isAlreadyInCalendar) {
      _showSnack('This job is already in your calendar.');
      return;
    }
    final scheduledAt = effectiveAgreedSchedulingTimeForJob(
      reply,
      request: _requestRecord,
    );
    if (reply.isQuoteAccepted &&
        reply.requiresAnyExactPin &&
        !reply.exactPinSaved) {
      _showSnack(
        'Wait for the exact pickup or drop-off pin before adding this job to the calendar.',
      );
      return;
    }
    if (scheduledAt == null || reply.isAwaitingAgreedTime) {
      _showSnack(
        'Set an exact agreed time before adding this job to the calendar.',
      );
      return;
    }
    final pastScheduleMessage = validateVanMateScheduledAt(scheduledAt);
    if (pastScheduleMessage != null) {
      _showSnack(pastScheduleMessage);
      return;
    }
    final durationMinutes =
        reply.estimatedDurationMinutes ?? _estimatedDurationSelection ?? 60;
    final schedulingStatus = reply.schedulingStatus.trim().isNotEmpty
        ? reply.schedulingStatus
        : 'accepted_time';
    final bool persisted;
    try {
      persisted = await DriverReplyMockState.instance.persistScheduledJob(
        jobId: _jobId,
        scheduledAt: scheduledAt,
        estimatedDurationMinutes: durationMinutes,
        schedulingStatus: schedulingStatus,
      );
    } on VanScheduleOverlapException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message);
      return;
    } on VanPastScheduleException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message);
      return;
    }
    if (!persisted) {
      if (!mounted) {
        return;
      }
      _showSnack('Could not save this job to Calendar. Please try again.');
      return;
    }
    try {
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[QuoteAddToCalendar] refresh failed: $error\n$stackTrace');
    }
    if (!mounted) {
      return;
    }
    _showSnack('Added to your calendar.');
  }

  void _copyMessage() {
    _applyFormattedQuoteAmountIfValid();
    final amountError = _quoteAmountValidationMessage();
    if (amountError != null) {
      _showSnack(amountError);
      return;
    }
    if (_blockIfProposedAppointmentOverlaps()) {
      return;
    }
    Clipboard.setData(ClipboardData(text: _quotePreviewText()));
    _showSnack('Quote message copied.');
  }

  List<String> _quoteExtraItemsForPayload() {
    if (!_canUseQuoteExtras) {
      return const <String>[];
    }
    return _selectedQuoteExtras.quoteExtras;
  }

  Future<void> _handleQuickExtraTap(VanQuoteExtraDefault extra) async {
    if (!_canUseQuoteExtras) {
      return;
    }

    if (isQuantityVanQuoteExtraKey(extra.key)) {
      await _openQuantityExtraEditor(extra);
      return;
    }

    if (extra.key == kVanQuoteExtraCustomKey) {
      await _openCustomExtraEditor(extra);
      return;
    }

    final next = _selectedQuoteExtras.toggleFixed(extra);
    _applyQuoteExtraSelection(next);
  }

  void _applyQuoteExtraSelection(VanQuoteExtraSelections next) {
    if (!_canUseQuoteExtras) {
      return;
    }
    final delta = next.total - _selectedQuoteExtras.total;
    setState(() {
      _selectedQuoteExtras = next;
    });
    _addAmountDeltaToQuote(delta);
  }

  void _addAmountDeltaToQuote(double delta) {
    if (delta == 0) {
      return;
    }
    final nextAmount = _currentQuoteAmount() + delta;
    if (nextAmount < 0) {
      _replaceAmountText('');
      _lastValidAmountInput = '';
      return;
    }
    if (nextAmount > kVanMateMaxQuoteAmount) {
      _showSnack('Quote amount is too high.');
      return;
    }
    final formatted = formatCurrencyInputValue(nextAmount);
    _lastValidAmountInput = normalizeCurrencyInput(formatted);
    _replaceAmountText(formatted);
  }

  Future<void> _openQuantityExtraEditor(VanQuoteExtraDefault extra) async {
    final existing = _selectedQuoteExtras.selectionForKey(extra.key);
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _QuoteQuantityExtraSheet(
        extra: extra,
        initialQuantity: existing?.quantity,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    _applyQuoteExtraSelection(
      _selectedQuoteExtras.applyQuantity(extra: extra, quantity: result),
    );
  }

  Future<void> _openCustomExtraEditor(VanQuoteExtraDefault extra) async {
    final existing = _selectedQuoteExtras.selectionForKey(extra.key);
    final result = await showModalBottomSheet<_QuoteCustomExtraResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _QuoteCustomExtraSheet(
        extra: extra,
        initialLabel: existing?.label,
        initialPrice: existing?.amount,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    _applyQuoteExtraSelection(
      _selectedQuoteExtras.applyCustom(
        extra: extra,
        label: result.label,
        price: result.price,
      ),
    );
  }

  Future<void> _openQuoteExtraSettings() async {
    final quoteService = _selectedQuoteService;
    final request = _requestRecord;
    final selectedServiceKey =
        request?.selectedServiceId.trim() ?? quoteService?.id.trim() ?? '';
    final selectedServiceName =
        request?.selectedServiceName.trim() ?? quoteService?.name.trim() ?? '';
    final hasSelectedServiceScope =
        selectedServiceKey.isNotEmpty || selectedServiceName.isNotEmpty;
    final serviceTitle = selectedServiceName.isNotEmpty
        ? selectedServiceName
        : quoteService?.name.trim() ?? '';
    final updated = await Navigator.of(context).push<VanQuoteExtraDefaults>(
      PageRouteBuilder<VanQuoteExtraDefaults>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        barrierLabel: 'Saved extras',
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return Material(
            type: MaterialType.transparency,
            child: FractionallySizedBox(
              widthFactor: 1,
              alignment: Alignment.bottomCenter,
              child: VanQuoteExtraDefaultsSheet(
                initialDefaults: _quoteExtraDefaults,
                resetDefaults: hasSelectedServiceScope
                    ? findVanServiceTemplateForService(
                            serviceId: selectedServiceKey,
                            serviceName: selectedServiceName,
                          )?.quoteExtraDefaults() ??
                          VanQuoteExtraDefaults.empty()
                    : null,
                title: !hasSelectedServiceScope
                    ? 'Saved extras'
                    : '${serviceTitle.isEmpty ? 'Service' : serviceTitle} extras',
                description: !hasSelectedServiceScope
                    ? 'Set the quick extra labels and amounts used when building quotes.'
                    : 'Set the quote extras shown for this service.',
              ),
            ),
          );
        },
        transitionsBuilder:
            (routeContext, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
      ),
    );
    if (!mounted) {
      return;
    }

    if (updated != null) {
      if (hasSelectedServiceScope) {
        final updatedService = quoteService?.copyWith(
          quoteExtraDefaults: updated,
          updatedAt: DateTime.now(),
        );
        if (quoteService != null) {
          await VanJobServicesStorage.instance.upsert(updatedService!);
        }
        await VanQuoteExtraDefaultsStorage.instance.saveForService(
          serviceKey: selectedServiceKey,
          serviceName: selectedServiceName,
          defaults: updated,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedQuoteService = updatedService;
          _quoteExtraDefaults = updated;
          _activeQuoteExtraDefaultsScopeKey = _quoteExtraDefaultsScopeKey(
            serviceKey: selectedServiceKey,
            serviceName: selectedServiceName,
          );
        });
        _showSnack(
          '${serviceTitle.isEmpty ? 'Service' : serviceTitle} extras updated.',
        );
        return;
      }
      await VanQuoteExtraDefaultsStorage.instance.save(updated);
      if (!mounted) {
        return;
      }
    }

    final refreshed = await _loadQuoteExtraDefaultsFromStorage(
      preferLocal: updated != null,
      serviceKey: selectedServiceKey,
      serviceName: selectedServiceName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _quoteExtraDefaults = refreshed ?? updated ?? _quoteExtraDefaults;
      _activeQuoteExtraDefaultsScopeKey = _quoteExtraDefaultsScopeKey(
        serviceKey: selectedServiceKey,
        serviceName: selectedServiceName,
      );
    });
    if (updated != null) {
      _showSnack('Saved extras updated.');
    }
  }

  String _amountValue() {
    return _amountController.text.trim();
  }

  double _currentQuoteAmount() => parseCurrencyValue(_amountValue());

  bool get _canUseQuoteExtras =>
      _quoteAmountValidationMessage() == null && _currentQuoteAmount() > 0;

  void _clearQuoteExtrasIfDisabled() {
    if (_canUseQuoteExtras || _selectedQuoteExtras.isEmpty) {
      return;
    }

    setState(() {
      _selectedQuoteExtras = VanQuoteExtraSelections.empty();
    });
  }

  String? _quoteAmountValidationMessage({bool allowEmpty = false}) {
    return validateVanMateQuoteAmountInput(
      _amountValue(),
      allowEmpty: allowEmpty,
    );
  }

  bool _hasValidQuoteAmount() => _quoteAmountValidationMessage() == null;

  bool _showsHighQuoteAmountWarning() {
    if (!_hasValidQuoteAmount()) {
      return false;
    }
    return _currentQuoteAmount() >= kVanMateHighQuoteAmountWarningThreshold;
  }

  Future<bool> _confirmHighQuoteAmount(double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send high quote amount?'),
        content: Text(
          'This quote is ${formatCurrency(amount)}. Double-check the amount before sending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Review amount'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send quote'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _formatQuoteAppointmentDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} at ${_formatTwentyFourHour(TimeOfDay.fromDateTime(dateTime))}';
  }

  String _quotePreviewText({String? quoteResponseLink}) {
    final jobDescription = _descriptionController.text.trim().isNotEmpty
        ? sanitizeVanText(_descriptionController.text).trim()
        : sanitizeVanText(reply.jobTitle).trim();
    final quoteAmountValue = _currentQuoteAmount();
    final proposedDateTime = _proposedAppointmentDateTime();
    return buildVanQuoteMessage(
      customerName: reply.customerName,
      jobTitle: jobDescription,
      quoteAmountText: formatCurrency(quoteAmountValue),
      quoteResponseLink: quoteAmountValue > 0
          ? (quoteResponseLink ??
                DriverReplyMockState.instance.resolveQuoteResponseLinkForJob(
                  reply,
                  creatingFreshQuote: reply.isQuoteDeclined,
                ))
          : '',
      businessName: _resolvedBusinessName(),
      proposedAppointmentText: proposedDateTime == null
          ? ''
          : _formatQuoteAppointmentDateTime(proposedDateTime),
    );
  }

  String _quotePreviewDisplayText(String message) {
    return message;
  }

  String _resolvedBusinessName() {
    final cleaned = sanitizeVanText(_businessName).trim();
    return cleaned.isEmpty ? 'Van Mate' : cleaned;
  }

  String? _currentJobCustomQuestionSummary() {
    if (!_hasRealRequestReply) {
      return null;
    }

    final parts = <String>[];
    final replyResponses = reply.customQuestionResponses;
    if (replyResponses.isNotEmpty) {
      for (final response in replyResponses) {
        final cleanedQuestion = response.question.trim();
        final cleanedAnswer = response.answer.trim();
        if (cleanedQuestion.isEmpty || cleanedAnswer.isEmpty) {
          continue;
        }

        parts.add(formatCustomQuestionAnswer(cleanedQuestion, cleanedAnswer));
      }
    } else {
      final request = _requestRecord;
      if (request != null) {
        final requestResponses = request.customQuestionResponses.isNotEmpty
            ? request.customQuestionResponses
                  .map(
                    (response) => DriverCustomQuestionResponse(
                      question: response.question,
                      answer: response.answer,
                    ),
                  )
                  .toList(growable: false)
            : request.answers
                  .where((item) => item.hasAnswer)
                  .map(
                    (answer) => DriverCustomQuestionResponse(
                      question: answer.questionText,
                      answer: answer.answerValue,
                    ),
                  )
                  .toList(growable: false);
        for (final response in requestResponses) {
          final cleanedQuestion = response.question.trim();
          final cleanedAnswer = response.answer.trim();
          if (cleanedQuestion.isEmpty || cleanedAnswer.isEmpty) {
            continue;
          }

          parts.add(formatCustomQuestionAnswer(cleanedQuestion, cleanedAnswer));
        }
      }
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join('\n\n');
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefixText,
    String? errorText,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: maxLines,
      onChanged: onChanged ?? (_) => setState(() {}),
      onTapOutside: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
        if (focusNode == _amountFocusNode) {
          _applyFormattedQuoteAmountIfValid();
        }
      },
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        hintText: hint,
        prefixText: prefixText,
        labelOpacity: 0.68,
        hintOpacity: 0.50,
      ).copyWith(errorText: errorText),
    );
  }

  Widget _buildQuoteChip(
    String label, {
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled
            ? color.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickExtraChip(
    VanQuoteExtraDefault extra, {
    bool suggested = false,
    bool enabled = true,
  }) {
    final selection = _selectedQuoteExtras.selectionForKey(extra.key);
    final selected = selection != null;
    final activeColor = selected
        ? const Color(0xFF4A7DFF)
        : suggested
        ? const Color(0xFF58D0A4)
        : Colors.white;
    final chipText = selected
        ? selection.chipLabel
        : isQuantityVanQuoteExtraKey(extra.key)
        ? '${extra.resolvedLabel} ${formatCurrency(extra.defaultPrice)}/'
              '${extra.key == kVanQuoteExtraWaitingTimeKey ? 'hr' : 'mile'}'
        : '${extra.resolvedLabel} ${formatCurrency(extra.defaultPrice)}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => unawaited(_handleQuickExtraTap(extra)) : null,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 245),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected
                  ? const Color(0xFF4A7DFF).withValues(alpha: 0.20)
                  : !enabled
                  ? Colors.white.withValues(alpha: 0.035)
                  : suggested
                  ? const Color(0xFF58D0A4).withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: selected
                    ? const Color(0xFF4A7DFF).withValues(alpha: 0.36)
                    : !enabled
                    ? Colors.white.withValues(alpha: 0.07)
                    : suggested
                    ? const Color(0xFF58D0A4).withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? Icons.check_circle
                      : !enabled
                      ? Icons.add_circle_outline
                      : suggested
                      ? Icons.auto_awesome
                      : Icons.add_circle_outline,
                  size: 13,
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.42),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    chipText,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: enabled ? (selected ? 0.98 : 0.90) : 0.42,
                      ),
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (suggested && !selected) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: activeColor.withValues(alpha: 0.16),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      'Suggested',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 9.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesChecklistQuestion(String actualQuestion, String targetQuestion) {
    final actual = sanitizeVanText(actualQuestion).trim().toLowerCase();
    final target = sanitizeVanText(targetQuestion).trim().toLowerCase();
    if (actual.isEmpty || target.isEmpty) {
      return false;
    }
    if (actual == target) {
      return true;
    }
    return vanJobChecklistDisplayLabel(actualQuestion).toLowerCase() ==
        vanJobChecklistDisplayLabel(targetQuestion).toLowerCase();
  }

  String? _checklistValue(List<String> questions) {
    if (!_hasRealRequestReply) {
      return null;
    }

    for (final question in questions) {
      final normalizedQuestion = question.trim().toLowerCase();
      if (normalizedQuestion.isEmpty) {
        continue;
      }

      for (final response in reply.checklistResponses) {
        if (!_matchesChecklistQuestion(response.question, normalizedQuestion)) {
          continue;
        }

        final answer = response.answer.trim();
        if (answer.isNotEmpty) {
          return answer;
        }
      }

      final request = _requestRecord;
      if (request == null) {
        continue;
      }

      for (final response in request.checklistResponses) {
        if (!_matchesChecklistQuestion(response.question, normalizedQuestion)) {
          continue;
        }

        final answer = response.answer.trim();
        if (answer.isNotEmpty) {
          return answer;
        }
      }
    }

    return null;
  }

  String? _checklistNote(List<String> questions) {
    if (!_hasRealRequestReply) {
      return null;
    }

    for (final question in questions) {
      final normalizedQuestion = question.trim().toLowerCase();
      if (normalizedQuestion.isEmpty) {
        continue;
      }

      for (final response in reply.checklistResponses) {
        if (!_matchesChecklistQuestion(response.question, normalizedQuestion)) {
          continue;
        }

        final note = (response.note ?? '').trim();
        if (note.isNotEmpty && _hasUsefulNote(note)) {
          return note;
        }
      }

      final request = _requestRecord;
      if (request == null) {
        continue;
      }

      for (final response in request.checklistResponses) {
        if (!_matchesChecklistQuestion(response.question, normalizedQuestion)) {
          continue;
        }

        final note = response.note.trim();
        if (note.isNotEmpty && _hasUsefulNote(note)) {
          return note;
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final previewText = _quotePreviewText();
    final quoteAmountError = _quoteAmountInputError.isNotEmpty
        ? _quoteAmountInputError
        : _quoteAmountValidationMessage(allowEmpty: true);
    final hasValidQuoteAmount = _hasValidQuoteAmount();
    final quoteExtrasEnabled = _canUseQuoteExtras;
    final showHighQuoteWarning = _showsHighQuoteAmountWarning();
    final customQuestionSummary = _currentJobCustomQuestionSummary();
    final request = _requestRecord;
    final actionState = deriveVanJobActionState(reply, request: request);
    final journeyCopy = reply.customerJourney.copy;
    final pageTitle = _isRevisingQuote
        ? 'Revise ${journeyCopy.requestNoun.toLowerCase()}'
        : journeyCopy.businessAction;
    final pageSubtitle = _isRevisingQuote
        ? 'Update the previous quote and resend it to the customer.'
        : 'Review the customer request and send a quote.';
    final quoteAccepted = actionState.isQuoteAccepted;
    final quoteDeclined = reply.isQuoteDeclined;
    final awaitingCustomerResponse =
        reply.isQuoteAwaitingCustomerResponse ||
        (_sent && reply.hasQuote && !quoteAccepted && !quoteDeclined);
    final alreadyInCalendar = _isAlreadyInCalendar;
    final canAddAcceptedQuoteToCalendar =
        !alreadyInCalendar && actionState.canAddToCalendar;

    final pricingSummary = <_QuoteSummaryItem>[];

    final parkingValue = _checklistValue(['Parking available?']);
    final parkingNote = _checklistNote(['Parking available?']);
    if ((parkingValue?.trim().isNotEmpty ?? false) ||
        (parkingNote?.trim().isNotEmpty ?? false)) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.local_parking,
          label: 'Parking',
          value: formatAnswerWithNote(parkingValue ?? '', parkingNote ?? ''),
          accent: const Color(0xFF58D0A4),
        ),
      );
    }

    final accessValue = _checklistValue(['Any access restrictions?']);
    final accessNote = _checklistNote(['Any access restrictions?']);
    if ((accessValue?.trim().isNotEmpty ?? false) ||
        (accessNote?.trim().isNotEmpty ?? false)) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.lock_outline,
          label: 'Access',
          value: formatAnswerWithNote(accessValue ?? '', accessNote ?? ''),
          accent: const Color(0xFF4A7DFF),
        ),
      );
    }

    final stairsValue = _checklistValue(['Stairs or lift?']);
    final stairsNote = _checklistNote(['Stairs or lift?']);
    if ((stairsValue?.trim().isNotEmpty ?? false) ||
        (stairsNote?.trim().isNotEmpty ?? false)) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.stairs_outlined,
          label: 'Stairs/lift',
          value: formatAnswerWithNote(stairsValue ?? '', stairsNote ?? ''),
          accent: const Color(0xFFB48CFF),
        ),
      );
    }

    final loadingHelpValue = _checklistValue(['Help loading/unloading?']);
    if (loadingHelpValue?.trim().isNotEmpty ?? false) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.support_agent_outlined,
          label: 'Loading help',
          value: loadingHelpValue!,
          accent: const Color(0xFF4A7DFF),
        ),
      );
    }

    final heavyItemsValue = _checklistValue(['Large or heavy items?']);
    if (heavyItemsValue?.trim().isNotEmpty ?? false) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.inventory_2_outlined,
          label: 'Heavy items',
          value: heavyItemsValue!,
          accent: const Color(0xFF58D0A4),
        ),
      );
    }

    if (customQuestionSummary?.trim().isNotEmpty ?? false) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.question_answer,
          label: 'Custom',
          value: customQuestionSummary!,
          accent: const Color(0xFF4A7DFF),
        ),
      );
    }

    if (reply.hasServiceHandover) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.swap_vert_circle_outlined,
          label: 'Handover',
          value: reply.handoverSummary,
          accent: const Color(0xFFFFA24C),
        ),
      );
    }

    if (reply.exactPinSaved || (request?.hasExactPin ?? false)) {
      pricingSummary.add(
        _QuoteSummaryItem(
          icon: Icons.location_on_outlined,
          label: 'Exact pin',
          value: 'Exact pin received',
          accent: const Color(0xFF58D0A4),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + bottomPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReplyBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        pageTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pageSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.45,
                        ),
                      ),
                      if (_isRevisingQuote) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: const Color(
                              0xFFFFC38C,
                            ).withValues(alpha: 0.14),
                            border: Border.all(
                              color: const Color(
                                0xFFFFC38C,
                              ).withValues(alpha: 0.34),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Previous quote declined',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (reply.declineReasonLabel.trim().isNotEmpty ||
                                  reply.declineReasonText.trim().isNotEmpty ||
                                  reply.declineNote.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                if (reply.declineReasonLabel.trim().isNotEmpty)
                                  Text(
                                    'Decline reason: ${reply.declineReasonLabel.trim()}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.84,
                                      ),
                                      height: 1.45,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (reply.declineNote.trim().isNotEmpty ||
                                    reply.declineReasonText
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: ${(reply.declineNote.trim().isNotEmpty ? reply.declineNote.trim() : reply.declineReasonText.trim())}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.84,
                                      ),
                                      height: 1.45,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _customerRequestExpanded =
                                      !_customerRequestExpanded;
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: _ReplySectionHeader(
                                        icon: Icons.fact_check_outlined,
                                        title: 'View customer request',
                                      ),
                                    ),
                                    AnimatedRotation(
                                      turns: _customerRequestExpanded ? 0.5 : 0,
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_customerRequestExpanded)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final tileWidth = constraints.maxWidth < 520
                                        ? constraints.maxWidth
                                        : 228.0;
                                    if (pricingSummary.isEmpty) {
                                      return Text(
                                        'No customer reply details found.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.82,
                                              ),
                                            ),
                                      );
                                    }
                                    return Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final item in pricingSummary)
                                          SizedBox(
                                            width: tileWidth,
                                            child: _QuoteDetailCard(item: item),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ReplySectionHeader(
                              icon: Icons.receipt,
                              title: 'Quote details',
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(
                                  0xFF58D0A4,
                                ).withValues(alpha: 0.08),
                                border: Border.all(
                                  color: const Color(
                                    0xFF58D0A4,
                                  ).withValues(alpha: 0.22),
                                ),
                              ),
                              child: _buildField(
                                controller: _amountController,
                                label: 'Total quote',
                                hint: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                prefixText: '£',
                              ),
                            ),
                            if (quoteAmountError != null &&
                                _amountController.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                quoteAmountError,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFFF8B8B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (showHighQuoteWarning) ...[
                              const SizedBox(height: 8),
                              Text(
                                'High quote amount. Double-check before sending.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFFFD166),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildField(
                              controller: _descriptionController,
                              label: 'Job description',
                              hint: 'Job title',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            _buildField(
                              controller: _quoteNotesController,
                              label: 'Quote notes',
                              hint:
                                  'Includes collection, delivery, loading help, waiting time, or any special terms...',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            _buildField(
                              controller: _paymentInstructionsController,
                              label: 'Payment instructions',
                              hint:
                                  'Please reply to confirm. Payment can be arranged directly with the driver/business.',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 14),
                            const _ReplySectionHeader(
                              icon: Icons.event_available_outlined,
                              title: 'Proposed appointment',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _requiresProposedAppointment
                                  ? 'Choose the exact date and start time you want the customer to accept.'
                                  : 'Optional exact appointment details for the quote.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickProposedDate,
                                    icon: const Icon(Icons.event_outlined),
                                    label: Text(_proposedDateLabel()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickProposedTime,
                                    icon: const Icon(Icons.schedule_outlined),
                                    label: Text(_proposedTimeLabel()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _pickEstimatedDuration,
                              icon: const Icon(Icons.timelapse_outlined),
                              label: Text(
                                'Estimated duration: ${_estimatedDurationLabel()}',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildField(
                              controller: _proposedAppointmentNoteController,
                              label: 'Appointment note',
                              hint: 'Arrival around this time',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Expanded(
                                  child: _ReplySectionHeader(
                                    icon: Icons.playlist_add,
                                    title: 'Optional extras',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Saved extras',
                                  onPressed: _openQuoteExtraSettings,
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (!quoteExtrasEnabled) ...[
                              Text(
                                'Enter a quote amount before adding extras.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final extra
                                    in _quoteExtraDefaults.enabledExtras)
                                  _buildQuickExtraChip(
                                    extra,
                                    suggested: _suggestedExtraKeys.contains(
                                      extra.key,
                                    ),
                                    enabled: quoteExtrasEnabled,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _messagePreviewExpanded =
                                      !_messagePreviewExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.preview,
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Message preview',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.94,
                                              ),
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                    if (parseCurrencyValue(
                                          _amountController.text,
                                        ) >
                                        0)
                                      PopupMenuButton<String>(
                                        tooltip: 'More quote actions',
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Colors.white,
                                        ),
                                        color: const Color(0xFF142031),
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'copy_message':
                                              _copyMessage();
                                              break;
                                            case 'share_message':
                                              unawaited(
                                                _shareQuoteMessage(
                                                  _quotePreviewText(),
                                                ),
                                              );
                                              break;
                                            case 'copy_link':
                                              _copyQuoteLink();
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem<String>(
                                            value: 'copy_message',
                                            child: Text('Copy quote message'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'share_message',
                                            child: Text('Share quote message'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'copy_link',
                                            child: Text('Copy quote link'),
                                          ),
                                        ],
                                      ),
                                    Icon(
                                      _messagePreviewExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_messagePreviewExpanded) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.black.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Text(
                                  _quotePreviewDisplayText(previewText),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              if (hasValidQuoteAmount) ...[
                                const SizedBox(height: 12),
                                _buildQuoteChip(
                                  'Quote response link ready',
                                  color: const Color(0xFF4A7DFF),
                                  icon: Icons.link,
                                ),
                              ],
                              if (actionState.canViewQuote &&
                                  (awaitingCustomerResponse ||
                                      quoteAccepted ||
                                      quoteDeclined)) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (awaitingCustomerResponse &&
                                        _isRevisingQuote)
                                      _buildQuoteChip(
                                        'Revised quote sent',
                                        color: const Color(0xFF58D0A4),
                                        icon: Icons.refresh_rounded,
                                        filled: true,
                                      ),
                                    if (awaitingCustomerResponse)
                                      _buildQuoteChip(
                                        'Awaiting customer response',
                                        color: const Color(0xFF4A7DFF),
                                        icon: Icons.hourglass_bottom,
                                        filled: true,
                                      ),
                                    if (quoteAccepted)
                                      _buildQuoteChip(
                                        'Quote accepted',
                                        color: const Color(0xFF58D0A4),
                                        icon: Icons.check_circle,
                                        filled: true,
                                      ),
                                    if (quoteDeclined)
                                      _buildQuoteChip(
                                        'Quote declined',
                                        color: const Color(0xFFFF6E6E),
                                        icon: Icons.cancel,
                                        filled: true,
                                      ),
                                  ],
                                ),
                              ] else if (_saved) ...[
                                const SizedBox(height: 12),
                                _buildQuoteChip(
                                  'Quote saved',
                                  color: const Color(0xFF58D0A4),
                                  icon: Icons.check_circle,
                                  filled: true,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 480;
                          FilledButton filledAction({
                            required VoidCallback? onPressed,
                            required IconData icon,
                            required String label,
                            Color color = const Color(0xFF58D0A4),
                          }) {
                            return FilledButton.icon(
                              onPressed: onPressed,
                              icon: Icon(icon),
                              label: Text(label),
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: color.withValues(
                                  alpha: 0.55,
                                ),
                                disabledForegroundColor: Colors.white
                                    .withValues(alpha: 0.96),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            );
                          }

                          OutlinedButton outlinedAction({
                            required VoidCallback? onPressed,
                            required IconData icon,
                            required String label,
                            Color color = Colors.white,
                            Color? borderColor,
                          }) {
                            return OutlinedButton.icon(
                              onPressed: onPressed,
                              icon: Icon(icon),
                              label: Text(label),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: color,
                                side: BorderSide(
                                  color:
                                      borderColor ??
                                      Colors.white.withValues(alpha: 0.16),
                                ),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            );
                          }

                          final actions = <Widget>[
                            if (!quoteAccepted &&
                                !quoteDeclined &&
                                !awaitingCustomerResponse)
                              filledAction(
                                onPressed:
                                    !hasValidQuoteAmount || _openingSendChannel
                                    ? null
                                    : _sendQuote,
                                icon: Icons.send,
                                label: _openingSendChannel
                                    ? 'Sending quote...'
                                    : journeyCopy.businessAction,
                              ),
                            if (quoteDeclined)
                              filledAction(
                                onPressed:
                                    !hasValidQuoteAmount || _openingSendChannel
                                    ? null
                                    : _sendQuote,
                                icon: Icons.refresh_rounded,
                                label: _openingSendChannel
                                    ? 'Sending quote...'
                                    : 'Revise / resend quote',
                              ),
                            if (actionState.canViewQuote)
                              outlinedAction(
                                onPressed: () => unawaited(_openQuoteLink()),
                                icon: Icons.open_in_new,
                                label: 'View quote',
                                color: const Color(0xFF4A7DFF),
                              ),
                            if (canAddAcceptedQuoteToCalendar)
                              filledAction(
                                onPressed: () =>
                                    unawaited(_addAcceptedQuoteToCalendar()),
                                icon: Icons.event_available,
                                label: 'Add to calendar',
                                color: const Color(0xFF4A7DFF),
                              ),
                            if (quoteAccepted && alreadyInCalendar)
                              filledAction(
                                onPressed: null,
                                icon: Icons.check_circle,
                                label: 'In calendar',
                                color: const Color(0xFF58D0A4),
                              ),
                          ];

                          if (stacked) {
                            return Column(
                              children: [
                                for (var i = 0; i < actions.length; i++) ...[
                                  actions[i],
                                  if (i < actions.length - 1)
                                    const SizedBox(height: 10),
                                ],
                              ],
                            );
                          }

                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final button in actions)
                                SizedBox(
                                  width: constraints.maxWidth < 620
                                      ? constraints.maxWidth
                                      : 220,
                                  child: button,
                                ),
                            ],
                          );
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Quote and message preview.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.62),
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (((awaitingCustomerResponse ||
                                      quoteDeclined ||
                                      (!quoteAccepted && !quoteDeclined)) &&
                                  hasValidQuoteAmount) ||
                              ((awaitingCustomerResponse ||
                                      (!quoteAccepted && !quoteDeclined)) &&
                                  hasValidQuoteAmount) ||
                              hasValidQuoteAmount)
                            PopupMenuButton<String>(
                              tooltip: 'More quote actions',
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              color: const Color(0xFF142031),
                              onSelected: (value) {
                                switch (value) {
                                  case 'copy_message':
                                    _copyMessage();
                                    break;
                                  case 'share_message':
                                    unawaited(_shareQuoteMessage(previewText));
                                    break;
                                  case 'copy_link':
                                    _copyQuoteLink();
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                if ((awaitingCustomerResponse ||
                                        quoteDeclined ||
                                        (!quoteAccepted && !quoteDeclined)) &&
                                    hasValidQuoteAmount)
                                  const PopupMenuItem<String>(
                                    value: 'copy_message',
                                    child: Text('Copy quote message'),
                                  ),
                                if ((awaitingCustomerResponse ||
                                        (!quoteAccepted && !quoteDeclined)) &&
                                    hasValidQuoteAmount)
                                  const PopupMenuItem<String>(
                                    value: 'share_message',
                                    child: Text('Share quote message'),
                                  ),
                                if (hasValidQuoteAmount)
                                  const PopupMenuItem<String>(
                                    value: 'copy_link',
                                    child: Text('Copy quote link'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteQuantityExtraSheet extends StatefulWidget {
  const _QuoteQuantityExtraSheet({
    required this.extra,
    required this.initialQuantity,
  });

  final VanQuoteExtraDefault extra;
  final double? initialQuantity;

  @override
  State<_QuoteQuantityExtraSheet> createState() =>
      _QuoteQuantityExtraSheetState();
}

class _QuoteQuantityExtraSheetState extends State<_QuoteQuantityExtraSheet> {
  late final TextEditingController _quantityController;

  bool get _isWaitingTime => widget.extra.key == kVanQuoteExtraWaitingTimeKey;

  String get _unitLabel => _isWaitingTime ? 'hours' : 'miles';

  String get _rateUnit => _isWaitingTime ? 'hr' : 'mile';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuantity;
    _quantityController = TextEditingController(
      text: initial == null || initial <= 0
          ? ''
          : _formatQuantityInput(initial),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double _quantity() {
    final cleaned = _quantityController.text
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .trim();
    if (cleaned.isEmpty) {
      return 0;
    }
    return double.tryParse(cleaned) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final rate = widget.extra.defaultPrice < 0
        ? 0.0
        : widget.extra.defaultPrice;
    final quantity = _quantity();
    final total = quantity * rate;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _QuoteExtraEditorShell(
          title: widget.extra.resolvedLabel,
          subtitle: 'Rate ${formatCurrency(rate)}/$_rateUnit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                style: kVanMateFieldTextStyle,
                decoration: vanMateFieldDecoration(
                  label: _unitLabel,
                  hintText: _isWaitingTime ? '1.5' : '1.5',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_formatQuantityInput(quantity)} ${_isWaitingTime ? 'h' : 'miles'} x ${formatCurrency(rate)}/$_rateUnit = ${formatCurrency(total)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(0.0),
                      child: const Text('Remove'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(quantity),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteCustomExtraResult {
  const _QuoteCustomExtraResult({required this.label, required this.price});

  final String label;
  final double price;
}

class _QuoteCustomExtraSheet extends StatefulWidget {
  const _QuoteCustomExtraSheet({
    required this.extra,
    required this.initialLabel,
    required this.initialPrice,
  });

  final VanQuoteExtraDefault extra;
  final String? initialLabel;
  final double? initialPrice;

  @override
  State<_QuoteCustomExtraSheet> createState() => _QuoteCustomExtraSheetState();
}

class _QuoteCustomExtraSheetState extends State<_QuoteCustomExtraSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.initialLabel?.trim().isNotEmpty == true
          ? widget.initialLabel!.trim()
          : widget.extra.resolvedLabel,
    );
    final initialPrice = widget.initialPrice ?? widget.extra.defaultPrice;
    _priceController = TextEditingController(
      text: initialPrice <= 0 ? '' : initialPrice.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double _price() => parseCurrencyValue(_priceController.text);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _QuoteExtraEditorShell(
          title: widget.extra.resolvedLabel,
          subtitle: 'Set the label and amount for this quote.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelController,
                style: kVanMateFieldTextStyle,
                decoration: vanMateFieldDecoration(
                  label: 'Label',
                  hintText: widget.extra.resolvedLabel,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: kVanMateFieldTextStyle,
                decoration: vanMateFieldDecoration(
                  label: 'Price',
                  hintText: '0.00',
                  prefixText: '£',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(const _QuoteCustomExtraResult(label: '', price: 0)),
                      child: const Text('Remove'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _QuoteCustomExtraResult(
                          label: _labelController.text,
                          price: _price(),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteExtraEditorShell extends StatelessWidget {
  const _QuoteExtraEditorShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatQuantityInput(double value) {
  final asFixed = value.toStringAsFixed(2);
  return asFixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

class _QuoteSummaryItem {
  const _QuoteSummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
}

class _QuoteDetailCard extends StatelessWidget {
  const _QuoteDetailCard({required this.item});

  final _QuoteSummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: item.accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: item.accent.withValues(alpha: 0.18),
                  border: Border.all(
                    color: item.accent.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(item.icon, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverQuoteMockPageState extends State<DriverQuoteMockPage> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;

  String _businessName = '';
  final bool _saved = DriverReplyMockState.instance.quoteSaved;
  bool _sent = false;
  bool _sendingQuote = false;

  DriverCustomerReplyMockData get reply => widget.reply;
  String get _jobId => reply.jobId;
  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: reply.jobTitle);
    _priceController = TextEditingController(
      text: reply.quoteAmount?.toStringAsFixed(2) ?? '',
    );
    _notesController = TextEditingController(
      text: 'Reply to confirm if you are happy to go ahead.',
    );
    unawaited(_loadBusinessName());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadBusinessName() async {
    try {
      final profile = await VanBusinessProfileStorage.instance
          .loadCanonicalProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _businessName = sanitizeVanText(profile.businessName).trim();
      });
    } catch (_) {}
  }

  Widget _buildStatusChip(
    String label, {
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled
            ? color.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendQuote() async {
    if (_sendingQuote) {
      return;
    }
    final amount = parseCurrencyValue(_priceController.text);
    if (amount <= 0) {
      _showSnack('Please enter a quote amount before sending.');
      return;
    }
    setState(() => _sendingQuote = true);
    final publicQuoteData = <String, dynamic>{
      'quoteMessage': _quoteText(),
      'quoteAmountText': formatCurrency(amount),
      'quotePublishKey':
          '${_jobId.trim()}:${DateTime.now().microsecondsSinceEpoch}',
    };
    try {
      await DriverReplyMockState.instance.setQuoteSent(
        true,
        jobId: _jobId,
        amount: amount,
        publicQuoteData: publicQuoteData,
      );
      if (!mounted) return;
      setState(() => _sent = true);
      _showSnack('Quote sent');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not send the quote. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _sendingQuote = false);
      }
    }
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: _quoteText()));
    _showSnack('Quote message copied.');
  }

  void _copyQuoteLink() {
    final link = reply.activeQuoteResponseLink;
    Clipboard.setData(ClipboardData(text: link));
    _showSnack('Quote link copied.');
  }

  String _quoteText() {
    final amount = parseCurrencyValue(_priceController.text);
    if (amount <= 0) {
      return '';
    }
    return buildVanQuoteMessage(
      customerName: reply.customerName,
      jobTitle: reply.jobTitle,
      quoteAmountText: formatCurrency(amount),
      quoteResponseLink: DriverReplyMockState.instance
          .resolveQuoteResponseLinkForJob(
            reply,
            creatingFreshQuote: reply.isQuoteDeclined,
          ),
      businessName: _businessName,
      proposedAppointmentText: _preferredTimingSummaryForQuote(reply),
    );
  }

  String _quotePreviewDisplayText(String message) {
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journeyCopy = reply.customerJourney.copy;
    final pageTitle = reply.isQuoteDeclined
        ? 'Revise ${journeyCopy.requestNoun.toLowerCase()}'
        : journeyCopy.businessAction;
    final pageSubtitle = reply.isQuoteDeclined
        ? 'Update the previous quote and resend it to the customer.'
        : 'Quote and message preview, no payment handling.';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReplyBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        pageTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pageSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ReplySectionHeader(
                              icon: Icons.request_quote_outlined,
                              title: 'Quote details',
                            ),
                            const SizedBox(height: 12),
                            _MiniInfoPill(
                              icon: Icons.person,
                              label: reply.customerName,
                            ),
                            const SizedBox(height: 10),
                            _MiniInfoPill(
                              icon: Icons.checklist,
                              label: reply.jobTitle,
                            ),
                            const SizedBox(height: 10),
                            _MiniInfoPill(
                              icon: Icons.location_on,
                              label: reply.address,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _descriptionController,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Job description',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w700,
                                ),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: const Color(
                                      0xFF4A7DFF,
                                    ).withValues(alpha: 0.75),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _priceController,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Price',
                                      hintText: '£120',
                                      labelStyle: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withValues(
                                        alpha: 0.14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.10,
                                          ),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.10,
                                          ),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide(
                                          color: const Color(
                                            0xFF4A7DFF,
                                          ).withValues(alpha: 0.75),
                                          width: 1.2,
                                        ),
                                      ),
                                      prefixIcon: const Icon(Icons.payments),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              maxLines: 3,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Extra notes / payment instructions',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w700,
                                ),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: const Color(
                                      0xFF4A7DFF,
                                    ).withValues(alpha: 0.75),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: _ReplySectionHeader(
                                    icon: Icons.preview,
                                    title: 'Message preview',
                                  ),
                                ),
                                if (parseCurrencyValue(_priceController.text) >
                                    0)
                                  PopupMenuButton<String>(
                                    tooltip: 'More quote actions',
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white,
                                    ),
                                    color: const Color(0xFF142031),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'copy_message':
                                          _copyMessage();
                                          break;
                                        case 'share_message':
                                          unawaited(() async {
                                            await shareRequestMessage(
                                              _quoteText(),
                                            );
                                            if (!mounted) {
                                              return;
                                            }
                                            _showSnack('Quote message shared.');
                                          }());
                                          break;
                                        case 'copy_link':
                                          _copyQuoteLink();
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'copy_message',
                                        child: Text('Copy quote message'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'share_message',
                                        child: Text('Share quote message'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'copy_link',
                                        child: Text('Copy quote link'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.black.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                _quotePreviewDisplayText(_quoteText()),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  height: 1.45,
                                ),
                              ),
                            ),
                            if (parseCurrencyValue(_priceController.text) >
                                0) ...[
                              const SizedBox(height: 12),
                              _buildStatusChip(
                                'Quote response link ready',
                                color: const Color(0xFF4A7DFF),
                                icon: Icons.link,
                              ),
                            ],
                            if (_saved || _sent) ...[
                              const SizedBox(height: 12),
                              _buildStatusChip(
                                _sent ? 'Quote sent' : 'Quote saved',
                                color: const Color(0xFF58D0A4),
                                icon: Icons.check_circle,
                                filled: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _sendingQuote ? null : _sendQuote,
                              icon: const Icon(Icons.send),
                              label: Text(
                                _sendingQuote
                                    ? 'Sending quote...'
                                    : _sent
                                    ? 'Resend ${journeyCopy.requestNoun.toLowerCase()}'
                                    : journeyCopy.businessAction,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (parseCurrencyValue(_priceController.text) > 0) ...[
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'Van Mate does not handle payment. This only creates the quote and message.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

VanJobBucketDecision _deriveVanJobBucket(DriverCustomerReplyMockData job) {
  if (job.isHiddenFromNormalLists || job.deleted || job.archived) {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.hiddenDeletedOrDraft,
      reason: 'hidden_deleted_or_archived',
    );
  }

  final normalizedStatus = job.status.trim().toLowerCase();
  final normalizedRequestStatus = normalizeVanJobRequestStatus(
    job.requestStatus,
  );
  final rawRequestStatus = job.requestStatus.trim().toLowerCase();
  final normalizedQuoteStatus = job.quoteStatus.trim().toLowerCase();
  final hasReplyData =
      job.hasCustomerReply ||
      job.replyReceivedAt != null ||
      job.requestSubmittedAt != null ||
      job.checklistResponses.isNotEmpty ||
      job.customQuestionResponses.isNotEmpty ||
      job.additionalNotes.trim().isNotEmpty;
  final hasExactPinSignals =
      job.exactPinLatitude != null ||
      job.exactPinLongitude != null ||
      job.exactPinShared ||
      job.hasExactPin;
  final hasQuoteSignals = job.hasQuote;
  final hasCustomerRequestContext =
      job._hasCustomerRequestWorkflow ||
      hasReplyData ||
      hasExactPinSignals ||
      hasQuoteSignals;
  final isConfirmedBooking = job.isConfirmed;
  final isManualBookedJob =
      !hasCustomerRequestContext &&
      (normalizedStatus == 'confirmed' ||
          normalizedStatus == 'ready' ||
          normalizedStatus == 'booked' ||
          normalizedStatus == 'accepted' ||
          normalizedStatus == 'scheduled' ||
          normalizedRequestStatus == 'confirmed' ||
          normalizedRequestStatus == 'accepted' ||
          normalizedRequestStatus == 'quote_accepted' ||
          normalizedStatus.isNotEmpty);

  if (job.isCompletedJob) {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.completedJob,
      reason: 'status_completed',
    );
  }

  if (normalizedStatus == 'draft') {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.hiddenDeletedOrDraft,
      reason: 'status_draft',
    );
  }

  if (normalizedStatus == 'cancelled') {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.cancelledJobHistory,
      reason: 'status_cancelled',
    );
  }

  if (job.isScheduledInCalendarState) {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.bookedJob,
      reason: 'calendar_state_scheduled_or_confirmed',
    );
  }

  if (normalizedStatus == 'declined' ||
      normalizedStatus == 'quotedeclined' ||
      normalizedRequestStatus == 'declined' ||
      normalizedRequestStatus == 'quote_declined' ||
      normalizedQuoteStatus == 'declined' ||
      job.isQuoteDeclined) {
    if (hasCustomerRequestContext && !job.archived) {
      return const VanJobBucketDecision(
        bucket: VanJobBucket.pendingCustomerRequest,
        reason: 'quote_declined_active_follow_up',
      );
    }
    return const VanJobBucketDecision(
      bucket: VanJobBucket.declinedQuoteHistory,
      reason: 'quote_declined_follow_up',
    );
  }

  if (!hasCustomerRequestContext && normalizedRequestStatus == 'draft') {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.hiddenDeletedOrDraft,
      reason: 'request_draft_without_request_signals',
    );
  }

  if (isConfirmedBooking) {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.bookedJob,
      reason: 'job_confirmed',
    );
  }

  if (isManualBookedJob) {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.bookedJob,
      reason: 'manual_job_default_booked',
    );
  }

  final pendingRequestStatuses = <String>{
    'pending',
    'sent',
    'requestsent',
    'request_sent',
    'replied',
    'reply_received',
    'action_needed',
    'actionneeded',
    'ready_to_quote',
    'readytoquote',
    'awaiting_reply',
    'awaitingreply',
  };
  final pendingQuoteStatuses = <String>{
    'opened_for_sending',
    'waiting',
    'sent',
    'prepared',
  };
  final hasPendingSignals =
      pendingRequestStatuses.contains(rawRequestStatus) ||
      pendingRequestStatuses.contains(normalizedRequestStatus) ||
      pendingQuoteStatuses.contains(normalizedQuoteStatus) ||
      hasReplyData ||
      hasExactPinSignals;
  final hasPreSchedulingSignals =
      hasPendingSignals ||
      job.isQuoteAccepted ||
      job.hasAgreedSchedulingTime ||
      job.isAwaitingAgreedTime;

  if (hasCustomerRequestContext && hasPreSchedulingSignals) {
    return const VanJobBucketDecision(
      bucket: VanJobBucket.pendingCustomerRequest,
      reason: 'customer_request_active_pre_scheduling',
    );
  }

  return const VanJobBucketDecision(
    bucket: VanJobBucket.hiddenDeletedOrDraft,
    reason: 'customer_request_not_actionable',
  );
}

void _debugLogJobClassification(
  DriverCustomerReplyMockData job,
  VanJobBucketDecision decision, {
  required String source,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    '[JobBucket] source=$source jobId=${job.jobId} bucket=${decision.bucket.name} quoteStatus=${job.quoteStatus} requestStatus=${job.requestStatus} status=${job.status} quoteAccepted=${job.quoteAccepted} ready=${job.isConfirmed} hasReply=${job.hasCustomerReply} hasPin=${job.exactPinSaved || job.exactPinLatitude != null || job.exactPinLongitude != null || job.exactPinShared}',
  );
}

VanJobBucketDecision debugBucketDecisionForJob(
  DriverCustomerReplyMockData job,
) {
  return _deriveVanJobBucket(job);
}

String currentUidForDebug() {
  return FirebaseAuth.instance.currentUser?.uid ?? '(none)';
}
