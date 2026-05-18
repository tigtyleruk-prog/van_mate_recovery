import 'package:flutter/foundation.dart';

import 'van_invoice_draft.dart';

@immutable
class VanInvoiceHistoryEntry {
  const VanInvoiceHistoryEntry({
    required this.jobKey,
    required this.draft,
    required this.savedAt,
  });

  final String jobKey;
  final VanInvoiceDraft draft;
  final DateTime savedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jobKey': jobKey,
      'draft': draft.toJson(),
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory VanInvoiceHistoryEntry.fromJson(Map<String, dynamic> json) {
    final draftJson = json['draft'];
    return VanInvoiceHistoryEntry(
      jobKey: json['jobKey']?.toString() ?? '',
      draft: draftJson is Map
          ? VanInvoiceDraft.fromJson(Map<String, dynamic>.from(draftJson))
          : VanInvoiceDraft.fromJson(<String, dynamic>{}),
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
