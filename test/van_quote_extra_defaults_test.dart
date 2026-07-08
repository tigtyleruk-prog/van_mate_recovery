import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/widgets/van_quote_extra_defaults_sheet.dart';

void main() {
  group('VanQuoteExtraDefaults', () {
    test('uses sensible quote extra defaults', () {
      final defaults = VanQuoteExtraDefaults.defaults();

      expect(defaults.extraForKey(kVanQuoteExtraHelperKey).defaultPrice, 20);
      expect(
        defaults.extraForKey(kVanQuoteExtraWaitingTimeKey).defaultPrice,
        10,
      );
      expect(defaults.extraForKey(kVanQuoteExtraStairsKey).defaultPrice, 10);
      expect(defaults.extraForKey(kVanQuoteExtraMileageKey).defaultPrice, 0);
      expect(
        defaults.extraForKey(kVanQuoteExtraCollectionDeliveryKey).defaultPrice,
        0,
      );
      expect(defaults.extraForKey(kVanQuoteExtraCustomKey).defaultPrice, 0);
      expect(
        defaults.enabledExtras,
        hasLength(kVanQuoteExtraDefaultOrder.length),
      );
    });

    test('round trips custom labels, prices, and visibility', () {
      final edited = VanQuoteExtraDefaults.defaults()
          .copyWithExtra(
            VanQuoteExtraDefault.fallback(
              kVanQuoteExtraCustomKey,
            ).copyWith(label: 'Packing materials', defaultPrice: 12.5),
          )
          .copyWithExtra(
            VanQuoteExtraDefault.fallback(
              kVanQuoteExtraMileageKey,
            ).copyWith(enabled: false),
          );

      final restored = VanQuoteExtraDefaults.fromJson(edited.toJson());

      expect(
        restored.extraForKey(kVanQuoteExtraCustomKey).resolvedLabel,
        'Packing materials',
      );
      expect(restored.extraForKey(kVanQuoteExtraCustomKey).defaultPrice, 12.5);
      expect(restored.extraForKey(kVanQuoteExtraMileageKey).enabled, isFalse);
      expect(
        restored.enabledExtras.map((extra) => extra.key),
        isNot(contains(kVanQuoteExtraMileageKey)),
      );
    });

    test('serializes custom extra into quote extras settings document', () {
      final edited = VanQuoteExtraDefaults.defaults().copyWithExtra(
        VanQuoteExtraDefault.fallback(kVanQuoteExtraCustomKey).copyWith(
          label: 'Packing materials',
          defaultPrice: 12.5,
          enabled: true,
        ),
      );

      final json = edited.toJson();
      final extras = json['extras']! as Map<String, dynamic>;
      final custom = extras[kVanQuoteExtraCustomKey]! as Map<String, dynamic>;

      expect(custom['label'], 'Packing materials');
      expect(custom['defaultPrice'], 12.5);
      expect(custom['enabled'], isTrue);

      final restored = VanQuoteExtraDefaults.fromJson(<String, dynamic>{
        'id': 'quote_extras',
        'ownerUid': 'driver-1',
        ...json,
      });
      expect(
        restored.extraForKey(kVanQuoteExtraCustomKey).resolvedLabel,
        'Packing materials',
      );
      expect(restored.extraForKey(kVanQuoteExtraCustomKey).defaultPrice, 12.5);
      expect(restored.extraForKey(kVanQuoteExtraCustomKey).enabled, isTrue);
    });

    test('restores legacy flat custom extra fields', () {
      final restored = VanQuoteExtraDefaults.fromJson(<String, dynamic>{
        'id': 'quote_extras',
        'customExtraLabel': '3rd person',
        'customExtraPrice': '\u00A315',
        'customExtraEnabled': 'false',
      });

      final custom = restored.extraForKey(kVanQuoteExtraCustomKey);
      expect(custom.resolvedLabel, '3rd person');
      expect(custom.defaultPrice, 15);
      expect(custom.enabled, isFalse);
    });
  });

  testWidgets('saved custom extra reloads in settings sheet', (tester) async {
    final initial = VanQuoteExtraDefaults.defaults();
    VanQuoteExtraDefaults? saved;

    await pumpSettingsHost(tester, () => saved ?? initial, (value) {
      saved = value;
    });

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.enterText(_customLabelField(), '3rd person');
    await tester.enterText(_customPriceField(), '15');
    await tester.scrollUntilVisible(
      _customEnabledSwitch(),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(_customEnabledSwitch());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save extras'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save extras'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    final custom = saved!.extraForKey(kVanQuoteExtraCustomKey);
    expect(custom.resolvedLabel, '3rd person');
    expect(custom.defaultPrice, 15);
    expect(custom.enabled, isFalse);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[10].controller?.text, '3rd person');
    expect(fields[11].controller?.text, '15.00');
    expect(tester.widget<Switch>(_customEnabledSwitch()).value, isFalse);
  });

  group('VanQuoteExtraSelections', () {
    test('toggles fixed extras on and off', () {
      final helper = VanQuoteExtraDefault.fallback(kVanQuoteExtraHelperKey);

      final selected = VanQuoteExtraSelections.empty().toggleFixed(helper);
      expect(selected.selectionForKey(kVanQuoteExtraHelperKey), isNotNull);
      expect(selected.total, 20);
      expect(selected.quoteExtras, hasLength(1));

      final removed = selected.toggleFixed(helper);
      expect(removed.selectionForKey(kVanQuoteExtraHelperKey), isNull);
      expect(removed.total, 0);
      expect(removed.quoteExtras, isEmpty);
    });

    test('calculates waiting time decimal quantity from hourly rate', () {
      final waiting = VanQuoteExtraDefault.fallback(
        kVanQuoteExtraWaitingTimeKey,
      ).copyWith(defaultPrice: 10);

      final selected = VanQuoteExtraSelections.empty().applyQuantity(
        extra: waiting,
        quantity: 1.5,
      );

      final item = selected.selectionForKey(kVanQuoteExtraWaitingTimeKey);
      expect(item, isNotNull);
      expect(item!.amount, 15);
      expect(item.chipLabel, 'Waiting time £15.00');
      expect(item.quoteExtraLabel, 'Waiting time - 1.5h x £10.00/hr = £15.00');
    });

    test('calculates mileage decimal quantity from per-mile rate', () {
      final mileage = VanQuoteExtraDefault.fallback(
        kVanQuoteExtraMileageKey,
      ).copyWith(defaultPrice: 1);

      final selected = VanQuoteExtraSelections.empty().applyQuantity(
        extra: mileage,
        quantity: 1.5,
      );

      final item = selected.selectionForKey(kVanQuoteExtraMileageKey);
      expect(item, isNotNull);
      expect(item!.amount, 1.5);
      expect(item.chipLabel, 'Mileage £1.50');
      expect(item.quoteExtraLabel, 'Mileage - 1.5 miles x £1.00/mile = £1.50');
    });

    test('stores editable custom extra label and price', () {
      final custom = VanQuoteExtraDefault.fallback(kVanQuoteExtraCustomKey);

      final selected = VanQuoteExtraSelections.empty().applyCustom(
        extra: custom,
        label: 'Packing materials',
        price: 12.5,
      );

      final item = selected.selectionForKey(kVanQuoteExtraCustomKey);
      expect(item, isNotNull);
      expect(item!.label, 'Packing materials');
      expect(item.amount, 12.5);
      expect(item.chipLabel, 'Packing materials £12.50');
    });

    test('updates a selected quantity extra without duplicate quote lines', () {
      final waiting = VanQuoteExtraDefault.fallback(
        kVanQuoteExtraWaitingTimeKey,
      ).copyWith(defaultPrice: 10);

      final selected = VanQuoteExtraSelections.empty()
          .applyQuantity(extra: waiting, quantity: 1)
          .applyQuantity(extra: waiting, quantity: 2);

      expect(selected.total, 20);
      expect(selected.quoteExtras, hasLength(1));
      expect(
        selected.selectionForKey(kVanQuoteExtraWaitingTimeKey)!.amount,
        20,
      );
    });
  });
}

Future<void> pumpSettingsHost(
  WidgetTester tester,
  VanQuoteExtraDefaults Function() defaults,
  ValueChanged<VanQuoteExtraDefaults> onSaved,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result =
                    await showModalBottomSheet<VanQuoteExtraDefaults>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => VanQuoteExtraDefaultsSheet(
                        initialDefaults: defaults(),
                      ),
                    );
                if (result != null) {
                  onSaved(result);
                }
              },
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _customLabelField() => find.byType(TextField).at(10);

Finder _customPriceField() => find.byType(TextField).at(11);

Finder _customEnabledSwitch() => find.byType(Switch).at(5);
