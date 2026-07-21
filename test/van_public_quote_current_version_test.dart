import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

DriverCustomerReplyMockData _quoteJob({
  String quoteResponseId = '',
  bool declined = false,
}) {
  return DriverCustomerReplyMockData(
    jobId: 'job-current-quote',
    customerName: 'Customer',
    jobTitle: 'Courier delivery',
    scheduledAt: null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: '',
    phoneNumber: '',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: declined ? 'quoteDeclined' : 'quoteSent',
    requestStatus: declined ? 'quote_declined' : 'quote_sent',
    quoteResponseId: quoteResponseId,
    quoteStatus: declined ? 'declined' : 'sent',
    quoteResponseStatus: declined ? 'declined' : '',
    quoteDeclined: declined,
  );
}

void main() {
  setUp(() {
    DriverReplyMockState.instance.debugResetStateForTest();
  });

  test('first quote uses the job id as its stable current quote id', () {
    final quoteId = DriverReplyMockState.instance.resolveQuoteResponseIdForJob(
      _quoteJob(),
    );

    expect(quoteId, 'job-current-quote');
  });

  test('repeated active sends update one stable quote document', () {
    final job = _quoteJob(quoteResponseId: 'job-current-quote');

    final first = DriverReplyMockState.instance.resolveQuoteResponseIdForJob(
      job,
    );
    final retry = DriverReplyMockState.instance.resolveQuoteResponseIdForJob(
      job,
    );

    expect(first, 'job-current-quote');
    expect(retry, first);
  });

  test('a declined quote creates the next recoverable history version', () {
    final job = _quoteJob(quoteResponseId: 'job-current-quote', declined: true);

    final revised = DriverReplyMockState.instance.resolveQuoteResponseIdForJob(
      job,
      creatingFreshQuote: true,
    );

    expect(revised, 'job-current-quote_q2');
  });

  test(
    'public quote publishing atomically switches current quote metadata',
    () {
      final source = File(
        'lib/features/van_mate/services/van_public_quote_cloud_service.dart',
      ).readAsStringSync();

      expect(source, contains('await _firestore.runTransaction'));
      expect(source, contains("'currentQuoteId': docId"));
      expect(source, contains("'quoteVersion': quoteVersion"));
      expect(source, contains("'isCurrent': false"));
      expect(source, contains("'lifecycleStatus': 'superseded'"));
      expect(source, contains("'supersededByQuoteId': docId"));
      expect(source, contains('existingPublishKey == quotePublishKey'));
    },
  );

  test('both quote send surfaces block duplicate taps while sending', () {
    final source = File(
      'lib/features/van_mate/pages/driver_customer_reply_mock_page.dart',
    ).readAsStringSync();

    expect(source, contains('if (_openingSendChannel)'));
    expect(source, contains('if (_sendingQuote)'));
    expect(source, contains('onPressed: _sendingQuote ? null : _sendQuote'));
    expect(source, contains("? 'Sending quote...'"));
    expect(source, contains("'quotePublishKey':"));
  });
}
