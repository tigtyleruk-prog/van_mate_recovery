import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

DriverCustomerReplyMockData _buildDeclinedQuoteReply() {
  final declinedAt = DateTime.parse('2026-06-20T10:00:00.000Z');
  return DriverCustomerReplyMockData(
    jobId: 'job-declined-1',
    customerName: 'Test Customer',
    jobTitle: 'Sofa move',
    scheduledAt: null,
    jobDateLabel: '2026-06-22',
    jobTimeLabel: '10:00',
    address: '1 Test Street',
    phoneNumber: '07123456789',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: 'quoteDeclined',
    requestStatus: 'quote_declined',
    hasReply: true,
    quoteAmount: 125,
    quoteSavedAt: declinedAt.subtract(const Duration(minutes: 5)),
    quoteSentAt: declinedAt.subtract(const Duration(minutes: 4)),
    quoteStatus: 'declined',
    quoteResponseStatus: 'declined',
    quoteDeclined: true,
    quoteDeclinedAt: declinedAt,
    quoteRespondedAt: declinedAt,
    quoteTimingChoice: 'declined',
    quoteResponseId: 'quote-old',
    quoteResponseToken: 'token-old',
    quoteResponseLink: 'https://example.com/quote-old',
    quoteMessage: 'Original quote',
  );
}

DriverCustomerReplyMockData _buildRevisedSentQuoteReply() {
  return DriverCustomerReplyMockData(
    jobId: 'job-declined-1',
    customerName: 'Test Customer',
    jobTitle: 'Sofa move',
    scheduledAt: null,
    jobDateLabel: '2026-06-22',
    jobTimeLabel: '10:00',
    address: '1 Test Street',
    phoneNumber: '07123456789',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: 'quoteSent',
    requestStatus: 'quote_sent',
    hasReply: true,
    quoteAmount: 150,
    quoteSavedAt: DateTime.parse('2026-06-20T10:55:00.000Z'),
    quoteSentAt: DateTime.parse('2026-06-20T11:00:00.000Z'),
    quoteOpenedAt: DateTime.parse('2026-06-20T11:00:00.000Z'),
    quoteStatus: 'sent',
    quoteResponseStatus: '',
    quoteDeclined: false,
    quoteDeclinedAt: null,
    quoteRespondedAt: null,
    quoteTimingChoice: '',
    quoteResponseId: 'quote-new',
    quoteResponseToken: 'token-new',
    quoteResponseLink: 'https://example.com/quote-new',
    quoteMessage: 'Revised quote',
  );
}

void main() {
  setUp(() {
    DriverReplyMockState.instance.debugResetStateForTest();
  });

  test(
    'declined quote keeps revise action when live job is stale after opening revise flow',
    () {
      final original = _buildDeclinedQuoteReply();
      final staleLiveJob = original.copyWith(
        status: 'quoteSent',
        requestStatus: 'quote_sent',
        quoteStatus: 'sent',
        quoteResponseStatus: '',
        quoteDeclined: false,
        quoteDeclinedAt: null,
        quoteRespondedAt: null,
      );

      DriverReplyMockState.instance.debugAddJobForTest(staleLiveJob);

      final resolved = resolveVanQuoteWorkflowReply(original);
      final actionState = deriveVanJobActionState(resolved);

      expect(resolved.isQuoteDeclined, isTrue);
      expect(resolved.hasQuote, isTrue);
      expect(actionState.canReviseQuote, isTrue);
      expect(actionState.canViewQuote, isTrue);
    },
  );

  test('saving and sending a revised quote replaces the declined state', () {
    final original = _buildDeclinedQuoteReply();
    final revisedSent = _buildRevisedSentQuoteReply();

    DriverReplyMockState.instance.debugAddJobForTest(revisedSent);

    final resolved = resolveVanQuoteWorkflowReply(original);
    final actionState = deriveVanJobActionState(resolved);

    expect(resolved.isQuoteDeclined, isFalse);
    expect(resolved.quoteStatus, 'sent');
    expect(resolved.requestStatus, 'quote_sent');
    expect(resolved.quoteRespondedAt, isNull);
    expect(resolved.quoteResponseId, isNot(original.quoteResponseId));
    expect(actionState.canReviseQuote, isFalse);
    expect(actionState.canViewQuote, isTrue);
  });

  test('partial draft revision fields do not hide revise action', () {
    final original = _buildDeclinedQuoteReply();
    final draftLikeLiveJob = original.copyWith(
      status: 'quoteSent',
      requestStatus: 'quote_sent',
      quoteStatus: 'sent',
      quoteResponseStatus: '',
      quoteDeclined: false,
      quoteDeclinedAt: null,
      quoteRespondedAt: null,
      quoteSavedAt: DateTime.parse('2026-06-20T10:30:00.000Z'),
      quoteSentAt: original.quoteSentAt,
      quoteResponseId: original.quoteResponseId,
      quoteResponseToken: original.quoteResponseToken,
      quoteResponseLink: original.quoteResponseLink,
    );

    DriverReplyMockState.instance.debugAddJobForTest(draftLikeLiveJob);

    final resolved = resolveVanQuoteWorkflowReply(original);
    final actionState = deriveVanJobActionState(resolved);

    expect(
      shouldPreserveDeclinedQuoteWorkflowState(original, draftLikeLiveJob),
      isTrue,
    );
    expect(resolved.isQuoteDeclined, isTrue);
    expect(actionState.canReviseQuote, isTrue);
  });
}
