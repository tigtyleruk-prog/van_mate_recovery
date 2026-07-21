import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/pages/business_hub_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Hub pencil opens Edit Business danger zone with typed confirmation',
    (tester) async {
      final now = DateTime(2026, 7, 20).toIso8601String();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'van_business_profiles_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'dave_delivery',
            'name': 'Dave Delivery',
            'createdAt': now,
            'updatedAt': now,
          },
        ]),
        'van_active_business_profile_id_v1': 'dave_delivery',
        'van_business_name_business_dave_delivery': 'Dave Delivery',
      });

      await tester.pumpWidget(const MaterialApp(home: VanBusinessHubPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit business'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Business'), findsOneWidget);

      for (var index = 0; index < 8; index += 1) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -500));
        await tester.pump();
        if (find.text('Danger Zone').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('Delete Business'), findsOneWidget);
      await tester.tap(find.text('Delete Business'));
      await tester.pumpAndSettle();

      expect(find.text('Delete business?'), findsOneWidget);
      expect(find.textContaining('Dave Delivery'), findsWidgets);
      expect(
        find.textContaining('archived, read-only records'),
        findsOneWidget,
      );
      var deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete permanently'),
      );
      expect(deleteButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'Dave Delivery');
      await tester.pump();
      deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete permanently'),
      );
      expect(deleteButton.onPressed, isNotNull);
    },
  );

  test('Business Hub has no delete control on its business card', () {
    final source = File(
      'lib/features/van_mate/pages/business_hub_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Icons.delete')));
    expect(source, isNot(contains("tooltip: 'Delete business'")));
    expect(source, contains("tooltip: 'Edit business'"));
  });
}
