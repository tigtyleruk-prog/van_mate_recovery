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

  var normalizedNote = _stripRepeatedAnswerPrefix(cleanedNote, answer);
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
    '^${RegExp.escape(cleanedAnswer)}(?:\\s*[-–—:,]\\s*|\\s+)',
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
