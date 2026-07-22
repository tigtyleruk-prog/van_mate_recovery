import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_draft.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_history_entry.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/pages/job_detail_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_deletion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets(
    'completed invoiced jobs require the enhanced second confirmation',
    (tester) async {
      final state = DriverReplyMockState.instance;
      state.debugResetStateForTest();
      addTearDown(state.debugResetStateForTest);
      final job = _completedJob();
      state.debugAddJobForTest(job);
      state.debugAddInvoiceHistoryForTest(_invoice(job.jobId));
      state.debugSetJobDeletionServiceForTest(
        VanJobDeletionService(
          activeProfile: () async => VanBusinessProfileSummary(
            id: 'courier-business',
            name: 'Swift Courier',
            createdAt: DateTime.utc(2026, 7, 1),
            updatedAt: DateTime.utc(2026, 7, 1),
          ),
          callable: (data) async => data['mode'] == 'preview'
              ? <String, dynamic>{
                  'previewToken': 'preview-confirmation',
                  'confirmationPhrase': 'DELETE JOB',
                  'expiresAt': '2026-07-22T10:15:00.000Z',
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'jobId': job.jobId,
                      'requestId': job.requestId,
                      'status': 'completed',
                    },
                  ],
                  'summary': <String, dynamic>{'jobs': 1},
                }
              : <String, dynamic>{
                  'operationId': 'operation-confirmation',
                  'results': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'jobId': job.jobId,
                      'requestId': job.requestId,
                      'status': 'deleted',
                    },
                  ],
                },
        ),
      );
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await confirmDriverJobDelete(
                    context,
                    job: job,
                    refreshCloudAfterDelete: false,
                  );
                },
                child: const Text('Start deletion'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start deletion'));
      await tester.pump();
      expect(
        find.text(
          'This permanently removes the operational job, request, replies, quotes and linked job photos. Any invoice and financial records will be kept.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete job'));
      await tester.pump();
      expect(find.text('Permanently delete operational job?'), findsOneWidget);
      expect(
        find.textContaining('invoice, payments and financial records'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
      await tester.pump();
      await tester.pump();

      expect(result, isTrue);
      expect(state.debugAllLoadedJobs(), isEmpty);
      expect(state.invoiceHistoryEntryForJob(job.jobId), isNotNull);
    },
  );
}

DriverCustomerReplyMockData _completedJob() => DriverCustomerReplyMockData(
  jobId: 'completed-job',
  customerName: 'Customer',
  jobTitle: 'Same-day Delivery',
  scheduledAt: DateTime.utc(2026, 7, 20, 10),
  jobDateLabel: '',
  jobTimeLabel: '',
  address: '1 Collection Road',
  phoneNumber: '07123456789',
  exactPinShared: false,
  checklistResponses: const <DriverChecklistResponse>[],
  customQuestionResponses: const <DriverCustomQuestionResponse>[],
  additionalNotes: '',
  status: 'completed',
  requestId: 'request-completed-job',
  requestStatus: 'completed',
  completedAt: DateTime.utc(2026, 7, 20, 11),
);

VanInvoiceHistoryEntry _invoice(String jobId) {
  final draft = VanInvoiceDraft(
    jobKey: jobId,
    linkedJobId: jobId,
    businessName: 'Swift Courier',
    contactName: 'Driver',
    phone: '',
    email: '',
    businessAddress: '',
    paymentInstructions: 'Bank transfer',
    quoteExtras: const <String>[],
    quoteNotes: '',
    quotePaymentInstructions: '',
    quoteMessage: '',
    customerName: 'Customer',
    customerPhone: '',
    billingAddress: '',
    customerEmail: '',
    invoiceNumber: 'VM-1001',
    invoiceDate: '20/07/2026',
    dueDate: VanInvoiceDraft.dueOnReceiptLabel,
    jobReference: 'Same-day Delivery',
    jobDescription: 'Courier work',
    lineItems: const <VanInvoiceLineItem>[
      VanInvoiceLineItem(description: 'Courier work', quantity: 1, amount: 80),
    ],
    estimatedMiles: '',
    mileageCharge: 0,
    invoiceNotes: '',
  );
  return VanInvoiceHistoryEntry(
    jobKey: jobId,
    draft: draft,
    savedAt: DateTime.utc(2026, 7, 20, 12),
    createdAt: DateTime.utc(2026, 7, 20, 12),
    updatedAt: DateTime.utc(2026, 7, 20, 12),
  );
}
