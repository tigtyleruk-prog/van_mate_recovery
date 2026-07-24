import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_capability.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_handover.dart';
import 'package:van_mate_app/features/van_mate/pages/van_job_types_services_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_hub_onboarding_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_custom_job_questions_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_service_configuration_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await VanBusinessHubOnboardingStorage.instance.dismissJobTypesOnboarding();
    await VanBusinessHubOnboardingStorage.instance
        .dismissServiceDetailSettingsHelp();
  });

  testWidgets('Services list Edit opens the shared saved-service editor', (
    tester,
  ) async {
    _setPhoneView(tester);
    final service = _courierService('list-edit', 'Same-day Delivery');
    final question = _question(service.linkedQuestionIds.single);
    final before = service.toJson();
    await _seed(<VanJobService>[service], <VanCustomJobQuestion>[question]);

    await tester.pumpWidget(const MaterialApp(home: VanJobTypesServicesPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Configure Service'), findsOneWidget);
    expect(find.text('Same-day Delivery'), findsOneWidget);
    expect(find.text('1 of 4 · Service Features'), findsOneWidget);
    expect(find.text('Multiple stops'), findsOneWidget);
    expect(find.text('Business collects'), findsOneWidget);
    expect(find.text('Business returns'), findsOneWidget);
    expect(find.text('Basic information'), findsNothing);
    expect(find.text('Step 1 of 8'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('cancel_service_configuration')));
    await tester.pumpAndSettle();

    expect(find.text('Services'), findsWidgets);
    expect(find.text('Same-day Delivery'), findsOneWidget);
    expect(
      (await VanJobServicesStorage.instance.loadAll()).single.toJson(),
      equals(before),
    );
  });

  testWidgets(
    'Service Detail Questions Edit Service opens the shared editor and returns',
    (tester) async {
      _setPhoneView(tester);
      final service = _courierService('detail-edit', 'Same-day Delivery');
      final question = _question(service.linkedQuestionIds.single);
      final before = service.toJson();
      await _seed(<VanJobService>[service], <VanCustomJobQuestion>[question]);

      await tester.pumpWidget(
        MaterialApp(home: VanJobServiceDetailPage(serviceId: service.id)),
      );
      await tester.pumpAndSettle();
      await _openDetailEdit(tester);

      expect(find.text('Configure Service'), findsOneWidget);
      expect(find.text('Same-day Delivery'), findsOneWidget);
      expect(find.text('2 of 4 · Customer Questions'), findsOneWidget);
      expect(find.text('Basic information'), findsNothing);
      expect(find.text('Step 1 of 8'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('cancel_service_configuration')));
      await tester.pumpAndSettle();

      expect(find.text('Service Detail'), findsOneWidget);
      expect(find.text('Questions'), findsOneWidget);
      expect(
        (await VanJobServicesStorage.instance.loadAll()).single.toJson(),
        equals(before),
      );
    },
  );

  testWidgets(
    'Services list completion returns to Services and updates only its service',
    (tester) async {
      _setPhoneView(tester);
      final service = _courierService('list-save', 'Same-day Delivery');
      final other = _courierService('list-other', 'Medical Delivery');
      final question = _question(service.linkedQuestionIds.single);
      final otherQuestion = _question(other.linkedQuestionIds.single);
      final originalPreferredTime =
          service.effectiveRequestFlowOptions.askPreferredTime;
      final otherBefore = other.toJson();
      await _seed(
        <VanJobService>[service, other],
        <VanCustomJobQuestion>[question, otherQuestion],
      );

      await tester.pumpWidget(
        const MaterialApp(home: VanJobTypesServicesPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      await _toggleFlowOption(tester, 'Preferred time');
      await _nextStage(tester);
      await _nextStage(tester);
      await _nextStage(tester);
      await _nextStage(tester);

      expect(find.text('Services'), findsWidgets);
      expect(find.text('Same-day Delivery'), findsOneWidget);
      expect(find.text('Medical Delivery'), findsOneWidget);
      final stored = await VanJobServicesStorage.instance.loadAll();
      final updated = stored.singleWhere((item) => item.id == service.id);
      final untouched = stored.singleWhere((item) => item.id == other.id);
      expect(
        updated.effectiveRequestFlowOptions.askPreferredTime,
        isNot(originalPreferredTime),
      );
      expect(untouched.toJson(), equals(otherBefore));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'existing service opens its loaded four-stage configuration and returns',
    (tester) async {
      _setPhoneView(tester);

      final service = _courierService('multi-drop', 'Multi-drop Delivery');
      final question = _question(service.linkedQuestionIds.single);
      await _seed(<VanJobService>[service], <VanCustomJobQuestion>[question]);

      await tester.pumpWidget(
        MaterialApp(home: VanJobServiceDetailPage(serviceId: service.id)),
      );
      await tester.pumpAndSettle();
      await _openConfiguration(tester);

      expect(find.text('Configure Service'), findsOneWidget);
      expect(find.text('Multi-drop Delivery'), findsOneWidget);
      expect(find.text('1 of 4 · Service Features'), findsOneWidget);
      expect(find.text('Service 1 of 1'), findsNothing);
      expect(find.text('Basic information'), findsNothing);
      expect(find.text('Step 1 of 8'), findsNothing);
      expect(find.text('Request a quote'), findsWidgets);
      expect(find.text('Multiple stops'), findsOneWidget);
      expect(find.text('Business collects'), findsOneWidget);
      expect(find.text('Business returns'), findsOneWidget);

      await _nextStage(tester);
      expect(find.text('2 of 4 · Customer Questions'), findsOneWidget);
      expect(find.text(question.questionText), findsOneWidget);
      expect(find.text('Long text - Multiple Stops'), findsOneWidget);

      await _nextStage(tester);
      expect(find.text('3 of 4 · Pricing Extras'), findsOneWidget);
      expect(find.textContaining('Waiting time'), findsOneWidget);

      await _nextStage(tester);
      expect(find.text('4 of 4 · Availability'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Opens 7:30 AM'), findsNWidgets(3));
      expect(find.text('Closes 7:00 PM'), findsNWidgets(3));

      await _nextStage(tester);
      expect(find.text('Service Detail'), findsOneWidget);
      expect(find.byType(VanJobServiceDetailPage), findsOneWidget);
      expect(
        (await VanJobServicesStorage.instance.loadAll()).single.toJson(),
        equals(service.toJson()),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel discards staged booking and question changes', (
    tester,
  ) async {
    final service = _courierService('cancel-service', 'Scheduled Delivery');
    final other = _courierService('cancel-other', 'Legal Document Delivery');
    final question = _question(service.linkedQuestionIds.single);
    final otherQuestion = _question(other.linkedQuestionIds.single);
    final beforeServices = <Map<String, dynamic>>[
      service.toJson(),
      other.toJson(),
    ];
    final beforeQuestions = <Map<String, dynamic>>[
      question.toJson(),
      otherQuestion.toJson(),
    ];
    await _seed(
      <VanJobService>[service, other],
      <VanCustomJobQuestion>[question, otherQuestion],
    );

    await tester.pumpWidget(
      MaterialApp(home: VanJobServiceDetailPage(serviceId: service.id)),
    );
    await tester.pumpAndSettle();
    await _openConfiguration(tester);
    await _toggleFlowOption(tester, 'Preferred time');
    await _nextStage(tester);
    final visibility = find.byKey(
      ValueKey<String>('question_visibility_${question.id}'),
    );
    await tester.ensureVisible(visibility);
    await tester.tap(visibility);
    await tester.pump();
    await tester.tap(find.byKey(const Key('cancel_service_configuration')));
    await tester.pumpAndSettle();

    expect(find.text('Service Detail'), findsOneWidget);
    final storedServices = await VanJobServicesStorage.instance.loadAll();
    final storedQuestions = await VanCustomJobQuestionsStorage.instance
        .loadAll();
    expect(
      storedServices.map((item) => item.toJson()).toList(),
      equals(beforeServices),
    );
    expect(
      storedQuestions.map((item) => item.toJson()).toList(),
      equals(beforeQuestions),
    );
  });

  testWidgets('save updates only the selected existing service', (
    tester,
  ) async {
    final service = _courierService('save-service', 'Multi-drop Delivery');
    final other = _courierService('save-other', 'Medical Delivery');
    final question = _question(service.linkedQuestionIds.single);
    final otherQuestion = _question(other.linkedQuestionIds.single);
    final originalPreferredTime =
        service.effectiveRequestFlowOptions.askPreferredTime;
    final otherBefore = other.toJson();
    final originalCapabilities = service.serviceCapabilityIds;
    final originalQuestionIds = service.linkedQuestionIds;
    final originalExtras = service.quoteExtraDefaults.toJson();
    final originalWorkingDays = service.workingDays;
    await _seed(
      <VanJobService>[service, other],
      <VanCustomJobQuestion>[question, otherQuestion],
    );

    await tester.pumpWidget(
      MaterialApp(home: VanJobServiceDetailPage(serviceId: service.id)),
    );
    await tester.pumpAndSettle();
    await _openConfiguration(tester);
    await _toggleFlowOption(tester, 'Preferred time');
    await _nextStage(tester);
    await _nextStage(tester);
    await _nextStage(tester);
    await _nextStage(tester);

    expect(find.text('Service Detail'), findsOneWidget);
    final stored = await VanJobServicesStorage.instance.loadAll();
    final updated = stored.singleWhere((item) => item.id == service.id);
    final untouched = stored.singleWhere((item) => item.id == other.id);
    expect(
      updated.effectiveRequestFlowOptions.askPreferredTime,
      isNot(originalPreferredTime),
    );
    expect(updated.serviceCapabilityIds, originalCapabilities);
    expect(updated.linkedQuestionIds, originalQuestionIds);
    expect(updated.quoteExtraDefaults.toJson(), equals(originalExtras));
    expect(updated.workingDays, originalWorkingDays);
    expect(updated.businessStartMinutes, service.businessStartMinutes);
    expect(updated.businessEndMinutes, service.businessEndMinutes);
    expect(updated.noticeHours, service.noticeHours);
    expect(
      updated.appointmentDurationMinutes,
      service.appointmentDurationMinutes,
    );
    expect(untouched.toJson(), equals(otherBefore));
  });

  testWidgets(
    'duplicate preserves configuration and edits questions copy-on-write',
    (tester) async {
      _setPhoneView(tester);
      final service = _courierService('duplicate-source', 'Generated Delivery');
      final question = _question(service.linkedQuestionIds.single);
      await _seed(<VanJobService>[service], <VanCustomJobQuestion>[question]);

      await tester.pumpWidget(
        const MaterialApp(home: VanJobTypesServicesPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(find.text('Generated Delivery copy'), findsWidgets);
      await _nextStage(tester);
      await _nextStage(tester);
      await _nextStage(tester);
      await _nextStage(tester);

      var stored = await VanJobServicesStorage.instance.loadAll();
      expect(stored, hasLength(2));
      final duplicate = stored.singleWhere((item) => item.id != service.id);
      final sourceConfiguration = Map<String, dynamic>.from(service.toJson())
        ..remove('id')
        ..remove('name')
        ..remove('createdAt')
        ..remove('updatedAt');
      final duplicateConfiguration =
          Map<String, dynamic>.from(duplicate.toJson())
            ..remove('id')
            ..remove('name')
            ..remove('createdAt')
            ..remove('updatedAt');
      expect(duplicate.name, 'Generated Delivery copy');
      expect(duplicateConfiguration, equals(sourceConfiguration));
      expect(duplicate.linkedQuestionIds, service.linkedQuestionIds);

      await tester.pumpWidget(
        MaterialApp(home: VanJobServiceDetailPage(serviceId: duplicate.id)),
      );
      await tester.pumpAndSettle();
      await _openConfiguration(tester);
      await _nextStage(tester);
      final editQuestion = find.byKey(
        ValueKey<String>('question_edit_${question.id}'),
      );
      await tester.ensureVisible(editQuestion);
      await tester.tap(editQuestion);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('service_question_text')),
        'How many stops are required for this copy?',
      );
      await tester.tap(find.byKey(const Key('save_service_question')));
      await tester.pumpAndSettle();
      await _nextStage(tester);
      await _nextStage(tester);
      await _nextStage(tester);

      stored = await VanJobServicesStorage.instance.loadAll();
      final storedSource = stored.singleWhere((item) => item.id == service.id);
      final storedDuplicate = stored.singleWhere(
        (item) => item.id == duplicate.id,
      );
      expect(storedSource.linkedQuestionIds, <String>[question.id]);
      expect(storedDuplicate.linkedQuestionIds.single, isNot(question.id));
      expect(
        storedDuplicate.linkedQuestionIds.single,
        startsWith('service_question_${duplicate.id}_'),
      );
      final storedQuestions = await VanCustomJobQuestionsStorage.instance
          .loadAll();
      expect(storedQuestions, hasLength(2));
      expect(
        storedQuestions
            .singleWhere((item) => item.id == question.id)
            .questionText,
        question.questionText,
      );
      expect(
        storedQuestions
            .singleWhere(
              (item) => item.id == storedDuplicate.linkedQuestionIds.single,
            )
            .questionText,
        'How many stops are required for this copy?',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy transport icon opens configuration without null crash', (
    tester,
  ) async {
    final legacy = _courierService('legacy-service', 'Legacy Courier Service')
        .copyWith(
          serviceCapabilityIds: const <String>[],
          capabilitySchemaVersion: 0,
          creationSource: 'existing',
          starterPackId: '',
          starterTemplateId: '',
        );
    await _seed(
      <VanJobService>[legacy],
      <VanCustomJobQuestion>[_question(legacy.linkedQuestionIds.single)],
    );

    await tester.pumpWidget(
      MaterialApp(home: VanJobServiceDetailPage(serviceId: legacy.id)),
    );
    await tester.pumpAndSettle();
    await _openConfiguration(tester);

    expect(find.text('Configure Service'), findsOneWidget);
    expect(find.text('Legacy Courier Service'), findsOneWidget);
    expect(find.text('Standard service'), findsOneWidget);
    expect(find.text('Basic information'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'generated service deletion removes only its unreferenced owned questions',
    () async {
      const serviceId = 'service_removals_man_with_van_general_100';
      const ownedGeneratedId =
          'service_capability_service_removals_man_with_van_general_100_0';
      const ownedEditedId =
          'service_question_service_removals_man_with_van_general_100_1';
      const sharedOwnedId =
          'service_question_service_removals_man_with_van_general_100_2';
      const unrelatedId = 'reusable_manual_question';
      final generated = _courierService(serviceId, 'Man with a Van').copyWith(
        linkedQuestionIds: const <String>[
          ownedGeneratedId,
          ownedEditedId,
          sharedOwnedId,
          unrelatedId,
        ],
        starterPackId: 'removals_man_with_van',
        starterTemplateId: 'removals_man_with_van_general',
        creationSource: 'capabilityBuilder',
      );
      final other = _courierService(
        'other-service',
        'Other Service',
      ).copyWith(linkedQuestionIds: const <String>[sharedOwnedId]);
      await _seed(
        <VanJobService>[generated, other],
        <VanCustomJobQuestion>[
          _question(ownedGeneratedId),
          _question(ownedEditedId),
          _question(sharedOwnedId),
          _question(unrelatedId),
        ],
      );

      await VanServiceConfigurationRepository().deleteServiceAndOwnedQuestions(
        generated,
      );

      final services = await VanJobServicesStorage.instance.loadAll();
      final questionIds =
          (await VanCustomJobQuestionsStorage.instance.loadAll())
              .map((question) => question.id)
              .toSet();
      expect(services.map((service) => service.id), <String>['other-service']);
      expect(questionIds, isNot(contains(ownedGeneratedId)));
      expect(questionIds, isNot(contains(ownedEditedId)));
      expect(questionIds, contains(sharedOwnedId));
      expect(questionIds, contains(unrelatedId));
    },
  );

  test('manual service deletion preserves its question definitions', () async {
    const serviceId = 'manual-service';
    const questionId = 'service_question_manual-service_1';
    final manual = _courierService(serviceId, 'Manual Service').copyWith(
      linkedQuestionIds: const <String>[questionId],
      starterPackId: '',
      starterTemplateId: '',
      creationSource: 'blank',
    );
    await _seed(
      <VanJobService>[manual],
      <VanCustomJobQuestion>[_question(questionId)],
    );

    await VanServiceConfigurationRepository().deleteServiceAndOwnedQuestions(
      manual,
    );

    expect(await VanJobServicesStorage.instance.loadAll(), isEmpty);
    expect(
      (await VanCustomJobQuestionsStorage.instance.loadAll()).map(
        (question) => question.id,
      ),
      contains(questionId),
    );
  });
}

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openConfiguration(WidgetTester tester) async {
  final button = find.text('Configure in Service Wizard');
  await tester.scrollUntilVisible(
    button,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _openDetailEdit(WidgetTester tester) async {
  final button = find.text('Edit Service');
  await tester.scrollUntilVisible(
    button,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _nextStage(WidgetTester tester) async {
  final button = find.byKey(const Key('service_review_next'));
  await tester.scrollUntilVisible(
    button,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _toggleFlowOption(WidgetTester tester, String label) async {
  final tile = find.widgetWithText(SwitchListTile, label);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pump();
}

Future<void> _seed(
  List<VanJobService> services,
  List<VanCustomJobQuestion> questions,
) async {
  await VanCustomJobQuestionsStorage.instance.saveAll(
    questions,
    syncCloud: false,
  );
  await VanJobServicesStorage.instance.saveAll(services, syncCloud: false);
}

VanJobService _courierService(String id, String name) {
  final now = DateTime.utc(2026, 7, 21, 10);
  return VanJobService(
    id: id,
    name: name,
    description: 'Saved customer configuration.',
    isActive: true,
    requestPhotos: true,
    requireAddress: true,
    requestExactPinAfterQuoteAccepted: false,
    requestType: VanCustomerRequestType.quoteRequest,
    customerJourneyType: VanCustomerJourneyType.quote,
    startHandover: VanStartHandover.businessCollects,
    endHandover: VanEndHandover.businessReturns,
    allowedStartHandoverOptions: const <VanStartHandover>[
      VanStartHandover.businessCollects,
    ],
    allowedEndHandoverOptions: const <VanEndHandover>[
      VanEndHandover.businessReturns,
    ],
    allowBusinessCollection: true,
    allowBusinessReturn: true,
    requestFlowOptions: VanCustomerRequestFlowOptions.defaultsFor(
      VanCustomerRequestType.quoteRequest,
    ).copyWith(askPreferredDate: true, askPreferredTime: true),
    linkedQuestionIds: <String>['$id-question'],
    quoteExtraDefaults: VanQuoteExtraDefaults.empty().copyWithExtra(
      VanQuoteExtraDefault.fallback(
        kVanQuoteExtraWaitingTimeKey,
      ).copyWith(enabled: true, label: 'Waiting time', defaultPrice: 20),
    ),
    createdAt: now,
    updatedAt: now,
    category: 'Transport & Delivery',
    iconKey: 'local_shipping',
    workingDays: const <int>[1, 3, 5],
    businessStartMinutes: 7 * 60 + 30,
    businessEndMinutes: 19 * 60,
    noticeHours: 4,
    maxBookingsPerDay: 4,
    appointmentDurationMinutes: 90,
    selectedBuiltInQuestionKeys: const <String>[
      'phone',
      'email',
      'collection_address',
      'delivery_address',
    ],
    serviceCapabilityIds: const <String>[
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.customQuote,
      VanServiceCapabilityIds.businessCollects,
      VanServiceCapabilityIds.businessReturns,
      VanServiceCapabilityIds.multipleStops,
      VanServiceCapabilityIds.photoUpload,
    ],
    capabilitySchemaVersion: 1,
    creationSource: 'capabilityBuilder',
    starterPackId: 'courier_business',
    starterTemplateId: 'multi_drop_delivery',
    pricingMode: VanServiceCapabilityIds.customQuote,
  );
}

VanCustomJobQuestion _question(String id) {
  final now = DateTime.utc(2026, 7, 21, 10);
  return VanCustomJobQuestion(
    id: id,
    questionText: 'How many delivery stops are required?',
    libraryQuestionId: 'transport.stops.count',
    tags: const <String>['transport', 'multiple_stops'],
    answerType: VanCustomQuestionAnswerType.longText,
    category: VanCustomQuestionCategory.multipleStops,
    isActive: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}
