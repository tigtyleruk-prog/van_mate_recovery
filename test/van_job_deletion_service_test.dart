import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_draft.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_history_entry.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_deletion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final profile = VanBusinessProfileSummary(
    id: 'courier-business',
    name: 'Swift Courier',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  test(
    'individual deletion previews and executes the exact immutable IDs',
    () async {
      final calls = <Map<String, dynamic>>[];
      final service = VanJobDeletionService(
        activeProfile: () async => profile,
        now: () => DateTime.utc(2026, 7, 22, 10),
        callable: (data) async {
          calls.add(Map<String, dynamic>.from(data));
          if (data['mode'] == 'preview') {
            return <String, dynamic>{
              'previewToken': 'preview-1',
              'confirmationPhrase': 'DELETE JOB',
              'expiresAt': '2026-07-22T10:15:00.000Z',
              'targets': <Map<String, dynamic>>[
                <String, dynamic>{
                  'jobId': 'job-1',
                  'requestId': 'request-1',
                  'status': 'pending',
                },
              ],
              'summary': <String, dynamic>{'jobs': 1, 'requests': 1},
            };
          }
          return <String, dynamic>{
            'operationId': data['idempotencyKey'],
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'jobId': 'job-1',
                'requestId': 'request-1',
                'status': 'deleted',
              },
            ],
          };
        },
      );

      final result = await service.deleteOne(
        jobId: 'job-1',
        requestId: 'request-1',
      );

      expect(result.completed.single.jobId, 'job-1');
      expect(calls, hasLength(2));
      expect(calls.first['businessProfileId'], 'courier-business');
      expect(calls.first['selection'], 'explicit');
      expect(calls.first['targets'], <Map<String, dynamic>>[
        <String, dynamic>{'jobId': 'job-1', 'requestId': 'request-1'},
      ]);
      expect(calls.last['previewToken'], 'preview-1');
      expect(calls.last['confirmationPhrase'], 'DELETE JOB');
    },
  );

  test('bulk preview exposes authoritative counts and typed phrase', () async {
    final service = VanJobDeletionService(
      activeProfile: () async => profile,
      callable: (_) async => <String, dynamic>{
        'previewToken': 'bulk-preview',
        'confirmationPhrase': 'DELETE SWIFT COURIER JOBS',
        'expiresAt': '2026-07-22T10:15:00.000Z',
        'targets': <Map<String, dynamic>>[
          <String, dynamic>{
            'jobId': 'job-1',
            'requestId': 'request-1',
            'status': 'completed',
          },
        ],
        'summary': <String, dynamic>{
          'jobs': 1,
          'requests': 1,
          'quoteVersions': 3,
          'tokens': 2,
          'photos': 4,
          'invoicesPreserved': 1,
          'ambiguousPreserved': 2,
        },
      },
    );

    final preview = await service.preview(
      selection: VanJobDeletionSelection.allOperational,
    );
    expect(preview.confirmationPhrase, 'DELETE SWIFT COURIER JOBS');
    expect(preview.summary.quoteVersions, 3);
    expect(preview.summary.invoicesPreserved, 1);
    expect(preview.targets.single.status, 'completed');
  });

  test(
    'confirmed deletion removes only the job graph locally and preserves invoice',
    () async {
      final state = DriverReplyMockState.instance;
      state.debugResetStateForTest();
      addTearDown(state.debugResetStateForTest);
      final target = _job('job-target', status: 'completed');
      final other = _job('job-other');
      state.debugAddJobForTest(target);
      state.debugAddRequestForTest(
        state.debugBuildRequestRecordForJobForTest(target),
      );
      state.debugAddJobForTest(other);
      state.debugAddInvoiceHistoryForTest(_invoiceForJob(target.jobId));
      state.debugSetJobDeletionServiceForTest(
        VanJobDeletionService(
          activeProfile: () async => profile,
          callable: (data) async {
            if (data['mode'] == 'preview') {
              return <String, dynamic>{
                'previewToken': 'preview-target',
                'confirmationPhrase': 'DELETE JOB',
                'expiresAt': '2026-07-22T10:15:00.000Z',
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'jobId': target.jobId,
                    'requestId': target.requestId,
                    'status': 'completed',
                  },
                ],
                'summary': <String, dynamic>{'jobs': 1},
              };
            }
            return <String, dynamic>{
              'operationId': 'operation-target',
              'results': <Map<String, dynamic>>[
                <String, dynamic>{
                  'jobId': target.jobId,
                  'requestId': target.requestId,
                  'status': 'deleted',
                },
              ],
            };
          },
        ),
      );

      expect(
        await state.deleteJob(jobId: target.jobId, refreshCloud: false),
        isTrue,
      );
      expect(
        state.debugAllLoadedJobs().any((job) => job.jobId == target.jobId),
        isFalse,
      );
      expect(
        state.debugAllLoadedJobs().any((job) => job.jobId == other.jobId),
        isTrue,
      );
      expect(state.invoiceHistoryEntryForJob(target.jobId), isNotNull);
      expect(state.savedInvoiceHistory.single.draft.invoiceNumber, 'VM-1001');
    },
  );

  test('backend failure keeps the visible job and request unchanged', () async {
    final state = DriverReplyMockState.instance;
    state.debugResetStateForTest();
    addTearDown(state.debugResetStateForTest);
    final target = _job('job-failure');
    state.debugAddJobForTest(target);
    final request = state.debugBuildRequestRecordForJobForTest(target);
    state.debugAddRequestForTest(request);
    state.debugSetJobDeletionServiceForTest(
      VanJobDeletionService(
        activeProfile: () async => profile,
        callable: (_) async => throw const VanJobDeletionException('offline'),
      ),
    );

    expect(
      await state.deleteJob(jobId: target.jobId, refreshCloud: false),
      isFalse,
    );
    expect(
      state.debugAllLoadedJobs().any((job) => job.jobId == target.jobId),
      isTrue,
    );
    expect(state.requestForId(request.requestId), isNotNull);
  });

  test('duplicate taps start only one authoritative deletion', () async {
    final state = DriverReplyMockState.instance;
    state.debugResetStateForTest();
    addTearDown(state.debugResetStateForTest);
    final target = _job('job-double-tap');
    state.debugAddJobForTest(target);
    final previewCompleter = Completer<Map<String, dynamic>>();
    var previewCalls = 0;
    state.debugSetJobDeletionServiceForTest(
      VanJobDeletionService(
        activeProfile: () async => profile,
        callable: (data) async {
          if (data['mode'] == 'preview') {
            previewCalls += 1;
            return previewCompleter.future;
          }
          return <String, dynamic>{
            'operationId': 'operation-double-tap',
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'jobId': target.jobId,
                'requestId': target.requestId,
                'status': 'deleted',
              },
            ],
          };
        },
      ),
    );

    final first = state.deleteJob(jobId: target.jobId, refreshCloud: false);
    await Future<void>.delayed(Duration.zero);
    expect(
      await state.deleteJob(jobId: target.jobId, refreshCloud: false),
      isFalse,
    );
    expect(previewCalls, 1);
    previewCompleter.complete(<String, dynamic>{
      'previewToken': 'preview-double-tap',
      'confirmationPhrase': 'DELETE JOB',
      'expiresAt': '2026-07-22T10:15:00.000Z',
      'targets': <Map<String, dynamic>>[
        <String, dynamic>{
          'jobId': target.jobId,
          'requestId': target.requestId,
          'status': 'pending',
        },
      ],
      'summary': <String, dynamic>{'jobs': 1},
    });
    expect(await first, isTrue);
    expect(previewCalls, 1);
  });
}

