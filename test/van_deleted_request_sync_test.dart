import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_draft.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_history_entry.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_draft.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final state = DriverReplyMockState.instance;

  setUp(state.debugResetStateForTest);
  tearDown(state.debugResetStateForTest);

  test('deleted pending request is excluded from active lists', () {
    final job = _pendingJob(jobId: 'pending-delete-job');
    final request = _requestFor(job);

    state.debugAddJobForTest(job);
    state.debugAddRequestForTest(request);
    expect(state.pendingJobs.map((item) => item.jobId), contains(job.jobId));

    state.debugAddDeletedRequestKeysForTest(
      state.deletedKeyAliasesForJob(job, request: request),
    );

    expect(
      state.pendingJobs.map((item) => item.jobId),
      isNot(contains(job.jobId)),
    );
    expect(
      state.todayJobs.map((item) => item.jobId),
      isNot(contains(job.jobId)),
    );
    expect(
      state.scheduledJobs.map((item) => item.jobId),
      isNot(contains(job.jobId)),
    );
  });

  test('deleted request does not return after Firebase or mock reload', () {
    final staleJob = _pendingJob(jobId: 'stale-cloud-job');
    final staleRequest = _requestFor(staleJob);

    state.debugAddDeletedRequestKeysForTest(
      state.deletedKeyAliasesForJob(staleJob, request: staleRequest),
    );

    state.debugMergeCloudJobsForTest(<DriverCustomerReplyMockData>[staleJob]);
    state.debugMergeCloudRequestsForTest(<VanJobRequestRecord>[staleRequest]);

    expect(
      state.debugAllLoadedJobs().map((item) => item.jobId),
      isNot(contains(staleJob.jobId)),
    );
    expect(state.requestForId(staleRequest.requestId), isNull);
    expect(
      state.pendingJobs.map((item) => item.jobId),
      isNot(contains(staleJob.jobId)),
    );
  });

  test('archived or deleted completed job remains out of active lists', () {
    final deletedCompleted = _completedJob(
      jobId: 'deleted-completed-job',
      deleted: true,
      archived: true,
    );

    state.debugAddJobForTest(deletedCompleted);

    expect(
      state.pendingJobs.map((item) => item.jobId),
      isNot(contains(deletedCompleted.jobId)),
    );
    expect(
      state.todayJobs.map((item) => item.jobId),
      isNot(contains(deletedCompleted.jobId)),
    );
    expect(
      state.scheduledJobs.map((item) => item.jobId),
      isNot(contains(deletedCompleted.jobId)),
    );
  });

  test('pending delete keeps customer history and invoices intact', () {
    final pending = _pendingJob(jobId: 'pending-delete-with-invoice');
    final request = _requestFor(pending);
    final completed = _completedJob(jobId: 'completed-history-job');

    state.debugAddJobForTest(pending);
    state.debugAddRequestForTest(request);
    state.debugAddJobForTest(completed);
    state.debugAddInvoiceHistoryForTest(_invoiceForJob(pending.jobId));

    state.debugAddDeletedRequestKeysForTest(
      state.deletedKeyAliasesForJob(pending, request: request),
    );

    expect(
      state.pendingJobs.map((item) => item.jobId),
      isNot(contains(pending.jobId)),
    );
    expect(
      state.completedJobs.map((item) => item.jobId),
      contains(completed.jobId),
    );
    expect(state.invoiceHistoryEntryForJob(pending.jobId), isNotNull);
    expect(
      state.savedInvoiceHistory.map((entry) => entry.jobKey),
      contains(pending.jobId),
    );
  });

  test('debug-created records are marked as test data going forward', () {
    final job = state.upsertDraftJob(_draft(jobId: 'debug-test-draft'));
    final request = state.debugBuildRequestRecordForJobForTest(job);
    final hydratedJob = state.debugBuildReplyFromRequestForTest(request);

    expect(job.isTestData, isTrue);
    expect(job.testMode, isTrue);
    expect(request.isTestData, isTrue);
    expect(request.testMode, isTrue);
    expect(hydratedJob.isMarkedTestData, isTrue);
  });

  test(
    'clear test requests hides test pending records but keeps real jobs',
    () async {
      final testPending = _pendingJob(jobId: 'cleanup-test-pending');
      final realPending = _pendingJob(
        jobId: 'cleanup-real-pending',
        customerName: 'Alice Jones',
        jobTitle: 'Piano move',
        isTestData: false,
        testMode: false,
      );
      final completed = _completedJob(jobId: 'cleanup-real-history');

      state.debugAddJobForTest(testPending);
      state.debugAddRequestForTest(_requestFor(testPending));
      state.debugAddJobForTest(realPending);
      state.debugAddRequestForTest(_requestFor(realPending));
      state.debugAddJobForTest(completed);
      state.debugAddInvoiceHistoryForTest(_invoiceForJob(completed.jobId));

      final result = await state.debugClearTestData(
        scope: VanMateTestCleanupScope.pendingRequests,
        syncCloud: false,
      );

      expect(result.clearedJobs, greaterThanOrEqualTo(1));
      expect(
        state.pendingJobs.map((item) => item.jobId),
        isNot(contains(testPending.jobId)),
      );
      expect(
        state.pendingJobs.map((item) => item.jobId),
        contains(realPending.jobId),
      );
      expect(
        state.completedJobs.map((item) => item.jobId),
        contains(completed.jobId),
      );
      expect(state.invoiceHistoryEntryForJob(completed.jobId), isNotNull);
    },
  );

  test(
    'clear all test jobs archives test history without deleting invoices',
    () async {
      final testCompleted = _completedJob(
        jobId: 'cleanup-test-completed',
        isTestData: true,
        testMode: true,
      );
      final realCompleted = _completedJob(
        jobId: 'cleanup-real-completed',
        customerName: 'Jordan Smith',
        jobTitle: 'Office move',
        isTestData: false,
        testMode: false,
      );

      state.debugAddJobForTest(testCompleted);
      state.debugAddJobForTest(realCompleted);
      state.debugAddInvoiceHistoryForTest(_invoiceForJob(realCompleted.jobId));

      final result = await state.debugClearTestData(
        scope: VanMateTestCleanupScope.allJobs,
        syncCloud: false,
      );

      expect(result.clearedJobs, greaterThanOrEqualTo(1));
      expect(
        state.completedJobs.map((item) => item.jobId),
        isNot(contains(testCompleted.jobId)),
      );
      expect(
        state.completedJobs.map((item) => item.jobId),
        contains(realCompleted.jobId),
      );
      expect(state.invoiceHistoryEntryForJob(realCompleted.jobId), isNotNull);
    },
  );
}

