import 'package:flutter/foundation.dart';

import 'van_text_formatters.dart';

@immutable
class VanQuoteDeclineSummary {
  const VanQuoteDeclineSummary({this.reason = '', this.note = ''});

  final String reason;
  final String note;

  bool get hasReason => reason.trim().isNotEmpty;
  bool get hasNote => note.trim().isNotEmpty;
  bool get hasAny => hasReason || hasNote;
}

String readVanNestedText(
  dynamic value,
  List<String> keys, {
  String fallback = '',
}) {
  if (value is Map) {
    for (final key in keys) {
      final candidate = sanitizeVanText(value[key]?.toString()).trim();
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
  }
  return fallback;
}

VanQuoteDeclineSummary buildVanQuoteDeclineSummary({
  String reasonLabel = '',
  String reasonCode = '',
  String note = '',
  String reasonText = '',
}) {
  final normalizedLabel = sanitizeVanText(reasonLabel).trim();
  final normalizedCode = sanitizeVanText(reasonCode).trim();
  final normalizedNote = sanitizeVanText(note).trim();
  final normalizedReasonText = sanitizeVanText(reasonText).trim();

  var reason = normalizedLabel;
  if (reason.isEmpty && normalizedCode.isNotEmpty) {
    reason = normalizedCode.replaceAll('_', ' ');
  }

  final resolvedNote = normalizedNote.isNotEmpty
      ? normalizedNote
      : normalizedReasonText;

  if (reason.isEmpty && resolvedNote.isNotEmpty) {
    reason = resolvedNote;
    return VanQuoteDeclineSummary(reason: reason);
  }

  return VanQuoteDeclineSummary(reason: reason, note: resolvedNote);
}

String? formatVanQuoteDeclineText(
  VanQuoteDeclineSummary summary, {
  String? emptyFallback,
}) {
  if (!summary.hasAny) {
    return emptyFallback;
  }
  return [
    if (summary.hasReason) 'Reason: ${summary.reason.trim()}',
    if (summary.hasNote) 'Note: ${summary.note.trim()}',
  ].join('\n');
}
