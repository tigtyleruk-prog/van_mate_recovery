import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_quote_ui_status.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/pages/job_detail_page.dart';

void main() {
  test('quote awaiting customer response never prompts set agreed time', () {
    final job = DriverCustomerReplyMockData(
      jobId: 'awaiting-quote-response',
      customerName: 'Casey',
      jobTitle: 'Office move',
      scheduledAt: null,
      jobDateLabel: '',
      jobTimeLabel: '',
      address: '50 Market Street',
      phoneNumber: '07000000000',
      exactPinShared: false,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      status: 'quoteSent',
      requestId: 'request-awaiting-quote-response',
      requestStatus: 'quoted',
      quoteAccepted: false,
      quoteDeclined: false,
      quoteStatus: 'sent',
      quoteResponseStatus: 'pending',
      quoteResponseId: 'quote-awaiting-quote-response',
      quoteTimingChoice: '',
      proposedDate: '2026-06-15',
      proposedStartTime: '10:00',
      schedulingStatus: 'proposed_time',
    );

    expect(job.isQuoteAwaitingCustomerResponse, isTrue);
    expect(job.requestStatusLabel, 'Awaiting quote response');
    expect(job.requestBadgeLabel, 'Awaiting quote response');
    expect(job.quoteUiStatus.primaryChipLabel, 'Quote sent');
    expect(job.shouldPromptSetAgreedTime, isFalse);
    expect(job.shouldPromptAddToCalendar, isFalse);
  });

  test('declined quote stays declined even when sent fields still exist', () {
    final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
      'jobId': 'declined-stays-declined',
      'customerName': 'Casey',
      'jobTitle': 'Office move',
      'address': '50 Market Street',
      'phoneNumber': '07000000000',
      'status': 'quoteSent',
      'requestId': 'request-declined-stays-declined',
      'requestStatus': 'quote_sent',
      'quoteStatus': 'sent',
      'quoteResponseStatus': 'declined',
      'quoteDeclined': true,
      'quoteSentAt': '2026-06-14T10:00:00.000Z',
      'quoteResponseLink': 'https://vanmate.example/quote/original-token',
      'declineReasonLabel': 'Too expensive',
      'declineReasonText': 'Thanks anyway',
      'declineNote': 'Thanks anyway',
    });

    expect(job.isQuoteDeclined, isTrue);
    expect(job.isQuoteAwaitingCustomerResponse, isFalse);
    expect(job.requestStatusLabel, 'Quote declined');
    expect(job.requestBadgeLabel, 'Quote declined');
    expect(job.quoteUiStatus.primaryChipLabel, 'Quote declined');
    expect(job.quoteDeclineReasonLabel, 'Too expensive');
    expect(job.quoteDeclineNote, 'Thanks anyway');
  });

  test(
    'accepted quote without an agreed time exposes arranging state on the job model',
    () {
      final job = DriverCustomerReplyMockData(
        jobId: 'time-to-arrange',
        customerName: 'Jamie',
        jobTitle: 'Flat move',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '12 Station Road',
        phoneNumber: '07123456789',
        exactPinShared: false,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        status: 'quoteAccepted',
        requestId: 'request-time-to-arrange',
        requestStatus: 'quote_accepted',
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteResponseId: 'quote-time-to-arrange',
        quoteTimingChoice: 'arrange_another_time',
      );

      expect(job.isAwaitingAgreedTime, isTrue);
      expect(job.requestStatusLabel, 'Time needs arranging');
      expect(job.requestBadgeLabel, 'Time needs arranging');
      expect(job.shouldPromptSetAgreedTime, isTrue);
    },
  );

  test(
    'accepted quote progresses from arrange time to calendar-ready to scheduled',
    () {
      const baseJob = DriverCustomerReplyMockData(
        jobId: 'schedule-progression',
        customerName: 'Morgan',
        jobTitle: 'Storage run',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '20 River Lane',
        phoneNumber: '07999999999',
        exactPinShared: false,
        requestExactPin: false,
        checklistResponses: <DriverChecklistResponse>[],
        customQuestionResponses: <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        status: 'quoteAccepted',
        requestId: 'request-schedule-progression',
        requestStatus: 'quote_accepted',
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
        quoteResponseId: 'quote-schedule-progression',
        quoteTimingChoice: 'arrange_another_time',
      );

      final withAgreedTime = baseJob.copyWith(
        agreedDateTime: DateTime.parse('2026-06-14T10:00:00.000Z'),
        scheduledDate: '2026-06-14',
        scheduledStartTime: '10:00',
        schedulingStatus: 'time_agreed',
      );
      final scheduled = withAgreedTime.copyWith(calendarStatus: 'scheduled');

      expect(baseJob.requestStatusLabel, 'Time needs arranging');
      expect(baseJob.shouldPromptSetAgreedTime, isTrue);
      expect(baseJob.shouldPromptAddToCalendar, isFalse);

      expect(withAgreedTime.shouldPromptSetAgreedTime, isFalse);
      expect(withAgreedTime.shouldPromptAddToCalendar, isTrue);
      expect(withAgreedTime.requestStatusLabel, 'Ready for Calendar');
      expect(withAgreedTime.requestBadgeLabel, 'Ready for Calendar');
      expect(withAgreedTime.isScheduledInCalendarState, isFalse);

      expect(scheduled.isScheduledInCalendarState, isTrue);
      expect(scheduled.requestStatusLabel, 'Added to Calendar');
      expect(scheduled.requestBadgeLabel, 'Added to Calendar');
      expect(scheduled.isPendingCustomerRequest, isFalse);
    },
  );

  test('manual agreed time with exact pin is ready for calendar', () {
    final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
      'jobId': 'manual-agreed-time',
      'customerName': 'Jamie',
      'jobTitle': 'Flat move',
      'address': '12 Station Road',
      'phoneNumber': '07123456789',
      'status': 'quoteAccepted',
      'requestStatus': 'quote_accepted',
      'quoteAccepted': true,
      'quoteStatus': 'accepted',
      'quoteResponseStatus': 'accepted',
      'quoteResponseId': 'quote-manual-agreed-time',
      'quoteTimingChoice': 'agreed_time_saved',
      'schedulingStatus': 'time_agreed',
      'agreedDateTime': '2026-06-14T10:00:00.000Z',
      'scheduledAt': '2026-06-14T10:00:00.000Z',
      'scheduledDate': '2026-06-14',
      'scheduledStartTime': '10:00',
      'estimatedDurationMinutes': 90,
      'exactPinShared': true,
      'hasExactPin': true,
      'exactPinLatitude': 51.5,
      'exactPinLongitude': -0.12,
    });

    expect(job.isQuoteAccepted, isTrue);
    expect(job.hasAgreedSchedulingTime, isTrue);
    expect(job.shouldPromptSetAgreedTime, isFalse);
    expect(job.shouldPromptAddToCalendar, isTrue);
    expect(job.isReadyToAddToCalendar, isTrue);
    expect(job.requestStatusLabel, 'Ready for Calendar');
    expect(job.requestBadgeLabel, 'Ready for Calendar');
    expect(job.quoteUiStatus.secondaryChipLabel, 'Ready for Calendar');
  });

  test(
    'accept quote and proposed time is treated as agreed time from persisted fields',
    () {
      final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
        'jobId': 'accepted-proposed-time',
        'customerName': 'Jamie',
        'jobTitle': 'Flat move',
        'address': '12 Station Road',
        'phoneNumber': '07123456789',
        'status': 'quoteAccepted',
        'requestStatus': 'quote_accepted',
        'quoteAccepted': true,
        'quoteStatus': 'accepted',
        'quoteResponseStatus': 'accepted',
        'quoteResponseId': 'quote-accepted-proposed-time',
        'quoteTimingChoice': 'accepted_proposed_time',
        'schedulingStatus': 'accepted_time',
        'agreedStartAt': '2026-06-14T10:00:00.000Z',
        'agreedDate': '2026-06-14',
        'agreedTime': '10:00',
        'estimatedDurationMinutes': 90,
        'agreedDurationMinutes': 90,
        'exactPinShared': true,
        'hasExactPin': true,
        'exactPinLatitude': 51.5,
        'exactPinLongitude': -0.12,
      });

      expect(job.isQuoteAccepted, isTrue);
      expect(job.isQuoteAwaitingCustomerResponse, isFalse);
      expect(job.hasAgreedSchedulingTime, isTrue);
      expect(job.shouldPromptSetAgreedTime, isFalse);
      expect(job.shouldPromptAddToCalendar, isTrue);
      expect(job.isReadyToAddToCalendar, isTrue);
      expect(job.isAwaitingAgreedTime, isFalse);
      expect(job.requestStatusLabel, 'Ready for Calendar');
      expect(job.requestBadgeLabel, 'Ready for Calendar');
      expect(job.quoteUiStatus.primaryChipLabel, 'Quote accepted');
      expect(job.quoteUiStatus.secondaryChipLabel, 'Ready for Calendar');
      expect(job.quoteUiStatus.showExactPinReceivedChip, isTrue);
    },
  );

  test(
    'canonical accepted timing beats stale sent quote fields in card and detail derivation',
    () {
      final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
        'jobId': 'accepted-beats-stale-sent',
        'customerName': 'Jamie',
        'jobTitle': 'Flat move',
        'address': '12 Station Road',
        'phoneNumber': '07123456789',
        'status': 'quoteSent',
        'requestId': 'request-accepted-beats-stale-sent',
        'requestStatus': 'quote_sent',
        'quoteStatus': 'sent',
        'quoteResponseStatus': 'pending',
        'quoteAccepted': true,
        'timeAccepted': true,
        'acceptedProposedTime': true,
        'readyForCalendar': true,
        'quoteResponseId': 'quote-accepted-beats-stale-sent',
        'quoteSentAt': '2026-06-14T09:00:00.000Z',
        'agreedStartAt': '2026-06-14T10:00:00.000Z',
        'scheduledAt': '2026-06-14T10:00:00.000Z',
        'scheduledDate': '2026-06-14',
        'scheduledStartTime': '10:00',
        'estimatedDurationMinutes': 90,
        'exactPinShared': true,
        'hasExactPin': true,
        'exactPinLatitude': 51.5,
        'exactPinLongitude': -0.12,
      });
      final request = VanJobRequestRecord.fromJson(<String, dynamic>{
        'requestId': 'request-accepted-beats-stale-sent',
        'ownerUid': 'owner-1',
        'jobId': 'accepted-beats-stale-sent',
        'linkedJobId': 'accepted-beats-stale-sent',
        'status': 'quote_sent',
        'requestStatus': 'quote_sent',
        'createdAt': '2026-06-14T08:00:00.000Z',
        'updatedAt': '2026-06-14T10:01:00.000Z',
        'expiresAt': '2026-06-21T08:00:00.000Z',
        'publicJobTitle': 'Flat move',
        'publicCustomerName': 'Jamie',
        'publicAddressSummary': '12 Station Road',
        'checklistItems': const <String>[],
        'customQuestions': const <String>[],
        'exactPinRequested': true,
        'timeAccepted': true,
        'readyForCalendar': true,
        'agreedStartAt': '2026-06-14T10:00:00.000Z',
        'scheduledAt': '2026-06-14T10:00:00.000Z',
        'scheduledDate': '2026-06-14',
        'scheduledStartTime': '10:00',
        'exactPinLat': 51.5,
        'exactPinLng': -0.12,
        'replyReceivedAt': '2026-06-14T10:01:00.000Z',
      });

      expect(job.isQuoteAccepted, isTrue);
      expect(job.isQuoteAwaitingCustomerResponse, isFalse);
      expect(job.hasAgreedSchedulingTime, isTrue);
      expect(job.requestStatusLabel, 'Ready for Calendar');
      expect(job.requestBadgeLabel, 'Ready for Calendar');
      expect(job.quoteUiStatus.primaryChipLabel, 'Quote accepted');
      expect(job.quoteUiStatus.secondaryChipLabel, 'Ready for Calendar');
      expect(job.quoteUiStatus.showExactPinReceivedChip, isTrue);

      expect(request.acceptedProposedTime, isTrue);
      expect(request.timeAgreed, isTrue);
      expect(request.hasAgreedSchedulingTime, isTrue);
      expect(
        hasCanonicalAgreedSchedulingTimeForJob(job, request: request),
        isTrue,
      );

      final detailStatus = deriveVanQuoteUiStatus(
        hasRequest: true,
        hasReply: true,
        hasQuote: job.hasQuote,
        hasRequestBeenSent: true,
        isQuoteAccepted: job.isQuoteAccepted,
        isQuoteDeclined: job.isQuoteDeclined,
        isConfirmed: job.isConfirmed,
        isScheduledInCalendar: false,
        isQuoteAwaitingCustomerResponse: job.isQuoteAwaitingCustomerResponse,
        hasAgreedTime: hasCanonicalAgreedSchedulingTimeForJob(
          job,
          request: request,
        ),
        needsAgreedTime: shouldPromptSetAgreedTimeForJob(job, request: request),
        requiresExactPin: job.requiresAnyExactPin,
        hasExactPin: job.exactPinSaved,
      );

      expect(detailStatus.primaryChipLabel, 'Quote accepted');
      expect(detailStatus.secondaryChipLabel, 'Ready for Calendar');
      expect(detailStatus.statusLabel, 'Ready for Calendar');
    },
  );

  testWidgets(
    'ready for calendar detail shows add calendar action instead of set agreed time',
    (tester) async {
      final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
        'jobId': 'ready-detail-action-button',
        'customerName': 'Jamie',
        'jobTitle': 'Flat move',
        'address': '12 Station Road',
        'phoneNumber': '07123456789',
        'status': 'quoteAccepted',
        'requestId': 'request-ready-detail-action-button',
        'requestStatus': 'quote_accepted',
        'quoteStatus': 'accepted',
        'quoteResponseStatus': 'accepted',
        'quoteAccepted': true,
        'timeAccepted': true,
        'acceptedProposedTime': true,
        'readyForCalendar': true,
        'quoteResponseId': 'quote-ready-detail-action-button',
        'agreedStartAt': '2026-06-14T10:00:00.000Z',
        'scheduledAt': '2026-06-14T10:00:00.000Z',
        'scheduledDate': '2026-06-14',
        'scheduledStartTime': '10:00',
        'estimatedDurationMinutes': 90,
        'requestExactPin': true,
        'exactPinShared': true,
        'hasExactPin': true,
        'exactPinLatitude': 51.5,
        'exactPinLongitude': -0.12,
      });

      await tester.pumpWidget(
        MaterialApp(home: JobDetailPage(reply: job, completed: false)),
      );
      await tester.pump();

      expect(find.text('Ready for Calendar'), findsWidgets);
      expect(find.text('Add job to Calendar'), findsOneWidget);
      expect(find.text('Set agreed time'), findsNothing);
    },
  );

  test(
    'accept quote and arrange another time still requires set agreed time',
    () {
      final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
        'jobId': 'arrange-another-time',
        'customerName': 'Morgan',
        'jobTitle': 'Storage run',
        'address': '20 River Lane',
        'phoneNumber': '07999999999',
        'status': 'quoteAccepted',
        'requestStatus': 'quote_accepted',
        'quoteAccepted': true,
        'quoteStatus': 'accepted',
        'quoteResponseStatus': 'accepted',
        'quoteResponseId': 'quote-arrange-another-time',
        'quoteTimingChoice': 'arrange_another_time',
        'schedulingStatus': 'awaiting_agreed_time',
        'exactPinShared': true,
        'hasExactPin': true,
        'exactPinLatitude': 51.51,
        'exactPinLongitude': -0.13,
      });

      expect(job.isQuoteAccepted, isTrue);
      expect(job.hasAgreedSchedulingTime, isFalse);
      expect(job.shouldPromptSetAgreedTime, isTrue);
      expect(job.shouldPromptAddToCalendar, isFalse);
      expect(job.isAwaitingAgreedTime, isTrue);
    },
  );

  test(
    'saved agreed time with ready_for_calendar status still shows ready state',
    () {
      final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
        'jobId': 'ready-for-calendar',
        'customerName': 'Morgan',
        'jobTitle': 'Storage run',
        'address': '20 River Lane',
        'phoneNumber': '07999999999',
        'status': 'quoteAccepted',
        'requestStatus': 'quote_accepted',
        'quoteAccepted': true,
        'quoteStatus': 'accepted',
        'quoteResponseStatus': 'accepted',
        'quoteResponseId': 'quote-ready-for-calendar',
        'quoteTimingChoice': 'arrange_another_time',
        'schedulingStatus': 'ready_for_calendar',
        'agreedDateTime': '2026-06-18T19:00:00.000Z',
        'scheduledDate': '2026-06-18',
        'scheduledStartTime': '19:00',
        'estimatedDurationMinutes': 90,
        'exactPinShared': true,
        'hasExactPin': true,
        'exactPinLatitude': 51.51,
        'exactPinLongitude': -0.13,
      });

      expect(job.quoteTimingChoice, 'arrange_another_time');
      expect(job.hasAgreedSchedulingTime, isTrue);
      expect(job.shouldPromptSetAgreedTime, isFalse);
      expect(job.shouldPromptAddToCalendar, isTrue);
      expect(job.requestStatusLabel, 'Ready for Calendar');
      expect(job.requestBadgeLabel, 'Ready for Calendar');
      expect(job.quoteUiStatus.secondaryChipLabel, 'Ready for Calendar');
    },
  );

  test(
    'accepted quote with agreed time and missing exact pin still exposes quote and skips set agreed time',
    () {
      final job = DriverCustomerReplyMockData.fromJson(<String, dynamic>{
        'jobId': 'awaiting-pin-with-agreed-time',
        'customerName': 'Jordan',
        'jobTitle': 'House move',
        'address': '30 Oak Street',
        'phoneNumber': '07010101010',
        'status': 'quoteAccepted',
        'requestId': 'request-awaiting-pin-with-agreed-time',
        'requestStatus': 'quote_accepted',
        'quoteAccepted': true,
        'quoteStatus': 'accepted',
        'quoteResponseStatus': 'accepted',
        'quoteResponseId': 'quote-123',
        'quoteResponseLink': 'https://vanmate.example/quote/quote-123',
        'quoteTimingChoice': 'arrange_another_time',
        'schedulingStatus': 'awaiting_agreed_time',
        'requiresExactPinAfterQuoteAccepted': true,
      });
      final request = VanJobRequestRecord.fromJson(<String, dynamic>{
        'requestId': 'request-awaiting-pin-with-agreed-time',
        'ownerUid': 'owner-1',
        'jobId': 'awaiting-pin-with-agreed-time',
        'linkedJobId': 'awaiting-pin-with-agreed-time',
        'status': 'quote_accepted',
        'createdAt': '2026-06-19T09:00:00.000Z',
        'updatedAt': '2026-06-19T09:30:00.000Z',
        'expiresAt': '2026-06-26T09:00:00.000Z',
        'publicJobTitle': 'House move',
        'publicCustomerName': 'Jordan',
        'publicAddressSummary': '30 Oak Street',
        'checklistItems': const <String>[],
        'customQuestions': const <String>[],
        'exactPinRequested': false,
        'requiresExactPinAfterQuoteAccepted': true,
        'quoteTimingChoice': 'agreed_time_saved',
        'schedulingStatus': 'time_agreed',
        'agreedDateTime': '2026-06-19T11:00:00.000Z',
        'agreedStartAt': '2026-06-19T11:00:00.000Z',
        'scheduledDate': '2026-06-19',
        'scheduledStartTime': '11:00',
      });

      expect(job.hasQuote, isTrue);
      expect(
        hasCanonicalAgreedSchedulingTimeForJob(job, request: request),
        isTrue,
      );
      expect(shouldPromptSetAgreedTimeForJob(job, request: request), isFalse);
      expect(shouldPromptAddToCalendarForJob(job, request: request), isFalse);

      final uiStatus = deriveVanQuoteUiStatus(
        hasRequest: true,
        hasReply: true,
        hasQuote: job.hasQuote,
        hasRequestBeenSent: true,
        isQuoteAccepted: true,
        isQuoteDeclined: false,
        isConfirmed: false,
        isScheduledInCalendar: false,
        isQuoteAwaitingCustomerResponse: false,
        hasAgreedTime: hasCanonicalAgreedSchedulingTimeForJob(
          job,
          request: request,
        ),
        needsAgreedTime: shouldPromptSetAgreedTimeForJob(job, request: request),
        requiresExactPin: job.requiresAnyExactPin,
        hasExactPin: job.exactPinSaved,
      );

      expect(uiStatus.statusLabel, 'Awaiting exact pin');
      expect(uiStatus.secondaryChipLabel, 'Awaiting exact pin');
    },
  );
}
