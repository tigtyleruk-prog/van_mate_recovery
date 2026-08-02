class VanQuoteUiStatus {
  const VanQuoteUiStatus({
    required this.primaryChipLabel,
    required this.secondaryChipLabel,
    required this.statusLabel,
    required this.summary,
    required this.nextActionText,
    this.showExactPinReceivedChip = false,
    this.exactPinChipLabel = 'Exact pin received',
  });

  final String primaryChipLabel;
  final String secondaryChipLabel;
  final String statusLabel;
  final String summary;
  final String nextActionText;
  final bool showExactPinReceivedChip;
  final String exactPinChipLabel;
}

VanQuoteUiStatus deriveVanQuoteUiStatus({
  required bool hasRequest,
  required bool hasReply,
  required bool hasQuote,
  required bool hasRequestBeenSent,
  required bool isQuoteAccepted,
  required bool isQuoteDeclined,
  required bool isConfirmed,
  required bool isScheduledInCalendar,
  required bool isQuoteAwaitingCustomerResponse,
  bool wasQuoteRevised = false,
  required bool hasAgreedTime,
  required bool needsAgreedTime,
  required bool requiresExactPin,
  required bool hasExactPin,
  String customerJourneyType = 'quote',
}) {
  final isPreOrder =
      customerJourneyType.trim().toLowerCase() == 'preorder' ||
      customerJourneyType.trim().toLowerCase() == 'pre_order';
  final documentName = isPreOrder ? 'Order Summary' : 'Quote';
  final documentNameLower = isPreOrder ? 'order summary' : 'quote';
  final isScheduled = isConfirmed || isScheduledInCalendar;
  final awaitingExactPin =
      isQuoteAccepted && hasAgreedTime && requiresExactPin && !hasExactPin;
  final readyForCalendar =
      isQuoteAccepted && hasAgreedTime && !awaitingExactPin && !isScheduled;
  final timeAgreedOnly =
      isQuoteAccepted && hasAgreedTime && awaitingExactPin && !isScheduled;
  final exactPinReceived =
      isQuoteAccepted && hasExactPin && !isScheduled && !readyForCalendar;

  if (isQuoteDeclined) {
    return VanQuoteUiStatus(
      primaryChipLabel: '$documentName declined',
      secondaryChipLabel: '$documentName declined',
      statusLabel: '$documentName declined',
      summary: '$documentName declined.',
      nextActionText: 'Open to review and resend or follow up if needed.',
    );
  }

  if (isScheduled) {
    return VanQuoteUiStatus(
      primaryChipLabel: '$documentName accepted',
      secondaryChipLabel: 'Added to Calendar',
      statusLabel: 'Added to Calendar',
      summary: 'Added to Calendar.',
      nextActionText: 'Open to review the confirmed booking details.',
    );
  }

  if (isQuoteAccepted) {
    if (readyForCalendar) {
      return VanQuoteUiStatus(
        primaryChipLabel: '$documentName accepted',
        secondaryChipLabel: 'Ready for Calendar',
        statusLabel: 'Ready for Calendar',
        summary: hasExactPin
            ? '$documentName accepted. Time agreed. Exact pin received. Ready for Calendar.'
            : '$documentName accepted. Time agreed. Ready for Calendar.',
        nextActionText: 'Next step: add the accepted job to Calendar.',
        showExactPinReceivedChip: hasExactPin,
      );
    }
    if (timeAgreedOnly) {
      return VanQuoteUiStatus(
        primaryChipLabel: '$documentName accepted',
        secondaryChipLabel: 'Awaiting exact pin',
        statusLabel: 'Awaiting exact pin',
        summary:
            '$documentName accepted. Time agreed. Waiting for the exact pin before adding it to Calendar.',
        nextActionText: 'Waiting for the customer to share the exact pin.',
      );
    }
    if (needsAgreedTime || !hasAgreedTime) {
      return VanQuoteUiStatus(
        primaryChipLabel: '$documentName accepted',
        secondaryChipLabel: 'Time needs arranging',
        statusLabel: 'Time needs arranging',
        summary: hasExactPin
            ? '$documentName accepted. Exact pin received. Time still needs arranging.'
            : '$documentName accepted. Time still needs arranging.',
        nextActionText: 'Next step: arrange the time with the customer.',
        showExactPinReceivedChip: hasExactPin,
      );
    }
    return VanQuoteUiStatus(
      primaryChipLabel: '$documentName accepted',
      secondaryChipLabel: '$documentName accepted',
      statusLabel: '$documentName accepted',
      summary: exactPinReceived
          ? '$documentName accepted. Exact pin received.'
          : '$documentName accepted.',
      nextActionText: exactPinReceived
          ? 'Open to review the accepted $documentNameLower details.'
          : 'Open to review the accepted $documentNameLower details.',
      showExactPinReceivedChip: exactPinReceived,
    );
  }

  if (isQuoteAwaitingCustomerResponse) {
    return VanQuoteUiStatus(
      primaryChipLabel: wasQuoteRevised
          ? '$documentName resent'
          : '$documentName sent',
      secondaryChipLabel: 'Awaiting $documentNameLower response',
      statusLabel: 'Awaiting $documentNameLower response',
      summary: wasQuoteRevised
          ? '$documentName resent. Awaiting customer response.'
          : '$documentName sent. Awaiting customer response.',
      nextActionText:
          'Waiting for the customer to respond to the $documentNameLower.',
    );
  }

  if (!hasRequest || !hasRequestBeenSent) {
    return VanQuoteUiStatus(
      primaryChipLabel: 'Request received',
      secondaryChipLabel: 'Not sent',
      statusLabel: 'Not sent',
      summary: 'Request not sent yet.',
      nextActionText: 'Open to review details and send a $documentNameLower.',
    );
  }

  if (hasReply && !hasQuote) {
    return VanQuoteUiStatus(
      primaryChipLabel: 'Request received',
      secondaryChipLabel: hasExactPin ? 'Exact pin received' : 'Reply received',
      statusLabel: hasExactPin ? 'Exact pin received' : 'Reply received',
      summary: hasExactPin
          ? 'Customer reply received. Exact pin received.'
          : 'Customer reply received.',
      nextActionText: 'Open to review details and send a $documentNameLower.',
      showExactPinReceivedChip: hasExactPin,
    );
  }

  return VanQuoteUiStatus(
    primaryChipLabel: 'Request received',
    secondaryChipLabel: 'Awaiting customer reply',
    statusLabel: 'Awaiting customer reply',
    summary: 'Awaiting customer reply.',
    nextActionText: 'Open to review details and send a $documentNameLower.',
  );
}
