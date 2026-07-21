import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_template.dart';
import 'package:van_mate_app/features/van_mate/services/van_quote_extra_defaults_storage.dart';
import 'package:van_mate_app/features/van_mate/widgets/van_quote_extra_defaults_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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
      expect(
        defaults.extraForKey(kVanQuoteExtraThirdPersonKey).defaultPrice,
        20,
      );
      expect(defaults.customExtras, isEmpty);
      expect(
        defaults.enabledExtras,
        hasLength(kVanQuoteExtraDefaultOrder.length),
      );
    });

    test('round trips multiple custom labels, prices, and visibility', () {
      final edited = VanQuoteExtraDefaults.defaults()
          .copyWithExtra(
            VanQuoteExtraDefault.fallback(
              kVanQuoteExtraMileageKey,
            ).copyWith(enabled: false),
          )
          .copyWithCustomExtras(<VanQuoteExtraDefault>[
            VanQuoteExtraDefault.custom(
              key: 'custom_extra_packing_materials',
              label: 'Packing materials',
              defaultPrice: 12.5,
            ),
            VanQuoteExtraDefault.custom(
              key: 'custom_extra_4th_person',
              label: '4th person',
              defaultPrice: 15,
              enabled: false,
            ),
          ]);

      final restored = VanQuoteExtraDefaults.fromJson(edited.toJson());

      expect(restored.customExtras, hasLength(2));
      expect(restored.customExtras[0].resolvedLabel, 'Packing materials');
      expect(restored.customExtras[0].defaultPrice, 12.5);
      expect(restored.customExtras[1].resolvedLabel, '4th person');
      expect(restored.customExtras[1].defaultPrice, 15);
      expect(restored.customExtras[1].enabled, isFalse);
      expect(restored.extraForKey(kVanQuoteExtraMileageKey).enabled, isFalse);
      expect(
        restored.enabledExtras.map((extra) => extra.key),
        isNot(contains(kVanQuoteExtraMileageKey)),
      );
      expect(
        restored.enabledExtras.map((extra) => extra.resolvedLabel),
        contains('Packing materials'),
      );
    });

    test('serializes custom extras into quote extras settings document', () {
      final edited = VanQuoteExtraDefaults.defaults().copyWithCustomExtras([
        VanQuoteExtraDefault.custom(
          key: 'custom_extra_packing_materials',
          label: 'Packing materials',
          defaultPrice: 12.5,
          enabled: true,
        ),
      ]);

      final json = edited.toJson();
      final customExtras = json['customExtras']! as List<dynamic>;
      final custom = customExtras.single as Map<String, dynamic>;

      expect(custom['key'], 'custom_extra_packing_materials');
      expect(custom['label'], 'Packing materials');
      expect(custom['defaultPrice'], 12.5);
      expect(custom['enabled'], isTrue);

      final restored = VanQuoteExtraDefaults.fromJson(<String, dynamic>{
        'id': 'quote_extras',
        'ownerUid': 'driver-1',
        ...json,
      });
      expect(restored.customExtras, hasLength(1));
      expect(restored.customExtras.single.resolvedLabel, 'Packing materials');
      expect(restored.customExtras.single.defaultPrice, 12.5);
      expect(restored.customExtras.single.enabled, isTrue);
    });

    test(
      'migrates legacy flat custom extra fields into custom extras list',
      () {
        final restored = VanQuoteExtraDefaults.fromJson(<String, dynamic>{
          'id': 'quote_extras',
          'customExtraLabel': '3rd person',
          'customExtraPrice': '\u00A315',
          'customExtraEnabled': 'false',
        });

        expect(restored.customExtras, hasLength(1));
        final custom = restored.customExtras.single;
        expect(custom.resolvedLabel, '3rd person');
        expect(custom.defaultPrice, 15);
        expect(custom.enabled, isFalse);
      },
    );

    test('service names no longer provide starter extras', () {
      for (final name in <String>[
        'Courier',
        'Man & Van',
        'Removals',
        'Gardening',
        'Cleaning',
      ]) {
        expect(
          VanQuoteExtraDefaults.starterForServiceName(name).orderedExtras,
          isEmpty,
        );
      }
    });

    test('empty template library provides no declared extras', () {
      expect(kVanServiceTemplateCategories, isEmpty);
      expect(findVanServiceTemplateById('courier'), isNull);
    });

    test('custom service starts with no extras', () {
      final custom = VanQuoteExtraDefaults.starterForServiceName(
        'My bespoke service',
      );
      expect(custom.orderedExtras, isEmpty);
      expect(custom.customExtras, isEmpty);
    });

    test(
      'legacy automatic generic seeds are removed without label matching',
      () {
        final legacy = <String, dynamic>{
          'extras': <String, dynamic>{
            for (final key in kVanQuoteExtraDefaultOrder)
              key: VanQuoteExtraDefault.fallback(
                key,
              ).copyWith(enabled: false).toJson(),
          },
          'customExtras': <Map<String, dynamic>>[
            VanQuoteExtraDefault.custom(
              key: 'custom_extra_user_helper',
              label: 'Extra helper',
              defaultPrice: 45,
            ).toJson(),
          ],
        };

        final migrated = VanQuoteExtraDefaults.fromJson(
          legacy,
          legacyIncludedBuiltInKeys: const <String>{},
        );

        expect(migrated.includedBuiltInKeys, isEmpty);
        expect(migrated.orderedExtras, hasLength(1));
        expect(migrated.orderedExtras.single.key, 'custom_extra_user_helper');
        expect(migrated.orderedExtras.single.resolvedLabel, 'Extra helper');
      },
    );

    test('legacy edited built-in survives service migration', () {
      final legacy = VanQuoteExtraDefaults.defaults().toJson();
      final extras = Map<String, dynamic>.from(legacy['extras']! as Map);
      extras[kVanQuoteExtraHelperKey] = VanQuoteExtraDefault.fallback(
        kVanQuoteExtraHelperKey,
      ).copyWith(label: 'Two-person lift', defaultPrice: 35).toJson();
      legacy
        ..remove('includedBuiltInKeys')
        ..['extras'] = extras;

      final migrated = VanQuoteExtraDefaults.fromJson(
        legacy,
        legacyIncludedBuiltInKeys: const <String>{},
      );

      expect(migrated.orderedExtras, hasLength(1));
      expect(migrated.orderedExtras.single.resolvedLabel, 'Two-person lift');
    });

    test(
      'reset restores explicit defaults and retains service custom extras',
      () {
        final explicitDefaults = VanQuoteExtraDefaults.empty()
            .copyWithCustomExtras(<VanQuoteExtraDefault>[
              VanQuoteExtraDefault.custom(
                key: 'custom_extra_materials',
                label: 'Materials',
                defaultPrice: 25,
              ),
            ]);
        final edited = explicitDefaults
            .copyWithCustomExtras(<VanQuoteExtraDefault>[
              ...explicitDefaults.customExtras,
              VanQuoteExtraDefault.custom(
                key: 'custom_extra_soil_disposal',
                label: 'Soil disposal',
                defaultPrice: 20,
              ),
            ]);

        final reset = edited.resetToStarter(explicitDefaults);

        expect(
          reset.orderedExtras.map((extra) => extra.resolvedLabel),
          <String>['Materials', 'Soil disposal'],
        );
        expect(
          reset.orderedExtras.map((extra) => extra.resolvedLabel),
          isNot(contains('Extra helper')),
        );
      },
    );

    test('manually configured services keep their own quote extras', () {
      final now = DateTime(2026, 7, 10);
      final service = VanJobService(
        id: 'gardening',
        name: 'Gardening',
        description: '',
        isActive: true,
        requestPhotos: false,
        requireAddress: true,
        requestExactPinAfterQuoteAccepted: false,
        linkedQuestionIds: const <String>[],
        quoteExtraDefaults: VanQuoteExtraDefaults.empty()
            .copyWithCustomExtras(<VanQuoteExtraDefault>[
              VanQuoteExtraDefault.custom(
                key: 'custom_extra_manual',
                label: 'Manual extra',
                defaultPrice: 18,
              ),
            ]),
        createdAt: now,
        updatedAt: now,
      );

      final restored = VanJobService.fromJson(service.toJson());

      expect(restored.quoteExtraDefaults.enabledExtras, hasLength(1));
      expect(
        restored.quoteExtraDefaults.enabledExtras.map(
          (extra) => extra.resolvedLabel,
        ),
        contains('Manual extra'),
      );
    });
  });

  test(
    'stores service extras without overwriting global or other service extras',
    () async {
      final storage = VanQuoteExtraDefaultsStorage.instance;
      await storage.save(
        VanQuoteExtraDefaults.defaults()
            .copyWithCustomExtras(<VanQuoteExtraDefault>[
              VanQuoteExtraDefault.custom(
                key: 'custom_extra_global_only',
                label: 'Global only',
                defaultPrice: 99,
              ),
            ]),
      );

      await storage.saveForService(
        serviceKey: 'cleaning-service',
        serviceName: 'Cleaning',
        defaults: VanQuoteExtraDefaults.starterForServiceName('Cleaning')
            .copyWithCustomExtras(<VanQuoteExtraDefault>[
              VanQuoteExtraDefault.custom(
                key: 'custom_extra_cleaning_service_only',
                label: 'Cleaning service only',
                defaultPrice: 25,
              ),
            ]),
      );
      await storage.saveForService(
        serviceKey: 'gardening-service',
        serviceName: 'Gardening',
        defaults: VanQuoteExtraDefaults.starterForServiceName('Gardening')
            .copyWithCustomExtras(<VanQuoteExtraDefault>[
              VanQuoteExtraDefault.custom(
                key: 'custom_extra_gardening_service_only',
                label: 'Gardening service only',
                defaultPrice: 30,
              ),
            ]),
      );

      final global = await storage.load(preferLocal: true);
      final cleaning = await storage.loadForService(
        serviceKey: 'cleaning-service',
        serviceName: 'Cleaning',
        preferLocal: true,
      );
      final gardening = await storage.loadForService(
        serviceKey: 'gardening-service',
        serviceName: 'Gardening',
        preferLocal: true,
      );

      expect(
        global.enabledExtras.map((extra) => extra.resolvedLabel),
        contains('Global only'),
      );
      expect(
        cleaning.enabledExtras.map((extra) => extra.resolvedLabel),
        contains('Cleaning service only'),
      );
      expect(
        cleaning.enabledExtras.map((extra) => extra.resolvedLabel),
        isNot(contains('Global only')),
      );
      expect(
        cleaning.enabledExtras.map((extra) => extra.resolvedLabel),
        isNot(contains('Gardening service only')),
      );
      expect(
        gardening.enabledExtras.map((extra) => extra.resolvedLabel),
        contains('Gardening service only'),
      );
      expect(
        gardening.enabledExtras.map((extra) => extra.resolvedLabel),
        isNot(contains('Cleaning service only')),
      );
    },
  );

  testWidgets('saved custom extras can be added, reloaded, and deleted', (
    tester,
  ) async {
    final initial = VanQuoteExtraDefaults.defaults();
    VanQuoteExtraDefaults? saved;

    await pumpSettingsHost(tester, () => saved ?? initial, (value) {
      saved = value;
    });

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await _scrollUntilBuilt(tester, find.text('Add custom extra'));
    await tester.tap(find.text('Add custom extra'));
    await tester.pumpAndSettle();
    await _enterLastCustomExtra(tester, label: '4th person', price: '15');

    await _scrollUntilBuilt(tester, find.text('Save extras'));
    await tester.tap(find.text('Save extras'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.customExtras, hasLength(1));
    final custom = saved!.customExtras.single;
    expect(custom.resolvedLabel, '4th person');
    expect(custom.defaultPrice, 15);
    expect(custom.enabled, isTrue);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    await _scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('quote-extra-label-custom_extra_item_1')),
    );

    expect(_textFieldValues(tester), contains('4th person'));
    expect(_textFieldValues(tester), contains('15.00'));

    await _scrollUntilBuilt(tester, find.byTooltip('Delete custom extra'));
    await tester.tap(find.byTooltip('Delete custom extra'));
    await tester.pumpAndSettle();
    await _scrollUntilBuilt(tester, find.text('Save extras'));
    await tester.tap(find.text('Save extras'));
    await tester.pumpAndSettle();

    expect(saved!.customExtras, isEmpty);
  });

  testWidgets('extras editor lazily builds rows and keeps rapid edits local', (
    tester,
  ) async {
    final customExtras = List<VanQuoteExtraDefault>.generate(
      24,
      (index) => VanQuoteExtraDefault.custom(
        key: 'custom_extra_test_$index',
        label: 'Test extra $index',
        defaultPrice: index.toDouble(),
      ),
    );
    final initial = VanQuoteExtraDefaults.defaults().copyWithCustomExtras(
      customExtras,
    );
    VanQuoteExtraDefaults? saved;

    await pumpSettingsHost(tester, () => initial, (value) {
      saved = value;
    });
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField).evaluate().length, lessThan(60));

    const labelKey = ValueKey('quote-extra-label-helper');
    await _scrollUntilBuilt(tester, find.byKey(labelKey));
    await tester.tap(find.byKey(labelKey));
    for (final value in <String>[
      'R',
      'Ra',
      'Rap',
      'Rapi',
      'Rapid',
      'Rapid ',
      'Rapid e',
      'Rapid ed',
      'Rapid edi',
      'Rapid edit',
    ]) {
      tester.testTextInput.enterText(value);
      await tester.pump();
    }

    expect(saved, isNull);
    expect(
      tester.widget<TextField>(find.byKey(labelKey)).controller!.text,
      'Rapid edit',
    );

    final labelFocusNode = tester
        .widget<TextField>(find.byKey(labelKey))
        .focusNode;
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 2);
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(labelKey)).controller!.text,
      'Rapid edit',
    );
    expect(
      tester.widget<TextField>(find.byKey(labelKey)).focusNode,
      same(labelFocusNode),
    );
    expect(labelFocusNode!.hasFocus, isTrue);

    final scrollPosition = _extrasScrollPosition(tester);
    scrollPosition.jumpTo(
      (scrollPosition.pixels + 1600).clamp(
        scrollPosition.minScrollExtent,
        scrollPosition.maxScrollExtent,
      ),
    );
    await tester.pump();
    scrollPosition.jumpTo(scrollPosition.minScrollExtent);
    await tester.pump();
    await _scrollUntilBuilt(tester, find.byKey(labelKey));

    expect(
      tester.widget<TextField>(find.byKey(labelKey)).controller!.text,
      'Rapid edit',
    );
    expect(saved, isNull);
  });

  testWidgets('default price accepts currency decimals and saves on submit', (
    tester,
  ) async {
    final initial = VanQuoteExtraDefaults.defaults();
    VanQuoteExtraDefaults? saved;

    await pumpSettingsHost(tester, () => initial, (value) {
      saved = value;
    });
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    const priceKey = ValueKey('quote-extra-price-helper');
    await _scrollUntilBuilt(tester, find.byKey(priceKey));
    await tester.enterText(find.byKey(priceKey), '12.34');
    await tester.enterText(find.byKey(priceKey), '12.345');
    await tester.pump();

    expect(saved, isNull);
    expect(
      tester.widget<TextField>(find.byKey(priceKey)).controller!.text,
      '12.34',
    );

    await _scrollUntilBuilt(tester, find.text('Save extras'));
    await tester.tap(find.text('Save extras'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.extraForKey(kVanQuoteExtraHelperKey).defaultPrice, 12.34);
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

    test('toggles saved custom extra label and price', () {
      final custom = VanQuoteExtraDefault.custom(
        key: 'custom_extra_4th_person',
        label: '4th person',
        defaultPrice: 15,
      );

      final selected = VanQuoteExtraSelections.empty().toggleFixed(custom);

      final item = selected.selectionForKey('custom_extra_4th_person');
      expect(item, isNotNull);
      expect(item!.label, '4th person');
      expect(item.amount, 15);
      expect(item.chipLabel, '4th person £15.00');
      expect(selected.quoteExtras, contains('4th person - £15.00'));
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

Future<void> _enterLastCustomExtra(
  WidgetTester tester, {
  required String label,
  required String price,
}) async {
  const labelKey = ValueKey('quote-extra-label-custom_extra_item_1');
  const priceKey = ValueKey('quote-extra-price-custom_extra_item_1');
  await _scrollUntilBuilt(tester, find.byKey(labelKey));
  await tester.enterText(find.byKey(labelKey), label);
  await tester.enterText(find.byKey(priceKey), price);
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
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

List<String> _textFieldValues(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((field) => field.controller?.text ?? '')
      .toList(growable: false);
}
