import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_quote_decline.dart';

void main() {
  test('decline summary keeps preset reason when note is blank', () {
    final summary = buildVanQuoteDeclineSummary(
      reasonLabel: 'Too expensive',
      note: '',
      reasonText: '',
    );

    expect(formatVanQuoteDeclineText(summary), 'Reason: Too expensive');
  });

  test('Incoming Jobs decline summary shows reason and note', () {
    final summary = buildVanQuoteDeclineSummary(
      reasonLabel: 'Time doesn\'t work',
      note: 'Need a weekend slot',
      reasonText: 'Need a weekend slot',
    );

    expect(
      formatVanQuoteDeclineText(summary),
      'Reason: Time doesn\'t work\nNote: Need a weekend slot',
    );
  });

  test(
    'Customer History decline summary shows note-only declines as a reason',
    () {
      final summary = buildVanQuoteDeclineSummary(
        reasonLabel: '',
        reasonCode: '',
        note: 'Need an earlier slot',
        reasonText: 'Need an earlier slot',
      );

      expect(
        formatVanQuoteDeclineText(summary),
        'Reason: Need an earlier slot',
      );
    },
  );

  test('older declined records use the dedicated fallback copy', () {
    const summary = VanQuoteDeclineSummary();

    expect(
      formatVanQuoteDeclineText(
        summary,
        emptyFallback: 'Decline reason not saved on this older test.',
      ),
      'Decline reason not saved on this older test.',
    );
  });
}
