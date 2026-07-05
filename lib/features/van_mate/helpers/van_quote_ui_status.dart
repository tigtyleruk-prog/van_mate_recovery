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
}) {
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
    return const VanQuoteUiStatus(
      primaryChipLabel: 'Quote declined',
      secondaryChipLabel: 'Quote declined',
      statusLabel: 'Quote declined',
      summary: 'Quote declined.',
      nextActionText: 'Open to review and resend or follow up if needed.',
    );
  }

  if (isScheduled) {
    return const VanQuoteUiStatus(
      primaryChipLabel: 'Quote accepted',
      secondaryChipLabel: 'Added to Calendar',
      statusLabel: 'Added to Calendar',
      summary: 'Added to Calendar.',
      nextActionText: 'Open to review the confirmed booking details.',
    );
  }

  if (isQuoteAccepted) {
    if (readyForCalendar) {
      return VanQuoteUiStatus(
        primaryChipLabel: 'Quote accepted',
        secondaryChipLabel: 'Ready for Calendar',
        statusLabel: 'Ready for Calendar',
        summary: hasExactPin
            ? 'Quote accepted. Time agreed. Exact pin received. Ready for Calendar.'
            : 'Quote accepted. Time agreed. Ready for Calendar.',
        nextActionText: 'Next step: add the accepted job to Calendar.',
        showExactPinReceivedChip: hasExactPin,
      );
    }
    if (timeAgreedOnly) {
      return const VanQuoteUiStatus(
        primaryChipLabel: 'Quote accepted',
        secondaryChipLabel: 'Awaiting exact pin',
        statusLabel: 'Awaiting exact pin',
        summary:
            'Quote accepted. Time agreed. Waiting for the exact pin before adding it to Calendar.',
        nextActionText: 'Waiting for the customer to share the exact pin.',
      );
    }
    if (needsAgreedTime || !hasAgreedTime) {
      return VanQuoteUiStatus(
        primaryChipLabel: 'Quote accepted',
        secondaryChipLabel: 'Time needs arranging',
        statusLabel: 'Time needs arranging',
        summary: hasExactPin
            ? 'Quote accepted. Exact pin received. Time still needs arranging.'
            : 'Quote accepted. Time still needs arranging.',
        nextActionText: 'Next step: arrange the time with the customer.',
        showExactPinReceivedChip: hasExactPin,
      );
    }
    return VanQuoteUiStatus(
      primaryChipLabel: 'Quote accepted',
      secondaryChipLabel: 'Quote accepted',
      statusLabel: 'Quote accepted',
      summary: exactPinReceived
          ? 'Quote accepted. Exact pin received.'
          : 'Quote accepted.',
      nextActionText: exactPinReceived
          ? 'Open to review the accepted quote details.'
          : 'Open to review the accepted quote details.',
      showExactPinReceivedChip: exactPinReceived,
    );
  }

  if (isQuoteAwaitingCustomerResponse) {
    return VanQuoteUiStatus(
      primaryChipLabel: wasQuoteRevised ? 'Quote resent' : 'Quote sent',
      secondaryChipLabel: 'Awaiting quote response',
      statusLabel: 'Awaiting quote response',
      summary: wasQuoteRevised
          ? 'Quote resent. Awaiting customer response.'
          : 'Quote sent. Awaiting customer response.',
      nextActionText: 'Waiting for the customer to respond to the quote.',
    );
  }

  if (!hasRequest || !hasRequestBeenSent) {
    return const VanQuoteUiStatus(
      primaryChipLabel: 'Request received',
      secondaryChipLabel: 'Not sent',
      statusLabel: 'Not sent',
      summary: 'Request not sent yet.',
      nextActionText: 'Open to review details and send a quote.',
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
      nextActionText: 'Open to review details and send a quote.',
      showExactPinReceivedChip: hasExactPin,
    );
  }

  return const VanQuoteUiStatus(
    primaryChipLabel: 'Request received',
    secondaryChipLabel: 'Awaiting customer reply',
    statusLabel: 'Awaiting customer reply',
    summary: 'Awaiting customer reply.',
    nextActionText: 'Open to review details and send a quote.',
  );
}
