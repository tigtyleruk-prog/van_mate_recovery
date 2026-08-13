import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/services/van_public_quote_cloud_service.dart';
import 'package:van_mate_app/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;
  late FirebaseAuth auth;
  late VanPublicQuoteCloudService service;
  late String ownerUid;

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firestore = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;
    firestore.useFirestoreEmulator('127.0.0.1', 8080);
    await auth.useAuthEmulator('127.0.0.1', 9099);
    final credential = await auth.signInAnonymously();
    ownerUid = credential.user!.uid;
    service = VanPublicQuoteCloudService.forTesting(
      firestore: firestore,
      ensureCurrentUid: ({String source = ''}) async => ownerUid,
    );
  });

  testWidgets('real saveQuote publishes order delivery and collection', (
    tester,
  ) async {
    for (final end in <String>['businessDelivers', 'customerCollects']) {
      final jobId =
          'integration-order-$end-${DateTime.now().microsecondsSinceEpoch}';
      final job = _job(
        jobId: jobId,
        requestType: 'orderRequest',
        customerJourneyType: 'order',
        businessProfileId: 'profile-order',
        startHandover: 'customerDropsOff',
        endHandover: end,
      );
      await service.saveQuote(
        job: job,
        extraData: const <String, dynamic>{'quotePublishKey': 'publish-order'},
      );
      await _expectPublished(
        firestore,
        ownerUid,
        job,
        expectedProfile: 'profile-order',
        expectedQuoteVersion: 1,
        expectedPublishKey: 'publish-order',
      );
    }
  });

  testWidgets('real saveQuote preserves quote and Pre Order journeys', (
    tester,
  ) async {
    for (final values in <({String requestType, String journey})>[
      (requestType: 'quoteRequest', journey: 'quote'),
      (requestType: 'orderRequest', journey: 'preOrder'),
    ]) {
      final job = _job(
        jobId:
            'integration-${values.journey}-${DateTime.now().microsecondsSinceEpoch}',
        requestType: values.requestType,
        customerJourneyType: values.journey,
        businessProfileId: 'profile-${values.journey}',
      );
      await service.saveQuote(
        job: job,
        extraData: <String, dynamic>{
          'quotePublishKey': 'publish-${values.journey}',
        },
      );
      await _expectPublished(
        firestore,
        ownerUid,
        job,
        expectedProfile: 'profile-${values.journey}',
        expectedQuoteVersion: 1,
        expectedPublishKey: 'publish-${values.journey}',
      );
    }
  });

  testWidgets('real saveQuote creates and updates the van_jobs mirror', (
    tester,
  ) async {
    final missingJob = _job(
      jobId: 'integration-missing-job-${DateTime.now().microsecondsSinceEpoch}',
      businessProfileId: 'profile-fallback',
    );
    await service.saveQuote(
      job: missingJob,
      extraData: const <String, dynamic>{'quotePublishKey': 'fallback-key'},
    );
    await _expectPublished(
      firestore,
      ownerUid,
      missingJob,
      expectedProfile: 'profile-fallback',
      expectedQuoteVersion: 1,
      expectedPublishKey: 'fallback-key',
    );

    final existingJob = _job(
      jobId:
          'integration-existing-job-${DateTime.now().microsecondsSinceEpoch}',
      businessProfileId: '',
    );
    final jobRef = firestore
        .collection('users')
        .doc(ownerUid)
        .collection('van_jobs')
        .doc(existingJob.jobId);
    await jobRef.set(<String, dynamic>{
      'ownerUid': ownerUid,
      'jobId': existingJob.jobId,
      'requestId': existingJob.requestId,
      'requestType': 'quoteRequest',
      'customerJourneyType': 'quote',
      'businessProfileId': 'profile-existing',
      'quoteVersion': 4,
    });
    await service.saveQuote(
      job: existingJob,
      extraData: const <String, dynamic>{'quotePublishKey': 'existing-key'},
    );
    await _expectPublished(
      firestore,
      ownerUid,
      existingJob,
      expectedProfile: 'profile-existing',
      expectedQuoteVersion: 5,
      expectedPublishKey: 'existing-key',
    );
  });

  testWidgets('real saveQuote handles archive permissions and ownership', (
    tester,
  ) async {
    final archivedJob = _job(
      jobId: 'integration-archived-${DateTime.now().microsecondsSinceEpoch}',
      businessProfileId: 'profile-archive',
    );
    final archivedRef = firestore
        .collection('users')
        .doc(ownerUid)
        .collection('van_jobs')
        .doc(archivedJob.jobId);
    await archivedRef.set(<String, dynamic>{
      'ownerUid': ownerUid,
      'jobId': archivedJob.jobId,
      'archivedReadOnly': true,
    });
    await expectLater(
      service.saveQuote(job: archivedJob),
      throwsA(isA<FirebaseException>()),
    );

    final explicitlyWritableJob = archivedJob.copyWith(
      jobId: 'integration-writable-${DateTime.now().microsecondsSinceEpoch}',
    );
    await firestore
        .collection('users')
        .doc(ownerUid)
        .collection('van_jobs')
        .doc(explicitlyWritableJob.jobId)
        .set(<String, dynamic>{
          'ownerUid': ownerUid,
          'jobId': explicitlyWritableJob.jobId,
          'archivedReadOnly': false,
        });
    await service.saveQuote(job: explicitlyWritableJob);
    await _expectPublished(
      firestore,
      ownerUid,
      explicitlyWritableJob,
      expectedProfile: 'profile-archive',
      expectedQuoteVersion: 1,
      expectedPublishKey: '',
    );

    final openJob = archivedJob.copyWith(
      jobId: 'integration-open-${DateTime.now().microsecondsSinceEpoch}',
    );
    await service.saveQuote(job: openJob);
    final openRef = firestore
        .collection('users')
        .doc(ownerUid)
        .collection('van_jobs')
        .doc(openJob.jobId);
    expect((await openRef.get()).exists, isTrue);
  });

  testWidgets('real saveQuote retry and supersession remain stable', (
    tester,
  ) async {
    final first = _job(
      jobId: 'integration-retry-${DateTime.now().microsecondsSinceEpoch}',
      businessProfileId: 'profile-retry',
    );
    const publishKey = 'retry-key';
    await service.saveQuote(
      job: first,
      extraData: const <String, dynamic>{'quotePublishKey': publishKey},
    );
    final firstQuoteBeforeRetry = await firestore
        .collection('public_quote_responses')
        .doc(first.jobId)
        .get();
    final firstTokenId =
        firstQuoteBeforeRetry.data()!['quoteResponseToken'] as String;
    final firstLink =
        firstQuoteBeforeRetry.data()!['quoteResponseLink'] as String;
    await service.saveQuote(
      job: first,
      extraData: const <String, dynamic>{'quotePublishKey': publishKey},
    );
    final firstQuote = await firestore
        .collection('public_quote_responses')
        .doc(first.jobId)
        .get();
    expect(firstQuote.data()!['quoteVersion'], 1);
    expect(firstQuote.data()!['quoteResponseToken'], firstTokenId);
    expect(firstQuote.data()!['quoteResponseLink'], firstLink);
    expect(
      (await firestore
              .collection('public_quote_response_tokens')
              .doc(firstTokenId)
              .get())
          .data()!['isCurrent'],
      true,
    );

    final second = first.copyWith(
      currentQuoteId: '${first.jobId}-replacement',
      quoteResponseToken: '',
    );
    await service.saveQuote(
      job: second,
      extraData: const <String, dynamic>{
        'quotePublishKey': 'replacement-key',
        'supersedesQuoteId': '',
      },
    );
    final oldQuote = await firestore
        .collection('public_quote_responses')
        .doc(first.jobId)
        .get();
    final currentQuote = await firestore
        .collection('public_quote_responses')
        .doc(second.currentQuoteId)
        .get();
    expect(oldQuote.data()!['isCurrent'], false);
    expect(oldQuote.data()!['supersededByQuoteId'], second.currentQuoteId);
    expect(currentQuote.data()!['isCurrent'], true);
    expect(currentQuote.data()!['businessProfileId'], 'profile-retry');
  });

  testWidgets('real saveQuote rejects an unauthorized publishing user', (
    tester,
  ) async {
    final job = _job(
      jobId:
          'integration-unauthorized-${DateTime.now().microsecondsSinceEpoch}',
      businessProfileId: 'profile-unauthorized',
    );
    final unauthorizedService = VanPublicQuoteCloudService.forTesting(
      firestore: firestore,
      ensureCurrentUid: ({String source = ''}) async => 'unauthorized-user',
    );
    await expectLater(
      unauthorizedService.saveQuote(job: job),
      throwsA(isA<FirebaseException>()),
    );
  });
}

