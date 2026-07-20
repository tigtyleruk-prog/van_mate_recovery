import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../helpers/van_text_formatters.dart';
import '../models/van_invoice_history_entry.dart';
import '../models/van_invoice_draft.dart';
import 'van_business_local_notifications.dart';

enum VanInvoiceReminderStage {
  threeDays(3),
  sevenDays(7),
  fourteenDays(14);

  const VanInvoiceReminderStage(this.days);

  final int days;

  static List<VanInvoiceReminderStage> get orderedAscending => values;
  static List<VanInvoiceReminderStage> get orderedDescending =>
      values.reversed.toList(growable: false);
}

@immutable
class VanInvoiceReminderCandidate {
  const VanInvoiceReminderCandidate({
    required this.entry,
    required this.stage,
    required this.overdueDays,
    required this.baselineDate,
  });

  final VanInvoiceHistoryEntry entry;
  final VanInvoiceReminderStage stage;
  final int overdueDays;
  final DateTime baselineDate;
}

@immutable
class VanInvoiceReminderInsight {
  const VanInvoiceReminderInsight({
    required this.baselineDate,
    required this.overdueDays,
    required this.highestReachedStage,
    required this.latestSentStage,
    required this.nextNotificationStage,
  });

  final DateTime? baselineDate;
  final int overdueDays;
  final VanInvoiceReminderStage? highestReachedStage;
  final VanInvoiceReminderStage? latestSentStage;
  final VanInvoiceReminderStage? nextNotificationStage;

  bool get showReminderHint => highestReachedStage != null;

  String get reminderHintLabel {
    final stage = highestReachedStage;
    if (stage == null) {
      return '';
    }
    return 'Unpaid ${stage.days} days';
  }

  bool get hasReminderSent => latestSentStage != null;
}

@immutable
class VanInvoiceReminderOpenTarget {
  const VanInvoiceReminderOpenTarget({
    required this.jobKey,
    this.openUnpaidFilter = true,
  });

  final String jobKey;
  final bool openUnpaidFilter;
}

DateTime? parseVanInvoiceReminderDate(String value) {
  final text = sanitizeVanText(value).trim();
  if (text.isEmpty) {
    return null;
  }

  final direct = DateTime.tryParse(text);
  if (direct != null) {
    return direct;
  }

  final slash = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$',
  ).firstMatch(text);
  if (slash != null) {
    final day = int.tryParse(slash.group(1) ?? '');
    final month = int.tryParse(slash.group(2) ?? '');
    final parsedYear = int.tryParse(slash.group(3) ?? '');
    if (day == null || month == null || parsedYear == null) {
      return null;
    }
    final year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
    return _tryBuildDate(year, month, day);
  }

  final words = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})$',
  ).firstMatch(text);
  if (words == null) {
    return null;
  }

  final day = int.tryParse(words.group(1) ?? '');
  final month = _monthNumber(words.group(2) ?? '');
  final year = int.tryParse(words.group(3) ?? '');
  if (day == null || month == null || year == null) {
    return null;
  }
  return _tryBuildDate(year, month, day);
}

DateTime? resolveVanInvoiceReminderBaseline(VanInvoiceHistoryEntry entry) {
  final dueLabel = sanitizeVanText(entry.draft.dueDate).trim();
  final dueIsOnReceipt =
      dueLabel.isEmpty ||
      dueLabel.toLowerCase() == VanInvoiceDraft.dueOnReceiptLabel.toLowerCase();
  if (!dueIsOnReceipt) {
    final parsedDueDate = parseVanInvoiceReminderDate(dueLabel);
    if (parsedDueDate != null) {
      return _normalizeDate(parsedDueDate);
    }
  }

  final invoiceDate = parseVanInvoiceReminderDate(entry.draft.invoiceDate);
  return _normalizeDate(
    invoiceDate ?? entry.createdAt ?? entry.updatedAt ?? entry.savedAt,
  );
}

