import 'package:flutter/material.dart';

bool shouldShowPrimaryCompleteJob({
  required bool isCompleted,
  required bool isCancelled,
  required bool isScheduled,
  required DateTime? scheduledAt,
  DateTime? now,
}) {
  if (isCompleted || isCancelled) {
    return false;
  }
  if (!isScheduled) {
    return true;
  }
  final scheduled = scheduledAt;
  if (scheduled == null) {
    return true;
  }
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final scheduledDay = DateUtils.dateOnly(scheduled);
  return !scheduledDay.isAfter(today);
}

bool shouldShowCompleteEarlyAction({
  required bool isCompleted,
  required bool isCancelled,
  required bool isScheduled,
  required DateTime? scheduledAt,
  DateTime? now,
}) {
  if (isCompleted || isCancelled || !isScheduled) {
    return false;
  }
  final scheduled = scheduledAt;
  if (scheduled == null) {
    return false;
  }
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final scheduledDay = DateUtils.dateOnly(scheduled);
  return scheduledDay.isAfter(today);
}

bool shouldShowScheduledDetailCompleteJob({
  required bool isCompleted,
  required bool isCancelled,
  required bool isScheduled,
}) {
  return !isCompleted && !isCancelled && isScheduled;
}

bool shouldShowCalendarDetailCompleteJob({
  required bool isCompleted,
  required bool isCancelled,
  required bool isScheduled,
  required bool openedFromCalendar,
}) {
  return openedFromCalendar && shouldShowScheduledDetailCompleteJob(
    isCompleted: isCompleted,
    isCancelled: isCancelled,
    isScheduled: isScheduled,
  );
}
