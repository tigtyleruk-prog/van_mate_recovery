import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/pages/van_job_types_services_page.dart';
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

  testWidgets('empty business library offers and completes manual creation', (
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
    expect(
      find.textContaining('No business templates are available yet.'),
      findsOneWidget,
    );
    expect(find.text('Popular businesses'), findsNothing);
    expect(find.text('Browse businesses'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('create_service_manually')));
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
    await tester.tap(find.byKey(const Key('create_service_manually')));
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

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
