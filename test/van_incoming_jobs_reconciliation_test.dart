import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_draft.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_history_entry.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/pages/business_hub_page.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_driver_mock_state_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_request_cloud_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DriverReplyMockState.instance.debugResetStateForTest();
  });

  test('driver cache is isolated by explicit business profile scope', () async {
    final storage = VanDriverMockStateStorage.instance;
    await storage.saveJson(<String, dynamic>{
      'profile': 'alpha',
    }, businessProfileId: 'business-alpha');
    await storage.saveJson(<String, dynamic>{
      'profile': 'beta',
    }, businessProfileId: 'business-beta');

    expect(
      await storage.loadJson(businessProfileId: 'business-alpha'),
      containsPair('profile', 'alpha'),
    );
    expect(
      await storage.loadJson(businessProfileId: 'business-beta'),
      containsPair('profile', 'beta'),
    );
  });

  test('legacy unscoped requests only belong to the default business', () {
    expect(
      vanJobRequestMatchesBusinessProfile(
        const <String, dynamic>{},
        activeBusinessProfileId:
            VanBusinessProfileScopeStorage.defaultBusinessId,
      ),
      isTrue,
    );
    expect(
      vanJobRequestMatchesBusinessProfile(
        const <String, dynamic>{},
        activeBusinessProfileId: 'business-new',
      ),
      isFalse,
    );
  });

  test('authoritative request snapshot replaces mixed cached requests', () {
    final state = DriverReplyMockState.instance;
    state.debugMergeCloudRequestsForTest(<VanJobRequestRecord>[
      _request('old-a', ownerUid: 'owner-1'),
      _request('other-business', ownerUid: 'owner-1'),
    ]);
    expect(state.pendingJobs, hasLength(2));

    state.debugReconcileScopedIncomingRequestsForTest(
      <VanJobRequestRecord>[_request('current', ownerUid: 'owner-1')],
      ownerUid: 'owner-1',
      businessProfileId: 'business-1',
    );

    expect(state.debugLoadedRequestCount(), 1);
    expect(state.pendingJobs.map((job) => job.requestId), <String?>['current']);
  });

  test(
    'collection snapshots discover new requests once and prune stale cards',
    () {
      final state = DriverReplyMockState.instance;
      final first = _request('first', ownerUid: 'owner-1');
      final second = _request('second', ownerUid: 'owner-1');

      state.debugReconcileScopedIncomingRequestsForTest(<VanJobRequestRecord>[
        first,
      ], ownerUid: 'owner-1');
      expect(state.pendingJobs.map((job) => job.requestId), <String?>['first']);

      state.debugReconcileScopedIncomingRequestsForTest(<VanJobRequestRecord>[
        first,
        second,
        second,
      ], ownerUid: 'owner-1');
      expect(state.pendingJobs, hasLength(2));
      expect(state.pendingJobs.map((job) => job.requestId).toSet(), <String?>{
        'first',
        'second',
      });

      state.debugReconcileScopedIncomingRequestsForTest(<VanJobRequestRecord>[
        second,
      ], ownerUid: 'owner-1');
      expect(state.pendingJobs.map((job) => job.requestId), <String?>[
        'second',
      ]);
    },
  );

  test(
    'out-of-owner requests are excluded and financial history is untouched',
    () {
      final state = DriverReplyMockState.instance;
      state.debugAddInvoiceHistoryForTest(_invoice('invoice-job'));

      state.debugReconcileScopedIncomingRequestsForTest(<VanJobRequestRecord>[
        _request('valid', ownerUid: 'owner-1'),
        _request('wrong-owner', ownerUid: 'owner-2'),
      ], ownerUid: 'owner-1');

      expect(state.pendingJobs.map((job) => job.requestId), <String?>['valid']);
      expect(state.savedInvoiceHistory, hasLength(1));
      expect(state.savedInvoiceHistory.single.jobKey, 'invoice-job');
    },
  );

  test('badge eligibility and visible Incoming list use the same jobs', () {
    final state = DriverReplyMockState.instance;
    state.debugReconcileScopedIncomingRequestsForTest(<VanJobRequestRecord>[
      _request('one', ownerUid: 'owner-1'),
      _request('two', ownerUid: 'owner-1'),
    ], ownerUid: 'owner-1');

    final visible = state.pendingJobs;
    final attention = buildVanIncomingJobsAttention(visible);
    expect(attention.count, visible.length);
    expect(attention.newIncomingRequestCount, visible.length);
  });

  test('late snapshots from a previous profile generation are rejected', () {
    expect(
      isVanIncomingScopeSnapshotCurrent(
        capturedOwnerUid: 'owner-1',
        capturedBusinessProfileId: 'business-old',
        capturedGeneration: 4,
        currentOwnerUid: 'owner-1',
        currentBusinessProfileId: 'business-new',
        currentGeneration: 5,
      ),
      isFalse,
    );
    expect(
      isVanIncomingScopeSnapshotCurrent(
        capturedOwnerUid: 'owner-1',
        capturedBusinessProfileId: 'business-new',
        capturedGeneration: 5,
        currentOwnerUid: 'owner-1',
        currentBusinessProfileId: 'business-new',
        currentGeneration: 5,
      ),
      isTrue,
    );
  });

  test(
    'booking notification always hydrates its request id before routing',
    () {
      final source = File(
        'lib/features/van_mate/pages/van_firebase_page.dart',
      ).readAsStringSync();
      final bookingBranchStart = source.indexOf(
        'if (payload.isBookingRequestNotification)',
      );
      final quoteBranchStart = source.indexOf(
        'if (payload.isQuoteReplyNotification)',
        bookingBranchStart,
      );
      final bookingBranch = source.substring(
        bookingBranchStart,
        quoteBranchStart,
      );

      expect(bookingBranch, contains('refreshIncomingRequestById'));
      expect(bookingBranch, contains('requestId: requestId'));
      expect(bookingBranch, isNot(contains('if (jobId.isEmpty')));
      expect(source, contains('registerForegroundHandler'));
    },
  );
}

