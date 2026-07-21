import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_starter_capability_pack.dart';
import 'package:van_mate_app/features/van_mate/pages/van_job_types_services_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_hub_onboarding_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await VanBusinessHubOnboardingStorage.instance
        .dismissServiceDetailSettingsHelp();
  });

  testWidgets('guided extras are directly editable and persist per service', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(390, 850));
    final first = _service('direct', 'Scheduled Delivery');
    final second = _service('untouched', 'Legal Document Delivery');
    final secondBefore = second.toJson();
    await _seed(<VanJobService>[first, second]);

    await _pumpGuided(tester, first, <String>[first.id, second.id]);
    await _goToExtras(tester);

    expect(find.text('Pricing extras'), findsOneWidget);
    expect(find.text('Waiting time'), findsOneWidget);
    expect(find.text('Enable, edit or add extras'), findsNothing);
    final price = find.byKey(
      const ValueKey<String>('guided-extra-price-direct-waiting_time'),
    );
    final toggle = find.byKey(
      const ValueKey<String>('guided-extra-enabled-direct-waiting_time'),
    );
    expect(price, findsOneWidget);
    await tester.ensureVisible(price);
    await tester.enterText(price, '27.50');
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    await _tapNext(tester);

    expect(find.textContaining('Availability'), findsWidgets);
    final stored = await VanJobServicesStorage.instance.loadAll();
    final updated = stored.singleWhere((service) => service.id == first.id);
    final untouched = stored.singleWhere((service) => service.id == second.id);
    final waiting = updated.quoteExtraDefaults.extraForKey(
      kVanQuoteExtraWaitingTimeKey,
    );
    expect(waiting.defaultPrice, 27.5);
    expect(waiting.enabled, isFalse);
    expect(untouched.toJson(), equals(secondBefore));
  });

  testWidgets('adding a custom extra affects only the reviewed service', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(390, 850));
    final first = _service('custom-target', 'Multi-drop Delivery');
    final second = _service('custom-other', 'Medical Delivery');
    final secondBefore = second.toJson();
    await _seed(<VanJobService>[first, second]);

    await _pumpGuided(tester, first, <String>[first.id, second.id]);
    await _goToExtras(tester);
    final add = find.byKey(const Key('guided_extras_add_custom'));
    await tester.tap(add);
    await tester.pumpAndSettle();
    const newLabelKey = ValueKey<String>(
      'guided-extra-label-custom-target-custom_extra_item_1',
    );
    final newLabel = find.byKey(newLabelKey);
    expect(newLabel, findsOneWidget);
    expect(tester.widget<TextField>(newLabel).focusNode!.hasFocus, isTrue);
    final newCard = find.byKey(
      const ValueKey<String>('guided-extra-custom-target-custom_extra_item_1'),
    );
    final cardRect = tester.getRect(newCard);
    expect(cardRect.top, greaterThanOrEqualTo(0));
    expect(cardRect.bottom, lessThanOrEqualTo(850));
    expect(
      tester.getTopLeft(newCard).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>(
                  'guided-extra-custom-target-waiting_time',
                ),
              ),
            )
            .dy,
      ),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byKey(newLabelKey), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'guided-extra-label-custom-target-custom_extra_item_2',
        ),
      ),
      findsNothing,
    );
    expect(tester.widget<TextField>(newLabel).focusNode!.hasFocus, isTrue);
    await tester.enterText(newLabel, 'Weekend surcharge');
    await tester.pump();

    expect(find.text('Weekend surcharge'), findsOneWidget);
    expect(find.text('Custom extra'), findsNothing);
    final price = find.byKey(
      const ValueKey<String>(
        'guided-extra-price-custom-target-custom_extra_item_1',
      ),
    );
    await tester.ensureVisible(price);
    await tester.enterText(price, '12');
    await _tapNext(tester);

    final stored = await VanJobServicesStorage.instance.loadAll();
    final updated = stored.singleWhere((service) => service.id == first.id);
    final untouched = stored.singleWhere((service) => service.id == second.id);
    final custom = updated.quoteExtraDefaults.customExtras.singleWhere(
      (extra) => extra.resolvedLabel == 'Weekend surcharge',
    );
    expect(custom.defaultPrice, 12);
    expect(custom.enabled, isTrue);
    expect(untouched.toJson(), equals(secondBefore));
  });

  testWidgets('Use Defaults restores curated extras then opens Availability', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(390, 850));
    final pack = findVanStarterCapabilityPackById('courier_business')!;
    final setup = pack.recommendationsFor(const <String>[
      'same_day_delivery',
    ]).single;
    final curated = setup.quoteExtraDefaults();
    final altered = curated.copyWithExtra(
      curated
          .extraForKey(kVanQuoteExtraMileageKey)
          .copyWith(defaultPrice: 99, enabled: false),
    );
    final service =
        _service(
          'defaults-target',
          'Same-day Delivery',
          extras: altered,
        ).copyWith(
          starterPackId: pack.id,
          starterTemplateId: setup.serviceKey,
          serviceCapabilityIds: setup.capabilityIds,
        );
    await _seed(<VanJobService>[service]);

    await _pumpGuided(tester, service, <String>[service.id]);
    await _goToExtras(tester);
    final defaultsButton = find.byKey(const Key('service_review_use_defaults'));
    await tester.scrollUntilVisible(
      defaultsButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(defaultsButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Availability'), findsWidgets);
    final stored = (await VanJobServicesStorage.instance.loadAll()).single;
    expect(stored.quoteExtraDefaults.toJson(), equals(curated.toJson()));
  });

  testWidgets('guided extras stay compact without overflow at 360 pixels', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(360, 800));
    final extras = VanQuoteExtraDefaults.empty()
        .copyWithExtra(
          VanQuoteExtraDefault.fallback(
            kVanQuoteExtraWaitingTimeKey,
          ).copyWith(label: 'Waiting time after the included allowance'),
        )
        .copyWithCustomExtras(<VanQuoteExtraDefault>[
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_weekend',
            label: 'Weekend and bank holiday surcharge',
            defaultPrice: 20,
          ),
        ]);
    final service = _service('narrow', 'Narrow Service', extras: extras);
    await _seed(<VanJobService>[service]);

    await _pumpGuided(tester, service, <String>[service.id]);
    await _goToExtras(tester);
    final price = find.byKey(
      const ValueKey<String>('guided-extra-price-narrow-waiting_time'),
    );
    await tester.scrollUntilVisible(
      price,
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(price, findsOneWidget);
    expect(tester.getSize(price).width, greaterThan(90));
    expect(
      find.byKey(
        const ValueKey<String>('guided-extra-enabled-narrow-waiting_time'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('guided-extra-delete-narrow-waiting_time'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('guided-extra-reorder-narrow-waiting_time'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline delete and reorder persist in the reviewed service', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(390, 850));
    final extras = VanQuoteExtraDefaults.empty()
        .copyWithExtra(
          VanQuoteExtraDefault.fallback(kVanQuoteExtraWaitingTimeKey),
        )
        .copyWithCustomExtras(<VanQuoteExtraDefault>[
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_weekend',
            label: 'Weekend surcharge',
            defaultPrice: 20,
          ),
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_signature',
            label: 'Signature service',
            defaultPrice: 5,
          ),
        ]);
    final service = _service('order-target', 'Ordered extras', extras: extras);
    await _seed(<VanJobService>[service]);

    await _pumpGuided(tester, service, <String>[service.id]);
    await _goToExtras(tester);
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 3);
    await tester.pump();
    final delete = find.byKey(
      const ValueKey<String>(
        'guided-extra-delete-order-target-custom_extra_weekend',
      ),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pump();
    await _tapNext(tester);

    final stored = (await VanJobServicesStorage.instance.loadAll()).single;
    expect(
      stored.quoteExtraDefaults.customExtras.map((extra) => extra.key),
      isNot(contains('custom_extra_weekend')),
    );
    expect(
      stored.quoteExtraDefaults.orderedExtras.map((extra) => extra.key),
      <String>['custom_extra_signature', kVanQuoteExtraWaitingTimeKey],
    );
  });

  testWidgets('Service Detail still opens the separate extras editor', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(390, 850));
    final detailExtras = VanQuoteExtraDefaults.empty()
        .copyWithExtra(
          VanQuoteExtraDefault.fallback(kVanQuoteExtraWaitingTimeKey),
        )
        .copyWithCustomExtras(<VanQuoteExtraDefault>[
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_signature',
            label: 'Signature service',
            defaultPrice: 5,
          ),
        ]);
    final service = _service('detail', 'Detail Delivery', extras: detailExtras);
    await _seed(<VanJobService>[service]);

    await tester.pumpWidget(
      MaterialApp(home: VanJobServiceDetailPage(serviceId: service.id)),
    );
    await tester.pumpAndSettle();
    final edit = find.widgetWithText(OutlinedButton, 'Edit extras');
    await tester.scrollUntilVisible(
      edit,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();

    expect(find.text('Detail Delivery extras'), findsOneWidget);
    expect(find.text('Add custom extra'), findsOneWidget);
    expect(find.text('Save extras'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('quote-extra-price-waiting_time')),
      findsOneWidget,
    );
    final add = find.text('Add custom extra');
    await tester.tap(add);
    await tester.pumpAndSettle();
    const labelKey = ValueKey<String>('quote-extra-label-custom_extra_item_2');
    final label = find.byKey(labelKey);
    final newRow = find.byKey(
      const ValueKey<String>('quote-extra-row-custom_extra_item_2'),
    );
    expect(label, findsOneWidget);
    expect(tester.widget<TextField>(label).focusNode!.hasFocus, isTrue);
    final rowRect = tester.getRect(newRow);
    expect(rowRect.top, greaterThanOrEqualTo(0));
    expect(rowRect.bottom, lessThanOrEqualTo(850));
    expect(
      tester.getTopLeft(newRow).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>('quote-extra-row-waiting_time'),
              ),
            )
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('quote-extra-row-waiting_time')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>(
                  'quote-extra-row-custom_extra_signature',
                ),
              ),
            )
            .dy,
      ),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byKey(labelKey), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('quote-extra-label-custom_extra_item_3'),
      ),
      findsNothing,
    );
    expect(tester.widget<TextField>(label).focusNode!.hasFocus, isTrue);

    await tester.enterText(label, 'Weekend surcharge');
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('quote-extra-price-custom_extra_item_2'),
      ),
      '12',
    );
    final save = find.text('Save extras');
    await _scrollExtrasUntilBuilt(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final stored = (await VanJobServicesStorage.instance.loadAll()).single;
    final added = stored.quoteExtraDefaults.customExtras.singleWhere(
      (extra) => extra.resolvedLabel == 'Weekend surcharge',
    );
    expect(added.defaultPrice, 12);
  });
}

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _seed(List<VanJobService> services) =>
    VanJobServicesStorage.instance.saveAll(services, syncCloud: false);