DriverCustomerReplyMockData _job({
  required String jobId,
  String requestType = 'orderRequest',
  String customerJourneyType = 'order',
  required String businessProfileId,
  String startHandover = 'customerDropsOff',
  String endHandover = 'customerCollects',
}) {
  return DriverCustomerReplyMockData(
    jobId: jobId,
    customerName: 'Integration Customer',
    jobTitle: 'Integration Quote',
    scheduledAt: null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: '1 Test Street',
    phoneNumber: '',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    businessProfileId: businessProfileId,
    requestId: '$jobId-request',
    requestType: requestType,
    customerJourneyType: customerJourneyType,
    startHandover: startHandover,
    endHandover: endHandover,
    quoteStatus: 'sent',
    quoteResponseStatus: 'sent',
    quoteSentAt: DateTime.now(),
    quoteAmount: 100,
  );
}

Future<void> _expectPublished(
  FirebaseFirestore firestore,
  String ownerUid,
  DriverCustomerReplyMockData job, {
  required String expectedProfile,
  required int expectedQuoteVersion,
  required String expectedPublishKey,
}) async {
  final quote = await firestore
      .collection('public_quote_responses')
      .doc(
        job.authoritativeCurrentQuoteId.isEmpty
            ? job.jobId
            : job.authoritativeCurrentQuoteId,
      )
      .get();
  expect(quote.exists, isTrue);
  final quoteData = quote.data()!;
  expect(quoteData['ownerUid'], ownerUid);
  expect(quoteData['jobId'], job.jobId);
  expect(quoteData['requestId'], job.requestId);
  expect(quoteData['requestType'], job.requestType);
  expect(quoteData['customerJourneyType'], job.customerJourneyType);
  expect(quoteData['businessProfileId'], expectedProfile);
  expect(quoteData['quoteVersion'], expectedQuoteVersion);
  expect(quoteData['quotePublishKey'], expectedPublishKey);
  expect(
    isCompleteVanQuoteResponseLink(quoteData['quoteResponseLink']),
    isTrue,
  );

  final token = await firestore
      .collection('public_quote_response_tokens')
      .doc(quoteData['quoteResponseToken'] as String)
      .get();
  expect(token.exists, isTrue);
  expect(token.data()!['ownerUid'], ownerUid);
  expect(token.data()!['jobId'], job.jobId);
  expect(token.data()!['requestId'], job.requestId);
  expect(token.data()!['businessProfileId'], expectedProfile);
  expect(token.data()!['currentQuoteId'], quote.id);
  expect(token.data()!['quoteResponseId'], quote.id);
  expect(token.data()!['quoteResponseLink'], quoteData['quoteResponseLink']);

  final mirror = await firestore
      .collection('users')
      .doc(ownerUid)
      .collection('van_jobs')
      .doc(job.jobId)
      .get();
  expect(mirror.exists, isTrue);
  final mirrorData = mirror.data()!;
  expect(mirrorData['ownerUid'], ownerUid);
  expect(mirrorData['jobId'], job.jobId);
  expect(mirrorData['requestId'], job.requestId);
  expect(mirrorData['requestType'], job.requestType);
  expect(mirrorData['customerJourneyType'], job.customerJourneyType);
  expect(mirrorData['businessProfileId'], expectedProfile);
  expect(mirrorData['currentQuoteId'], quote.id);
  expect(mirrorData['quoteResponseId'], quote.id);
  expect(mirrorData['quoteVersion'], expectedQuoteVersion);
  expect(mirrorData['quotePublishKey'], expectedPublishKey);
}
