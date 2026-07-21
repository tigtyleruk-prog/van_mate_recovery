import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/pages/van_job_types_services_page.dart';
import 'package:van_mate_app/features/van_mate/pages/van_service_wizard_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_hub_onboarding_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_custom_job_questions_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('narrow setup chooses a business and builds selected services', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MaterialApp(home: VanServiceWizardPage()));
    await tester.pumpAndSettle();

    expect(find.text('Set Up My Business'), findsOneWidget);
    expect(find.text('Create From Scratch'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Choose Business Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Business Type'));
    await tester.pumpAndSettle();
    expect(find.text('What business do you run?'), findsOneWidget);
    expect(find.text('Popular businesses'), findsOneWidget);
    expect(find.text('Browse businesses'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final searchField = find.byKey(const Key('business_search_field'));
    await tester.ensureVisible(searchField);
    await tester.pumpAndSettle();
    await tester.enterText(searchField, 'cake');
    await tester.pump();
    expect(find.text('Wedding Cakes'), findsOneWidget);
    expect(find.text('Cupcakes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Bakery'));
    await tester.tap(find.text('Bakery'));
    await tester.pumpAndSettle();

    expect(find.text('Bakery'), findsOneWidget);
    expect(find.text('Which services do you offer?'), findsOneWidget);
    for (final serviceName in const <String>[
      'Walk-in Purchases',
      'Click & Collect',
      'Pre-orders',
      'Local Delivery',
      'Wedding & Celebration Cakes',
      'Corporate Orders',
    ]) {
      expect(find.text(serviceName), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Walk-in Purchases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walk-in Purchases'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Click & Collect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Click & Collect'));
    await tester.pumpAndSettle();
    expect(find.text('2 services selected'), findsOneWidget);
    expect(find.textContaining('recommended capabilities'), findsNothing);
    expect(find.text('How should your services work?'), findsNothing);

    final reviewBusinessButton = find.widgetWithText(
      FilledButton,
      'Review Business',
    );
    await tester.ensureVisible(reviewBusinessButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewBusinessButton);
    await tester.pumpAndSettle();
    expect(find.text('Review business'), findsOneWidget);
    expect(find.text('Journey'), findsNWidgets(2));
    expect(find.text('Handover'), findsNWidgets(2));
    expect(find.text('Pricing extras'), findsNWidgets(2));
    expect(find.text('Availability'), findsNWidgets(2));
    expect(find.text('Questions'), findsNothing);

    await tester.ensureVisible(find.text('Create 2 Services'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create 2 Services'));
    await tester.pumpAndSettle();
    final services = await VanJobServicesStorage.instance.loadAll();
    expect(
      services.map((service) => service.name),
      containsAll(<String>['Click & Collect', 'Walk-in Purchases']),
    );
    expect(
      services.every((service) => service.starterPackId == 'bakery_business'),
      isTrue,
    );
    expect(
      services.every(
        (service) =>
            service.customerJourneyType == VanCustomerJourneyType.order,
      ),
      isTrue,
    );
    expect(
      services
          .firstWhere((service) => service.name == 'Click & Collect')
          .serviceCapabilityIds,
      contains('customer_collects'),
    );
    expect(services.every((service) => service.isCapabilityDriven), isTrue);
    final questions = await VanCustomJobQuestionsStorage.instance.loadAll();
    final questionLookup = <String, String>{
      for (final question in questions) question.id: question.questionText,
    };
    final walkIn = services.firstWhere(
      (service) => service.name == 'Walk-in Purchases',
    );
    final clickCollect = services.firstWhere(
      (service) => service.name == 'Click & Collect',
    );
    expect(
      walkIn.linkedQuestionIds.map((id) => questionLookup[id]),
      containsAll(<String>[
        'What would you like to order?',
        'Quantity',
        'Allergies or dietary requirements',
      ]),
    );
    expect(
      clickCollect.linkedQuestionIds.map((id) => questionLookup[id]),
      contains('Preferred collection time'),
    );
    expect(
      clickCollect.effectiveSelectedBuiltInQuestionKeys,
      containsAll(<String>['phone', 'email', 'preferred_date']),
    );
    expect(
      clickCollect.quoteExtraDefaults.enabledExtras.map(
        (extra) => extra.resolvedLabel,
      ),
      containsAll(<String>['Gift box', 'Rush order']),
    );
    expect(clickCollect.workingDays, containsAll(<int>[1, 2, 3, 4, 5]));
    expect(clickCollect.businessStartMinutes, 9 * 60);
    expect(clickCollect.businessEndMinutes, 17 * 60);
    expect(clickCollect.configuredQuestionCount, greaterThan(3));
    expect(tester.takeException(), isNull);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      'van_service_detail_settings_help_dismissed_v1',
      true,
    );
    await VanBusinessHubOnboardingStorage.instance
        .dismissServiceDetailSettingsHelp();
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: VanJobServiceDetailPage(serviceId: clickCollect.id),
      ),
    );
    await tester.pumpAndSettle();
    if (find.text('Got it').evaluate().isNotEmpty) {
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Service Detail'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Extras'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Gift box'), findsOneWidget);
    if (find.text('Got it').evaluate().isNotEmpty) {
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.text('Questions'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('7 attached'), findsOneWidget);
    expect(find.textContaining('Phone number'), findsOneWidget);
    expect(find.text('Preferred collection time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing and duplication skip the starting choice', (
    tester,
  ) async {
    final service = _service();
    await tester.pumpWidget(
      MaterialApp(home: VanServiceWizardPage(initialService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set Up My Business'), findsNothing);
    expect(find.text('Window Cleaning'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: VanServiceWizardPage(key: UniqueKey(), duplicateFrom: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set Up My Business'), findsNothing);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.any((field) => field.controller?.text == 'Window Cleaning Copy'),
      isTrue,
    );
  });

  testWidgets('previous services appear as recent business shortcuts', (
    tester,
  ) async {
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      _service().copyWith(id: 'boiler-service', name: 'Boiler Service'),
    ], syncCloud: false);

    await tester.pumpWidget(const MaterialApp(home: VanServiceWizardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Business Type'));
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Boiler Service'), findsOneWidget);
    await tester.tap(find.text('Boiler Service'));
    await tester.pumpAndSettle();

    expect(find.text('Plumber'), findsWidgets);
    expect(find.text('Which services do you offer?'), findsOneWidget);
  });

  testWidgets('rebuilding a starter service never overwrites custom data', (
    tester,
  ) async {
    final existing = _service().copyWith(
      id: 'service_courier_business_same_day_delivery_existing',
      name: 'My Priority Courier',
      description: 'Customer-edited description',
      noticeHours: 72,
      creationSource: 'capabilityBuilder',
      starterPackId: 'courier_business',
      starterTemplateId: 'same_day_delivery',
      extraChargeUnits: const <String, String>{
        'custom_extra_customer_rate': 'Hour',
      },
      quoteExtraDefaults: VanQuoteExtraDefaults.empty()
          .copyWithCustomExtras(<VanQuoteExtraDefault>[
            VanQuoteExtraDefault.custom(
              key: 'custom_extra_customer_rate',
              label: 'My custom rate',
              defaultPrice: 37,
            ),
          ]),
    );
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      existing,
    ], syncCloud: false);

    await tester.pumpWidget(const MaterialApp(home: VanServiceWizardPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Business Type'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('business_search_field')),
      'courier',
    );
    await tester.pump();
    await tester.tap(find.text('Courier').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same-day Delivery'));
    await tester.pumpAndSettle();
    final reviewExistingBusinessButton = find.widgetWithText(
      FilledButton,
      'Review Business',
    );
    await tester.ensureVisible(reviewExistingBusinessButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewExistingBusinessButton);
    await tester.pumpAndSettle();
    final createServiceButton = find.widgetWithText(
      FilledButton,
      'Create Service',
    );
    await tester.ensureVisible(createServiceButton);
    await tester.tap(createServiceButton);
    await tester.pumpAndSettle();

    final stored = await VanJobServicesStorage.instance.loadAll();
    expect(stored, hasLength(1));
    expect(stored.single.toJson(), existing.toJson());
  });

  testWidgets(
    'browse keeps one category open and search has a blank fallback',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VanServiceWizardPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose Business Type'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Trades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trades'));
      await tester.pumpAndSettle();
      expect(find.text('Painter & Decorator'), findsOneWidget);

      await tester.ensureVisible(find.text('Food & Local Businesses'));
      await tester.tap(find.text('Food & Local Businesses'));
      await tester.pumpAndSettle();
      expect(find.text('Painter & Decorator'), findsNothing);
      expect(find.text('Catering'), findsOneWidget);

      final searchField = find.byKey(const Key('business_search_field'));
      await tester.ensureVisible(searchField);
      await tester.enterText(searchField, 'definitely-not-a-business');
      await tester.pump();
      expect(find.text("Can't find your business?"), findsOneWidget);
      expect(find.text('Create a Custom Service'), findsNothing);
    },
  );

  testWidgets('starter-pack and blank drafts restore without reselecting', (
    tester,
  ) async {
    final starterDraft = _service().copyWith(
      name: 'Edited Bakery Draft',
      isDraft: true,
      creationSource: 'starterPack',
      starterTemplateId: 'bakery',
      wizardStep: 4,
      selectedBuiltInQuestionKeys: const <String>['phone'],
    );
    await tester.pumpWidget(
      MaterialApp(home: VanServiceWizardPage(initialService: starterDraft)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 5 of 8'), findsOneWidget);
    expect(find.text('How would you like to start?'), findsNothing);
    expect(find.text('Customise your selected questions'), findsOneWidget);

    final blankDraft = _service().copyWith(
      id: 'blank-draft',
      name: 'Blank Draft',
      isDraft: true,
      creationSource: 'blank',
      starterTemplateId: '',
      wizardStep: 0,
      selectedBuiltInQuestionKeys: const <String>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VanServiceWizardPage(
          key: UniqueKey(),
          initialService: blankDraft,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.text('How would you like to start?'), findsNothing);
    expect(find.text('Blank Draft'), findsWidgets);
  });
}

VanJobService _service() {
  final now = DateTime(2026, 7, 20);
  return VanJobService(
    id: 'window-cleaning',
    name: 'Window Cleaning',
    description: 'Regular exterior window cleaning.',
    isActive: true,
    requestPhotos: false,
    requireAddress: true,
    requestExactPinAfterQuoteAccepted: false,
    linkedQuestionIds: const <String>[],
    quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
    createdAt: now,
    updatedAt: now,
  );
}
