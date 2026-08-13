import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

DriverCustomerReplyMockData _draftJob({
  String jobId = 'quote-send-job',
  String requestType = 'quoteRequest',
  String customerJourneyType = 'quote',
}) {
  return DriverCustomerReplyMockData(
    jobId: jobId,
    requestId: 'request-$jobId',
    requestType: requestType,
    customerJourneyType: customerJourneyType,
    customerName: 'Customer',
    jobTitle: 'Celebration Cake',
    scheduledAt: null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: '',
    phoneNumber: '',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: 'draft',
    requestStatus: 'received',
    quoteStatus: 'draft',
    quoteResponseStatus: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DriverReplyMockState state;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    state = DriverReplyMockState.instance;
    state.debugResetStateForTest();
  });

  test(
    'successful public publish commits sent state and a usable quote link',
    () async {
      final job = _draftJob();
      final published = <DriverCustomerReplyMockData>[];
      final publishedPayloads = <Map<String, dynamic>>[];
      state.debugAddJobForTest(job, cloudBacked: false);
      state.debugSetPublicQuotePublisherForTest((job, extraData) async {
        published.add(job);
        publishedPayloads.add(extraData);
      });

      await state.setQuoteSent(
        true,
        jobId: job.jobId,
        amount: 125,
        publicQuoteData: const <String, dynamic>{
          'quotePublishKey': 'successful-publish',
        },
      );

      final saved = state.jobById(job.jobId)!;
      expect(published, hasLength(1));
      expect(published.single.currentQuoteId, job.jobId);
      expect(published.single.quoteResponseToken, isNotEmpty);
      expect(published.single.activeQuoteResponseLink, isNotEmpty);
      expect(publishedPayloads.single['quoteStatus'], 'sent');
      expect(saved.isQuoteSent, isTrue);
      expect(saved.isQuoteAwaitingCustomerResponse, isTrue);
      expect(saved.quoteStatus, 'sent');
      expect(saved.currentQuoteId, job.jobId);
      expect(saved.quoteResponseId, job.jobId);
      expect(
        saved.activeQuoteResponseLink,
        published.single.activeQuoteResponseLink,
      );
    },
  );

  test('failed public publish leaves the draft job entirely unsent', () async {
    final job = _draftJob();
    state.debugAddJobForTest(job, cloudBacked: false);
    state.debugSetPublicQuotePublisherForTest((_, _) async {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Public quote write denied.',
      );
    });

    await expectLater(
      state.setQuoteSent(true, jobId: job.jobId, amount: 125),
      throwsA(
        isA<FirebaseException>().having(
          (error) => error.code,
          'code',
          'permission-denied',
        ),
      ),
    );

    final unchanged = state.jobById(job.jobId)!;
    expect(unchanged.isQuoteSent, isFalse);
    expect(unchanged.isQuoteAwaitingCustomerResponse, isFalse);
    expect(unchanged.quoteStatus, 'draft');
    expect(unchanged.currentQuoteId, isEmpty);
    expect(unchanged.quoteResponseId, isEmpty);
    expect(unchanged.quoteResponseToken, isEmpty);
    expect(unchanged.quoteResponseLink, isEmpty);
    expect(unchanged.isQuoteOpenedForSending, isFalse);
  });

  test(
    'retry commits once only after the later successful public publish',
    () async {
      final job = _draftJob();
      var attempts = 0;
      final successfullyPublished = <DriverCustomerReplyMockData>[];
      state.debugAddJobForTest(job, cloudBacked: false);
      state.debugSetPublicQuotePublisherForTest((publishedJob, _) async {
        attempts += 1;
        if (attempts == 1) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Public quote write denied.',
          );
        }
        successfullyPublished.add(publishedJob);
      });

      await expectLater(
        state.setQuoteSent(true, jobId: job.jobId, amount: 125),
        throwsA(isA<FirebaseException>()),
      );
      expect(state.jobById(job.jobId)!.isQuoteSent, isFalse);

      await state.setQuoteSent(true, jobId: job.jobId, amount: 125);

      final saved = state.jobById(job.jobId)!;
      expect(attempts, 2);
      expect(successfullyPublished, hasLength(1));
      expect(successfullyPublished.single.currentQuoteId, job.jobId);
      expect(saved.isQuoteSent, isTrue);
      expect(saved.currentQuoteId, successfullyPublished.single.currentQuoteId);
    },
  );

  test(
    'Quote Request and Bakery Order Request share the public-first sequence',
    () async {
      for (final job in <DriverCustomerReplyMockData>[
        _draftJob(jobId: 'quote-request-job'),
        _draftJob(
          jobId: 'bakery-order-job',
          requestType: 'orderRequest',
          customerJourneyType: 'order',
        ),
      ]) {
        state.debugAddJobForTest(job, cloudBacked: false);
      }
      final published = <DriverCustomerReplyMockData>[];
      state.debugSetPublicQuotePublisherForTest((job, _) async {
        published.add(job);
      });

      await state.setQuoteSent(true, jobId: 'quote-request-job', amount: 50);
      await state.setQuoteSent(true, jobId: 'bakery-order-job', amount: 75);

      expect(published.map((job) => job.jobId), <String>[
        'quote-request-job',
        'bakery-order-job',
      ]);
      expect(state.jobById('quote-request-job')!.isQuoteSent, isTrue);
      final bakeryJob = state.jobById('bakery-order-job')!;
      expect(bakeryJob.isQuoteSent, isTrue);
      expect(bakeryJob.requestType, 'orderRequest');
      expect(bakeryJob.customerJourneyType, 'order');
    },
  );
}
