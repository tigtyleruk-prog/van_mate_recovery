import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/pages/job_detail_page.dart';

void main() {
  test(
    'New Job sent then customer reply received shows create quote, not accepted',
    () {
      final job = _job(
        jobId: 'reply-no-real-quote',
        address: '',
        status: 'replyReceived',
        requestStatus: 'quote_accepted',
        replyReceivedAt: DateTime.parse('2026-06-19T09:00:00.000Z'),
        quoteAccepted: true,
        quoteStatus: 'accepted',
        quoteResponseStatus: 'accepted',
      );

      expect(job.hasCustomerReply, isTrue);
      expect(job.hasQuote, isFalse);
      expect(job.isQuoteAccepted, isFalse);
      expect(job.canCreateQuoteFromCustomerReply, isTrue);
      expect(job.quoteUiStatus.statusLabel, 'Reply received');
      expect(job.quoteUiStatus.nextActionText, contains('send a quote'));

      final actionState = deriveVanJobActionState(job);
      expect(actionState.canCreateQuote, isTrue);
      expect(actionState.canViewQuote, isFalse);
      expect(actionState.isQuoteAccepted, isFalse);
      expect(actionState.canAddToCalendar, isFalse);
      expect(actionState.canNavigate, isFalse);
      expect(actionState.canCallCustomer, isTrue);
      expect(actionState.canTextCustomer, isTrue);
    },
  );

  test(
    'quote created and sent awaits quote response and exposes view quote',
    () {
      final job = _quotedJob(
        jobId: 'sent-real-quote',
        status: 'quoteSent',
        requestStatus: 'quoted',
        quoteStatus: 'sent',
        quoteResponseStatus: 'pending',
      );

      expect(job.hasQuote, isTrue);
      expect(job.isQuoteAwaitingCustomerResponse, isTrue);
      expect(job.quoteUiStatus.statusLabel, 'Awaiting quote response');
      expect(job.quoteUiStatus.secondaryChipLabel, 'Awaiting quote response');
      expect(job.canCreateQuoteFromCustomerReply, isFalse);

      final actionState = deriveVanJobActionState(job);
      expect(actionState.canViewQuote, isTrue);
      expect(actionState.canCreateQuote, isFalse);
      expect(actionState.canAddToCalendar, isFalse);
    },
  );

  test(
    'accepted quote with required exact pin missing blocks add to calendar',
    () {
      final job = _acceptedQuoteJob(
        jobId: 'accepted-missing-pin',
        requiresExactPinAfterQuoteAccepted: true,
        agreedDateTime: DateTime.parse('2026-06-20T10:00:00.000Z'),
        scheduledDate: '2026-06-20',
        scheduledStartTime: '10:00',
        schedulingStatus: 'time_agreed',
      );

      expect(job.hasQuote, isTrue);
      expect(job.isQuoteAccepted, isTrue);
      expect(job.isAwaitingRequiredExactPin, isTrue);
      expect(job.quoteUiStatus.statusLabel, 'Awaiting exact pin');
      expect(job.quoteUiStatus.secondaryChipLabel, 'Awaiting exact pin');
      expect(shouldPromptSetAgreedTimeForJob(job), isFalse);
      expect(shouldPromptAddToCalendarForJob(job), isFalse);

      final actionState = deriveVanJobActionState(job);
      expect(actionState.canViewQuote, isTrue);
      expect(actionState.isAwaitingExactPin, isTrue);
      expect(actionState.canAddToCalendar, isFalse);
    },
  );

  test('accepted quote with agreed time and exact pin can add to calendar', () {
    final job = _acceptedQuoteJob(
      jobId: 'accepted-ready-calendar',
      requestExactPin: true,
      requiresExactPinAfterQuoteAccepted: true,
      exactPinShared: true,
      hasExactPin: true,
      exactPinLatitude: 51.501,
      exactPinLongitude: -0.141,
      agreedDateTime: DateTime.parse('2026-06-20T10:00:00.000Z'),
      scheduledDate: '2026-06-20',
      scheduledStartTime: '10:00',
      schedulingStatus: 'time_agreed',
    );

    expect(job.hasQuote, isTrue);
    expect(job.isQuoteAccepted, isTrue);
    expect(job.isAwaitingRequiredExactPin, isFalse);
    expect(shouldPromptSetAgreedTimeForJob(job), isFalse);
    expect(shouldPromptAddToCalendarForJob(job), isTrue);
    expect(job.isReadyToAddToCalendar, isTrue);
    expect(job.quoteUiStatus.statusLabel, 'Ready for Calendar');

    final actionState = deriveVanJobActionState(job);
    expect(actionState.canViewQuote, isTrue);
    expect(actionState.canAddToCalendar, isTrue);
    expect(actionState.canNavigate, isTrue);
  });

  test(
    'accepted quote with exact pin but unconfirmed time still needs arranging',
    () {
      final job = _acceptedQuoteJob(
        jobId: 'accepted-pin-no-time',
        requestExactPin: true,
        requiresExactPinAfterQuoteAccepted: true,
        exactPinShared: true,
        hasExactPin: true,
        exactPinLatitude: 51.501,
        exactPinLongitude: -0.141,
        scheduledDate: '2026-06-20',
        scheduledStartTime: '10:00',
      );

      expect(job.isQuoteAccepted, isTrue);
      expect(job.exactPinSaved, isTrue);
      expect(job.hasAgreedSchedulingTime, isFalse);
      expect(job.quoteUiStatus.primaryChipLabel, 'Quote accepted');
      expect(job.quoteUiStatus.showExactPinReceivedChip, isTrue);
      expect(job.quoteUiStatus.exactPinChipLabel, 'Exact pin received');
      expect(job.quoteUiStatus.statusLabel, 'Time needs arranging');
      expect(job.quoteUiStatus.secondaryChipLabel, 'Time needs arranging');
      expect(job.quoteUiStatus.summary, contains('Time still needs arranging'));
      expect(job.shouldPromptSetAgreedTime, isTrue);
      expect(job.shouldPromptAddToCalendar, isFalse);
      expect(job.isReadyToAddToCalendar, isFalse);

      final actionState = deriveVanJobActionState(job);
      expect(actionState.isQuoteAccepted, isTrue);
      expect(actionState.canViewQuote, isTrue);
      expect(actionState.canSetAgreedTime, isTrue);
      expect(actionState.canAddToCalendar, isFalse);
      expect(actionState.canNavigate, isTrue);
    },
  );

  test(
    'accepted quote with accepted proposed time and exact pin is calendar ready',
    () {
      final job =
          _acceptedQuoteJob(
            jobId: 'accepted-proposed-ready',
            requestExactPin: true,
            requiresExactPinAfterQuoteAccepted: true,
            exactPinShared: true,
            hasExactPin: true,
            exactPinLatitude: 51.501,
            exactPinLongitude: -0.141,
          ).copyWith(
            quoteTimingChoice: 'accepted_proposed_time',
            schedulingStatus: 'accepted_time',
            proposedDate: '2026-06-20',
            proposedStartTime: '10:00',
          );

      expect(job.hasAgreedSchedulingTime, isTrue);
      expect(job.quoteUiStatus.statusLabel, 'Ready for Calendar');
      expect(job.quoteUiStatus.secondaryChipLabel, 'Ready for Calendar');
      expect(job.shouldPromptSetAgreedTime, isFalse);
      expect(job.shouldPromptAddToCalendar, isTrue);
      expect(job.isReadyToAddToCalendar, isTrue);

      final actionState = deriveVanJobActionState(job);
      expect(actionState.canAddToCalendar, isTrue);
      expect(
        effectiveAgreedSchedulingTimeForJob(job),
        DateTime.parse('2026-06-20T10:00:00.000'),
      );
    },
  );

  test(
    'stale sent quote cannot downgrade accepted ready-for-calendar state',
    () {
      final accepted =
          _acceptedQuoteJob(
            jobId: 'accepted-stale-sent-regression',
            requestExactPin: true,
            requiresExactPinAfterQuoteAccepted: true,
            exactPinShared: true,
            hasExactPin: true,
            exactPinLatitude: 51.501,
            exactPinLongitude: -0.141,
          ).copyWith(
            quoteTimingChoice: 'accepted_proposed_time',
            schedulingStatus: 'accepted_time',
            proposedDate: '2026-06-20',
            proposedStartTime: '10:00',
            updatedAt: DateTime.parse('2026-06-19T09:35:00.000Z'),
          );
      final staleSent = _quotedJob(
        jobId: accepted.jobId,
        status: 'quoteSent',
        requestStatus: 'quoted',
        quoteStatus: 'sent',
        quoteResponseStatus: 'pending',
      ).copyWith(updatedAt: DateTime.parse('2026-06-19T09:40:00.000Z'));

      DriverReplyMockState.instance.debugResetStateForTest();
      try {
        DriverReplyMockState.instance.debugAddJobForTest(accepted);
        DriverReplyMockState.instance.debugMergeCloudJobsForTest(
          <DriverCustomerReplyMockData>[staleSent],
          sourceLabel: 'public_quote_responses',
        );

        final incomingCardJob = DriverReplyMockState.instance.jobById(
          accepted.jobId,
        )!;
        final detailJob = resolveVanQuoteWorkflowReply(accepted);

        for (final job in <DriverCustomerReplyMockData>[
          incomingCardJob,
          detailJob,
        ]) {
          expect(job.isQuoteAccepted, isTrue);
          expect(job.isQuoteAwaitingCustomerResponse, isFalse);
          expect(job.quoteUiStatus.primaryChipLabel, 'Quote accepted');
          expect(job.quoteUiStatus.secondaryChipLabel, 'Ready for Calendar');
          expect(job.quoteUiStatus.showExactPinReceivedChip, isTrue);
          expect(job.requestStatusLabel, 'Ready for Calendar');
        }
      } finally {
        DriverReplyMockState.instance.debugResetStateForTest();
      }
    },
  );

  test('original requested time alone does not count as agreed time', () {
    final job = _acceptedQuoteJob(
      jobId: 'accepted-original-time-only',
      requestExactPin: true,
      requiresExactPinAfterQuoteAccepted: true,
      exactPinShared: true,
      hasExactPin: true,
      exactPinLatitude: 51.501,
      exactPinLongitude: -0.141,
      scheduledDate: '2026-06-20',
      scheduledStartTime: '10:00',
    );

    expect(job.scheduledAtOrParsed, DateTime.parse('2026-06-20T10:00:00.000'));
    expect(effectiveAgreedSchedulingTimeForJob(job), isNull);
    expect(hasCanonicalAgreedSchedulingTimeForJob(job), isFalse);
    expect(shouldPromptSetAgreedTimeForJob(job), isTrue);
    expect(shouldPromptAddToCalendarForJob(job), isFalse);
  });

  test(
    'request scheduled fields without time acceptance still do not unlock calendar',
    () {
      final job = _acceptedQuoteJob(
        jobId: 'accepted-request-fallback-no-time',
        requestExactPin: true,
        requiresExactPinAfterQuoteAccepted: true,
        exactPinShared: true,
        hasExactPin: true,
        exactPinLatitude: 51.501,
        exactPinLongitude: -0.141,
      );
      final request = VanJobRequestRecord.fromJson(<String, dynamic>{
        'requestId': 'request-accepted-request-fallback-no-time',
        'ownerUid': 'owner-1',
        'jobId': job.jobId,
        'linkedJobId': job.jobId,
        'status': 'quote_accepted',
        'createdAt': '2026-06-19T08:00:00.000Z',
        'updatedAt': '2026-06-19T09:35:00.000Z',
        'expiresAt': '2026-06-26T08:00:00.000Z',
        'publicJobTitle': 'House move',
        'publicCustomerName': 'Mr Smith',
        'publicAddressSummary': '30 Oak Street',
        'publicPhoneNumber': '07010101010',
        'checklistItems': const <String>[],
        'customQuestions': const <String>[],
        'exactPinRequested': true,
        'requiresExactPinAfterQuoteAccepted': true,
        'scheduledAt': '2026-06-20T10:00:00.000Z',
        'scheduledDate': '2026-06-20',
        'scheduledStartTime': '10:00',
        'calendarStatus': 'unscheduled',
        'quoteTimingChoice': 'arrange_another_time',
        'schedulingStatus': 'awaiting_agreed_time',
      });

      expect(
        effectiveAgreedSchedulingTimeForJob(job, request: request),
        isNull,
      );
      expect(
        hasCanonicalAgreedSchedulingTimeForJob(job, request: request),
        isFalse,
      );
      expect(shouldPromptSetAgreedTimeForJob(job, request: request), isTrue);
      expect(shouldPromptAddToCalendarForJob(job, request: request), isFalse);

      final actionState = deriveVanJobActionState(job, request: request);
      expect(actionState.canSetAgreedTime, isTrue);
      expect(actionState.canAddToCalendar, isFalse);
    },
  );

  test('existing scheduled calendar job remains added to calendar', () {
    final job = _acceptedQuoteJob(
      jobId: 'accepted-already-scheduled',
      requestExactPin: true,
      requiresExactPinAfterQuoteAccepted: true,
      exactPinShared: true,
      hasExactPin: true,
      exactPinLatitude: 51.501,
      exactPinLongitude: -0.141,
      scheduledDate: '2026-06-20',
      scheduledStartTime: '10:00',
      calendarStatus: 'scheduled',
    );

    expect(job.isScheduledInCalendarState, isTrue);
    expect(job.hasAgreedSchedulingTime, isTrue);
    expect(job.quoteUiStatus.statusLabel, 'Added to Calendar');
    expect(job.requestStatusLabel, 'Added to Calendar');
    expect(shouldPromptAddToCalendarForJob(job), isFalse);
    expect(effectiveAgreedSchedulingTimeForJob(job), isNotNull);
  });

  test('no usable location hides navigate even when quote is accepted', () {
    final job = _acceptedQuoteJob(
      jobId: 'accepted-no-location',
      address: '',
      agreedDateTime: DateTime.parse('2026-06-20T10:00:00.000Z'),
      scheduledDate: '2026-06-20',
      scheduledStartTime: '10:00',
      schedulingStatus: 'time_agreed',
    );

    final actionState = deriveVanJobActionState(job);

    expect(actionState.isQuoteAccepted, isTrue);
    expect(actionState.canAddToCalendar, isTrue);
    expect(actionState.canNavigate, isFalse);
  });

  test('completed and paid job never appears in today or pending requests', () {
    final completed = _acceptedQuoteJob(
      jobId: 'completed-paid-job',
      status: 'completed',
      requestStatus: 'completed',
      calendarStatus: 'completed',
      completedAt: DateTime.parse('2026-06-20T12:00:00.000Z'),
      agreedDateTime: DateTime.parse('2026-06-20T10:00:00.000Z'),
      scheduledDate: '2026-06-20',
      scheduledStartTime: '10:00',
      schedulingStatus: 'scheduled',
      exactPinShared: true,
      hasExactPin: true,
      exactPinLatitude: 51.501,
      exactPinLongitude: -0.141,
    );

    expect(completed.isCompletedJob, isTrue);
    expect(completed.isPendingCustomerRequest, isFalse);
    expect(
      debugBucketDecisionForJob(completed).bucket,
      VanJobBucket.completedJob,
    );
  });

  test('Business Hub booking-link quote flow still awaits quote response', () {
    final request = VanJobRequestRecord(
      requestId: 'booking-link-request',
      ownerUid: 'owner-1',
      jobId: 'booking-link-job',
      linkedJobId: 'booking-link-job',
      status: 'reply_received',
      createdAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
      updatedAt: DateTime.parse('2026-06-19T09:00:00.000Z'),
      expiresAt: DateTime.parse('2026-06-26T08:00:00.000Z'),
      publicJobTitle: 'Sofa move',
      publicCustomerName: 'Morgan',
      publicAddressSummary: '20 River Lane',
      publicPhoneNumber: '07123456789',
      source: 'booking_link',
      sourceLabel: 'Booking Link',
      selectedServiceName: 'Sofa move',
      checklistItems: const <String>[],
      customQuestions: const <String>[],
      exactPinRequested: false,
      replyReceivedAt: DateTime.parse('2026-06-19T09:00:00.000Z'),
    );
    final job = _quotedJob(
      jobId: request.jobId,
      status: 'quoteSent',
      requestStatus: 'quoted',
      replyReceivedAt: request.replyReceivedAt,
    );

    expect(request.source, 'booking_link');
    expect(request.selectedServiceName, 'Sofa move');
    expect(job.hasCustomerReply, isTrue);
    expect(job.hasQuote, isTrue);
    expect(job.isQuoteAwaitingCustomerResponse, isTrue);
    expect(job.quoteUiStatus.statusLabel, 'Awaiting quote response');
    expect(shouldPromptSetAgreedTimeForJob(job, request: request), isFalse);
    expect(shouldPromptAddToCalendarForJob(job, request: request), isFalse);
  });

  testWidgets(
    'pressing Create quote from detail opens Create Quote with reply answers',
    (tester) async {
      final job = _jobWithAnswers(jobId: 'detail-create-quote-route');

      await tester.pumpWidget(
        MaterialApp(home: JobDetailPage(reply: job, completed: false)),
      );
      await tester.pumpAndSettle();

      final createQuoteButton = find.byKey(
        const ValueKey('job_detail_bottom_create_quote_button'),
      );
      expect(createQuoteButton, findsOneWidget);
      expect(find.text('View quote'), findsNothing);
      expect(find.text('Quote accepted'), findsNothing);
      expect(find.text('Add to calendar'), findsNothing);
      expect(find.text('Add job to Calendar'), findsNothing);
      expect(find.text('Navigate'), findsNothing);
      expect(find.text('Call customer'), findsOneWidget);
      expect(find.text('Text customer'), findsOneWidget);
      expect(
        find.descendant(
          of: find.text('Actions'),
          matching: find.text('Create quote'),
        ),
        findsNothing,
      );

      final customerReplyTitle = find.text('Customer reply');
      final customerRequestTitle = find.text('Customer request');
      expect(
        tester.getTopLeft(createQuoteButton).dy,
        greaterThan(tester.getTopLeft(customerReplyTitle).dy),
      );
      expect(
        tester.getTopLeft(createQuoteButton).dy,
        greaterThan(tester.getTopLeft(customerRequestTitle).dy),
      );

      await tester.ensureVisible(createQuoteButton);
      await tester.tap(createQuoteButton);
      await tester.pumpAndSettle();

      expect(find.text('Create quote'), findsWidgets);
      expect(find.text('Job info'), findsOneWidget);
      expect(find.text('Parking'), findsOneWidget);
      expect(find.textContaining('Driveway'), findsWidgets);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.textContaining('Two wardrobes'), findsWidgets);
    },
  );

  testWidgets(
    'accepted quote detail with exact pin and unconfirmed time hides calendar readiness',
    (tester) async {
      final job = _acceptedQuoteJob(
        jobId: 'detail-accepted-pin-no-time',
        requestExactPin: true,
        requiresExactPinAfterQuoteAccepted: true,
        exactPinShared: true,
        hasExactPin: true,
        exactPinLatitude: 51.501,
        exactPinLongitude: -0.141,
        scheduledDate: '2026-06-20',
        scheduledStartTime: '10:00',
      );

      await tester.pumpWidget(
        MaterialApp(home: JobDetailPage(reply: job, completed: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quote accepted'), findsWidgets);
      expect(find.text('Exact pin received'), findsWidgets);
      expect(find.text('Time needs arranging'), findsWidgets);
      expect(find.text('Ready for Calendar'), findsNothing);
      expect(find.text('Time agreed'), findsNothing);
      expect(find.text('Add job to Calendar'), findsNothing);
      expect(find.text('View quote'), findsWidgets);
    },
  );

  testWidgets(
    'pressing Create quote from customer reply page opens Create Quote with reply answers',
    (tester) async {
      final job = _jobWithAnswers(jobId: 'reply-page-create-quote-route');

      await tester.pumpWidget(
        MaterialApp(home: DriverCustomerReplyPage(reply: job)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create quote'), findsOneWidget);
      expect(find.text('View quote'), findsNothing);
      expect(find.text('Quote accepted'), findsNothing);
      expect(find.text('Add to calendar'), findsNothing);
      expect(find.text('Call customer'), findsOneWidget);
      expect(find.text('Text customer'), findsOneWidget);

      final createQuoteButton = find.text('Create quote');
      await tester.ensureVisible(createQuoteButton);
      await tester.tap(createQuoteButton);
      await tester.pumpAndSettle();

      expect(find.text('Create quote'), findsWidgets);
      expect(find.text('Job info'), findsOneWidget);
      expect(find.text('Parking'), findsOneWidget);
      expect(find.textContaining('Driveway'), findsWidgets);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.textContaining('Two wardrobes'), findsWidgets);
    },
  );

  testWidgets(
    'pressing Create quote from pending-card route opens same quote flow',
    (tester) async {
      final job = _jobWithAnswers(jobId: 'pending-card-create-quote-route');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => openVanQuoteWorkflowForJob(context, job),
                child: const Text('Create quote'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create quote'));
      await tester.pumpAndSettle();

      expect(find.text('Create quote'), findsWidgets);
      expect(find.text('Job info'), findsOneWidget);
      expect(find.text('Parking'), findsOneWidget);
      expect(find.textContaining('Driveway'), findsWidgets);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.textContaining('Two wardrobes'), findsWidgets);
    },
  );
}

DriverCustomerReplyMockData _job({
  required String jobId,
  String status = 'replyReceived',
  String requestStatus = 'reply_received',
  DateTime? replyReceivedAt,
  DateTime? quoteSavedAt,
  DateTime? quoteSentAt,
  DateTime? quoteOpenedAt,
  DateTime? quoteAcceptedAt,
  DateTime? quoteRespondedAt,
  String quoteResponseId = '',
  String quoteResponseToken = '',
  String quoteResponseLink = '',
  String quoteStatus = '',
  String quoteResponseStatus = '',
  bool quoteAccepted = false,
  bool quoteDeclined = false,
  String address = '30 Oak Street',
  String postcode = '',
  bool requestExactPin = false,
  bool requiresExactPinAfterQuoteAccepted = false,
  bool exactPinShared = false,
  bool hasExactPin = false,
  double? exactPinLatitude,
  double? exactPinLongitude,
  DateTime? agreedDateTime,
  String scheduledDate = '',
  String scheduledStartTime = '',
  String schedulingStatus = '',
  String calendarStatus = 'unscheduled',
  DateTime? completedAt,
  List<DriverChecklistResponse> checklistResponses =
      const <DriverChecklistResponse>[],
  List<DriverCustomQuestionResponse> customQuestionResponses =
      const <DriverCustomQuestionResponse>[],
  String additionalNotes = 'Customer replied with the moving details.',
}) {
  return DriverCustomerReplyMockData(
    jobId: jobId,
    customerName: 'Mr Smith',
    jobTitle: 'House move',
    scheduledAt: null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: address,
    phoneNumber: '07010101010',
    postcode: postcode,
    exactPinShared: exactPinShared,
    hasExactPin: hasExactPin,
    checklistResponses: checklistResponses,
    customQuestionResponses: customQuestionResponses,
    additionalNotes: additionalNotes,
    requestId: 'request-$jobId',
    requestStatus: requestStatus,
    requestSentAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    replyReceivedAt: replyReceivedAt,
    status: status,
    quoteSavedAt: quoteSavedAt,
    quoteSentAt: quoteSentAt,
    quoteOpenedAt: quoteOpenedAt,
    quoteAcceptedAt: quoteAcceptedAt,
    quoteRespondedAt: quoteRespondedAt,
    quoteResponseId: quoteResponseId,
    quoteResponseToken: quoteResponseToken,
    quoteResponseLink: quoteResponseLink,
    quoteStatus: quoteStatus,
    quoteResponseStatus: quoteResponseStatus,
    quoteAccepted: quoteAccepted,
    quoteDeclined: quoteDeclined,
    quoteAmount: quoteSavedAt == null ? null : 120,
    requestExactPin: requestExactPin,
    requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
    exactPinLatitude: exactPinLatitude,
    exactPinLongitude: exactPinLongitude,
    agreedDateTime: agreedDateTime,
    scheduledDate: scheduledDate,
    scheduledStartTime: scheduledStartTime,
    schedulingStatus: schedulingStatus,
    calendarStatus: calendarStatus,
    completedAt: completedAt,
  );
}

DriverCustomerReplyMockData _jobWithAnswers({required String jobId}) {
  return _job(
    jobId: jobId,
    address: '',
    status: 'replyReceived',
    requestStatus: 'reply_received',
    replyReceivedAt: DateTime.parse('2026-06-19T09:00:00.000Z'),
    checklistResponses: const <DriverChecklistResponse>[
      DriverChecklistResponse(
        question: 'Parking available?',
        answer: 'Driveway parking',
        note: 'Use the side entrance.',
      ),
    ],
    customQuestionResponses: const <DriverCustomQuestionResponse>[
      DriverCustomQuestionResponse(
        question: 'Any large items?',
        answer: 'Two wardrobes',
      ),
    ],
  );
}

DriverCustomerReplyMockData _quotedJob({
  required String jobId,
  String status = 'quoteSent',
  String requestStatus = 'quoted',
  String quoteStatus = 'sent',
  String quoteResponseStatus = 'pending',
  DateTime? replyReceivedAt,
  String address = '30 Oak Street',
}) {
  return _job(
    jobId: jobId,
    address: address,
    status: status,
    requestStatus: requestStatus,
    replyReceivedAt:
        replyReceivedAt ?? DateTime.parse('2026-06-19T09:00:00.000Z'),
    quoteSavedAt: DateTime.parse('2026-06-19T09:15:00.000Z'),
    quoteSentAt: DateTime.parse('2026-06-19T09:20:00.000Z'),
    quoteResponseId: 'quote-$jobId',
    quoteResponseToken: 'token-$jobId',
    quoteResponseLink: 'https://vanmate.example/quote/token-$jobId',
    quoteStatus: quoteStatus,
    quoteResponseStatus: quoteResponseStatus,
  );
}

DriverCustomerReplyMockData _acceptedQuoteJob({
  required String jobId,
  String status = 'quoteAccepted',
  String requestStatus = 'quote_accepted',
  bool requestExactPin = false,
  bool requiresExactPinAfterQuoteAccepted = false,
  bool exactPinShared = false,
  bool hasExactPin = false,
  double? exactPinLatitude,
  double? exactPinLongitude,
  String address = '30 Oak Street',
  DateTime? agreedDateTime,
  String scheduledDate = '',
  String scheduledStartTime = '',
  String schedulingStatus = '',
  String calendarStatus = 'unscheduled',
  DateTime? completedAt,
}) {
  return _job(
    jobId: jobId,
    address: address,
    status: status,
    requestStatus: requestStatus,
    replyReceivedAt: DateTime.parse('2026-06-19T09:00:00.000Z'),
    quoteSavedAt: DateTime.parse('2026-06-19T09:15:00.000Z'),
    quoteSentAt: DateTime.parse('2026-06-19T09:20:00.000Z'),
    quoteAcceptedAt: DateTime.parse('2026-06-19T09:35:00.000Z'),
    quoteRespondedAt: DateTime.parse('2026-06-19T09:35:00.000Z'),
    quoteResponseId: 'quote-$jobId',
    quoteResponseToken: 'token-$jobId',
    quoteResponseLink: 'https://vanmate.example/quote/token-$jobId',
    quoteStatus: 'accepted',
    quoteResponseStatus: 'accepted',
    quoteAccepted: true,
    requestExactPin: requestExactPin,
    requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
    exactPinShared: exactPinShared,
    hasExactPin: hasExactPin,
    exactPinLatitude: exactPinLatitude,
    exactPinLongitude: exactPinLongitude,
    agreedDateTime: agreedDateTime,
    scheduledDate: scheduledDate,
    scheduledStartTime: scheduledStartTime,
    schedulingStatus: schedulingStatus,
    calendarStatus: calendarStatus,
    completedAt: completedAt,
  );
}
