String normalizeVanJobRequestStatus(Object? value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text.isEmpty) {
    return 'draft';
  }

  switch (text) {
    case 'draft':
    case 'no_request':
    case 'norequest':
      return 'draft';
    case 'pending':
    case 'sent':
    case 'requestsent':
    case 'request_sent':
    case 'request_received':
    case 'awaiting_reply':
    case 'awaitingreply':
      return 'request_sent';
    case 'submitted':
    case 'replyreceived':
    case 'reply_received':
    case 'received_note':
    case 'receivednote':
      return 'reply_received';
    case 'quoteaccepted':
    case 'quote_accepted':
      return 'quote_accepted';
    case 'quotedeclined':
    case 'quote_declined':
      return 'quote_declined';
    case 'quote_sent':
    case 'quotesent':
    case 'quoted':
    case 'revised_quote_sent':
    case 'revisedquotesent':
      return 'quoted';
    case 'confirmed':
      return 'confirmed';
    case 'completed':
    case 'done':
      return 'completed';
    case 'cancelled':
    case 'canceled':
    case 'deleted':
      return 'cancelled';
    default:
      return text;
  }
}

bool vanJobRequestHasBeenSent(Object? value) {
  return normalizeVanJobRequestStatus(value) != 'draft';
}

bool vanJobRequestHasCustomerReply({
  required Object? status,
  DateTime? replyReceivedAt,
  DateTime? requestSubmittedAt,
  required bool hasChecklistResponses,
  required bool hasCustomQuestionResponses,
  required bool hasAdditionalNotes,
}) {
  final normalizedStatus = normalizeVanJobRequestStatus(status);
  if (normalizedStatus == 'reply_received') {
    return true;
  }

  return replyReceivedAt != null ||
      requestSubmittedAt != null ||
      hasChecklistResponses ||
      hasCustomQuestionResponses ||
      hasAdditionalNotes;
}

bool vanJobRequestHasExactPin({
  required bool exactPinShared,
  double? exactPinLatitude,
  double? exactPinLongitude,
}) {
  return exactPinShared ||
      (exactPinLatitude != null && exactPinLongitude != null);
}

bool vanJobRequestCanCreateQuote({
  required Object? status,
  DateTime? replyReceivedAt,
  DateTime? requestSubmittedAt,
  required bool hasChecklistResponses,
  required bool hasCustomQuestionResponses,
  required bool hasAdditionalNotes,
}) {
  return vanJobRequestHasCustomerReply(
    status: status,
    replyReceivedAt: replyReceivedAt,
    requestSubmittedAt: requestSubmittedAt,
    hasChecklistResponses: hasChecklistResponses,
    hasCustomQuestionResponses: hasCustomQuestionResponses,
    hasAdditionalNotes: hasAdditionalNotes,
  );
}

bool vanJobLocationIsPending({
  required bool locationPending,
  required bool requiresExactPinAfterQuoteAccepted,
  required bool hasExactPin,
  required String address,
  required String postcode,
}) {
  final hasLocationText =
      address.trim().isNotEmpty || postcode.trim().isNotEmpty;
  if (hasLocationText || hasExactPin) {
    return false;
  }

  return locationPending || requiresExactPinAfterQuoteAccepted;
}

String buildVanJobLocationSummary({
  required String address,
  required String postcode,
  required bool locationPending,
  required bool requiresExactPinAfterQuoteAccepted,
  required bool hasExactPin,
  String emptyFallback = 'No address added yet.',
}) {
  final pieces = <String>[];
  final trimmedAddress = address.trim();
  final trimmedPostcode = postcode.trim();
  if (trimmedAddress.isNotEmpty) {
    pieces.add(trimmedAddress);
  }
  if (trimmedPostcode.isNotEmpty) {
    pieces.add(trimmedPostcode);
  }
  if (pieces.isNotEmpty) {
    return pieces.join(' • ');
  }

  if (vanJobLocationIsPending(
    locationPending: locationPending,
    requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
    hasExactPin: hasExactPin,
    address: address,
    postcode: postcode,
  )) {
    return 'Location pending';
  }

  return emptyFallback;
}