VanInvoiceReminderInsight analyzeVanInvoiceReminder(
  VanInvoiceHistoryEntry entry, {
  DateTime? now,
}) {
  if (entry.deleted ||
      entry.archived ||
      entry.linkedJobDeleted ||
      entry.draft.isPaid) {
    return const VanInvoiceReminderInsight(
      baselineDate: null,
      overdueDays: 0,
      highestReachedStage: null,
      latestSentStage: null,
      nextNotificationStage: null,
    );
  }

  final baselineDate = resolveVanInvoiceReminderBaseline(entry);
  if (baselineDate == null) {
    return const VanInvoiceReminderInsight(
      baselineDate: null,
      overdueDays: 0,
      highestReachedStage: null,
      latestSentStage: null,
      nextNotificationStage: null,
    );
  }

  final normalizedNow = _normalizeDate(now ?? DateTime.now());
  final overdueDays = normalizedNow.difference(baselineDate).inDays;
  if (overdueDays < 0) {
    return VanInvoiceReminderInsight(
      baselineDate: baselineDate,
      overdueDays: 0,
      highestReachedStage: null,
      latestSentStage: _latestSentStage(entry.draft),
      nextNotificationStage: null,
    );
  }

  final highestReachedStage = VanInvoiceReminderStage.orderedDescending
      .firstWhere(
        (stage) => overdueDays >= stage.days,
        orElse: () => VanInvoiceReminderStage.threeDays,
      );
  final reachedStage = overdueDays >= VanInvoiceReminderStage.threeDays.days
      ? highestReachedStage
      : null;
  final latestSentStage = _latestSentStage(entry.draft);

  return VanInvoiceReminderInsight(
    baselineDate: baselineDate,
    overdueDays: overdueDays,
    highestReachedStage: reachedStage,
    latestSentStage: latestSentStage,
    nextNotificationStage:
        reachedStage != null &&
            !entry.draft.hasReminderBeenSentForStage(reachedStage.days)
        ? reachedStage
        : null,
  );
}

List<VanInvoiceReminderCandidate> collectVanInvoiceReminderCandidates(
  Iterable<VanInvoiceHistoryEntry> invoices, {
  DateTime? now,
}) {
  final candidates = <VanInvoiceReminderCandidate>[];
  for (final entry in invoices) {
    final insight = analyzeVanInvoiceReminder(entry, now: now);
    final stage = insight.nextNotificationStage;
    final baselineDate = insight.baselineDate;
    if (stage == null || baselineDate == null) {
      continue;
    }
    candidates.add(
      VanInvoiceReminderCandidate(
        entry: entry,
        stage: stage,
        overdueDays: insight.overdueDays,
        baselineDate: baselineDate,
      ),
    );
  }

  candidates.sort((a, b) {
    final stageCompare = b.stage.days.compareTo(a.stage.days);
    if (stageCompare != 0) {
      return stageCompare;
    }
    return b.baselineDate.compareTo(a.baselineDate);
  });
  return candidates;
}

String buildVanInvoiceReminderBody(VanInvoiceHistoryEntry entry) {
  final invoiceNumber = sanitizeVanText(entry.draft.invoiceNumber).trim();
  final customerName = sanitizeVanText(entry.draft.customerName).trim();
  final amount = entry.draft.totalDueText;

  final leading = [
    if (invoiceNumber.isNotEmpty) invoiceNumber,
    if (customerName.isNotEmpty) customerName,
  ].join(' · ');

  if (leading.isNotEmpty) {
    return '$leading · $amount is still awaiting payment.';
  }

  if (customerName.isNotEmpty) {
    return '$customerName still owes $amount.';
  }

  if (invoiceNumber.isNotEmpty) {
    return 'Invoice $invoiceNumber is still awaiting payment for $amount.';
  }

  return 'An invoice is still awaiting payment.';
}

