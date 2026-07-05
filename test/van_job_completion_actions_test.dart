import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_job_completion_actions.dart';

void main() {
  final now = DateTime.parse('2026-06-14T09:00:00.000Z');

  test('future scheduled job does not show primary complete job button', () {
    expect(
      shouldShowPrimaryCompleteJob(
        isCompleted: false,
        isCancelled: false,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-15T10:00:00.000Z'),
        now: now,
      ),
      isFalse,
    );
  });

  test('calendar detail only shows complete job when opened from Calendar', () {
    expect(
      shouldShowCalendarDetailCompleteJob(
        isCompleted: false,
        isCancelled: false,
        isScheduled: true,
        openedFromCalendar: false,
      ),
      isFalse,
    );
    expect(
      shouldShowCalendarDetailCompleteJob(
        isCompleted: false,
        isCancelled: false,
        isScheduled: true,
        openedFromCalendar: true,
      ),
      isTrue,
    );
  });

  test(
    'scheduled detail job shows one completion path even when future-dated',
    () {
      expect(
        shouldShowScheduledDetailCompleteJob(
          isCompleted: false,
          isCancelled: false,
          isScheduled: true,
        ),
        isTrue,
      );
    },
  );

  test('future scheduled job exposes one complete early action path', () {
    expect(
      shouldShowCompleteEarlyAction(
        isCompleted: false,
        isCancelled: false,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-15T10:00:00.000Z'),
        now: now,
      ),
      isTrue,
    );
  });

  test('today scheduled job shows primary complete job button', () {
    expect(
      shouldShowPrimaryCompleteJob(
        isCompleted: false,
        isCancelled: false,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-14T18:00:00.000Z'),
        now: now,
      ),
      isTrue,
    );
    expect(
      shouldShowCompleteEarlyAction(
        isCompleted: false,
        isCancelled: false,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-14T18:00:00.000Z'),
        now: now,
      ),
      isFalse,
    );
  });

  test('completed or cancelled jobs never expose completion actions', () {
    expect(
      shouldShowPrimaryCompleteJob(
        isCompleted: true,
        isCancelled: false,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-15T10:00:00.000Z'),
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldShowPrimaryCompleteJob(
        isCompleted: false,
        isCancelled: true,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-15T10:00:00.000Z'),
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldShowCompleteEarlyAction(
        isCompleted: true,
        isCancelled: false,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-15T10:00:00.000Z'),
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldShowCompleteEarlyAction(
        isCompleted: false,
        isCancelled: true,
        isScheduled: true,
        scheduledAt: DateTime.parse('2026-06-15T10:00:00.000Z'),
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldShowScheduledDetailCompleteJob(
        isCompleted: true,
        isCancelled: false,
        isScheduled: true,
      ),
      isFalse,
    );
    expect(
      shouldShowScheduledDetailCompleteJob(
        isCompleted: false,
        isCancelled: true,
        isScheduled: true,
      ),
      isFalse,
    );
  });
}
