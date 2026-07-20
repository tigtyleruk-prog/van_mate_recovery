import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/services/van_pickup_reminder_service.dart';

void main() {
  test('pickup reminder is scheduled thirty minutes before pickup', () {
    final plan = buildVanPickupReminderPlan(
      pickUpAt: DateTime(2026, 7, 27, 17, 30),
      now: DateTime(2026, 7, 27, 12),
    );

    expect(plan.timing, VanPickupReminderTiming.scheduled);
    expect(plan.notificationAt, DateTime(2026, 7, 27, 17));
  });

  test('nearby pickup produces an immediate reminder', () {
    final now = DateTime(2026, 7, 27, 17, 10);
    final plan = buildVanPickupReminderPlan(
      pickUpAt: DateTime(2026, 7, 27, 17, 30),
      now: now,
    );

    expect(plan.timing, VanPickupReminderTiming.immediate);
    expect(plan.notificationAt, now);
  });

  test('past pickup is skipped safely', () {
    final plan = buildVanPickupReminderPlan(
      pickUpAt: DateTime(2026, 7, 27, 17, 30),
      now: DateTime(2026, 7, 27, 18),
    );

    expect(plan.timing, VanPickupReminderTiming.skipped);
    expect(plan.notificationAt, isNull);
  });

  test('body contains customer, pickup time and service', () {
    expect(
      buildVanPickupReminderBody(
        customerName: 'Lazy Git',
        serviceName: 'Pet Sitting',
        pickUpAt: DateTime(2026, 7, 27, 17, 30),
      ),
      'Lazy Git is due for pick-up at 17:30 · Pet Sitting',
    );
  });

  test('body distinguishes customer collection from business return', () {
    final pickUpAt = DateTime(2026, 7, 27, 17, 30);

    expect(
      buildVanPickupReminderBody(
        customerName: 'Customer',
        serviceName: 'Repair',
        pickUpAt: pickUpAt,
        endHandover: 'customerCollects',
      ),
      contains('customer collection'),
    );
    expect(
      buildVanPickupReminderBody(
        customerName: 'Customer',
        serviceName: 'Repair',
        pickUpAt: pickUpAt,
        endHandover: 'businessReturns',
      ),
      contains('business return'),
    );
  });

  test('only active scheduled drop-off pickup jobs qualify', () {
    final pickUpAt = DateTime(2026, 7, 27, 17, 30);

    bool qualifies({
      bool isDropOffPickup = true,
      bool isScheduled = true,
      bool isCompleted = false,
      bool isCancelled = false,
      bool isHidden = false,
      DateTime? pickup,
    }) {
      return shouldScheduleVanPickupReminder(
        isDropOffPickup: isDropOffPickup,
        isScheduled: isScheduled,
        isCompleted: isCompleted,
        isCancelled: isCancelled,
        isHidden: isHidden,
        pickUpAt: pickup ?? pickUpAt,
      );
    }

    expect(qualifies(), isTrue);
    expect(qualifies(isDropOffPickup: false), isFalse);
    expect(qualifies(isScheduled: false), isFalse);
    expect(qualifies(isCompleted: true), isFalse);
    expect(qualifies(isCancelled: true), isFalse);
    expect(qualifies(isHidden: true), isFalse);
    expect(
      shouldScheduleVanPickupReminder(
        isDropOffPickup: true,
        isScheduled: true,
        isCompleted: false,
        isCancelled: false,
        isHidden: false,
        pickUpAt: null,
      ),
      isFalse,
    );
  });

  test('notification id is stable per job and distinct across jobs', () {
    final first = vanPickupReminderNotificationId('job-1');
    expect(vanPickupReminderNotificationId('job-1'), first);
    expect(vanPickupReminderNotificationId('job-2'), isNot(first));
    expect(vanStartHandoverReminderNotificationId('job-1'), isNot(first));
  });
}
