import 'package:flutter/material.dart';

const String kVanMatePaymentInstructionsFallback =
    'Payment will be arranged directly with the trader/business.';
const String kVanMatePastBookingMessage =
    "You can't book a job in the past. Please choose today or a future date.";
const double kVanMateMaxQuoteAmount = 99999.99;
const double kVanMateHighQuoteAmountWarningThreshold = 10000.0;

String sanitizeVanText(String? value) {
  final text = value ?? '';
  if (text.isEmpty) {
    return '';
  }

  return text
      .replaceAll('Ãƒâ€šÃ‚Â£', '\u00A3')
      .replaceAll('Ã‚Â£', '\u00A3')
      .replaceAll('Ã¢â‚¬â„¢', "'")
      .replaceAll('Ã¢â‚¬Ëœ', "'")
      .replaceAll('Ã¢â‚¬Å“', '"')
      .replaceAll('Ã¢â‚¬Â', '"')
      .replaceAll('Ã¢â‚¬â€', '-')
      .replaceAll('Ã¢â‚¬â€œ', '-')
      .replaceAll('Ã¢â‚¬Â¢', '\u2022');
}

String formatCurrency(num value) {
  final isNegative = value < 0;
  final absolute = value.abs().toStringAsFixed(2);
  final parts = absolute.split('.');
  final wholePart = _formatThousands(parts.first);
  final decimalPart = parts.length > 1 ? parts[1] : '00';
  final prefix = isNegative ? '-\u00A3' : '\u00A3';
  return '$prefix$wholePart.$decimalPart';
}

String formatCurrencyInputValue(num value) {
  final absolute = value.abs().toStringAsFixed(2);
  final parts = absolute.split('.');
  final wholePart = _formatThousands(parts.first);
  final decimalPart = parts.length > 1 ? parts[1] : '00';
  return '$wholePart.$decimalPart';
}

String normalizeCurrencyInput(String value) {
  return sanitizeVanText(
    value,
  ).replaceAll('\u00A3', '').replaceAll(',', '').trim();
}

String? validateVanMateQuoteAmountInput(
  String value, {
  bool allowEmpty = false,
}) {
  final cleaned = normalizeCurrencyInput(value);
  if (cleaned.isEmpty) {
    return allowEmpty ? null : 'Enter a valid quote amount.';
  }
  if (!RegExp(r'^\d{1,5}(\.\d{0,2})?$').hasMatch(cleaned)) {
    return 'Enter a valid quote amount.';
  }

  final parsed = double.tryParse(cleaned);
  if (parsed == null || parsed <= 0) {
    return 'Enter a valid quote amount.';
  }
  if (parsed > kVanMateMaxQuoteAmount) {
    return 'Quote amount is too high.';
  }
  return null;
}

double parseCurrencyValue(String value) {
  final cleaned = normalizeCurrencyInput(
    value,
  ).replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty || cleaned == '.') {
    return 0;
  }

  return double.tryParse(cleaned) ?? 0;
}

bool isVanMatePastDate(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(reference));
}

bool isVanMatePastDateTime(DateTime dateTime, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return dateTime.isBefore(reference);
}

String? validateVanMateScheduledAt(DateTime scheduledAt, {DateTime? now}) {
  return isVanMatePastDateTime(scheduledAt, now: now)
      ? kVanMatePastBookingMessage
      : null;
}

String? validateVanMatePreferredBookingWindow({
  required DateTime? preferredDate,
  required String preferredTimeWindow,
  required bool preferredIsFlexible,
  DateTime? now,
}) {
  if (preferredDate == null) {
    return null;
  }
  final reference = now ?? DateTime.now();
  if (isVanMatePastDate(preferredDate, now: reference)) {
    return kVanMatePastBookingMessage;
  }
  if (preferredIsFlexible) {
    return null;
  }
  if (!DateUtils.isSameDay(preferredDate, reference)) {
    return null;
  }

  final normalizedWindow = preferredTimeWindow.trim().toLowerCase();
  final slotEndHour = switch (normalizedWindow) {
    'morning' => 12,
    'afternoon' => 17,
    'evening' => 21,
    _ => null,
  };
  if (slotEndHour == null) {
    return null;
  }

  final slotEnd = DateTime(
    reference.year,
    reference.month,
    reference.day,
    slotEndHour,
  );
  return reference.isAfter(slotEnd) ? kVanMatePastBookingMessage : null;
}

