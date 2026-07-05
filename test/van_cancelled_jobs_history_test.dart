import 'package:flutter_test/flutter_test.dart';

import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

void main() {
  test('fromJson preserves cancelled request status and cancellation date', () {
    final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
      'jobId': 'job-1',
      'customerName': 'Alex',
      'jobTitle': 'House move',
      'status': 'cancelled',
      'requestStatus': 'cancelled',
      'calendarStatus': 'scheduled',
      'scheduledDate': '2026-06-10',
      'scheduledStartTime': '09:30',
      'updatedAt': '2026-06-09T12:00:00.000Z',
      'cancelledAt': '2026-06-09T11:00:00.000Z',
      'hasReply': true,
      'additionalNotes': 'Customer cancelled after booking.',
    });

    expect(job.isCancelled, isTrue);
    expect(job.requestStatus, 'cancelled');
    expect(job.cancelledAt, DateTime.parse('2026-06-09T11:00:00.000Z'));
  });

  test('cancelled scheduled jobs do not produce a booked calendar slot', () {
    final job = DriverCustomerReplyMockData(
      jobId: 'job-2',
      customerName: 'Jamie',
      jobTitle: 'Flat clearance',
      scheduledAt: null,
      jobDateLabel: '',
      jobTimeLabel: '',
      address: '1 Test Street',
      phoneNumber: '07123456789',
      exactPinShared: false,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      status: 'cancelled',
      scheduledDate: '2026-06-12',
      scheduledStartTime: '14:00',
      calendarStatus: 'cancelled',
    );

    expect(job.bookedCalendarSlot, isNull);
  });
}
