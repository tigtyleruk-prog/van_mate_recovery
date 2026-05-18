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
  return <String, dynamic>{
    ...data,
    'id': sanitizeVanText(id).trim(),
    'ownerUid': sanitizeVanText(ownerUid).trim(),
    'appVersion': vanMateCloudAppVersion,
    'source': sanitizeVanText(source).trim(),
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    'archived': archived,
    'deleted': deleted,
  };
}