String formatDate(DateTime date) {
  const months = <String>[
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

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatDateTime(DateTime date, TimeOfDay time) {
  return '${formatDate(date)} at ${formatTime(time)}';
}

String formatAnswerWithNote(String answer, [String? note]) {
  final cleanedAnswer = sanitizeVanText(answer).trim();
  final cleanedNote = _cleanReplyNote(cleanedAnswer, note);

  if (cleanedAnswer.isEmpty) {
    return cleanedNote ?? '';
  }

  if (cleanedNote == null) {
    return cleanedAnswer;
  }

  return '$cleanedAnswer\nNote: $cleanedNote';
}

String formatCustomQuestionAnswer(String question, String answer) {
  final cleanedQuestion = sanitizeVanText(question).trim();
  final cleanedAnswer = sanitizeVanText(answer).trim();

  if (cleanedQuestion.isEmpty) {
    return cleanedAnswer;
  }

  if (cleanedAnswer.isEmpty) {
    return cleanedQuestion;
  }

  return '$cleanedQuestion\nAnswer: $cleanedAnswer';
}

String formatMileage(num value) {
  if (value <= 0) {
    return '-';
  }

  return '${value.toStringAsFixed(1)} miles';
}

String formatMileageTotal(num value) => '${value.toStringAsFixed(1)} miles';

String formatDateForFile(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String resolveVanMatePaymentInstructions(String? value) {
  final cleaned = sanitizeVanText(value).trim();
  if (cleaned.isEmpty || _looksLikePlaceholderPaymentInstructions(cleaned)) {
    return kVanMatePaymentInstructionsFallback;
  }
  return cleaned;
}

bool _looksLikePlaceholderPaymentInstructions(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return true;
  }

  const junkValues = <String>{
    'test',
    'testing',
    'demo',
    'sample',
    'example',
    'dummy',
    'placeholder',
    'lorem ipsum',
  };
  if (junkValues.contains(normalized) || normalized.contains('@example.')) {
    return true;
  }

  final junkPattern = RegExp(
    r'\b(test|testing|demo|sample|example|dummy|placeholder|lorem|ipsum)\b',
    caseSensitive: false,
  );
  return junkPattern.hasMatch(normalized);
}

bool _isBlankNote(String value) {
  if (value.isEmpty) {
    return true;
  }

  final normalized = value.toLowerCase().replaceAll(RegExp(r'[.!]+$'), '');
  return normalized == 'no extra note' ||
      normalized == 'no extra notes' ||
      normalized == 'no extra notes added' ||
      normalized == 'none' ||
      normalized == 'n/a' ||
      normalized == 'na' ||
      normalized == 'no note';
}

String? _cleanReplyNote(String answer, String? note) {
  final cleanedNote = sanitizeVanText(note).trim();
  if (cleanedNote.isEmpty) {
    return null;
  }

  final normalizedNote = _stripRepeatedAnswerPrefix(cleanedNote, answer);
  if (_isBlankNote(normalizedNote)) {
    return null;
  }

  return normalizedNote;
}

String _stripRepeatedAnswerPrefix(String note, String answer) {
  final cleanedAnswer = answer.trim();
  if (cleanedAnswer.isEmpty) {
    return note.trim();
  }

  var result = note.trim();
  final pattern = RegExp(
    '^${RegExp.escape(cleanedAnswer)}(?:\\s*[-\u2013\u2014:,]\\s*|\\s+)',
    caseSensitive: false,
  );

  while (true) {
    final match = pattern.firstMatch(result);
    if (match == null) {
      break;
    }

    result = result.substring(match.end).trimLeft();
  }

  return result.trim();
}

String _formatThousands(String digits) {
  if (digits.length <= 3) {
    return digits;
  }

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
