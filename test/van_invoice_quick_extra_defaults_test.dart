import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_business_profile.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_draft.dart';
import 'package:van_mate_app/features/van_mate/pages/create_invoice_hub_page.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved helper default pre-fills quick extra amount and totals', (
    tester,
  ) async {
    final profile = const VanBusinessProfile(
      businessName: 'Van Mate',
      contactName: 'Driver',
      phone: '07123456789',
      email: 'driver@example.com',
      businessAddress: '1 High Street',
      paymentInstructions: 'Bank transfer',
      defaultExtraHelperAmount: 20,
      defaultStairsAccessAmount: 10,
      defaultWaitingTimeAmount: 15,
      defaultCollectionDeliveryAmount: 0,
      defaultMileageRate: 0,
    );
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-1',
      businessProfile: profile,
      customerName: 'Customer',
      customerPhone: '07111111111',
      customerEmail: '',
      billingAddress: '2 Market Road',
      invoiceDate: '21 Jun 2026',
      jobReference: 'House move',
      jobDescription: 'House move',
      invoiceNumber: 'INV-1',
      quoteAmount: 120,
    );

    final savedDraft = await _openAndSaveInvoiceItemsPage(
      tester,
      draft: draft,
      profile: profile,
      reply: _reply('job-1'),
      extraLabel: 'Extra helper',
    );

    expect(savedDraft.lineItems, hasLength(2));
    expect(savedDraft.lineItems[1].description, 'Extra helper');
    expect(savedDraft.lineItems[1].quantity, 1);
    expect(savedDraft.lineItems[1].amount, 20);
    expect(savedDraft.totalDue, 140);
    expect(profile.defaultExtraHelperAmount, 20);
  });

  testWidgets('tapping quick extra twice removes it without duplicates', (
    tester,
  ) async {
    final profile = const VanBusinessProfile.defaults();
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-2',
      businessProfile: profile,
      customerName: 'Customer',
      customerPhone: '07111111111',
      customerEmail: '',
      billingAddress: '2 Market Road',
      invoiceDate: '21 Jun 2026',
      jobReference: 'House move',
      jobDescription: 'House move',
      invoiceNumber: 'INV-2',
      quoteAmount: 120,
    );

    final savedDraft = await _openAndSaveInvoiceItemsPage(
      tester,
      draft: draft,
      profile: profile,
      reply: _reply('job-2'),
      extraLabel: 'Extra helper',
      taps: 2,
    );

    expect(savedDraft.lineItems, hasLength(1));
    expect(savedDraft.totalDue, 120);
  });

  testWidgets('mileage supports decimal miles', (tester) async {
    final profile = const VanBusinessProfile.defaults();
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-3',
      businessProfile: profile,
      customerName: 'Customer',
      customerPhone: '07111111111',
      customerEmail: '',
      billingAddress: '2 Market Road',
      invoiceDate: '21 Jun 2026',
      jobReference: 'House move',
      jobDescription: 'House move',
      invoiceNumber: 'INV-3',
      quoteAmount: 120,
    );

    final savedDraft = await _openAndSaveInvoiceItemsPage(
      tester,
      draft: draft,
      profile: profile,
      reply: _reply('job-3'),
      extraLabel: 'Mileage',
      editMiles: '1.5',
    );

    expect(savedDraft.estimatedMiles, '1.5');
    expect(
      savedDraft.lineItems.where((item) => item.extraKey == 'mileage'),
      isEmpty,
    );
  });

  testWidgets('edit saved extras opens shared settings sheet', (tester) async {
    final profile = const VanBusinessProfile.defaults();
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-4',
      businessProfile: profile,
      customerName: 'Customer',
      customerPhone: '07111111111',
      customerEmail: '',
      billingAddress: '2 Market Road',
      invoiceDate: '21 Jun 2026',
      jobReference: 'House move',
      jobDescription: 'House move',
      invoiceNumber: 'INV-4',
      quoteAmount: 120,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditInvoiceItemsPage(
          draft: draft,
          reply: _reply('job-4'),
          businessProfile: profile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit saved extras'));
    await tester.pumpAndSettle();

    expect(find.text('Saved extras'), findsOneWidget);
    expect(find.text('Save extras'), findsOneWidget);
  });

  test('invoice draft date prefers confirmed appointment time', () {
    const profile = VanBusinessProfile.defaults();
    final reply = DriverCustomerReplyMockData(
      jobId: 'completed-confirmed-time',
      customerName: 'Customer',
      jobTitle: 'House move',
      scheduledAt: null,
      jobDateLabel: '13 Jul 2026',
      jobTimeLabel: 'morning',
      scheduledDate: '2026-07-13',
      scheduledStartTime: '09:00',
      status: 'completed',
      calendarStatus: 'completed',
      address: '2 Market Road',
      phoneNumber: '07111111111',
      exactPinShared: false,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      preferredDate: DateTime(2026, 7, 13),
      preferredTimeWindow: 'morning',
    );

    final draft = reply.toInvoiceDraft(
      businessProfile: profile,
      invoiceNumber: 'INV-3',
    );

    expect(draft.invoiceDate, '13 Jul 2026 at 09:00');
  });
}

Future<VanInvoiceDraft> _openAndSaveInvoiceItemsPage(
  WidgetTester tester, {
  required VanInvoiceDraft draft,
  required VanBusinessProfile profile,
  required DriverCustomerReplyMockData reply,
  required String extraLabel,
  int taps = 1,
  String? editMiles,
}) async {
  VanInvoiceDraft? savedDraft;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                savedDraft = await Navigator.of(context).push<VanInvoiceDraft>(
                  MaterialPageRoute(
                    builder: (_) => EditInvoiceItemsPage(
                      draft: draft,
                      reply: reply,
                      businessProfile: profile,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  for (var index = 0; index < taps; index++) {
    await tester.tap(_quickExtraChip(extraLabel));
    await tester.pumpAndSettle();
  }

  if (editMiles != null) {
    await tester.enterText(find.widgetWithText(TextField, 'Miles'), editMiles);
    await tester.pumpAndSettle();
  }

  await tester.scrollUntilVisible(
    find.text('Save & back'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Save & back'));
  await tester.pumpAndSettle();

  expect(savedDraft, isNotNull);
  return savedDraft!;
}

Finder _quickExtraChip(String label) {
  final chipIndex = switch (label) {
    'Waiting time' => 1,
    'Stairs / access' => 2,
    'Mileage' => 3,
    'Collection / delivery' => 4,
    '3rd person' => 5,
    _ => 0,
  };
  return find.byType(ChoiceChip).at(chipIndex);
}

DriverCustomerReplyMockData _reply(String jobId) {
  return DriverCustomerReplyMockData(
    jobId: jobId,
    customerName: 'Customer',
    jobTitle: 'House move',
    scheduledAt: null,
    jobDateLabel: '21 Jun 2026',
    jobTimeLabel: '10:00',
    address: '2 Market Road',
    phoneNumber: '07111111111',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
  );
}
