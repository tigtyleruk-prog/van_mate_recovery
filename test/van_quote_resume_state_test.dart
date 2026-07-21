import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

DriverCustomerReplyMockData _job({
  required DateTime updatedAt,
  String currentQuoteId = '',
  String quoteResponseId = '',
  DateTime? quoteSavedAt,
  DateTime? quoteSentAt,
  double? quoteAmount,
  List<String> quoteExtras = const <String>[],
  String proposedDate = '',
  String proposedStartTime = '',
  String proposedAppointmentNote = '',
  String status = 'replyReceived',
  String requestStatus = 'reply_received',
  String quoteStatus = '',
}) {
  return DriverCustomerReplyMockData(
    jobId: 'job-sms-resume',
    customerName: 'Customer',
    jobTitle: 'Same-day Delivery',
    scheduledAt: null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: '1 Test Street',
    phoneNumber: '07123456789',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: 'Leave with reception.',
    requestId: 'request-sms-resume',
    hasReply: true,
    replyReceivedAt: DateTime.parse('2026-07-21T08:45:00Z'),
    updatedAt: updatedAt,
    currentQuoteId: currentQuoteId,
    quoteResponseId: quoteResponseId,
    quoteResponseToken: quoteResponseId.isEmpty ? '' : 'quote-token',
    quoteResponseLink: quoteResponseId.isEmpty
        ? ''
        : 'https://example.com/q/quote-token',
    quoteSavedAt: quoteSavedAt,
    quoteSentAt: quoteSentAt,
    quoteAmount: quoteAmount,
    quoteExtras: quoteExtras,
    quoteJobDescription: quoteResponseId.isEmpty ? '' : 'Urgent documents',
    quoteNotes: quoteResponseId.isEmpty ? '' : 'Includes proof of delivery',
    quotePaymentInstructions: quoteResponseId.isEmpty
        ? ''
        : 'Payment on completion',
    quoteMessage: quoteResponseId.isEmpty ? '' : 'Your quote is ready',
    proposedDate: proposedDate,
    proposedStartTime: proposedStartTime,
    proposedAppointmentNote: proposedAppointmentNote,
    status: status,
    requestStatus: requestStatus,
    quoteStatus: quoteStatus,
  );
}

