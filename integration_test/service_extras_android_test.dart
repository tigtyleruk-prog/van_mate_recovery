import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/widgets/van_quote_extra_defaults_sheet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rapid Service Extras input stays responsive on Android', (
    tester,
  ) async {
    final initial = VanQuoteExtraDefaults.defaults().copyWithCustomExtras(
      List<VanQuoteExtraDefault>.generate(
        24,
        (index) => VanQuoteExtraDefault.custom(
          key: 'custom_extra_android_$index',
          label: 'Android extra $index',
          defaultPrice: index.toDouble(),
        ),
      ),
    );
    VanQuoteExtraDefaults? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  saved = await showModalBottomSheet<VanQuoteExtraDefaults>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => VanQuoteExtraDefaultsSheet(
                      initialDefaults: initial,
                      title: 'Service extras',
                    ),
                  );
                },
                child: const Text('Open extras'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open extras'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField).evaluate().length, lessThan(60));

    const labelKey = ValueKey('quote-extra-label-helper');
    const priceKey = ValueKey('quote-extra-price-helper');
    await tester.tap(find.byKey(labelKey));
    const rapidValue = 'Rapid Android service extra input';
    for (var length = 1; length <= rapidValue.length; length++) {
      tester.testTextInput.enterText(rapidValue.substring(0, length));
      await tester.pump();
    }
    await tester.enterText(find.byKey(priceKey), '42.75');
    await tester.enterText(find.byKey(priceKey), '42.756');
    await tester.pump();

    expect(saved, isNull);
    expect(
      tester.widget<TextField>(find.byKey(labelKey)).controller!.text,
      rapidValue,
    );
    expect(
      tester.widget<TextField>(find.byKey(priceKey)).controller!.text,
      '42.75',
    );

    final position = _extrasScrollPosition(tester);
    position.jumpTo(
      (position.pixels + 1600).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
    position.jumpTo(position.minScrollExtent);
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(labelKey)).controller!.text,
      rapidValue,
    );
    await _scrollUntilBuilt(tester, find.text('Save extras'));
    await tester.tap(find.text('Save extras'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(
      saved!.extraForKey(kVanQuoteExtraHelperKey).resolvedLabel,
      rapidValue,
    );
    expect(saved!.extraForKey(kVanQuoteExtraHelperKey).defaultPrice, 42.75);
  });
}

Future<void> _scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    final position = _extrasScrollPosition(tester);
    position.jumpTo(
      (position.pixels + 300).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

ScrollPosition _extrasScrollPosition(WidgetTester tester) {
  final scrollable = find
      .descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Scrollable),
      )
      .first;
  return tester.state<ScrollableState>(scrollable).position;
}
