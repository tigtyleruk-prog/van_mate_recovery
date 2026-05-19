import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_live_pin_request.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_exact_pin_source.dart';
import '../models/van_job_request_draft.dart';
import '../models/van_job_request_record.dart';
import '../models/van_invoice_history_entry.dart';
import '../models/van_invoice_draft.dart';
import '../services/van_driver_mock_state_storage.dart';
import '../services/van_firebase_auth_service.dart';
import '../services/van_firebase_debug_logging.dart';
import '../services/van_job_request_cloud_service.dart';
import '../services/van_jobs_cloud_service.dart';
import '../services/van_quotes_cloud_service.dart';
import '../services/van_invoices_cloud_service.dart';
import '../services/van_invoice_number_storage.dart';
import '../widgets/van_form_field_styles.dart';

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
    this.customerEmail = '',
    this.postcode = '',
    this.notesMessage = '',
    this.requestExactPin = true,
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
    this.confirmedAt,
    this.completedAt,
    this.quoteAmount,
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
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final double? quoteAmount;
  final bool exactPinShared;
  final List<DriverChecklistResponse> checklistResponses;
  final List<DriverCustomQuestionResponse> customQuestionResponses;
  final String additionalNotes;
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

  DateTime? get scheduledAtOrParsed {
    final direct = scheduledAt;
    if (direct != null) {
      return direct;
    }
    return _parseScheduledAt(jobDateLabel, jobTimeLabel);
  }

  bool get hasExactPinCoordinates =>
      exactPinLatitude != null && exactPinLongitude != null;

  int get checklistAnsweredCount => checklistResponses.length;

  int get customAnsweredCount => customQuestionResponses
      .where((response) => response.answer.trim().isNotEmpty)
      .length;

  String get invoiceHistoryKey => jobId.trim().isNotEmpty
      ? jobId.trim()
      : '${customerName.trim().toLowerCase()}|${jobTitle.trim().toLowerCase()}|${address.trim().toLowerCase()}';

  bool get isDraft => status == 'draft';
  bool get isRequestSent => status == 'requestSent';
  bool get isReplyReceived => status == 'replyReceived';
  bool get isQuoteSent => status == 'quoteSent';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompletedJob {
    final normalized = status.trim().toLowerCase();
    return normalized == 'completed' ||
        normalized == 'done' ||
        normalized == 'completedjob';
  }

  bool get isCompleted => isCompletedJob;
  bool get isCancelled => status == 'cancelled';

  String get statusLabel {
    switch (status) {
      case 'requestSent':
        return 'Pending customer request';
      case 'replyReceived':
        return 'Reply received';
      case 'quoteSent':
        return 'Quote sent';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
      case 'done':
      case 'completedjob':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
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
    DateTime? confirmedAt,
    DateTime? completedAt,
    double? quoteAmount,
    bool? exactPinShared,
    List<DriverChecklistResponse>? checklistResponses,
    List<DriverCustomQuestionResponse>? customQuestionResponses,
    String? additionalNotes,
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
  }) {
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
      checklistItems: checklistItems ?? this.checklistItems,
      customQuestions: customQuestions ?? this.customQuestions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      draftSavedAt: draftSavedAt ?? this.draftSavedAt,
      requestSentAt: requestSentAt ?? this.requestSentAt,
      replyReceivedAt: replyReceivedAt ?? this.replyReceivedAt,
      quoteSavedAt: quoteSavedAt ?? this.quoteSavedAt,
      quoteSentAt: quoteSentAt ?? this.quoteSentAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      quoteAmount: quoteAmount ?? this.quoteAmount,
      exactPinShared: exactPinShared ?? this.exactPinShared,
      checklistResponses: checklistResponses ?? this.checklistResponses,
      customQuestionResponses:
          customQuestionResponses ?? this.customQuestionResponses,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      exactPinShareSource: exactPinShareSource ?? this.exactPinShareSource,
      exactPinNote: exactPinNote ?? this.exactPinNote,
      exactPinLatitude: exactPinLatitude ?? this.exactPinLatitude,
      exactPinLongitude: exactPinLongitude ?? this.exactPinLongitude,
      requestId: requestId ?? this.requestId,
      requestStatus: requestStatus ?? this.requestStatus,
      requestCreatedAt: requestCreatedAt ?? this.requestCreatedAt,
      requestUpdatedAt: requestUpdatedAt ?? this.requestUpdatedAt,
      requestSubmittedAt: requestSubmittedAt ?? this.requestSubmittedAt,
      requestExpiresAt: requestExpiresAt ?? this.requestExpiresAt,
      requestLink: requestLink ?? this.requestLink,
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
      'phoneNumber': phoneNumber,
      'customerEmail': customerEmail,
      'postcode': postcode,
      'notesMessage': notesMessage,
      'requestExactPin': requestExactPin,
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
      'confirmedAt': confirmedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'quoteAmount': quoteAmount,
      'exactPinShared': exactPinShared,
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
    };
  }

  factory DriverCustomerReplyMockData.fromJson(Map<String, dynamic> json) {
    final checklistJson = json['checklistResponses'];
    final customJson = json['customQuestionResponses'];
    return DriverCustomerReplyMockData(
      jobId: _jsonText(json['jobId']),
      customerName: _jsonText(json['customerName']),
      jobTitle: _jsonText(json['jobTitle']),
      scheduledAt: _jsonDateTime(json['scheduledAt']),
      jobDateLabel: _jsonText(json['jobDateLabel']),
      jobTimeLabel: _jsonText(json['jobTimeLabel']),
      address: _jsonText(json['address']),
      phoneNumber: _jsonText(json['phoneNumber']),
      customerEmail: _jsonText(json['customerEmail']),
      postcode: _jsonText(json['postcode']),
      notesMessage: _jsonText(json['notesMessage']),
      requestExactPin: _jsonBool(json['requestExactPin']),
      checklistItems:
          (json['checklistItems'] as List?)
              ?.map((item) => sanitizeVanText(item?.toString()).trim())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      customQuestions:
          (json['customQuestions'] as List?)
              ?.map((item) => sanitizeVanText(item?.toString()).trim())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      status: _jsonText(json['status'], fallback: 'draft'),
      createdAt: _jsonDateTime(json['createdAt']),
      updatedAt: _jsonDateTime(json['updatedAt']),
      draftSavedAt: _jsonDateTime(json['draftSavedAt']),
      requestSentAt: _jsonDateTime(json['requestSentAt']),
      replyReceivedAt: _jsonDateTime(json['replyReceivedAt']),
      quoteSavedAt: _jsonDateTime(json['quoteSavedAt']),
      quoteSentAt: _jsonDateTime(json['quoteSentAt']),
      confirmedAt: _jsonDateTime(json['confirmedAt']),
      completedAt: _jsonDateTime(json['completedAt']),
      quoteAmount: _jsonDoubleOrNull(json['quoteAmount']),
      exactPinShared: _jsonBool(json['exactPinShared']),
      checklistResponses: checklistJson is List
          ? checklistJson.whereType<Map>().map((item) {
              final map = Map<String, dynamic>.from(item);
              return DriverChecklistResponse(
                question: _jsonText(map['question']),
                answer: _jsonText(map['answer']),
                note: _jsonTextOrNull(map['note']),
                icon: Icons.checklist,
              );
            }).toList()
          : const <DriverChecklistResponse>[],
      customQuestionResponses: customJson is List
          ? customJson
                .whereType<Map>()
                .map(
                  (item) => DriverCustomQuestionResponse(
                    question: _jsonText(item['question']),
                    answer: _jsonText(item['answer']),
                  ),
                )
                .toList()
          : const <DriverCustomQuestionResponse>[],
      additionalNotes: _jsonText(json['additionalNotes']),
      exactPinShareSource: vanExactPinSourceFromStorage(
        json['exactPinShareSource']?.toString(),
      ),
      exactPinNote: _jsonTextOrNull(json['exactPinNote']),
      exactPinLatitude: _jsonDoubleOrNull(json['exactPinLatitude']),
      exactPinLongitude: _jsonDoubleOrNull(json['exactPinLongitude']),
      requestId: _jsonTextOrNull(json['requestId']),
      requestStatus: _jsonText(json['requestStatus'], fallback: 'draft'),
      requestCreatedAt: _jsonDateTime(json['requestCreatedAt']),
      requestUpdatedAt: _jsonDateTime(json['requestUpdatedAt']),
      requestSubmittedAt: _jsonDateTime(json['requestSubmittedAt']),
      requestExpiresAt: _jsonDateTime(json['requestExpiresAt']),
      requestLink: _jsonText(json['requestLink']),
    );
  }
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
  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  );
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

