enum VanAvailabilityValueUnit { minutes, hours, days }

const List<int> kVanDurationPresetMinutes = <int>[
  15,
  30,
  45,
  60,
  90,
  120,
  180,
  240,
];

const List<num> kVanNoticePresetHours = <num>[0, 1, 2, 4, 12, 24, 48, 72, 168];

const List<int> kVanBookingLimitPresets = <int>[1, 2, 4, 6, 8, 10, 12, 16, 20];

const int kVanMaximumDurationMinutes = 7 * 24 * 60;
const int kVanMaximumNoticeMinutes = 365 * 24 * 60;
const int kVanMaximumBookingsPerDay = 999;

String? validateVanCustomDuration(String input, VanAvailabilityValueUnit unit) {
  final value = _positiveWholeNumber(input);
  if (input.trim().isEmpty) return 'Enter a duration.';
  if (value == null) return 'Enter a positive whole number.';
  final minutes = unit == VanAvailabilityValueUnit.hours ? value * 60 : value;
  if (minutes > kVanMaximumDurationMinutes) {
    return 'Duration must be 7 days or less.';
  }
  return null;
}

int? normalizeVanCustomDurationMinutes(
  String input,
  VanAvailabilityValueUnit unit,
) {
  if (validateVanCustomDuration(input, unit) != null) return null;
  final value = int.parse(input.trim());
  return unit == VanAvailabilityValueUnit.hours ? value * 60 : value;
}

String? validateVanCustomNotice(String input, VanAvailabilityValueUnit unit) {
  final value = _positiveWholeNumber(input);
  if (input.trim().isEmpty) return 'Enter a minimum notice.';
  if (value == null) return 'Enter a positive whole number.';
  final minutes = switch (unit) {
    VanAvailabilityValueUnit.minutes => value,
    VanAvailabilityValueUnit.hours => value * 60,
    VanAvailabilityValueUnit.days => value * 24 * 60,
  };
  if (minutes > kVanMaximumNoticeMinutes) {
    return 'Minimum notice must be 365 days or less.';
  }
  return null;
}

num? normalizeVanCustomNoticeHours(
  String input,
  VanAvailabilityValueUnit unit,
) {
  if (validateVanCustomNotice(input, unit) != null) return null;
  final value = int.parse(input.trim());
  return switch (unit) {
    VanAvailabilityValueUnit.minutes => value / 60,
    VanAvailabilityValueUnit.hours => value.toDouble(),
    VanAvailabilityValueUnit.days => (value * 24).toDouble(),
  };
}

String? validateVanCustomBookingLimit(String input) {
  final value = _positiveWholeNumber(input);
  if (input.trim().isEmpty) return 'Enter a booking limit.';
  if (value == null) return 'Enter a positive whole number.';
  if (value > kVanMaximumBookingsPerDay) {
    return 'Booking limit must be 999 or less.';
  }
  return null;
}

int? normalizeVanCustomBookingLimit(String input) {
  if (validateVanCustomBookingLimit(input) != null) return null;
  return int.parse(input.trim());
}

String formatVanDurationMinutes(int minutes) {
  if (minutes < 60) return '$minutes minute${minutes == 1 ? '' : 's'}';
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return '$hours hour${hours == 1 ? '' : 's'}';
  }
  return '$minutes minutes';
}

String formatVanNoticeHours(num hours) {
  final minutes = (hours * 60).round();
  if (minutes == 0) return 'No minimum';
  if (minutes < 60 || minutes % 60 != 0) {
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }
  final wholeHours = minutes ~/ 60;
  if (wholeHours >= 24 && wholeHours % 24 == 0) {
    final days = wholeHours ~/ 24;
    return '$days day${days == 1 ? '' : 's'}';
  }
  return '$wholeHours hour${wholeHours == 1 ? '' : 's'}';
}

String formatVanBookingLimit(int bookings) =>
    '$bookings booking${bookings == 1 ? '' : 's'}';

int? _positiveWholeNumber(String input) {
  final value = int.tryParse(input.trim());
  return value != null && value > 0 ? value : null;
}