DriverCustomerReplyMockData _pendingJob({
  required String jobId,
  String customerName = 'Bob Sinclair',
  String jobTitle = 'Sofa move',
  bool isTestData = true,
  bool testMode = true,
}) {
  return DriverCustomerReplyMockData(
    jobId: jobId,
    customerName: customerName,
    jobTitle: jobTitle,
    scheduledAt: null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: '10 Market Road',
    phoneNumber: '07123456789',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: 'requestSent',
    requestId: 'request-$jobId',
    requestStatus: 'request_sent',
    requestSentAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    requestCreatedAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    requestUpdatedAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    createdAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    updatedAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    isTestData: isTestData,
    testMode: testMode,
  );
}

DriverCustomerReplyMockData _completedJob({
  required String jobId,
  String customerName = 'Taylor',
  String jobTitle = 'House move',
  bool isTestData = false,
  bool testMode = false,
  bool deleted = false,
  bool archived = false,
}) {
  return DriverCustomerReplyMockData(
    jobId: jobId,
    customerName: customerName,
    jobTitle: jobTitle,
    scheduledAt: DateTime.parse('2026-06-20T10:00:00.000Z'),
    jobDateLabel: '20 Jun 2026',
    jobTimeLabel: '10:00',
    address: '20 High Street',
    phoneNumber: '07123456780',
    exactPinShared: true,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: 'completed',
    requestStatus: 'completed',
    calendarStatus: 'completed',
    completedAt: DateTime.parse('2026-06-20T12:00:00.000Z'),
    isTestData: isTestData,
    testMode: testMode,
    deleted: deleted,
    archived: archived,
  );
}

VanJobRequestRecord _requestFor(DriverCustomerReplyMockData job) {
  final requestId = job.requestId ?? 'request-${job.jobId}';
  return VanJobRequestRecord(
    requestId: requestId,
    ownerUid: 'owner-1',
    jobId: job.jobId,
    linkedJobId: job.jobId,
    status: 'request_sent',
    createdAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    updatedAt: DateTime.parse('2026-06-19T08:00:00.000Z'),
    expiresAt: DateTime.parse('2026-06-26T08:00:00.000Z'),
    publicJobTitle: job.jobTitle,
    publicCustomerName: job.customerName,
    publicAddressSummary: job.address,
    publicPhoneNumber: job.phoneNumber,
    checklistItems: const <String>[],
    customQuestions: const <String>[],
    exactPinRequested: false,
    source: 'new_job',
    sourceLabel: 'New Job',
    isTestData: job.isTestData,
    testMode: job.testMode,
  );
}

VanJobRequestDraft _draft({required String jobId}) {
  return VanJobRequestDraft(
    jobId: jobId,
    customerName: 'Debug Tester',
    phoneNumber: '07123456789',
    jobTitle: 'Test move',
    scheduledAt: DateTime.parse('2026-06-21T09:00:00.000Z'),
    jobDateLabel: '21 Jun 2026',
    jobTimeLabel: '09:00',
    address: '1 Debug Road',
    requestExactPin: false,
    requestPhotos: false,
    requiresExactPinAfterQuoteAccepted: false,
    selectedQuestionIds: const <String>[],
    answers: const <VanJobRequestAnswer>[],
    checklistItems: const <String>[],
    customQuestions: const <String>[],
  );
}

VanInvoiceHistoryEntry _invoiceForJob(String jobKey) {
  final draft = VanInvoiceDraft(
    jobKey: jobKey,
    linkedJobId: jobKey,
    businessName: 'Van Mate',
    contactName: 'Driver',
    phone: '07123456789',
    email: 'driver@example.com',
    businessAddress: '1 Van Street',
    paymentInstructions: 'Bank transfer',
    quoteExtras: const <String>[],
    quoteNotes: '',
    quotePaymentInstructions: '',
    quoteMessage: '',
    customerName: 'Bob Sinclair',
    customerPhone: '07123456789',
    billingAddress: '10 Market Road',
    customerEmail: 'customer@example.com',
    invoiceNumber: 'VM-1001',
    invoiceDate: '20/06/2026',
    dueDate: VanInvoiceDraft.dueOnReceiptLabel,
    jobReference: 'Sofa move',
    jobDescription: 'Sofa move',
    lineItems: const <VanInvoiceLineItem>[
      VanInvoiceLineItem(description: 'Sofa move', quantity: 1, amount: 60),
    ],
    estimatedMiles: '',
    mileageCharge: 0,
    invoiceNotes: '',
  );
  return VanInvoiceHistoryEntry(
    jobKey: jobKey,
    draft: draft,
    savedAt: DateTime.parse('2026-06-20T12:00:00.000Z'),
    createdAt: DateTime.parse('2026-06-20T12:00:00.000Z'),
    updatedAt: DateTime.parse('2026-06-20T12:00:00.000Z'),
  );
}
