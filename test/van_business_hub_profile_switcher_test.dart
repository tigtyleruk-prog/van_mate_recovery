import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/pages/business_hub_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add business dialog closes before active profile switch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'van_business_name': "Dave's Delivery Services",
    });

    await tester.pumpWidget(const MaterialApp(home: VanBusinessHubPage()));
    await tester.pumpAndSettle();

    expect(find.text("Dave's Delivery Services"), findsWidgets);
    expect(find.text("Dave's Gardening"), findsNothing);

    await tester.tap(find.text('Add another business'));
    await tester.pumpAndSettle();

    expect(find.text('Add business'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter a business name.'), findsOneWidget);
    expect(find.text('Add business'), findsOneWidget);

    await tester.enterText(find.byType(TextField), "Dave's Gardening");
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Add business'), findsNothing);
    expect(find.text("Dave's Gardening"), findsWidgets);
    expect(find.text("Dave's Delivery Services"), findsWidgets);

    final scope = VanBusinessProfileScopeStorage.instance;
    expect((await scope.activeProfile()).name, "Dave's Gardening");

    await tester.tap(
      find.widgetWithText(ChoiceChip, "Dave's Delivery Services"),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect((await scope.activeProfile()).name, "Dave's Delivery Services");

    await tester.tap(find.widgetWithText(ChoiceChip, "Dave's Gardening"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect((await scope.activeProfile()).name, "Dave's Gardening");
  });
}
