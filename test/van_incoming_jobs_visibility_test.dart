import 'package:flutter_test/flutter_test.dart';

import 'package:van_mate_app/features/van_mate/pages/van_incoming_requests_page.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

void main() {
  test(
    'incoming job timing display prefers confirmed appointment when agreed',
    () {
      final job = DriverCustomerReplyMockData(
        jobId: 'confirmed-job',
        customerName: 'Taylor',
        jobTitle: 'Office move',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '10 Market Road',
        phoneNumber: '07123456789',
        exactPinShared: true,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        status: 'quoteAccepted',
        requestId: 'request-confirmed',
        requestStatus: 'quote_accepted',
        agreedDateTime: DateTime.parse('2026-06-22T13:00:00.000Z'),
        scheduledDate: '2026-06-22',
        scheduledStartTime: '13:00',
        schedulingStatus: 'accepted_time',
        calendarStatus: 'unscheduled',
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteResponseId: 'quote-confirmed-job',
        preferredDate: DateTime.parse('2026-06-22T00:00:00.000Z'),
        preferredTimeWindow: 'afternoon',
      );

      final display = buildIncomingJobTimingDisplay(job);

      expect(display.label, 'Confirmed appointment');
      expect(display.value, '22 Jun 2026 • 13:00');
    },
  );

  test(
    'incoming job timing display falls back to preferred date/time when awaiting arrange another time',
    () {
      final job = DriverCustomerReplyMockData(
        jobId: 'arrange-later-job',
        customerName: 'Morgan',
        jobTitle: 'Storage run',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '20 River Lane',
        phoneNumber: '07999999999',
        exactPinShared: false,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        status: 'quoteAccepted',
        requestId: 'request-arrange',
        requestStatus: 'quote_accepted',
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteResponseId: 'quote-arrange-later-job',
        quoteTimingChoice: 'arrange_another_time',
        schedulingStatus: 'awaiting_agreed_time',
        preferredDate: DateTime.parse('2026-06-22T00:00:00.000Z'),
        preferredTimeWindow: 'afternoon',
      );

      final display = buildIncomingJobTimingDisplay(job);

      expect(display.label, 'Preferred date/time');
      expect(display.value, '22 Jun 2026 • Afternoon');
    },
  );

  test(
    'accepted job with agreed time stays pending until added to calendar',
    () {
      final job = DriverCustomerReplyMockData(
        jobId: 'pending-ready',
        customerName: 'Taylor',
        jobTitle: 'Office move',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '10 Market Road',
        phoneNumber: '07123456789',
        exactPinShared: false,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        status: 'quoteAccepted',
        requestId: 'request-1',
        requestStatus: 'quote_accepted',
        agreedDateTime: DateTime.parse('2026-06-14T10:00:00.000Z'),
        scheduledDate: '2026-06-14',
        scheduledStartTime: '10:00',
        schedulingStatus: 'accepted_time',
        calendarStatus: 'unscheduled',
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteResponseId: 'quote-pending-ready',
      );

      expect(job.isScheduledInCalendarState, isFalse);
      expect(job.isPendingCustomerRequest, isTrue);
      expect(
        debugBucketDecisionForJob(job).bucket,
        VanJobBucket.pendingCustomerRequest,
      );
    },
  );

  test(
    'scheduled calendar job is excluded from pending and treated as booked',
    () {
      final job = DriverCustomerReplyMockData(
        jobId: 'scheduled-job',
        customerName: 'Morgan',
        jobTitle: 'Storage run',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '20 River Lane',
        phoneNumber: '07999999999',
        exactPinShared: false,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        status: 'quoteAccepted',
        requestId: 'request-2',
        requestStatus: 'quote_accepted',
        agreedDateTime: DateTime.parse('2026-06-15T09:00:00.000Z'),
        scheduledDate: '2026-06-15',
        scheduledStartTime: '09:00',
        schedulingStatus: 'accepted_time',
        calendarStatus: 'scheduled',
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteResponseId: 'quote-scheduled-job',
      );

      expect(job.isScheduledInCalendarState, isTrue);
      expect(job.isPendingCustomerRequest, isFalse);
      expect(debugBucketDecisionForJob(job).bucket, VanJobBucket.bookedJob);
    },
  );

  test(
    'scheduled accepted job with exact pin is no longer pending and stays booked',
    () {
      final readyForCalendar = DriverCustomerReplyMockData(
        jobId: 'ready-then-scheduled',
        customerName: 'Jordan',
        jobTitle: 'House move',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '30 Oak Street',
        phoneNumber: '07010101010',
        exactPinShared: true,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        status: 'quoteAccepted',
        requestId: 'request-3',
        requestStatus: 'quote_accepted',
        agreedDateTime: DateTime.parse('2026-06-16T13:30:00.000Z'),
        scheduledDate: '2026-06-16',
        scheduledStartTime: '13:30',
        schedulingStatus: 'accepted_time',
        calendarStatus: 'unscheduled',
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteResponseId: 'quote-ready-then-scheduled',
      );
      final scheduled = readyForCalendar.copyWith(
        status: 'scheduled',
        requestStatus: 'confirmed',
        calendarStatus: 'scheduled',
        schedulingStatus: 'scheduled',
        scheduledAt: DateTime.parse('2026-06-16T13:30:00.000Z'),
      );

      expect(readyForCalendar.isPendingCustomerRequest, isTrue);
      expect(
        debugBucketDecisionForJob(readyForCalendar).bucket,
        VanJobBucket.pendingCustomerRequest,
      );

      expect(scheduled.isScheduledInCalendarState, isTrue);
      expect(scheduled.isPendingCustomerRequest, isFalse);
      expect(scheduled.requestStatusLabel, 'Added to Calendar');
      expect(scheduled.requestBadgeLabel, 'Added to Calendar');
      expect(
        debugBucketDecisionForJob(scheduled).bucket,
        VanJobBucket.bookedJob,
      );
    },
  );

  test('completed scheduled job stays out of incoming jobs', () {
    final completed = DriverCustomerReplyMockData(
      jobId: 'completed-scheduled-job',
      customerName: 'Casey',
      jobTitle: 'Furniture move',
      scheduledAt: DateTime.parse('2026-06-16T13:30:00.000Z'),
      jobDateLabel: '16 Jun 2026',
      jobTimeLabel: '1:30 PM',
      address: '40 High Street',
      phoneNumber: '07111111111',
      exactPinShared: true,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      status: 'completed',
      requestId: 'request-4',
      requestStatus: 'completed',
      agreedDateTime: DateTime.parse('2026-06-16T13:30:00.000Z'),
      scheduledDate: '2026-06-16',
      scheduledStartTime: '13:30',
      schedulingStatus: 'scheduled',
      calendarStatus: 'completed',
      quoteAccepted: true,
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteResponseId: 'quote-completed-scheduled-job',
      completedAt: DateTime.parse('2026-06-16T15:00:00.000Z'),
    );

    expect(completed.isPendingCustomerRequest, isFalse);
    expect(completed.isCompletedJob, isTrue);
    expect(
      debugBucketDecisionForJob(completed).bucket,
      VanJobBucket.completedJob,
    );
  });

  test('deleted jobs stay hidden from incoming jobs buckets', () {
    final deleted = DriverCustomerReplyMockData(
      jobId: 'deleted-job',
      customerName: 'Alex',
      jobTitle: 'Move out',
      scheduledAt: null,
      jobDateLabel: '',
      jobTimeLabel: '',
      address: '50 Hill Road',
      phoneNumber: '07000000000',
      exactPinShared: false,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      status: 'deleted',
      requestId: 'request-deleted',
      requestStatus: 'deleted',
      deleted: true,
      archived: true,
    );

    expect(deleted.isHiddenFromNormalLists, isTrue);
    expect(
      debugBucketDecisionForJob(deleted).bucket,
      VanJobBucket.hiddenDeletedOrDraft,
    );
  });
}
