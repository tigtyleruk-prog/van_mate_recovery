import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'van_invoice_draft.dart';

@immutable
class VanInvoiceHistoryEntry {
  const VanInvoiceHistoryEntry({
    required this.jobKey,
    required this.draft,
    required this.savedAt,
    this.createdAt,
    this.updatedAt,
    this.deleted = false,
    this.archived = false,
    this.linkedJobDeleted = false,
  });

  final String jobKey;
  final VanInvoiceDraft draft;
  final DateTime savedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool deleted;
  final bool archived;
  final bool linkedJobDeleted;

  VanInvoiceHistoryEntry copyWith({
    String? jobKey,
    VanInvoiceDraft? draft,
    DateTime? savedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    bool? archived,
    bool? linkedJobDeleted,
  }) {
    return VanInvoiceHistoryEntry(
      jobKey: jobKey ?? this.jobKey,
      draft: draft ?? this.draft,
      savedAt: savedAt ?? this.savedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      archived: archived ?? this.archived,
      linkedJobDeleted: linkedJobDeleted ?? this.linkedJobDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jobKey': jobKey,
      'draft': draft.toJson(),
      'savedAt': savedAt.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deleted': deleted,
      'archived': archived,
      'linkedJobDeleted': linkedJobDeleted,
    };
  }

  factory VanInvoiceHistoryEntry.fromJson(Map<String, dynamic> json) {
    final draftJson = json['draft'];
    final draftMap = draftJson is Map
        ? Map<String, dynamic>.from(draftJson)
        : Map<String, dynamic>.from(json);
    return VanInvoiceHistoryEntry(
      jobKey:
          json['jobKey']?.toString() ??
          json['id']?.toString() ??
          draftMap['jobKey']?.toString() ??
          '',
      draft: VanInvoiceDraft.fromJson(draftMap),
      savedAt:
          _readDateTime(json['savedAt']) ??
          _readDateTime(json['updatedAt']) ??
          _readDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: _readDateTime(json['updatedAt']),
      deleted: _readBool(json['deleted']),
      archived: _readBool(json['archived']),
      linkedJobDeleted: _readBool(json['linkedJobDeleted']),
    );
  }
}

DateTime? _readDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }

  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}