DriverCustomerReplyMockData _job(String id, {String status = 'requestSent'}) {
  return DriverCustomerReplyMockData(
    jobId: id,
    customerName: 'Customer',
    jobTitle: 'Same-day Delivery',
    scheduledAt: status == 'completed' ? DateTime.utc(2026, 7, 20, 10) : null,
    jobDateLabel: '',
    jobTimeLabel: '',
    address: '1 Collection Road',
    phoneNumber: '07123456789',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: status,
    requestId: 'request-$id',
    requestStatus: status,
    completedAt: status == 'completed' ? DateTime.utc(2026, 7, 20, 11) : null,
  );
}

VanInvoiceHistoryEntry _invoiceForJob(String jobId) {
  final draft = VanInvoiceDraft(
    jobKey: jobId,
    linkedJobId: jobId,
    businessName: 'Swift Courier',
    contactName: 'Driver',
    phone: '07123456789',
    email: 'driver@example.com',
    businessAddress: '1 Van Street',
    paymentInstructions: 'Bank transfer',
    quoteExtras: const <String>[],
    quoteNotes: '',
    quotePaymentInstructions: '',
    quoteMessage: '',
    customerName: 'Customer',
    customerPhone: '07123456789',
    billingAddress: '1 Collection Road',
    customerEmail: 'customer@example.com',
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
