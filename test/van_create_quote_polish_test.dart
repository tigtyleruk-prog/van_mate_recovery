import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_quote_extra_defaults_storage.dart';

DriverCustomerReplyMockData _reply({String jobId = 'create-quote-polish'}) {
  return DriverCustomerReplyMockData(
    jobId: jobId,
    customerName: 'Alex',
    jobTitle: 'Sofa move',
    scheduledAt: null,
    jobDateLabel: '2026-07-14',
    jobTimeLabel: '10:00',
    address: '1 Test Street',
    phoneNumber: '07123456789',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    hasReply: true,
  );
}

Finder _amountField() {
  return find.widgetWithText(TextField, 'Total quote');
}

Finder _extraHelperChip() {
  return find.textContaining('Extra helper').first;
}

String _amountText(WidgetTester tester) {
  return tester.widget<TextField>(_amountField()).controller?.text ?? '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DriverReplyMockState.instance.debugResetStateForTest();
  });

  testWidgets('Create Quote gates extras and starts preview collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateQuotePage(reply: _reply())),
    );
    await tester.pump();

    expect(find.text('Enter a quote amount before adding extras.'), findsOne);
    expect(find.widgetWithText(TextField, 'Add extra line item'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);
    expect(find.textContaining('Quote:'), findsNothing);

    await tester.scrollUntilVisible(
      _extraHelperChip(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_extraHelperChip());
    await tester.pump();

    expect(_amountText(tester), isEmpty);

    await tester.scrollUntilVisible(
      _amountField(),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(_amountField(), '50');
    await tester.pump();

    expect(
      find.text('Enter a quote amount before adding extras.'),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      _extraHelperChip(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_extraHelperChip());
    await tester.pump();

    expect(_amountText(tester), '70.00');

    await tester.scrollUntilVisible(
      find.text('Message preview'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Quote: \u00A370.00'), findsNothing);

    await tester.tap(find.text('Message preview'));
    await tester.pump();

    expect(find.textContaining('Quote: \u00A370.00'), findsOne);

    await tester.scrollUntilVisible(
      _amountField(),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(_amountField(), '');
    await tester.pump();

    expect(_amountText(tester), isEmpty);
    expect(find.text('Enter a quote amount before adding extras.'), findsOne);

    await tester.scrollUntilVisible(
      _extraHelperChip(),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_extraHelperChip());
    await tester.pump();

    expect(_amountText(tester), isEmpty);
  });

  testWidgets('Create Quote refreshes saved custom extras while mounted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateQuotePage(reply: _reply())),
    );
    await tester.pump();

    expect(find.textContaining('Packing materials'), findsNothing);

    await tester.enterText(_amountField(), '100');
    await tester.pump();

    await VanQuoteExtraDefaultsStorage.instance.save(
      VanQuoteExtraDefaults.defaults().copyWithCustomExtras([
        VanQuoteExtraDefault.custom(
          key: 'custom_extra_packing_materials',
          label: 'Packing materials',
          defaultPrice: 15,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final packingMaterialsChip = find.textContaining('Packing materials').first;
    expect(packingMaterialsChip, findsOneWidget);

    await tester.scrollUntilVisible(
      packingMaterialsChip,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(packingMaterialsChip);
    await tester.pump();

    expect(_amountText(tester), '115.00');
  });

  testWidgets('Create Quote uses extras for the selected service only', (
    tester,
  ) async {
    final reply = _reply(jobId: 'service-specific-extras');
    final now = DateTime(2026, 7, 10);
    DriverReplyMockState.instance.debugAddJobForTest(reply);
    DriverReplyMockState.instance.debugAddRequestForTest(
      VanJobRequestRecord(
        requestId: 'service-specific-request',
        ownerUid: 'owner-1',
        jobId: reply.jobId,
        linkedJobId: reply.jobId,
        status: 'reply_received',
        createdAt: now,
        updatedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        publicJobTitle: reply.jobTitle,
        publicCustomerName: reply.customerName,
        publicAddressSummary: reply.address,
        checklistItems: const <String>[],
        customQuestions: const <String>[],
        exactPinRequested: false,
        selectedServiceId: 'cleaning-service',
        selectedServiceName: 'Cleaning',
      ),
    );
    await VanQuoteExtraDefaultsStorage.instance.save(
      VanQuoteExtraDefaults.defaults().copyWithCustomExtras([
        VanQuoteExtraDefault.custom(
          key: 'custom_extra_global_only',
          label: 'Global only',
          defaultPrice: 99,
        ),
      ]),
    );
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      VanJobService(
        id: 'cleaning-service',
        name: 'Cleaning',
        description: '',
        isActive: true,
        requestPhotos: false,
        requireAddress: true,
        requestExactPinAfterQuoteAccepted: false,
        linkedQuestionIds: const <String>[],
        quoteExtraDefaults: VanQuoteExtraDefaults.starterForServiceName(
          'Cleaning',
        ),
        createdAt: now,
        updatedAt: now,
      ),
    ], syncCloud: false);

    await tester.pumpWidget(MaterialApp(home: CreateQuotePage(reply: reply)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oven clean'), findsOneWidget);
    expect(find.textContaining('Deep clean'), findsOneWidget);
    expect(find.textContaining('Extra room'), findsOneWidget);
    expect(find.textContaining('Global only'), findsNothing);
    expect(find.textContaining('Extra helper'), findsNothing);

    await tester.enterText(_amountField(), '100');
    await tester.pump();

    final ovenCleanChip = find.textContaining('Oven clean').first;
    await tester.scrollUntilVisible(
      ovenCleanChip,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(ovenCleanChip);
    await tester.pump();

    expect(_amountText(tester), '140.00');
  });

  testWidgets('Create Quote reloads name-scoped extras without a service row', (
    tester,
  ) async {
    final reply = _reply(jobId: 'name-scoped-service-extras');
    final now = DateTime(2026, 7, 10);
    DriverReplyMockState.instance.debugAddJobForTest(reply);
    DriverReplyMockState.instance.debugAddRequestForTest(
      VanJobRequestRecord(
        requestId: 'name-scoped-service-request',
        ownerUid: 'owner-1',
        jobId: reply.jobId,
        linkedJobId: reply.jobId,
        status: 'reply_received',
        createdAt: now,
        updatedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        publicJobTitle: reply.jobTitle,
        publicCustomerName: reply.customerName,
        publicAddressSummary: reply.address,
        checklistItems: const <String>[],
        customQuestions: const <String>[],
        exactPinRequested: false,
        selectedServiceId: 'cleaning-request-service',
        selectedServiceName: 'Cleaning',
      ),
    );
    await VanQuoteExtraDefaultsStorage.instance.save(
      VanQuoteExtraDefaults.defaults().copyWithCustomExtras([
        VanQuoteExtraDefault.custom(
          key: 'custom_extra_global_only',
          label: 'Global only',
          defaultPrice: 99,
        ),
      ]),
    );
    await VanQuoteExtraDefaultsStorage.instance.saveForService(
      serviceKey: 'cleaning-request-service',
      serviceName: 'Cleaning',
      defaults: VanQuoteExtraDefaults.starterForServiceName('Cleaning')
          .copyWithCustomExtras([
            VanQuoteExtraDefault.custom(
              key: 'custom_extra_name_scoped_only',
              label: 'Name scoped only',
              defaultPrice: 22,
            ),
          ]),
    );

    await tester.pumpWidget(MaterialApp(home: CreateQuotePage(reply: reply)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Name scoped only'), findsOneWidget);
    expect(find.textContaining('Global only'), findsNothing);
    expect(find.textContaining('Extra helper'), findsNothing);

    await tester.enterText(_amountField(), '100');
    await tester.pump();

    final nameScopedChip = find.textContaining('Name scoped only').first;
    await tester.scrollUntilVisible(
      nameScopedChip,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(nameScopedChip);
    await tester.pump();

    expect(_amountText(tester), '122.00');
  });

  testWidgets('Create Quote reflects saved service extras immediately', (
    tester,
  ) async {
    final reply = _reply(jobId: 'immediate-service-extra-refresh');
    final now = DateTime(2026, 7, 10);
    DriverReplyMockState.instance.debugAddJobForTest(reply);
    DriverReplyMockState.instance.debugAddRequestForTest(
      VanJobRequestRecord(
        requestId: 'immediate-service-extra-request',
        ownerUid: 'owner-1',
        jobId: reply.jobId,
        linkedJobId: reply.jobId,
        status: 'reply_received',
        createdAt: now,
        updatedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        publicJobTitle: reply.jobTitle,
        publicCustomerName: reply.customerName,
        publicAddressSummary: reply.address,
        checklistItems: const <String>[],
        customQuestions: const <String>[],
        exactPinRequested: false,
        selectedServiceId: 'cleaning-request-service',
        selectedServiceName: 'Cleaning',
      ),
    );
    await VanQuoteExtraDefaultsStorage.instance.saveForService(
      serviceKey: 'cleaning-request-service',
      serviceName: 'Cleaning',
      defaults: VanQuoteExtraDefaults.starterForServiceName('Cleaning'),
    );

    await tester.pumpWidget(MaterialApp(home: CreateQuotePage(reply: reply)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Saved extras'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Saved extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add custom extra'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(
      fields.at(fields.evaluate().length - 2),
      'Eco products',
    );
    await tester.enterText(fields.at(fields.evaluate().length - 1), '8');
    await tester.scrollUntilVisible(
      find.text('Save extras'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save extras'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Eco products'), findsOneWidget);
  });
}
