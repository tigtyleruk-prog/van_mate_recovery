import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/pages/business_hub_page.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

DriverCustomerReplyMockData _job({
  required String id,
  String status = 'replyReceived',
  String requestStatus = 'request_sent',
  String quoteStatus = '',
  bool quoteAccepted = false,
  String schedulingStatus = '',
  String calendarStatus = 'unscheduled',
  bool requestExactPin = false,
  DateTime? updatedAt,
}) {
  return DriverCustomerReplyMockData(
    jobId: id,
    customerName: 'Customer',
    jobTitle: 'Cake Orders',
    scheduledAt: null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: '',
    phoneNumber: '',
    requestId: 'request-$id',
    status: status,
    requestStatus: requestStatus,
    quoteStatus: quoteStatus,
    quoteAccepted: quoteAccepted,
    schedulingStatus: schedulingStatus,
    calendarStatus: calendarStatus,
    requestExactPin: requestExactPin,
    quoteAmount: quoteAccepted ? 42 : null,
    quoteResponseId: quoteAccepted ? 'quote-$id' : '',
    updatedAt: updatedAt ?? DateTime.parse('2026-07-12T10:00:00.000Z'),
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
  );
}

void main() {
  test('new incoming request count takes priority over accepted jobs', () {
    final newRequest = _job(id: 'new-request');
    final acceptedOrder = _job(
      id: 'accepted-order',
      status: 'quoteAccepted',
      requestStatus: 'quote_accepted',
      quoteStatus: 'accepted',
      quoteAccepted: true,
      schedulingStatus: 'awaiting_agreed_time',
    );
    final scheduled = _job(
      id: 'scheduled-job',
      status: 'confirmed',
      requestStatus: 'confirmed',
      calendarStatus: 'scheduled',
    );

    final attention = buildVanIncomingJobsAttention(
      <DriverCustomerReplyMockData>[newRequest, acceptedOrder, scheduled],
    );

    expect(attention.count, 2);
    expect(attention.newIncomingRequestCount, 1);
    expect(attention.label, '1 new');
    expect(attention.hasAttention, isTrue);
  });

  test('multiple new incoming requests use the new count', () {
    final attention = buildVanIncomingJobsAttention(
      <DriverCustomerReplyMockData>[
        _job(id: 'new-request-1'),
        _job(id: 'new-request-2'),
        _job(id: 'new-request-3'),
      ],
    );

    expect(attention.newIncomingRequestCount, 3);
    expect(attention.label, '3 new');
  });

  test('viewed actions clear until the incoming job changes again', () {
    final job = _job(id: 'viewed-job');
    final initial = buildVanIncomingJobsAttention(<DriverCustomerReplyMockData>[
      job,
    ]);
    final viewed = buildVanIncomingJobsAttention(<DriverCustomerReplyMockData>[
      job,
    ], viewedTokens: initial.actionTokens);
    final changed = job.copyWith(
      quoteStatus: 'sent',
      updatedAt: DateTime.parse('2026-07-12T11:00:00.000Z'),
    );
    final refreshed = buildVanIncomingJobsAttention(
      <DriverCustomerReplyMockData>[changed],
      viewedTokens: initial.actionTokens,
    );

    expect(viewed.hasAttention, isFalse);
    expect(refreshed.count, 1);
    expect(refreshed.label, '1 new');
  });

  test('ready-for-calendar incoming jobs use the calendar attention label', () {
    final readyForCalendar = _job(
      id: 'calendar-job',
      status: 'quoteAccepted',
      requestStatus: 'quote_accepted',
      quoteStatus: 'accepted',
      quoteAccepted: true,
      schedulingStatus: 'accepted_time',
    ).copyWith(proposedDate: '2026-07-20', proposedStartTime: '10:00');

    final attention = buildVanIncomingJobsAttention(
      <DriverCustomerReplyMockData>[readyForCalendar],
    );

    expect(attention.count, 1);
    expect(attention.readyForCalendarCount, 1);
    expect(attention.label, 'Ready for Calendar');
  });
}
