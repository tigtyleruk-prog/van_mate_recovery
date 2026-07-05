String buildVanRequestDeleteKey({
  String? requestId,
  String? firestoreDocId,
  String? docId,
  String? linkedJobId,
  String? source,
  String? title,
  String? customerName,
  String? phone,
  String? date,
  String? createdAt,
}) {
  String cleaned(String? value) => value?.trim() ?? '';
  String lowered(String? value) => cleaned(value).toLowerCase();

  final normalizedRequestId = cleaned(requestId);
  if (normalizedRequestId.isNotEmpty) {
    return 'request:$normalizedRequestId';
  }

  final normalizedFirestoreDocId = cleaned(firestoreDocId);
  if (normalizedFirestoreDocId.isNotEmpty) {
    return 'firestore:$normalizedFirestoreDocId';
  }

  final normalizedDocId = cleaned(docId);
  if (normalizedDocId.isNotEmpty) {
    return 'doc:$normalizedDocId';
  }

  final normalizedLinkedJobId = cleaned(linkedJobId);
  if (normalizedLinkedJobId.isNotEmpty) {
    return 'job:$normalizedLinkedJobId';
  }

  final normalizedSource = lowered(source);
  if (normalizedSource.isNotEmpty && normalizedDocId.isNotEmpty) {
    return 'source_doc:$normalizedSource|$normalizedDocId';
  }

  final normalizedTitle = lowered(title);
  final normalizedCustomerName = lowered(customerName);
  final normalizedPhone = lowered(phone);
  final normalizedDate = lowered(date);
  final normalizedCreatedAt = lowered(createdAt);
  final temporalLabel = normalizedDate.isNotEmpty
      ? normalizedDate
      : normalizedCreatedAt;

  if (normalizedSource.isNotEmpty &&
      (normalizedTitle.isNotEmpty ||
          normalizedCustomerName.isNotEmpty ||
          normalizedPhone.isNotEmpty ||
          temporalLabel.isNotEmpty)) {
    return 'source_legacy:$normalizedSource|$normalizedTitle|$normalizedCustomerName|$normalizedPhone|$temporalLabel';
  }

  return 'legacy:$normalizedTitle|$normalizedCustomerName|$normalizedPhone|$temporalLabel';
}

Set<String> buildVanRequestDeleteAliases({
  String? requestId,
  String? firestoreDocId,
  String? docId,
  String? linkedJobId,
  String? source,
  String? title,
  String? customerName,
  String? phone,
  String? date,
  String? createdAt,
}) {
  String cleaned(String? value) => value?.trim() ?? '';
  final aliases = <String>{
    buildVanRequestDeleteKey(
      requestId: requestId,
      firestoreDocId: firestoreDocId,
      docId: docId,
      linkedJobId: linkedJobId,
      source: source,
      title: title,
      customerName: customerName,
      phone: phone,
      date: date,
      createdAt: createdAt,
    ),
  };

  final normalizedRequestId = cleaned(requestId);
  if (normalizedRequestId.isNotEmpty) {
    aliases.add(normalizedRequestId);
    aliases.add('request:$normalizedRequestId');
  }

  final normalizedFirestoreDocId = cleaned(firestoreDocId);
  if (normalizedFirestoreDocId.isNotEmpty) {
    aliases.add(normalizedFirestoreDocId);
    aliases.add('firestore:$normalizedFirestoreDocId');
  }

  final normalizedDocId = cleaned(docId);
  if (normalizedDocId.isNotEmpty) {
    aliases.add(normalizedDocId);
    aliases.add('doc:$normalizedDocId');
  }

  final normalizedLinkedJobId = cleaned(linkedJobId);
  if (normalizedLinkedJobId.isNotEmpty) {
    aliases.add(normalizedLinkedJobId);
    aliases.add('job:$normalizedLinkedJobId');
  }

  final normalizedSource = cleaned(source).toLowerCase();
  if (normalizedSource.isNotEmpty && normalizedDocId.isNotEmpty) {
    aliases.add('source_doc:$normalizedSource|$normalizedDocId');
  }
  if (normalizedSource.isNotEmpty && normalizedLinkedJobId.isNotEmpty) {
    aliases.add('source_job:$normalizedSource|$normalizedLinkedJobId');
  }

  return aliases.where((value) => value.trim().isNotEmpty).toSet();
}
