import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_availability_value.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';

void main() {
  test('custom duration validates and normalizes to whole minutes', () {
    expect(
      normalizeVanCustomDurationMinutes('75', VanAvailabilityValueUnit.minutes),
      75,
    );
    expect(
      normalizeVanCustomDurationMinutes('2', VanAvailabilityValueUnit.hours),
      120,
    );
    expect(formatVanDurationMinutes(75), '75 minutes');

    for (final input in <String>['', '0', '-1', '3.5']) {
      expect(
        validateVanCustomDuration(input, VanAvailabilityValueUnit.minutes),
        isNotNull,
      );
    }
    expect(
      validateVanCustomDuration(
        '${kVanMaximumDurationMinutes + 1}',
        VanAvailabilityValueUnit.minutes,
      ),
      isNotNull,
    );
  });

  test('custom notice validates and normalizes to numeric hours', () {
    expect(
      normalizeVanCustomNoticeHours('30', VanAvailabilityValueUnit.minutes),
      .5,
    );
    expect(
      normalizeVanCustomNoticeHours('3', VanAvailabilityValueUnit.hours),
      3,
    );
    expect(
      normalizeVanCustomNoticeHours('2', VanAvailabilityValueUnit.days),
      48,
    );
    expect(formatVanNoticeHours(.5), '30 minutes');
    expect(formatVanNoticeHours(48), '2 days');

    for (final input in <String>['', '0', '-1', '1.5']) {
      expect(
        validateVanCustomNotice(input, VanAvailabilityValueUnit.hours),
        isNotNull,
      );
    }
    expect(
      validateVanCustomNotice('366', VanAvailabilityValueUnit.days),
      isNotNull,
    );
  });

  test('custom booking limits are positive bounded whole numbers', () {
    expect(normalizeVanCustomBookingLimit('14'), 14);
    expect(formatVanBookingLimit(1), '1 booking');
    expect(formatVanBookingLimit(14), '14 bookings');
    for (final input in <String>['', '0', '-1', '2.5', '1000']) {
      expect(validateVanCustomBookingLimit(input), isNotNull);
    }
  });

  test('custom availability values round trip and drive calculations', () {
    final service = _service().copyWith(
      appointmentDurationMinutes: 75,
      noticeHours: .5,
      maxBookingsPerDay: 14,
    );
    final restored = VanJobService.fromJson(service.toJson());

    expect(restored.appointmentDuration, const Duration(minutes: 75));
    expect(restored.minimumNoticeDuration, const Duration(minutes: 30));
    expect(restored.maxBookingsPerDay, 14);
    expect(restored.canAcceptAnotherBooking(13), isTrue);
    expect(restored.canAcceptAnotherBooking(14), isFalse);

    final duplicated = restored.copyWith(id: 'copy');
    expect(duplicated.appointmentDurationMinutes, 75);
    expect(duplicated.noticeHours, .5);
    expect(duplicated.maxBookingsPerDay, 14);
  });

  test('legacy integer-hour and preset services remain compatible', () {
    final json = _service().toJson()..['noticeHours'] = 24;
    final restored = VanJobService.fromJson(json);

    expect(restored.noticeHours, 24);
    expect(restored.minimumNoticeDuration, const Duration(hours: 24));
    expect(restored.appointmentDurationMinutes, 60);
    expect(restored.maxBookingsPerDay, 8);
  });
}

VanJobService _service() {
  final now = DateTime.utc(2026, 7, 21);
  return VanJobService(
    id: 'service',
    name: 'Service',
    description: 'Description',
    isActive: true,
    requestPhotos: false,
    requireAddress: false,
    requestExactPinAfterQuoteAccepted: false,
    linkedQuestionIds: const <String>[],
    quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
    createdAt: now,
    updatedAt: now,
  );
}
