import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_quote_ui_status.dart';

void main() {
  test(
    'quote accepted plus proposed time plus exact pin resolves to ready for calendar',
    () {
      final status = deriveVanQuoteUiStatus(
        hasRequest: true,
        hasReply: true,
        hasQuote: true,
        hasRequestBeenSent: true,
        isQuoteAccepted: true,
        isQuoteDeclined: false,
        isConfirmed: false,
        isScheduledInCalendar: false,
        isQuoteAwaitingCustomerResponse: false,
        hasAgreedTime: true,
        needsAgreedTime: false,
        requiresExactPin: true,
        hasExactPin: true,
      );

      expect(status.primaryChipLabel, 'Quote accepted');
      expect(status.secondaryChipLabel, 'Ready for Calendar');
      expect(status.statusLabel, 'Ready for Calendar');
      expect(status.showExactPinReceivedChip, isTrue);
    },
  );
}