VanJobRequestRecord _request(String requestId, {required String ownerUid}) {
  final timestamp = DateTime.parse('2026-07-22T10:00:00.000Z');
  return VanJobRequestRecord(
    requestId: requestId,
    ownerUid: ownerUid,
    jobId: 'job-$requestId',
    linkedJobId: 'job-$requestId',
    status: 'request_received',
    createdAt: timestamp,
    updatedAt: timestamp,
    expiresAt: timestamp.add(const Duration(days: 7)),
    publicJobTitle: 'Same-day Delivery',
    publicCustomerName: 'Customer $requestId',
    publicAddressSummary: '1 Test Street',
    checklistItems: const <String>[],
    customQuestions: const <String>[],
    exactPinRequested: false,
    source: 'booking_link',
  );
}

VanInvoiceHistoryEntry _invoice(String jobKey) {
  final draft = VanInvoiceDraft(
    jobKey: jobKey,
    businessName: 'Business',
    contactName: 'Owner',
    phone: '',
    email: '',
    businessAddress: '',
    paymentInstructions: '',
    quoteExtras: const <String>[],
    quoteNotes: '',
    quotePaymentInstructions: '',
    quoteMessage: '',
    customerName: 'Customer',
    customerPhone: '',
    billingAddress: '',
    customerEmail: '',
    invoiceNumber: 'INV-1',
    invoiceDate: '22/07/2026',
    dueDate: VanInvoiceDraft.dueOnReceiptLabel,
    jobReference: 'Reference',
    jobDescription: 'Description',
    lineItems: const <VanInvoiceLineItem>[
      VanInvoiceLineItem(description: 'Service', quantity: 1, amount: 10),
    ],
    estimatedMiles: '',
    mileageCharge: 0,
    invoiceNotes: '',
  );
  return VanInvoiceHistoryEntry(
    jobKey: jobKey,
    draft: draft,
    savedAt: DateTime.parse('2026-07-22T10:00:00.000Z'),
  );
}
