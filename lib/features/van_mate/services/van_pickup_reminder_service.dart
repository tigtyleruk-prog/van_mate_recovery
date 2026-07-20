import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers/van_text_formatters.dart';
import '../models/van_customer_journey.dart';
import '../models/van_service_handover.dart';
import 'van_business_local_notifications.dart';

const Duration vanPickupReminderLeadTime = Duration(minutes: 30);

enum VanPickupReminderTiming { scheduled, immediate, skipped }

@immutable
class VanPickupReminderPlan {
  const VanPickupReminderPlan({required this.timing, this.notificationAt});

  final VanPickupReminderTiming timing;
  final DateTime? notificationAt;
}

bool shouldScheduleVanPickupReminder({
  required bool isDropOffPickup,
  required bool isScheduled,
  required bool isCompleted,
  required bool isCancelled,
  required bool isHidden,
  required DateTime? pickUpAt,
}) {
  return isDropOffPickup &&
      isScheduled &&
      !isCompleted &&
      !isCancelled &&
      !isHidden &&
      pickUpAt != null;
}

VanPickupReminderPlan buildVanPickupReminderPlan({
  required DateTime pickUpAt,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  if (!pickUpAt.isAfter(resolvedNow)) {
    return const VanPickupReminderPlan(timing: VanPickupReminderTiming.skipped);
  }

  final reminderAt = pickUpAt.subtract(vanPickupReminderLeadTime);
  if (!reminderAt.isAfter(resolvedNow)) {
    return VanPickupReminderPlan(
      timing: VanPickupReminderTiming.immediate,
      notificationAt: resolvedNow,
    );
  }
  return VanPickupReminderPlan(
    timing: VanPickupReminderTiming.scheduled,
    notificationAt: reminderAt,
  );
}

String buildVanPickupReminderBody({
  required String customerName,
  required String serviceName,
  required DateTime pickUpAt,
  String customerJourneyType = 'quote',
  String endHandover = '',
}) {
  final customer = sanitizeVanText(customerName).trim();
  final service = sanitizeVanText(serviceName).trim();
  final hour = pickUpAt.hour.toString().padLeft(2, '0');
  final minute = pickUpAt.minute.toString().padLeft(2, '0');
  final journey = vanCustomerJourneyTypeFromStorage(customerJourneyType);
  final subject = customer.isEmpty ? 'Your ${journey.name}' : customer;
  final serviceSuffix = service.isEmpty ? '' : ' · $service';
  final resolvedEnd = tryVanEndHandoverFromStorage(endHandover);
  final action = resolvedEnd?.calendarLabel.toLowerCase() ?? 'pick-up';
  return '$subject is due for $action at $hour:$minute$serviceSuffix';
}

String buildVanStartHandoverReminderBody({
  required String customerName,
  required String serviceName,
  required DateTime startAt,
  String customerJourneyType = 'quote',
  String startHandover = '',
}) {
  final customer = sanitizeVanText(customerName).trim();
  final service = sanitizeVanText(serviceName).trim();
  final hour = startAt.hour.toString().padLeft(2, '0');
  final minute = startAt.minute.toString().padLeft(2, '0');
  final journey = vanCustomerJourneyTypeFromStorage(customerJourneyType);
  final subject = customer.isEmpty ? 'Your ${journey.name}' : customer;
  final serviceSuffix = service.isEmpty ? '' : ' · $service';
  final resolvedStart = tryVanStartHandoverFromStorage(startHandover);
  final action = resolvedStart?.calendarLabel.toLowerCase() ?? 'drop-off';
  return '$subject is due for $action at $hour:$minute$serviceSuffix';
}

int vanPickupReminderNotificationId(String jobId) {
  final value = 'van_pickup_reminder:${jobId.trim()}';
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

int vanStartHandoverReminderNotificationId(String jobId) {
  final value = 'van_start_handover_reminder:${jobId.trim()}';
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

class VanPickupReminderService {
  VanPickupReminderService._();

  static final VanPickupReminderService instance = VanPickupReminderService._();

  bool _initialized = false;

  void initialize() {
    _initialized = true;
  }

  Future<VanPickupReminderTiming> schedule({
    required String jobId,
    required String customerName,
    required String serviceName,
    required DateTime pickUpAt,
    String customerJourneyType = 'quote',
    String endHandover = '',
    DateTime? now,
  }) async {
    final normalizedJobId = jobId.trim();
    if (normalizedJobId.isEmpty || kIsWeb || !_initialized) {
      return VanPickupReminderTiming.skipped;
    }

    return _scheduleAction(
      id: vanPickupReminderNotificationId(normalizedJobId),
      jobId: normalizedJobId,
      handoverAt: pickUpAt,
      title:
          '${tryVanEndHandoverFromStorage(endHandover)?.calendarLabel ?? 'Pick-up'} reminder',
      body: buildVanPickupReminderBody(
        customerName: customerName,
        serviceName: serviceName,
        pickUpAt: pickUpAt,
        customerJourneyType: customerJourneyType,
        endHandover: endHandover,
      ),
      handoverStage: 'end',
      now: now,
    );
  }

  Future<VanPickupReminderTiming> scheduleStart({
    required String jobId,
    required String customerName,
    required String serviceName,
    required DateTime startAt,
    String customerJourneyType = 'quote',
    String startHandover = '',
    DateTime? now,
  }) async {
    final normalizedJobId = jobId.trim();
    if (normalizedJobId.isEmpty || kIsWeb || !_initialized) {
      return VanPickupReminderTiming.skipped;
    }

    return _scheduleAction(
      id: vanStartHandoverReminderNotificationId(normalizedJobId),
      jobId: normalizedJobId,
      handoverAt: startAt,
      title:
          '${tryVanStartHandoverFromStorage(startHandover)?.calendarLabel ?? 'Drop-off'} reminder',
      body: buildVanStartHandoverReminderBody(
        customerName: customerName,
        serviceName: serviceName,
        startAt: startAt,
        customerJourneyType: customerJourneyType,
        startHandover: startHandover,
      ),
      handoverStage: 'start',
      now: now,
    );
  }

  Future<VanPickupReminderTiming> _scheduleAction({
    required int id,
    required String jobId,
    required DateTime handoverAt,
    required String title,
    required String body,
    required String handoverStage,
    DateTime? now,
  }) async {
    final plan = buildVanPickupReminderPlan(pickUpAt: handoverAt, now: now);
    try {
      await vanBusinessLocalNotificationsPlugin.cancel(id: id);
      if (plan.timing == VanPickupReminderTiming.skipped) {
        return plan.timing;
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'van_pickup_reminders',
          'Pick-up reminders',
          channelDescription: 'Business reminders for scheduled pick-ups.',
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
      );
      final payload = jsonEncode(<String, dynamic>{
        'type': 'pickup_reminder',
        'jobId': jobId,
        'handoverStage': handoverStage,
      });

      if (plan.timing == VanPickupReminderTiming.immediate) {
        await vanBusinessLocalNotificationsPlugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: details,
          payload: payload,
        );
      } else {
        final notificationAt = plan.notificationAt!;
        await vanBusinessLocalNotificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(notificationAt.toUtc(), tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
      return plan.timing;
    } catch (error, stackTrace) {
      debugPrint(
        '[PickupReminder] schedule failed jobId=$jobId stage=$handoverStage error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return VanPickupReminderTiming.skipped;
    }
  }

  Future<void> cancel(String jobId) async {
    await cancelStart(jobId);
    await cancelEnd(jobId);
  }

  Future<void> cancelStart(String jobId) async {
    final normalizedJobId = jobId.trim();
    if (normalizedJobId.isEmpty || kIsWeb || !_initialized) {
      return;
    }
    try {
      await vanBusinessLocalNotificationsPlugin.cancel(
        id: vanStartHandoverReminderNotificationId(normalizedJobId),
      );
    } catch (error) {
      debugPrint(
        '[PickupReminder] cancel failed jobId=$normalizedJobId error=$error',
      );
    }
  }

  Future<void> cancelEnd(String jobId) async {
    final normalizedJobId = jobId.trim();
    if (normalizedJobId.isEmpty || kIsWeb || !_initialized) {
      return;
    }
    try {
      await vanBusinessLocalNotificationsPlugin.cancel(
        id: vanPickupReminderNotificationId(normalizedJobId),
      );
    } catch (error) {
      debugPrint(
        '[PickupReminder] end cancel failed jobId=$normalizedJobId error=$error',
      );
    }
  }
}