class VanInvoiceReminderService {
  VanInvoiceReminderService._({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? vanBusinessLocalNotificationsPlugin;

  static final VanInvoiceReminderService instance =
      VanInvoiceReminderService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  Future<void> Function(VanInvoiceReminderOpenTarget target)? _openHandler;
  VanInvoiceReminderOpenTarget? _pendingOpenTarget;
  bool _initialized = false;
  bool _isChecking = false;
  DateTime? _lastCheckAt;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    final settings = const InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: LinuxInitializationSettings(defaultActionName: 'Open invoice'),
    );

    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;

    final launchDetails = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse != null) {
      _handleNotificationResponse(launchDetails!.notificationResponse!);
    }
  }

  void registerOpenHandler(
    Future<void> Function(VanInvoiceReminderOpenTarget target) handler,
  ) {
    _openHandler = handler;
    _flushPendingOpenTarget();
  }

  void clearOpenHandler() {
    _openHandler = null;
  }

  Future<void> runReminderCheck({
    required List<VanInvoiceHistoryEntry> invoices,
    required FutureOr<void> Function(
      String jobKey,
      int stageDays,
      DateTime sentAt,
    )
    onReminderSent,
    DateTime? now,
  }) async {
    if (kIsWeb || !_initialized || _isChecking) {
      return;
    }

    final throttleNow = DateTime.now();
    if (_lastCheckAt != null &&
        throttleNow.difference(_lastCheckAt!) < const Duration(seconds: 5)) {
      return;
    }

    _isChecking = true;
    _lastCheckAt = throttleNow;
    try {
      final sentAt = now ?? DateTime.now();
      final candidates = collectVanInvoiceReminderCandidates(
        invoices,
        now: sentAt,
      );
      for (final candidate in candidates) {
        final jobKey = candidate.entry.jobKey.trim();
        if (jobKey.isEmpty) {
          continue;
        }

        await _notificationsPlugin.show(
          id: _notificationIdFor(jobKey, candidate.stage.days),
          title: 'Invoice still unpaid',
          body: buildVanInvoiceReminderBody(candidate.entry),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'van_invoice_reminders',
              'Invoice reminders',
              channelDescription: 'Reminders for invoices awaiting payment.',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              category: AndroidNotificationCategory.reminder,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
            macOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
            linux: LinuxNotificationDetails(),
          ),
          payload: jsonEncode(<String, dynamic>{
            'type': 'invoice_reminder',
            'jobKey': jobKey,
            'openUnpaidFilter': true,
          }),
        );

        await onReminderSent(jobKey, candidate.stage.days, sentAt);
      }
    } finally {
      _isChecking = false;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload?.trim() ?? '';
    if (payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return;
      }

      final data = Map<String, dynamic>.from(decoded);
      if ((data['type']?.toString().trim() ?? '') != 'invoice_reminder') {
        return;
      }

      final target = VanInvoiceReminderOpenTarget(
        jobKey: data['jobKey']?.toString().trim() ?? '',
        openUnpaidFilter: data['openUnpaidFilter'] != 'false',
      );
      if (target.jobKey.isEmpty) {
        return;
      }
      _pendingOpenTarget = target;
      _flushPendingOpenTarget();
    } catch (_) {
      return;
    }
  }

  void _flushPendingOpenTarget() {
    final target = _pendingOpenTarget;
    final handler = _openHandler;
    if (target == null || handler == null) {
      return;
    }

    _pendingOpenTarget = null;
    unawaited(handler(target));
  }

  static int _notificationIdFor(String jobKey, int stageDays) {
    return Object.hash(jobKey, stageDays) & 0x7fffffff;
  }
}

VanInvoiceReminderStage? _latestSentStage(VanInvoiceDraft draft) {
  for (final stage in VanInvoiceReminderStage.orderedDescending) {
    if (draft.hasReminderBeenSentForStage(stage.days)) {
      return stage;
    }
  }
  return null;
}

DateTime _normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int? _monthNumber(String raw) {
  const months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  return months[raw.trim().toLowerCase()];
}

DateTime? _tryBuildDate(int year, int month, int day) {
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final built = DateTime(year, month, day);
  if (built.year != year || built.month != month || built.day != day) {
    return null;
  }
  return built;
}
