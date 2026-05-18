import 'package:flutter/material.dart';

String sanitizeVanText(String? value) {
  final text = value ?? '';
  if (text.isEmpty) {
    return '';
  }

  return text
      .replaceAll('Ã‚Â£', '£')
      .replaceAll('Â£', '£')
      .replaceAll('â€™', "'")
      .replaceAll('â€˜', "'")
      .replaceAll('â€œ', '"')
      .replaceAll('â€', '"')
      .replaceAll('â€”', '-')
      .replaceAll('â€“', '-')
      .replaceAll('â€¢', '•');
}

String formatCurrency(num value) => '£${value.toStringAsFixed(2)}';

double parseCurrencyValue(String value) {
  final cleaned = sanitizeVanText(value).replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
    return 0;
  }

  return double.tryParse(cleaned) ?? 0;
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

String formatAnswerWithNote(String answer, String note) {
  final cleanedAnswer = sanitizeVanText(answer).trim();
  final cleanedNote = sanitizeVanText(note).trim();
  final noteText = _isBlankNote(cleanedNote) ? 'No extra note.' : cleanedNote;

  if (cleanedAnswer.isEmpty) {
    return noteText;
  }

  return '$cleanedAnswer - $noteText';
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