class DriverReplyMockState {
  DriverReplyMockState._();

  static final DriverReplyMockState instance = DriverReplyMockState._();

  final VanDriverMockStateStorage _storage = VanDriverMockStateStorage.instance;
  final VanInvoiceNumberStorage _invoiceNumberStorage =
      VanInvoiceNumberStorage.instance;

  VanInvoiceDraft? savedInvoice;
  String? _activeJobId;
  final Map<String, DriverCustomerReplyMockData> _jobsById =
      <String, DriverCustomerReplyMockData>{};
  final Map<String, VanInvoiceHistoryEntry> _invoiceHistoryByJobKey =
      <String, VanInvoiceHistoryEntry>{};
  final Map<String, VanJobRequestRecord> _jobRequestsById =
      <String, VanJobRequestRecord>{};

  Future<void> ensureLoaded() => _storage.ensureLoaded();

  Future<void> loadFromStorage() async {
    await ensureLoaded();
    final json = await _storage.loadJson();
    if (json == null) {
      return;
    }

    _applyJson(json);
  }

  Future<void> saveToStorage({bool syncCloud = true}) async {
    await _storage.saveJson(_toJson());
    if (!syncCloud) {
      return;
    }

    try {
      logVanFirebaseHydration(
        stage: 'started',
        target: 'jobs cloud sync',
        extra:
            'jobs=${jobs.length} invoices=${_invoiceHistoryByJobKey.length}',
      );
      await _syncToCloud();
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'jobs cloud sync',
        extra:
            'jobs=${jobs.length} invoices=${_invoiceHistoryByJobKey.length}',
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

  Future<void> loadFromCloud() async {
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
      final results = await Future.wait([
        VanJobsCloudService.instance.loadJobs(ownerUid: ownerUid),
        VanQuotesCloudService.instance.loadQuotes(ownerUid: ownerUid),
      ]);
      final cloudJobs = results.expand((items) => items).toList(growable: false);
      final cloudInvoices = await VanInvoicesCloudService.instance.loadInvoices(
        ownerUid: ownerUid,
      );

      if (cloudJobs.isEmpty && cloudInvoices.isEmpty) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'jobs cloud load',
          extra: 'no_cloud_jobs_or_invoices',
        );
        return;
      }

      _mergeCloudJobs(cloudJobs);
      _mergeCloudInvoices(cloudInvoices);
      await saveToStorage(syncCloud: false);
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'jobs cloud load',
        extra: 'jobs=${cloudJobs.length} invoices=${cloudInvoices.length}',
      );
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'jobs cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> loadJobRequestsFromCloud() async {
    logVanFirebaseHydration(
      stage: 'started',
      target: 'job request cloud load',
    );
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
      final cloudRequests = await VanJobRequestCloudService.instance
          .loadRequestsForOwner(ownerUid: ownerUid);
      if (cloudRequests.isNotEmpty) {
        _mergeCloudRequests(cloudRequests);
        await saveToStorage(syncCloud: false);
      }
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'job request cloud load',
        extra: 'requests=${cloudRequests.length}',
      );
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'job request cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> clearAllLocalJobData() async {
    _jobsById.clear();
    _invoiceHistoryByJobKey.clear();
    _jobRequestsById.clear();
    savedInvoice = null;
    _activeJobId = null;
    await _storage.clear();
    await _invoiceNumberStorage.resetNextNumber();
  }

  void resetTransientWorkflowState() {
    _activeJobId = null;
    savedInvoice = null;
  }

  void _scheduleSave() {
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

    final jobsToSync = jobs;
    final invoiceEntries = _invoiceHistoryByJobKey.values.toList(growable: false);
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

  DriverCustomerReplyMockData? _latestJob() {
    final jobs = _jobsById.values.toList();
    if (jobs.isEmpty) {
      return null;
    }
    jobs.sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return jobs.first;
  }

  DateTime _jobSortDate(DriverCustomerReplyMockData job) {
    return job.scheduledAtOrParsed ??
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

  String? _resolveJobId([String? jobId]) {
    final candidate = jobId?.trim();
    if (candidate != null &&
        candidate.isNotEmpty &&
        _jobsById.containsKey(candidate)) {
      return candidate;
    }
    if (_activeJobId != null && _jobsById.containsKey(_activeJobId)) {
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
    final jobs = _jobsById.values.toList();
    jobs.sort((a, b) => _jobSortDate(b).compareTo(_jobSortDate(a)));
    return jobs;
  }

  List<DriverCustomerReplyMockData> get scheduledJobs {
    return jobs
        .where((job) {
          return job.scheduledAtOrParsed != null && !job.isCancelled;
        })
        .toList(growable: false);
  }

  List<DriverCustomerReplyMockData> jobsForDate(DateTime date) {
    final target = DateUtils.dateOnly(date);
    final matches = scheduledJobs
        .where((job) {
          final scheduledAt = job.scheduledAtOrParsed;
          return scheduledAt != null &&
              DateUtils.isSameDay(scheduledAt, target);
        })
        .toList(growable: true);
    matches.sort((a, b) => _jobSortDate(a).compareTo(_jobSortDate(b)));
    return matches;
  }

  List<DriverCustomerReplyMockData> get todayJobs => jobsForDate(DateTime.now())
      .where(
        (job) =>
            !job.isCompletedJob &&
            job.status != 'draft' &&
            job.status != 'cancelled',
      )
      .toList(growable: false);

  List<DriverCustomerReplyMockData> get upcomingJobs =>
      jobs
          .where((job) {
            final scheduledAt = job.scheduledAtOrParsed;
            if (scheduledAt == null) {
              return false;
            }
            final today = DateUtils.dateOnly(DateTime.now());
            final scheduledDay = DateUtils.dateOnly(scheduledAt);
            return scheduledDay.isAfter(today) &&
                !job.isCompletedJob &&
                job.status != 'draft' &&
                job.status != 'cancelled';
          })
          .toList(growable: true)
        ..sort((a, b) => _jobSortDate(a).compareTo(_jobSortDate(b)));

  List<DriverCustomerReplyMockData> jobsWithStatus(String status) {
    return jobs.where((job) => job.status == status).toList(growable: false);
  }

  List<DriverCustomerReplyMockData> get pendingJobs => jobs
      .where(
        (job) =>
            job.status == 'draft' ||
            job.status == 'requestSent' ||
            job.status == 'replyReceived' ||
            job.status == 'quoteSent',
      )
      .toList(growable: false);

  List<DriverCustomerReplyMockData> get confirmedJobs =>
      jobs.where((job) => job.status == 'confirmed').toList(growable: false);

  List<DriverCustomerReplyMockData> get completedJobs =>
      jobs.where((job) => job.isCompletedJob).toList(growable: false);

  DriverCustomerReplyMockData? jobById(String jobId) {
    return _jobsById[jobId];
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
    return DriverCustomerReplyMockData(
      jobId: draft.jobId,
      customerName: draft.customerName,
      jobTitle: draft.jobTitle,
      scheduledAt: draft.scheduledAt,
      jobDateLabel: draft.jobDateLabel,
      jobTimeLabel: draft.jobTimeLabel,
      address: draft.address,
      phoneNumber: draft.phoneNumber,
      customerEmail: draft.customerEmail,
      postcode: draft.postcode,
      notesMessage: draft.notesMessage,
      requestExactPin: draft.requestExactPin,
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
      exactPinShared: exactPinShared ?? existing?.exactPinShared ?? false,
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
      exactPinLatitude: exactPinLatitude ?? existing?.exactPinLatitude,
      exactPinLongitude: exactPinLongitude ?? existing?.exactPinLongitude,
      requestId: existing?.requestId,
      requestStatus: existing?.requestStatus ?? 'draft',
      requestCreatedAt: existing?.requestCreatedAt,
      requestUpdatedAt: existing?.requestUpdatedAt,
      requestSubmittedAt: existing?.requestSubmittedAt,
      requestExpiresAt: existing?.requestExpiresAt,
      requestLink: existing?.requestLink ?? '',
    );
  }

  DriverCustomerReplyMockData upsertDraftJob(VanJobRequestDraft draft) {
    final existing = _jobsById[draft.jobId];
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
    _activeJobId = updated.jobId;
    _scheduleSave();
    return updated;
  }

  DriverCustomerReplyMockData saveDraftJob(VanJobRequestDraft draft) {
    final updated = _withDefaultsFromDraft(
      draft,
      status: 'draft',
      existing: _jobsById[draft.jobId],
      draftSavedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _jobsById[updated.jobId] = updated;
    _activeJobId = updated.jobId;
    _scheduleSave();
    return updated;
  }

  Future<DriverCustomerReplyMockData> sendJobRequest(
    VanJobRequestDraft draft,
  ) async {
    final existing = _jobsById[draft.jobId];
    final now = DateTime.now();
    final existingRequestId = existing?.requestId?.trim() ?? '';
    final requestId = existingRequestId.isNotEmpty
        ? existingRequestId
        : VanJobRequestCloudService.instance.createRequestId();
    final requestLink = buildVanJobRequestLink(requestId);
    final updated = _withDefaultsFromDraft(
      draft,
      status: 'requestSent',
      existing: existing,
      requestSentAt: now,
      updatedAt: now,
    ).copyWith(
      requestId: requestId,
      requestStatus: 'pending',
      requestCreatedAt: existing?.requestCreatedAt ?? now,
      requestUpdatedAt: now,
      requestExpiresAt:
          existing?.requestExpiresAt ?? now.add(const Duration(hours: 48)),
      requestLink: requestLink,
    );
    _jobsById[updated.jobId] = updated;
    _activeJobId = updated.jobId;
    _jobRequestsById[requestId] = _requestRecordFromJob(
      updated,
      ownerUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      requestId: requestId,
      requestStatus: 'pending',
      submittedAt: null,
      customerSubmittedAt: null,
      checklistResponses: const <VanJobRequestChecklistResponse>[],
      customQuestionResponses: const <VanJobRequestCustomQuestionResponse>[],
      additionalNotes: '',
      exactPinSource: '',
      exactPinNote: '',
      exactPinLat: null,
      exactPinLng: null,
    );
    _scheduleSave();
    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.job_request_send',
      );
      if (ownerUid != null && ownerUid.trim().isNotEmpty) {
      final record = await VanJobRequestCloudService.instance
            .createOrUpdateFromDraft(
              ownerUid: ownerUid,
              jobId: updated.jobId,
              draft: draft,
              requestId: requestId,
              source: 'van_mate.job_request',
            );
        _jobRequestsById[record.requestId] = record;
        _jobsById[updated.jobId] = _replyFromRequestRecord(record, existing: updated);
        await saveToStorage(syncCloud: false);
      }
    } catch (error) {
      debugPrint('[VanJobRequestCloud] create request failed: $error');
    }
    return _jobsById[updated.jobId] ?? updated;
  }

  DriverCustomerReplyMockData saveCustomerReplyForJob(
    String jobId,
    DriverCustomerReplyMockData reply,
  ) {
    final existing = _jobsById[jobId];
    final updated = (existing ?? reply).copyWith(
      jobId: jobId,
      customerName: reply.customerName,
      jobTitle: reply.jobTitle,
      jobDateLabel: reply.jobDateLabel,
      jobTimeLabel: reply.jobTimeLabel,
      address: reply.address,
      phoneNumber: reply.phoneNumber,
      customerEmail: reply.customerEmail,
      postcode: reply.postcode,
      notesMessage: reply.notesMessage,
      requestExactPin: reply.requestExactPin,
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
      requestStatus: 'submitted',
      requestCreatedAt: existing?.requestCreatedAt ?? reply.requestCreatedAt,
      requestUpdatedAt: DateTime.now(),
      requestSubmittedAt:
          existing?.requestSubmittedAt ?? reply.requestSubmittedAt ?? DateTime.now(),
      requestExpiresAt: existing?.requestExpiresAt ?? reply.requestExpiresAt,
      requestLink: existing?.requestLink ?? reply.requestLink,
    );
    _jobsById[jobId] = updated;
    final requestId = updated.requestId?.trim();
    if (requestId != null && requestId.isNotEmpty) {
      _jobRequestsById[requestId] = _requestRecordFromJob(
        updated,
        ownerUid: _jobRequestsById[requestId]?.ownerUid ??
            FirebaseAuth.instance.currentUser?.uid ??
            '',
        requestId: requestId,
        requestStatus: 'submitted',
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
        exactPinSource:
            vanExactPinSourceToStorage(updated.exactPinShareSource) ?? '',
        exactPinNote: updated.exactPinNote ?? '',
        exactPinLat: updated.exactPinLatitude,
        exactPinLng: updated.exactPinLongitude,
      );
    }
    _activeJobId = jobId;
    _scheduleSave();
    return updated;
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
    if (current == null) {
      return null;
    }
    final updated = update(current).copyWith(updatedAt: DateTime.now());
    _jobsById[resolvedId] = updated;
    _activeJobId = resolvedId;
    _scheduleSave();
    return updated;
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
      return job.copyWith(
        customerName: customerName ?? job.customerName,
        phoneNumber: phoneNumber ?? job.phoneNumber,
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
      );
    });
  }

  DriverCustomerReplyMockData? updateJobDateTime({
    String? jobId,
    required DateTime scheduledAt,
  }) {
    return _updateJob(jobId, (job) {
      return job.copyWith(
        scheduledAt: scheduledAt,
        jobDateLabel: _formatJobDate(DateUtils.dateOnly(scheduledAt)),
        jobTimeLabel: _formatJobTime(TimeOfDay.fromDateTime(scheduledAt)),
      );
    });
  }

  DriverCustomerReplyMockData? cancelJob({String? jobId}) {
    return _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(status: 'cancelled');
    });
  }

  bool deleteJob({String? jobId}) {
    final resolvedId = _resolveJobId(jobId);
    if (resolvedId == null) {
      return false;
    }

    final removed = _jobsById.remove(resolvedId);
    if (removed == null) {
      return false;
    }

    final invoiceKey = removed.invoiceHistoryKey;
    _invoiceHistoryByJobKey.remove(invoiceKey);
    if (savedInvoice?.jobKey == invoiceKey) {
      savedInvoice = null;
    }

    if (_activeJobId == resolvedId) {
      _activeJobId = _latestJob()?.jobId;
    }

    _scheduleSave();
    return true;
  }

  void setJobReady(bool value, {String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      if (!value) {
        return job.copyWith(status: 'draft');
      }
      final nextStatus = job.isCompletedJob
          ? 'completed'
          : job.status == 'confirmed'
          ? 'confirmed'
          : job.status == 'quoteSent'
          ? 'quoteSent'
          : 'replyReceived';
      return job.copyWith(
        status: nextStatus,
        replyReceivedAt: job.replyReceivedAt ?? DateTime.now(),
      );
    });
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

  void setQuoteSent(bool value, {String? jobId, double? amount}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(
        quoteAmount: amount ?? job.quoteAmount,
        quoteSavedAt: job.quoteSavedAt ?? DateTime.now(),
        quoteSentAt: value
            ? (job.quoteSentAt ?? DateTime.now())
            : job.quoteSentAt,
        status: value
            ? (job.isCompletedJob
                  ? 'completed'
                  : job.status == 'confirmed'
                  ? 'confirmed'
                  : 'quoteSent')
            : job.status,
      );
    });
  }

  void setJobConfirmed(bool value, {String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(
        confirmedAt: value
            ? (job.confirmedAt ?? DateTime.now())
            : job.confirmedAt,
        status: value
            ? (job.isCompletedJob ? 'completed' : 'confirmed')
            : job.status,
      );
    });
  }

  void setJobCompleted(bool value, {DateTime? completedAt, String? jobId}) {
    _updateJob(jobId, (job) {
      if (job.isCancelled) {
        return job;
      }
      return job.copyWith(
        completedAt: value
            ? (completedAt ?? job.completedAt ?? DateTime.now())
            : job.completedAt,
        status: value ? 'completed' : job.status,
      );
    });
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

  Map<String, dynamic> _toJson() {
    final active = activeJob;
    return <String, dynamic>{
      'activeJobId': _activeJobId,
      'jobs': jobs.map((job) => job.toJson()).toList(),
      'jobReady': active?.isReplyReceived ?? false,
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
          .map((request) => request.toFirestore())
          .toList(),
      'invoiceHistory': _invoiceHistoryByJobKey.values
          .map((entry) => entry.toJson())
          .toList(),
    };
  }

  void _applyJson(Map<String, dynamic> json) {
    _activeJobId = json['activeJobId']?.toString();
    _jobsById.clear();
    final jobsJson = json['jobs'];
    if (jobsJson is List) {
      for (final item in jobsJson) {
        if (item is Map) {
          final job = DriverCustomerReplyMockData.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (job.jobId.trim().isNotEmpty) {
            _jobsById[job.jobId] = job;
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

    if (_jobsById.isEmpty && _hasLegacyState(json)) {
      final demoJob = driverCustomerReplySample.copyWith(
        jobId: 'legacy-demo-job',
        status: _legacyStatusFromJson(json),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        quoteAmount: _jsonDoubleOrNull(json['quoteAmount']) ?? 45.0,
        exactPinShared:
            _jsonBool(json['pinSavedToJob']) ||
            vanExactPinSourceFromStorage(
                  json['exactPinShareSource']?.toString(),
                ) !=
                null,
      );
      _jobsById[demoJob.jobId] = demoJob;
      _activeJobId = demoJob.jobId;
    }

    savedInvoice = savedInvoiceHistory.isEmpty
        ? null
        : savedInvoiceHistory.first.draft;
  }

  void _mergeCloudJobs(List<DriverCustomerReplyMockData> cloudJobs) {
    for (final cloudJob in cloudJobs) {
      final existing = _jobsById[cloudJob.jobId];
      if (existing == null) {
        _jobsById[cloudJob.jobId] = cloudJob;
        continue;
      }

      final existingUpdated = existing.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cloudUpdated = cloudJob.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (cloudUpdated.isAfter(existingUpdated)) {
        _jobsById[cloudJob.jobId] = cloudJob;
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

  void _mergeCloudRequests(List<VanJobRequestRecord> cloudRequests) {
    for (final request in cloudRequests) {
      final existing = _jobRequestsById[request.requestId];
      final existingUpdated = existing?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (existing == null || request.updatedAt.isAfter(existingUpdated)) {
        _jobRequestsById[request.requestId] = request;
      }

      final linkedJob = _jobsById[request.jobId];
      final requestReply = _replyFromRequestRecord(request, existing: linkedJob);
      final shouldApply = request.isSubmitted ||
          request.hasReply ||
          linkedJob?.status == 'requestSent' ||
          linkedJob?.status == 'draft' ||
          linkedJob == null;
      if (!shouldApply) {
        continue;
      }

      _jobsById[request.jobId] = requestReply;
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
      status: requestStatus,
      createdAt: job.requestCreatedAt ?? job.createdAt ?? now,
      updatedAt: job.requestUpdatedAt ?? now,
      expiresAt:
          job.requestExpiresAt ?? now.add(const Duration(hours: 48)),
      scheduledAt: job.scheduledAtOrParsed,
      jobDateLabel: job.jobDateLabel,
      jobTimeLabel: job.jobTimeLabel,
      publicJobTitle: job.jobTitle,
      publicCustomerName: job.customerName,
      publicAddressSummary: job.address,
      publicPhoneNumber: job.phoneNumber,
      publicCustomerEmail: job.customerEmail,
      checklistItems: job.checklistItems,
      customQuestions: job.customQuestions,
      exactPinRequested: job.requestExactPin,
      driverMessagePreview: job.notesMessage,
      submittedAt: submittedAt,
      customerSubmittedAt: customerSubmittedAt,
      checklistResponses: checklistResponses,
      customQuestionResponses: customQuestionResponses,
      additionalNotes: additionalNotes,
      exactPinLat: exactPinLat,
      exactPinLng: exactPinLng,
      exactPinSource: exactPinSource,
      exactPinNote: exactPinNote,
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
    final customResponses = request.customQuestionResponses
        .map(
          (response) => DriverCustomQuestionResponse(
            question: response.question,
            answer: response.answer,
          ),
        )
        .toList(growable: false);

    final status = request.isSubmitted || request.hasReply
        ? (existing?.isCompletedJob == true
              ? 'completed'
              : existing?.status == 'confirmed'
              ? 'confirmed'
              : existing?.status == 'quoteSent'
              ? 'quoteSent'
              : 'replyReceived')
        : (existing?.status ?? 'requestSent');

    return (existing ??
            DriverCustomerReplyMockData(
              jobId: request.jobId,
              customerName: request.publicCustomerName,
              jobTitle: request.publicJobTitle,
              scheduledAt: request.scheduledAt,
              jobDateLabel: request.jobDateLabel,
              jobTimeLabel: request.jobTimeLabel,
              address: request.publicAddressSummary,
              phoneNumber: request.publicPhoneNumber,
              customerEmail: request.publicCustomerEmail,
              requestExactPin: request.exactPinRequested,
              checklistItems: request.checklistItems,
              customQuestions: request.customQuestions,
              status: status,
              createdAt: request.createdAt,
              updatedAt: request.updatedAt,
              exactPinShared: request.hasExactPin,
              checklistResponses: checklistResponses,
              customQuestionResponses: customResponses,
              additionalNotes: request.additionalNotes,
              exactPinShareSource:
                  vanExactPinSourceFromStorage(request.exactPinSource),
              exactPinNote: request.exactPinNote,
              exactPinLatitude: request.exactPinLat,
              exactPinLongitude: request.exactPinLng,
              requestId: request.requestId,
              requestStatus: request.status,
              requestCreatedAt: request.createdAt,
              requestUpdatedAt: request.updatedAt,
              requestSubmittedAt: request.submittedAt,
              requestExpiresAt: request.expiresAt,
              requestLink: buildVanJobRequestLink(request.requestId),
            ))
        .copyWith(
          jobId: request.jobId,
          customerName: request.publicCustomerName,
          jobTitle: request.publicJobTitle,
          scheduledAt: request.scheduledAt,
          jobDateLabel: request.jobDateLabel,
          jobTimeLabel: request.jobTimeLabel,
          address: request.publicAddressSummary,
          phoneNumber: request.publicPhoneNumber,
          customerEmail: request.publicCustomerEmail,
          requestExactPin: request.exactPinRequested,
          checklistItems: request.checklistItems,
          customQuestions: request.customQuestions,
          status: status,
          updatedAt: request.updatedAt,
          replyReceivedAt: request.isSubmitted || request.hasReply
              ? (request.customerSubmittedAt ?? request.submittedAt)
              : existing?.replyReceivedAt,
          exactPinShared: request.hasExactPin,
          checklistResponses: checklistResponses,
          customQuestionResponses: customResponses,
          additionalNotes: request.additionalNotes,
          exactPinShareSource:
              vanExactPinSourceFromStorage(request.exactPinSource),
          exactPinNote: request.exactPinNote,
          exactPinLatitude: request.exactPinLat,
          exactPinLongitude: request.exactPinLng,
          requestId: request.requestId,
          requestStatus: request.status,
          requestCreatedAt: request.createdAt,
          requestUpdatedAt: request.updatedAt,
          requestSubmittedAt: request.submittedAt,
          requestExpiresAt: request.expiresAt,
          requestLink: buildVanJobRequestLink(request.requestId),
        );
  }

  bool _hasLegacyState(Map<String, dynamic> json) {
    return _jsonBool(json['jobReady']) ||
        _jsonBool(json['pinSavedToJob']) ||
        _jsonBool(json['quoteSaved']) ||
        _jsonBool(json['quoteSent']) ||
        _jsonBool(json['jobConfirmed']) ||
        _jsonBool(json['jobCompleted']) ||
        _jsonBool(json['invoiceCreated']) ||
        _jsonBool(json['invoiceSent']) ||
        (json['exactPinShareSource']?.toString().trim().isNotEmpty ?? false) ||
        (json['invoiceHistory'] is List &&
            (json['invoiceHistory'] as List).isNotEmpty);
  }

  String _legacyStatusFromJson(Map<String, dynamic> json) {
    if (_jsonBool(json['jobCompleted']) || _jsonBool(json['invoiceCreated'])) {
      return 'completed';
    }
    if (_jsonBool(json['jobConfirmed'])) {
      return 'confirmed';
    }
    if (_jsonBool(json['quoteSent'])) {
      return 'quoteSent';
    }
    if (_jsonBool(json['jobReady'])) {
      return 'replyReceived';
    }
    if (_jsonBool(json['pinSavedToJob'])) {
      return 'requestSent';
    }
    return 'draft';
  }

  bool get jobReady => activeJob?.isReplyReceived ?? false;
  bool get pinSavedToJob => activeJob?.exactPinShared ?? false;
  bool get quoteSaved => activeJob?.quoteAmount != null;
  bool get quoteSent => activeJob?.isQuoteSent ?? false;
  bool get jobConfirmed => activeJob?.isConfirmed ?? false;
  bool get jobCompleted => activeJob?.isCompleted ?? false;
  DateTime? get jobCompletedAt => activeJob?.completedAt;
  bool get invoiceCreated => _invoiceHistoryByJobKey.isNotEmpty;
  bool get invoiceSent => activeJob?.isCompleted ?? false;
  VanExactPinSource? get exactPinShareSource => activeJob?.exactPinShareSource;
  String? get exactPinNote => activeJob?.exactPinNote;

  List<VanInvoiceHistoryEntry> get savedInvoiceHistory {
    final entries = _invoiceHistoryByJobKey.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return entries;
  }

  VanInvoiceHistoryEntry? invoiceHistoryEntryForJob(String jobKey) {
    return _invoiceHistoryByJobKey[jobKey];
  }

  VanInvoiceDraft? invoiceForJob(String jobKey) {
    return _invoiceHistoryByJobKey[jobKey]?.draft;
  }

  VanJobRequestRecord? requestForId(String requestId) {
    return _jobRequestsById[requestId.trim()];
  }

  void upsertInvoiceForJob(String jobKey, VanInvoiceDraft draft) {
    final existing = _invoiceHistoryByJobKey[jobKey];
    final savedDraft = draft.copyWith(jobKey: jobKey);
    _invoiceHistoryByJobKey[jobKey] = VanInvoiceHistoryEntry(
      jobKey: jobKey,
      draft: savedDraft,
      savedAt: existing?.savedAt ?? DateTime.now(),
    );
    savedInvoice = savedDraft;
    _scheduleSave();
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

    _invoiceHistoryByJobKey[jobKey] = VanInvoiceHistoryEntry(
      jobKey: jobKey,
      draft: updatedDraft,
      savedAt: entry.savedAt,
    );

    if (savedInvoice?.jobKey == jobKey ||
        savedInvoice?.invoiceNumber == entry.draft.invoiceNumber) {
      savedInvoice = updatedDraft;
    }

    _scheduleSave();
    return updatedDraft;
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

    _invoiceHistoryByJobKey[jobKey] = VanInvoiceHistoryEntry(
      jobKey: jobKey,
      draft: updatedDraft,
      savedAt: entry.savedAt,
    );

    if (savedInvoice?.jobKey == jobKey ||
        savedInvoice?.invoiceNumber == entry.draft.invoiceNumber) {
      savedInvoice = updatedDraft;
    }

    _scheduleSave();
    return updatedDraft;
  }
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
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
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

String _jsonText(Object? value, {String fallback = ''}) {
  final text = sanitizeVanText(value?.toString()).trim();
  return text.isEmpty ? fallback : text;
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

final DriverCustomerReplyMockData driverCustomerReplySample =
    DriverCustomerReplyMockData(
      jobId: 'demo-job',
      customerName: 'Demo Customer',
      jobTitle: 'Sample job',
      scheduledAt: DateTime(2026, 5, 17, 14, 2),
      jobDateLabel: 'Today',
      jobTimeLabel: '14:02',
      address: 'Sample address',
      phoneNumber: '00000000000',
      quoteAmount: 0.0,
      status: 'completed',
      exactPinShared: true,
      exactPinShareSource: VanExactPinSource.currentLocation,
      exactPinNote: 'Demo pin note.',
      exactPinLatitude: 53.4084,
      exactPinLongitude: -2.9916,
      checklistResponses: <DriverChecklistResponse>[
        DriverChecklistResponse(
          question: 'Parking available?',
          answer: 'Yes',
          note: 'demo',
          icon: Icons.local_parking,
        ),
        DriverChecklistResponse(
          question: 'Any access restrictions?',
          answer: 'No',
          note: 'demo',
          icon: Icons.lock_outline,
        ),
        DriverChecklistResponse(
          question: 'Stairs or lift?',
          answer: 'Stairs',
          note: 'demo',
          icon: Icons.stairs_outlined,
        ),
        DriverChecklistResponse(
          question: 'Help loading/unloading?',
          answer: 'Maybe',
          note: 'demo',
          icon: Icons.support_agent_outlined,
        ),
        DriverChecklistResponse(
          question: 'Large or heavy items?',
          answer: 'No',
          note: 'demo',
          icon: Icons.inventory_2_outlined,
        ),
        DriverChecklistResponse(
          question: 'Fragile items?',
          answer: 'No',
          icon: Icons.warning_amber_outlined,
        ),
        DriverChecklistResponse(
          question: 'Photos needed?',
          answer: 'Photo requested',
          note: 'demo',
          icon: Icons.photo_camera_outlined,
        ),
      ],
      customQuestionResponses: <DriverCustomQuestionResponse>[
        DriverCustomQuestionResponse(
          question: 'Is there a brew involved',
          answer: 'Yes',
        ),
        DriverCustomQuestionResponse(
          question: 'Any gate codes or access instructions?',
          answer: '',
        ),
      ],
      additionalNotes: 'Demo customer notes.',
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

class DriverCustomerReplyPage extends StatefulWidget {
  const DriverCustomerReplyPage({super.key, required this.reply});

  final DriverCustomerReplyMockData reply;

  @override
  State<DriverCustomerReplyPage> createState() =>
      _DriverCustomerReplyPageState();
}

class _DriverCustomerReplyPageState extends State<DriverCustomerReplyPage> {
  late bool _jobReady;
  late bool _pinSavedToJob;

  DriverCustomerReplyMockData get reply => widget.reply;

  String get _jobId => reply.jobId;

  @override
  void initState() {
    super.initState();
    _jobReady =
        reply.isReplyReceived ||
        reply.isQuoteSent ||
        reply.isConfirmed ||
        reply.isCompleted;
    _pinSavedToJob = reply.exactPinShared;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _markReady() {
    setState(() {
      _jobReady = true;
    });
    DriverReplyMockState.instance.setJobReady(true, jobId: _jobId);
    _showSnack('Job marked ready');
  }

  void _openMaps() {
    final latLng = _exactPinCoordinates();
    if (latLng == null) {
      _showSnack('No exact pin coordinates saved yet.');
      return;
    }

    unawaited(
      openVanGoogleMapsAtCoordinates(
        context,
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      ),
    );
  }

  void _savePin() {
    setState(() {
      _pinSavedToJob = true;
    });
    DriverReplyMockState.instance.setPinSavedToJob(true, jobId: _jobId);
    _showSnack('Pin saved to this job.');
  }

  void _saveNotesToPlace() {
    _showSnack('Customer notes saved to place.');
  }

  void _createQuote() {
    unawaited(openDriverQuoteMockPage(context, reply));
  }

  void _navigate() {
    if (!reply.exactPinShared) {
      _showSnack('Exact pin is not shared yet');
      return;
    }

    _showSnack('Navigation would open using your preferred nav app.');
  }

  VanExactPinSource? _exactPinSource() {
    return DriverReplyMockState.instance.jobById(_jobId)?.exactPinShareSource ??
        reply.exactPinShareSource;
  }

  String _exactPinSourceText() {
    final source = _exactPinSource();
    if (source == null) {
      return 'Customer shared the drop-off location.';
    }
    return source.driverSourceText;
  }

  LatLng? _exactPinCoordinates() {
    final job = DriverReplyMockState.instance.jobById(_jobId) ?? reply;
    final latitude = job.exactPinLatitude;
    final longitude = job.exactPinLongitude;
    if (latitude == null || longitude == null) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  String _exactPinHelperText() {
    final source = _exactPinSource();
    if (source == null) {
      return 'This can be saved to the job/place and used for navigation.';
    }
    switch (source) {
      case VanExactPinSource.currentLocation:
        return 'Use this exact spot for navigation and save it to the job if needed.';
      case VanExactPinSource.mapSelection:
        return 'Use the selected pin for the route.';
    }
  }

  String _exactPinCoordinatesText() {
    final latLng = _exactPinCoordinates();
    if (latLng == null) {
      return 'Coordinates not saved yet.';
    }
    return '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
  }

  String _exactPinNoteText() {
    final note =
        DriverReplyMockState.instance.jobById(_jobId)?.exactPinNote ??
        reply.exactPinNote;
    if (note == null || note.trim().isEmpty) {
      return '';
    }
    return note.trim();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final replyStatus = _jobReady ? 'Ready' : 'Reply received';
    final replyAccent = _jobReady
        ? const Color(0xFF58D0A4)
        : const Color(0xFF4A7DFF);

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
                        'Customer reply received',
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
                                    _jobReady
                                        ? Icons.check_circle_outline
                                        : Icons.mark_email_read_outlined,
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
                                          _buildStatusChip(
                                            replyStatus,
                                            color: replyAccent,
                                            icon: _jobReady
                                                ? Icons.check_circle
                                                : Icons
                                                      .mark_email_read_outlined,
                                            filled: true,
                                          ),
                                          _buildStatusChip(
                                            reply.exactPinShared
                                                ? 'Exact pin shared'
                                                : 'Exact pin missing',
                                            color: reply.exactPinShared
                                                ? const Color(0xFF58D0A4)
                                                : const Color(0xFFFFC38C),
                                            icon: Icons.location_on,
                                          ),
                                          _buildStatusChip(
                                            '5 checklist answers',
                                            color: const Color(0xFF4A7DFF),
                                            icon: Icons.checklist,
                                          ),
                                          _buildStatusChip(
                                            '${reply.customAnsweredCount} custom answer${reply.customAnsweredCount == 1 ? '' : 's'}',
                                            color: const Color(0xFFB48CFF),
                                            icon: Icons.question_answer,
                                          ),
                                          _buildStatusChip(
                                            'Ready to quote',
                                            color: const Color(0xFF58D0A4),
                                            icon: Icons.request_quote_outlined,
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
                                _MiniInfoPill(
                                  icon: Icons.schedule,
                                  label:
                                      '${reply.jobDateLabel} | ${reply.jobTimeLabel}',
                                ),
                                _MiniInfoPill(
                                  icon: Icons.location_on,
                                  label: reply.address,
                                ),
                                _MiniInfoPill(
                                  icon: Icons.phone,
                                  label: reply.phoneNumber,
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
                            const _ReplySectionHeader(
                              icon: Icons.location_on,
                              title: 'Exact pin received',
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(
                                  0xFF58D0A4,
                                ).withValues(alpha: 0.14),
                                border: Border.all(
                                  color: const Color(
                                    0xFF58D0A4,
                                  ).withValues(alpha: 0.24),
                                ),
                              ),
                              child: Builder(
                                builder: (context) {
                                  final noteText = _exactPinNoteText();
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _exactPinSourceText(),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _exactPinHelperText(),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.76,
                                              ),
                                              height: 1.4,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Source: ${_exactPinSourceText()}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.70,
                                              ),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _exactPinCoordinatesText(),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.64,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      if (noteText.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Customer pin note',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.68,
                                                          ),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .sticky_note_2_outlined,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      noteText,
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.82,
                                                                ),
                                                            height: 1.4,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (_pinSavedToJob) ...[
                                        const SizedBox(height: 10),
                                        _buildStatusChip(
                                          'Pin saved to job',
                                          color: const Color(0xFF58D0A4),
                                          icon: Icons.check_circle,
                                          filled: true,
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 480;
                                final pinLabel = _pinSavedToJob
                                    ? 'Pin saved to job'
                                    : 'Save pin to job/place';
                                final actions = <Widget>[
                                  FilledButton.icon(
                                    onPressed: _openMaps,
                                    icon: const Icon(Icons.map_outlined),
                                    label: const Text('Open in Maps'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A7DFF),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pinSavedToJob ? null : _savePin,
                                    icon: const Icon(Icons.save),
                                    label: Text(pinLabel),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                      ),
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ];

                                if (stacked) {
                                  return Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < actions.length;
                                        i++
                                      ) ...[
                                        actions[i],
                                        if (i < actions.length - 1)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: actions[0]),
                                    const SizedBox(width: 10),
                                    Expanded(child: actions[1]),
                                  ],
                                );
                              },
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
                              icon: Icons.checklist,
                              title: 'Customer answers',
                            ),
                            const SizedBox(height: 12),
                            for (
                              var index = 0;
                              index < reply.checklistResponses.length;
                              index++
                            ) ...[
                              _buildAnswerCard(
                                icon: reply.checklistResponses[index].icon,
                                question:
                                    reply.checklistResponses[index].question,
                                answer: reply.checklistResponses[index].answer,
                                note: reply.checklistResponses[index].note,
                              ),
                              if (index < reply.checklistResponses.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
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
                                answer:
                                    reply.customQuestionResponses[index].answer,
                              ),
                              if (index <
                                  reply.customQuestionResponses.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ReplySectionHeader(
                              icon: Icons.notes,
                              title: 'Additional notes',
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
                                reply.additionalNotes.isEmpty
                                    ? 'No extra notes added.'
                                    : reply.additionalNotes,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.76),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final actionWidgets = <Widget>[
                            FilledButton.icon(
                              onPressed: _createQuote,
                              icon: const Icon(Icons.request_quote_outlined),
                              label: const Text('Create quote'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4A7DFF),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _markReady,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Mark job ready'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _navigate,
                              icon: const Icon(Icons.navigation),
                              label: const Text('Navigate'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saveNotesToPlace,
                              icon: const Icon(Icons.place_outlined),
                              label: const Text('Save notes to place'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
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
                              for (final button in actionWidgets)
                                SizedBox(width: buttonWidth, child: button),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This reply will save back to the driver\'s job, calendar and place notes.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.45,
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

class _CreateQuotePageState extends State<CreateQuotePage> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quoteNotesController;
  late final TextEditingController _paymentInstructionsController;
  late final TextEditingController _extraItemController;

  final List<String> _extraItems = <String>[];

  bool _saved = DriverReplyMockState.instance.quoteSaved;
  bool _sent = DriverReplyMockState.instance.quoteSent;

  DriverCustomerReplyMockData get reply => widget.reply;
  String get _jobId => reply.jobId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: reply.quoteAmount?.toStringAsFixed(2) ?? '',
    );
    _descriptionController = TextEditingController(text: reply.jobTitle);
    _quoteNotesController = TextEditingController();
    _paymentInstructionsController = TextEditingController(
      text: 'Payment is arranged directly with the driver/business.',
    );
    _extraItemController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _quoteNotesController.dispose();
    _paymentInstructionsController.dispose();
    _extraItemController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _saveQuote() {
    setState(() {
      _saved = true;
    });
    final amount = parseCurrencyValue(_amountValue());
    DriverReplyMockState.instance.setQuoteSaved(true, jobId: _jobId);
    DriverReplyMockState.instance.setQuoteSent(
      false,
      jobId: _jobId,
      amount: amount,
    );
    _showSnack('Quote saved.');
  }

  void _sendQuote() {
    setState(() {
      _saved = true;
      _sent = true;
    });
    final amount = parseCurrencyValue(_amountValue());
    DriverReplyMockState.instance
      ..setQuoteSaved(true, jobId: _jobId)
      ..setQuoteSent(true, jobId: _jobId, amount: amount);
    _showSnack('Quote sent to customer.');
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: _quotePreviewText()));
    _showSnack('Quote message copied.');
  }

  void _addExtraItem(String item) {
    final cleaned = item.trim();
    if (cleaned.isEmpty) {
      return;
    }

    setState(() {
      if (!_extraItems.contains(cleaned)) {
        _extraItems.add(cleaned);
      }
    });
    _extraItemController.clear();
  }

  void _toggleExtraItem(String item) {
    final cleaned = item.trim();
    if (cleaned.isEmpty) {
      return;
    }

    setState(() {
      if (_extraItems.contains(cleaned)) {
        _extraItems.remove(cleaned);
      } else {
        _extraItems.add(cleaned);
      }
    });
  }

  String _amountValue() {
    final raw = _amountController.text.trim();
    if (raw.isEmpty) {
      return reply.quoteAmount?.toStringAsFixed(2) ?? '0.00';
    }

    return raw;
  }

  String _quotePreviewText() {
    final notes = _quoteNotesController.text.trim();
    final instructions = _paymentInstructionsController.text.trim();
    final extras = _extraItems.isEmpty
        ? ''
        : '\nExtras:\n${_extraItems.map((item) => '- $item').join('\n')}';
    final notesBlock = notes.isEmpty
        ? 'No extra notes added.'
        : sanitizeVanText(notes).trim();
    final instructionsBlock = instructions.isEmpty
        ? 'Payment is arranged directly with the driver/business.'
        : sanitizeVanText(instructions).trim();
    final quoteAmount = formatCurrency(parseCurrencyValue(_amountValue()));

    return '''
Hi ${sanitizeVanText(reply.customerName).trim()}, here's the quote for your ${sanitizeVanText(reply.jobTitle).trim().toLowerCase()}.

Job date: ${sanitizeVanText(reply.jobDateLabel).trim()}
Address: ${sanitizeVanText(reply.address).trim()}

Quote: $quoteAmount
$extras
Notes:
$notesBlock

Payment / confirmation:
$instructionsBlock

Please reply to confirm if you're happy to go ahead.
''';
  }

  String? _currentJobCustomQuestionSummary() {
    final parts = <String>[];
    for (final question in reply.customQuestions) {
      final cleanedQuestion = question.trim();
      if (cleanedQuestion.isEmpty) {
        continue;
      }

      final match = reply.customQuestionResponses.firstWhere(
        (item) => item.question.trim() == cleanedQuestion,
        orElse: () =>
            DriverCustomQuestionResponse(question: cleanedQuestion, answer: ''),
      );
      final cleanedAnswer = match.answer.trim();
      if (cleanedAnswer.isEmpty) {
        continue;
      }

      parts.add(formatCustomQuestionAnswer(cleanedQuestion, cleanedAnswer));
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: maxLines,
      onChanged: (_) => setState(() {}),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        hintText: hint,
        prefixText: prefixText,
        labelOpacity: 0.68,
        hintOpacity: 0.50,
      ),
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

  Widget _buildSuggestionChip(String label) {
    final selected = _extraItems.contains(label);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleExtraItem(label),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? const Color(0xFF4A7DFF).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4A7DFF).withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_circle, size: 13, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedExtraChip(String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleExtraItem(label),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF4A7DFF).withValues(alpha: 0.16),
            border: Border.all(
              color: const Color(0xFF4A7DFF).withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.label_outline, size: 13, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.close, size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  String _checklistValue(String question, String fallback) {
    final match = reply.checklistResponses.firstWhere(
      (item) => item.question == question,
      orElse: () =>
          DriverChecklistResponse(question: question, answer: fallback),
    );
    return match.answer.isEmpty ? fallback : match.answer;
  }

  String? _checklistNote(String question) {
    final match = reply.checklistResponses.firstWhere(
      (item) => item.question == question,
      orElse: () => const DriverChecklistResponse(question: '', answer: ''),
    );
    final note = match.note?.trim() ?? '';
    if (note.isEmpty || !_hasUsefulNote(note)) {
      return null;
    }
    return note;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final previewText = _quotePreviewText();
    final customQuestionSummary = _currentJobCustomQuestionSummary();

    final pricingSummary = <_QuoteSummaryItem>[
      _QuoteSummaryItem(
        icon: Icons.local_parking,
        label: 'Parking',
        value: formatAnswerWithNote(
          _checklistValue('Parking available?', 'Yes'),
          _checklistNote('Parking available?'),
        ),
        accent: const Color(0xFF58D0A4),
      ),
      _QuoteSummaryItem(
        icon: Icons.lock_outline,
        label: 'Access',
        value: 'No restrictions',
        accent: const Color(0xFF4A7DFF),
      ),
      _QuoteSummaryItem(
        icon: Icons.stairs_outlined,
        label: 'Stairs/lift',
        value: formatAnswerWithNote(
          _checklistValue('Stairs or lift?', 'Stairs'),
          _checklistNote('Stairs or lift?'),
        ),
        accent: const Color(0xFFB48CFF),
      ),
      _QuoteSummaryItem(
        icon: Icons.support_agent_outlined,
        label: 'Loading help',
        value: _checklistValue('Help loading/unloading?', 'Maybe'),
        accent: const Color(0xFF4A7DFF),
      ),
      _QuoteSummaryItem(
        icon: Icons.inventory_2_outlined,
        label: 'Heavy items',
        value: _checklistValue('Large or heavy items?', 'No'),
        accent: const Color(0xFF58D0A4),
      ),
      _QuoteSummaryItem(
        icon: Icons.photo_camera_outlined,
        label: 'Photos',
        value: 'Photo requested',
        accent: const Color(0xFFB48CFF),
      ),
      _QuoteSummaryItem(
        icon: Icons.question_answer,
        label: 'Custom',
        value: customQuestionSummary ?? 'No extra custom questions added.',
        accent: const Color(0xFF4A7DFF),
      ),
    ];

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
                        'Create quote',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the customer reply to price the job.',
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
                              icon: Icons.receipt_long_outlined,
                              title: 'Job summary',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _MiniInfoPill(
                                  icon: Icons.person,
                                  label: reply.customerName,
                                ),
                                _MiniInfoPill(
                                  icon: Icons.phone,
                                  label: reply.phoneNumber,
                                ),
                                _MiniInfoPill(
                                  icon: Icons.checklist,
                                  label: reply.jobTitle,
                                ),
                                _MiniInfoPill(
                                  icon: Icons.schedule,
                                  label: reply.scheduledAtOrParsed == null
                                      ? '${sanitizeVanText(reply.jobDateLabel).trim()} at ${sanitizeVanText(reply.jobTimeLabel).trim()}'
                                      : formatDateTime(
                                          reply.scheduledAtOrParsed!,
                                          TimeOfDay.fromDateTime(
                                            reply.scheduledAtOrParsed!,
                                          ),
                                        ),
                                ),
                                _MiniInfoPill(
                                  icon: Icons.location_on,
                                  label: reply.address,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildQuoteChip(
                                  'Reply received',
                                  color: const Color(0xFF4A7DFF),
                                  icon: Icons.mark_email_read_outlined,
                                  filled: true,
                                ),
                                _buildQuoteChip(
                                  reply.exactPinShared
                                      ? 'Exact pin shared'
                                      : 'Exact pin missing',
                                  color: reply.exactPinShared
                                      ? const Color(0xFF58D0A4)
                                      : const Color(0xFFFFC38C),
                                  icon: Icons.location_on,
                                ),
                                _buildQuoteChip(
                                  'Ready to quote',
                                  color: const Color(0xFF58D0A4),
                                  icon: Icons.request_quote_outlined,
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
                            const _ReplySectionHeader(
                              icon: Icons.fact_check_outlined,
                              title: 'Job info',
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final tileWidth = constraints.maxWidth < 520
                                    ? constraints.maxWidth
                                    : 228.0;
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
                            _buildField(
                              controller: _amountController,
                              label: 'Quote amount',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              prefixText: '£',
                            ),
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
                              icon: Icons.playlist_add,
                              title: 'Optional extras',
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 460;
                                final addButton = SizedBox(
                                  height: 54,
                                  width: stacked ? double.infinity : 96,
                                  child: FilledButton(
                                    onPressed: () => _addExtraItem(
                                      _extraItemController.text,
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A7DFF),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text('Add'),
                                  ),
                                );

                                if (stacked) {
                                  return Column(
                                    children: [
                                      _buildField(
                                        controller: _extraItemController,
                                        label: 'Add extra line item',
                                        hint: 'Waiting time',
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 10),
                                      addButton,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child: _buildField(
                                        controller: _extraItemController,
                                        label: 'Add extra line item',
                                        hint: 'Waiting time',
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    addButton,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in <String>[
                                  'Collection/delivery',
                                  'Extra helper',
                                  'Waiting time',
                                  'Stairs/access charge',
                                  'Mileage charge',
                                ])
                                  _buildSuggestionChip(item),
                              ],
                            ),
                            if (_extraItems.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final item in _extraItems)
                                    _buildSelectedExtraChip(item),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ReplyGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ReplySectionHeader(
                              icon: Icons.preview,
                              title: 'Message preview',
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
                                previewText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.45,
                                ),
                              ),
                            ),
                            if (_sent) ...[
                              const SizedBox(height: 12),
                              _buildQuoteChip(
                                'Quote sent',
                                color: const Color(0xFF58D0A4),
                                icon: Icons.check_circle,
                                filled: true,
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 480;
                          final actions = <Widget>[
                            FilledButton.icon(
                              onPressed: _sent ? null : _sendQuote,
                              icon: const Icon(Icons.send),
                              label: Text(_sent ? 'Quote sent' : 'Send quote'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saveQuote,
                              icon: const Icon(Icons.save),
                              label: const Text('Save quote'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _copyMessage,
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy message'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
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
                      const SizedBox(height: 14),
                      Text(
                        'Quote and message preview.',
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

  bool _saved = DriverReplyMockState.instance.quoteSaved;
  bool _sent = false;

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

  void _saveQuote() {
    setState(() {
      _saved = true;
    });
    final amount = parseCurrencyValue(_priceController.text);
    DriverReplyMockState.instance.setQuoteSaved(true, jobId: _jobId);
    DriverReplyMockState.instance.setQuoteSent(
      false,
      jobId: _jobId,
      amount: amount,
    );
    _showSnack('Quote saved');
  }

  void _sendQuote() {
    setState(() {
      _sent = true;
    });
    final amount = parseCurrencyValue(_priceController.text);
    DriverReplyMockState.instance.setQuoteSent(
      true,
      jobId: _jobId,
      amount: amount,
    );
    _showSnack('Quote sent');
  }

  String _quoteText() {
    final priceText = formatCurrency(parseCurrencyValue(_priceController.text));
    return '''
Hi ${sanitizeVanText(reply.customerName).trim()}, here's the quote for your ${sanitizeVanText(reply.jobTitle).trim().toLowerCase()}.

Job date: ${sanitizeVanText(reply.jobDateLabel).trim()}
Address: ${sanitizeVanText(reply.address).trim()}

Quote: $priceText

Please reply to confirm if you are happy to go ahead.
''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                        'Create quote',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quote and message preview, no payment handling.',
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
                            const _ReplySectionHeader(
                              icon: Icons.preview,
                              title: 'Message preview',
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
                                _quoteText(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  height: 1.45,
                                ),
                              ),
                            ),
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
                          final stacked = constraints.maxWidth < 480;
                          final actions = <Widget>[
                            OutlinedButton.icon(
                              onPressed: _saved ? null : _saveQuote,
                              icon: const Icon(Icons.save),
                              label: const Text('Save quote'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _sendQuote,
                              icon: const Icon(Icons.send),
                              label: const Text('Send quote'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
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

                          return Row(
                            children: [
                              Expanded(child: actions[0]),
                              const SizedBox(width: 10),
                              Expanded(child: actions[1]),
                            ],
                          );
                        },
                      ),
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
