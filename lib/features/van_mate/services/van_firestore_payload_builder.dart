import 'package:cloud_firestore/cloud_firestore.dart';

import '../helpers/van_text_formatters.dart';

const String vanMateCloudAppVersion = '1.0.0+3';

Map<String, dynamic> buildVanCloudDocPayload({
  required String id,
  required String ownerUid,
  required String source,
  required Map<String, dynamic> data,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool archived = false,
  bool deleted = false,
}) {
  final sanitizedData = sanitizeVanFirestoreMap(data);
  return <String, dynamic>{
    ...sanitizedData,
    'id': sanitizeVanText(id).trim(),
    'ownerUid': sanitizeVanText(ownerUid).trim(),
    'appVersion': vanMateCloudAppVersion,
    'source': sanitizeVanText(source).trim(),
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'updatedAt': FieldValue.serverTimestamp(),
    'archived': archived,
    'deleted': deleted,
  };
}

Map<String, dynamic> sanitizeVanFirestoreMap(Map<String, dynamic> data) {
  final sanitized = <String, dynamic>{};
  for (final entry in data.entries) {
    sanitized[entry.key] = _sanitizeVanFirestoreValue(entry.value);
  }
  return sanitized;
}

dynamic _sanitizeVanFirestoreValue(dynamic value) {
  if (value is Map) {
    return sanitizeVanFirestoreMap(
      Map<String, dynamic>.from(
        value.map((key, item) => MapEntry(key.toString(), item)),
      ),
    );
  }

  if (value is Iterable) {
    return value.map(_sanitizeVanFirestoreValue).toList(growable: false);
  }

  return value;
}
