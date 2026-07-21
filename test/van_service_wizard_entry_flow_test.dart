import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/pages/van_job_types_services_page.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_handover.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_hub_onboarding_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_custom_job_questions_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await VanBusinessHubOnboardingStorage.instance.dismissJobTypesOnboarding();
    await VanBusinessHubOnboardingStorage.instance
        .dismissServiceDetailSettingsHelp();
    await VanCustomJobQuestionsStorage.instance.saveAll(
      const [],
      syncCloud: false,
    );
    await VanJobServicesStorage.instance.saveAll(const [], syncCloud: false);
  });

  testWidgets('curated business library still offers manual creation', (
    tester,
  ) async {
    _setPhoneView(tester);
    await tester.pumpWidget(const MaterialApp(home: VanJobTypesServicesPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Service'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose Business Type'));
    await tester.pumpAndSettle();
    expect(find.text('What business do you run?'), findsOneWidget);
    expect(find.text('Browse businesses'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final manual = find.byKey(const Key('create_service_manually'));
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 8'), findsNothing);
    expect(find.text('Basic information'), findsNothing);
    expect(find.text('What service do you offer?'), findsOneWidget);
    expect(find.text('Continue to Service Features'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    final nameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Service name',
    );
    await tester.enterText(nameField, 'Manual Test Service');
    await _tapWizardAction(tester, 'Continue to Service Features');

    expect(find.text('Review Services'), findsOneWidget);
    expect(find.text('Service 1 of 1'), findsOneWidget);
    expect(find.text('1 of 4 · Service Features'), findsOneWidget);
    expect(await VanJobServicesStorage.instance.loadAll(), isEmpty);

    for (final capabilityId in <String>[
      'request_quote',
      'customer_drops_off',
      'customer_collects',
    ]) {
      final control = find.byKey(
        ValueKey<String>('service_feature_$capabilityId'),
      );
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pump();
    }
    await _tapReviewNext(tester);
    expect(find.text('2 of 4 · Customer Questions'), findsOneWidget);
    await _tapReviewNext(tester);
    expect(find.text('3 of 4 · Pricing Extras'), findsOneWidget);
    await _tapReviewNext(tester);
    expect(find.text('4 of 4 · Availability'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('guided-availability-day-1')),
    );
    await tester.pumpAndSettle();
    await _tapReviewNext(tester);

    final services = await VanJobServicesStorage.instance.loadAll();
    expect(services, hasLength(1));
    final service = services.single;
    expect(service.name, 'Manual Test Service');
    expect(service.starterPackId, isEmpty);
    expect(service.starterTemplateId, isEmpty);
    expect(service.linkedQuestionIds, isEmpty);
    expect(service.quoteExtraDefaults.orderedExtras, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Courier templates materialise independently into four stages', (
    tester,
  ) async {
    _setPhoneView(tester);
    await tester.pumpWidget(const MaterialApp(home: VanJobTypesServicesPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Business Type'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('business_search_field')),
      'courier',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courier').first);
    await tester.pumpAndSettle();

    for (final name in <String>['Same-day Delivery', 'Scheduled Delivery']) {
      final choice = find.widgetWithText(CheckboxListTile, name);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
    }
    await _tapWizardAction(tester, 'Review Business');
    expect(find.text('Review business'), findsOneWidget);
    await _tapWizardAction(tester, 'Create 2 Services');

    expect(find.text('Review Services'), findsOneWidget);
    expect(find.text('Service 1 of 2'), findsOneWidget);
    expect(find.text('Same-day Delivery'), findsWidgets);
    expect(await VanJobServicesStorage.instance.loadAll(), isEmpty);

    await _tapReviewNext(tester);
    expect(find.text('What are we collecting and delivering?'), findsOneWidget);
    await _tapReviewNext(tester);
    expect(find.text('Additional stop'), findsOneWidget);
    expect(find.text('Waiting time'), findsNothing);
    await _tapReviewNext(tester);
    await _tapReviewDefaults(tester);

    expect(find.text('Service 2 of 2'), findsOneWidget);
    expect(find.text('Scheduled Delivery'), findsWidgets);
    await _tapReviewNext(tester);
    expect(
      find.text('Are there any collection or delivery access restrictions?'),
      findsOneWidget,
    );
    await _tapReviewNext(tester);
    expect(find.text('Weekend or bank holiday delivery'), findsOneWidget);
    expect(find.text('Evening or out-of-hours delivery'), findsNothing);
    await _tapReviewNext(tester);
    await _tapReviewDefaults(tester);

    final services = await VanJobServicesStorage.instance.loadAll();
    final questions = await VanCustomJobQuestionsStorage.instance.loadAll();
    expect(services, hasLength(2));
    final sameDay = services.singleWhere(
      (service) => service.starterTemplateId == 'courier_same_day_delivery',
    );
    final scheduled = services.singleWhere(
      (service) => service.starterTemplateId == 'courier_scheduled_delivery',
    );
    expect(sameDay.endHandover?.storageKey, 'businessDelivers');
    expect(scheduled.endHandover?.storageKey, 'businessDelivers');
    expect(sameDay.quoteExtraDefaults.orderedExtras, hasLength(3));
    expect(scheduled.quoteExtraDefaults.orderedExtras, hasLength(3));
    expect(
      sameDay.quoteExtraDefaults.orderedExtras
          .map((extra) => extra.key)
          .toSet()
          .intersection(
            scheduled.quoteExtraDefaults.orderedExtras
                .map((extra) => extra.key)
                .toSet(),
          ),
      isEmpty,
    );
    expect(sameDay.effectiveAvailabilityByDay.keys, <int>[1, 2, 3, 4, 5, 6]);
    expect(scheduled.effectiveAvailabilityByDay.keys, <int>[1, 2, 3, 4, 5]);
    expect(
      questions.where(
        (question) => question.libraryQuestionId.startsWith('courier_'),
      ),
      hasLength(10),
    );
  });

  testWidgets('cancelling manual configuration leaves no partial service', (
    tester,
  ) async {
    _setPhoneView(tester);
    await tester.pumpWidget(const MaterialApp(home: VanJobTypesServicesPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Business Type'));
    await tester.pumpAndSettle();
    final manual = find.byKey(const Key('create_service_manually'));
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    final nameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Service name',
    );
    await tester.enterText(nameField, 'Cancelled Manual Service');
    await _tapWizardAction(tester, 'Continue to Service Features');

    expect(find.text('Review Services'), findsOneWidget);
    expect(await VanJobServicesStorage.instance.loadAll(), isEmpty);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Services'), findsWidgets);
    expect(await VanJobServicesStorage.instance.loadAll(), isEmpty);
  });
}

Future<void> _tapWizardAction(WidgetTester tester, String label) async {
  final action = find.widgetWithText(FilledButton, label).last;
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _tapReviewNext(WidgetTester tester) async {
  final action = find.byKey(const Key('service_review_next'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _tapReviewDefaults(WidgetTester tester) async {
  final target = find.byKey(const Key('service_review_use_defaults'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