void main() {
  final state = DriverReplyMockState.instance;

  setUp(state.debugResetStateForTest);

  test(
    'SMS resume stale job snapshot cannot downgrade a published current quote',
    () {
      final published = _job(
        updatedAt: DateTime.parse('2026-07-21T10:00:00Z'),
        currentQuoteId: 'job-sms-resume',
        quoteResponseId: 'job-sms-resume',
        quoteSavedAt: DateTime.parse('2026-07-21T10:00:00Z'),
        quoteSentAt: DateTime.parse('2026-07-21T10:00:01Z'),
        quoteAmount: 185,
        quoteExtras: const <String>['Timed delivery: GBP 25.00'],
        proposedDate: '2026-07-27',
        proposedStartTime: '10:00',
        proposedAppointmentNote: '27 Jul 2026 at 10:00',
        status: 'quoteSent',
        requestStatus: 'quote_sent',
        quoteStatus: 'sent',
      );
      state.debugAddJobForTest(published);

      final beforeResume = deriveVanJobActionState(
        state.jobById(published.jobId)!,
      );
      expect(beforeResume.canViewQuote, isTrue);
      expect(beforeResume.canCreateQuote, isFalse);

      // This models the server read started by lifecycle resume while the SMS
      // hand-off and quote transaction were still finishing.
      final delayedPrePublicationSnapshot = _job(
        updatedAt: DateTime.parse('2026-07-21T10:00:03Z'),
      );
      state.debugMergeCloudJobsForTest(<DriverCustomerReplyMockData>[
        delayedPrePublicationSnapshot,
      ], sourceLabel: 'users/{uid}/van_jobs');

      final afterResume = state.jobById(published.jobId)!;
      final afterResumeAction = deriveVanJobActionState(afterResume);
      expect(afterResumeAction.canViewQuote, isTrue);
      expect(afterResumeAction.canCreateQuote, isFalse);
      expect(afterResume.currentQuoteId, 'job-sms-resume');
      expect(afterResume.authoritativeCurrentQuoteId, 'job-sms-resume');
      expect(afterResume.quoteAmount, 185);
      expect(afterResume.proposedDate, '2026-07-27');
      expect(afterResume.proposedStartTime, '10:00');
      expect(afterResume.proposedAppointmentNote, '27 Jul 2026 at 10:00');
      expect(afterResume.quoteExtras, const <String>[
        'Timed delivery: GBP 25.00',
      ]);
      expect(state.resolveQuoteResponseIdForJob(afterResume), 'job-sms-resume');

      // The transaction can expose currentQuoteId before a separate job
      // projection contains the quote payload. That partial snapshot must not
      // erase the locally confirmed amount, proposal, or extras.
      final partialCurrentQuoteSnapshot = _job(
        updatedAt: DateTime.parse('2026-07-21T10:00:04Z'),
        currentQuoteId: 'job-sms-resume',
        quoteResponseId: 'job-sms-resume',
        status: 'quoteSent',
        requestStatus: 'quote_sent',
        quoteStatus: 'sent',
      );
      state.debugMergeCloudJobsForTest(<DriverCustomerReplyMockData>[
        partialCurrentQuoteSnapshot,
      ], sourceLabel: 'users/{uid}/van_jobs');

      final afterPartialSnapshot = state.jobById(published.jobId)!;
      expect(
        deriveVanJobActionState(afterPartialSnapshot).canViewQuote,
        isTrue,
      );
      expect(afterPartialSnapshot.currentQuoteId, 'job-sms-resume');
      expect(afterPartialSnapshot.quoteAmount, 185);
      expect(afterPartialSnapshot.proposedDate, '2026-07-27');
      expect(afterPartialSnapshot.proposedStartTime, '10:00');
      expect(afterPartialSnapshot.quoteExtras, const <String>[
        'Timed delivery: GBP 25.00',
      ]);
    },
  );

  test('authoritative current quote hydrates after an initially stale job', () {
    final stale = _job(updatedAt: DateTime.parse('2026-07-21T10:00:00Z'));
    state.debugAddJobForTest(stale);
    expect(deriveVanJobActionState(stale).canCreateQuote, isTrue);

    final authoritativeQuote = _job(
      updatedAt: DateTime.parse('2026-07-21T10:00:02Z'),
      currentQuoteId: 'job-sms-resume',
      quoteResponseId: 'job-sms-resume',
      quoteSavedAt: DateTime.parse('2026-07-21T10:00:01Z'),
      quoteSentAt: DateTime.parse('2026-07-21T10:00:02Z'),
      quoteAmount: 185,
      quoteExtras: const <String>['Timed delivery: GBP 25.00'],
      proposedDate: '2026-07-27',
      proposedStartTime: '10:00',
      status: 'quoteSent',
      requestStatus: 'quote_sent',
      quoteStatus: 'sent',
    );
    state.debugMergeCloudJobsForTest(<DriverCustomerReplyMockData>[
      authoritativeQuote,
    ], sourceLabel: 'public_quote_responses');

    final hydrated = state.jobById(stale.jobId)!;
    expect(hydrated.authoritativeCurrentQuoteId, 'job-sms-resume');
    expect(deriveVanJobActionState(hydrated).canViewQuote, isTrue);
    expect(deriveVanJobActionState(hydrated).canCreateQuote, isFalse);
    expect(hydrated.quoteAmount, 185);
    expect(hydrated.quoteExtras, const <String>['Timed delivery: GBP 25.00']);
  });

  test(
    'authoritative quote fills a newer-timestamp partial job projection',
    () {
      final partialJobProjection = _job(
        updatedAt: DateTime.parse('2026-07-21T10:00:04Z'),
        currentQuoteId: 'job-sms-resume',
        quoteResponseId: 'job-sms-resume',
        status: 'quoteSent',
        requestStatus: 'quote_sent',
        quoteStatus: 'sent',
      );
      state.debugAddJobForTest(partialJobProjection);

      final authoritativeQuote = _job(
        updatedAt: DateTime.parse('2026-07-21T10:00:02Z'),
        currentQuoteId: 'job-sms-resume',
        quoteResponseId: 'job-sms-resume',
        quoteSavedAt: DateTime.parse('2026-07-21T10:00:01Z'),
        quoteSentAt: DateTime.parse('2026-07-21T10:00:02Z'),
        quoteAmount: 185,
        quoteExtras: const <String>['Timed delivery: GBP 25.00'],
        proposedDate: '2026-07-27',
        proposedStartTime: '10:00',
        status: 'quoteSent',
        requestStatus: 'quote_sent',
        quoteStatus: 'sent',
      );
      state.debugMergeCloudJobsForTest(<DriverCustomerReplyMockData>[
        authoritativeQuote,
      ], sourceLabel: 'public_quote_responses');

      final hydrated = state.jobById(partialJobProjection.jobId)!;
      expect(hydrated.quoteAmount, 185);
      expect(hydrated.proposedDate, '2026-07-27');
      expect(hydrated.proposedStartTime, '10:00');
      expect(hydrated.quoteExtras, const <String>['Timed delivery: GBP 25.00']);
      expect(deriveVanJobActionState(hydrated).canViewQuote, isTrue);
    },
  );

  test(
    'currentQuoteId alone is hydrated as the authoritative quote identity',
    () {
      final hydrated = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
        'jobId': 'job-sms-resume',
        'currentQuoteId': 'quote-current',
        'requestId': 'request-sms-resume',
        'requestStatus': 'reply_received',
        'replyReceivedAt': '2026-07-21T08:45:00Z',
      });

      expect(hydrated.currentQuoteId, 'quote-current');
      expect(hydrated.quoteResponseId, 'quote-current');
      expect(hydrated.hasQuote, isTrue);
      expect(deriveVanJobActionState(hydrated).canViewQuote, isTrue);
      expect(hydrated.toJson()['currentQuoteId'], 'quote-current');
    },
  );

  test('legacy quoteResponseId round-trips into currentQuoteId', () {
    final legacy = _job(
      updatedAt: DateTime.parse('2026-07-21T10:00:00Z'),
      quoteResponseId: 'legacy-current-quote',
      quoteSentAt: DateTime.parse('2026-07-21T10:00:00Z'),
      quoteAmount: 95,
      status: 'quoteSent',
      requestStatus: 'quote_sent',
      quoteStatus: 'sent',
    );

    final json = legacy.toJson();
    expect(json['currentQuoteId'], 'legacy-current-quote');
    expect(json['quoteResponseId'], 'legacy-current-quote');

    final restored = DriverCustomerReplyMockData.fromJson(json);
    expect(restored.currentQuoteId, 'legacy-current-quote');
    expect(restored.authoritativeCurrentQuoteId, 'legacy-current-quote');
    expect(restored.quoteAmount, 95);
  });

  test('resume refresh is read-only and cannot trigger quote publication', () {
    final source = File(
      'lib/features/van_mate/pages/driver_customer_reply_mock_page.dart',
    ).readAsStringSync();
    final lifecycleStart = source.indexOf(
      'void didChangeAppLifecycleState(AppLifecycleState state)',
      source.indexOf('class CreateQuotePage'),
    );
    final lifecycleEnd = source.indexOf('void _showSnack', lifecycleStart);
    final lifecycleHandler = source.substring(lifecycleStart, lifecycleEnd);

    expect(lifecycleHandler, contains('refreshJobsFromCloud'));
    expect(lifecycleHandler, isNot(contains('setQuoteSent')));
    expect(lifecycleHandler, isNot(contains('saveQuote')));
  });
}