Future<void> _pumpGuided(
  WidgetTester tester,
  VanJobService service,
  List<String> serviceIds,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VanJobServiceDetailPage(
        serviceId: service.id,
        reviewServiceIds: serviceIds,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _goToExtras(WidgetTester tester) async {
  await _tapNext(tester);
  await _tapNext(tester);
  expect(find.textContaining('Pricing Extras'), findsWidgets);
}

Future<void> _tapNext(WidgetTester tester) async {
  final next = find.byKey(const Key('service_review_next'));
  await tester.scrollUntilVisible(
    next,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> _scrollExtrasUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
    final scrollable = find
        .descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(
      (position.pixels + 300).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pump();
}

VanJobService _service(
  String id,
  String name, {
  VanQuoteExtraDefaults? extras,
}) {
  final now = DateTime.utc(2026, 7, 21, 10);
  return VanJobService(
    id: id,
    name: name,
    description: 'Pricing extras test service.',
    isActive: true,
    requestPhotos: false,
    requireAddress: true,
    requestExactPinAfterQuoteAccepted: false,
    linkedQuestionIds: const <String>[],
    quoteExtraDefaults:
        extras ??
        VanQuoteExtraDefaults.empty().copyWithExtra(
          VanQuoteExtraDefault.fallback(
            kVanQuoteExtraWaitingTimeKey,
          ).copyWith(label: 'Waiting time', defaultPrice: 15),
        ),
    createdAt: now,
    updatedAt: now,
    serviceCapabilityIds: const <String>['booking', 'request_quote'],
    capabilitySchemaVersion: 1,
    creationSource: 'capabilityBuilder',
  );
}
