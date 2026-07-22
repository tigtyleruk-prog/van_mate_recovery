import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
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

  testWidgets(
    'manual availability starts empty and saves independent grouped hours',
    (tester) async {
      await _setPhoneSize(tester, const Size(360, 900));
      final service = _service(
        'grouped-hours',
        availabilityByDay: _weekdaySchedules(),
      );
      await _seed(<VanJobService>[service]);
      await _pumpGuidedReview(tester, <VanJobService>[service]);
      await _openAvailability(tester);

      for (var day = 1; day <= 7; day++) {
        final chip = tester.widget<FilterChip>(
          find.byKey(ValueKey<String>('guided-availability-day-$day')),
        );
        expect(chip.selected, isFalse);
      }
      expect(
        find.byKey(
          const ValueKey<String>(
            'guided-availability-schedule-grouped-hours-1',
          ),
        ),
        findsNothing,
      );

      await _selectDay(tester, 1);
      await _applyDayTo(tester, 1, <int>[3]);
      await _selectDay(tester, 2);
      await _setClosingHour(tester, 2, '8');
      await _applyDayTo(tester, 2, <int>[4, 5]);

      expect(find.text('Closes 5:00 PM'), findsNWidgets(2));
      expect(find.text('Closes 8:00 PM'), findsNWidgets(3));
      expect(find.text('Saturday'), findsNothing);
      expect(find.text('Sunday'), findsNothing);

      await _selectDay(tester, 7);
      expect(find.text('Sunday'), findsOneWidget);
      await _selectDay(tester, 7);
      expect(find.text('Sunday'), findsNothing);
      expect(tester.takeException(), isNull);

      await _tapReviewNext(tester);
      final saved = (await VanJobServicesStorage.instance.loadAll()).single;
      expect(saved.effectiveAvailabilityByDay.keys, <int>[1, 2, 3, 4, 5]);
      expect(saved.effectiveAvailabilityByDay[1]!.startMinutes, 9 * 60);
      expect(saved.effectiveAvailabilityByDay[1]!.endMinutes, 17 * 60);
      expect(saved.effectiveAvailabilityByDay[3]!.endMinutes, 17 * 60);
      expect(saved.effectiveAvailabilityByDay[2]!.endMinutes, 20 * 60);
      expect(saved.effectiveAvailabilityByDay[4]!.endMinutes, 20 * 60);
      expect(saved.effectiveAvailabilityByDay[5]!.endMinutes, 20 * 60);
      expect(saved.effectiveAvailabilityByDay.containsKey(7), isFalse);
    },
  );

  testWidgets('manual continue validates that at least one day is selected', (
    tester,
  ) async {
    final service = _service('validation');
    await _seed(<VanJobService>[service]);
    await _pumpGuidedReview(tester, <VanJobService>[service]);
    await _openAvailability(tester);

    await _tapReviewNext(tester);

    expect(find.text('Choose at least one working day.'), findsOneWidget);
    expect(find.text('4 of 4 · Availability'), findsOneWidget);
  });

  testWidgets('Use Defaults applies the original curated availability', (
    tester,
  ) async {
    final service = _service(
      'curated-defaults',
      availabilityByDay: const <int, VanServiceDaySchedule>{
        1: VanServiceDaySchedule(startMinutes: 0, endMinutes: 24 * 60 - 1),
        2: VanServiceDaySchedule(startMinutes: 0, endMinutes: 24 * 60 - 1),
        3: VanServiceDaySchedule(startMinutes: 0, endMinutes: 24 * 60 - 1),
        4: VanServiceDaySchedule(startMinutes: 0, endMinutes: 24 * 60 - 1),
        5: VanServiceDaySchedule(startMinutes: 0, endMinutes: 24 * 60 - 1),
        6: VanServiceDaySchedule(startMinutes: 0, endMinutes: 24 * 60 - 1),
        7: VanServiceDaySchedule(startMinutes: 0, endMinutes: 24 * 60 - 1),
      },
    );
    await _seed(<VanJobService>[service]);
    await _pumpGuidedReview(tester, <VanJobService>[service]);
    await _openAvailability(tester);

    expect(_selectedDayCount(tester), 0);
    await _selectDay(tester, 1);
    expect(_selectedDayCount(tester), 1);
    await _tapTextButton(tester, 'Use Defaults & Finish');
    expect(find.text('4 of 4 · Availability'), findsNothing);

    final saved = (await VanJobServicesStorage.instance.loadAll()).single;
    expect(saved.effectiveAvailabilityByDay.keys, <int>[1, 2, 3, 4, 5, 6, 7]);
    expect(saved.effectiveAvailabilityByDay[7]!.startMinutes, 0);
    expect(saved.effectiveAvailabilityByDay[7]!.endMinutes, 24 * 60 - 1);
  });

  testWidgets('reviewed services keep completely independent schedules', (
    tester,
  ) async {
    final first = _service('first-service');
    final second = _service('second-service');
    await _seed(<VanJobService>[first, second]);
    await _pumpGuidedReview(tester, <VanJobService>[first, second]);
    await _openAvailability(tester);

    await _selectDay(tester, 1);
    await _tapReviewNext(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Service 2 of 2'), findsOneWidget);
    await _openAvailability(tester);
    expect(_selectedDayCount(tester), 0);
    await _selectDay(tester, 2);
    await _tapReviewNext(tester);

    final saved = await VanJobServicesStorage.instance.loadAll();
    final savedFirst = saved.singleWhere((item) => item.id == first.id);
    final savedSecond = saved.singleWhere((item) => item.id == second.id);
    expect(savedFirst.effectiveAvailabilityByDay.keys, <int>[1]);
    expect(savedSecond.effectiveAvailabilityByDay.keys, <int>[2]);
  });

  testWidgets('existing Service Detail edits and saves its per-day schedule', (
    tester,
  ) async {
    final service = _service(
      'existing-service',
      availabilityByDay: const <int, VanServiceDaySchedule>{
        1: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
        2: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 20 * 60),
      },
    );
    await _seed(<VanJobService>[service]);
    await tester.pumpWidget(
      MaterialApp(home: VanJobServiceDetailPage(serviceId: service.id)),
    );
    await tester.pumpAndSettle();
    await _tapTextButton(tester, 'Configure in Service Wizard');
    await _openAvailability(tester);

    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Closes 5:00 PM'), findsOneWidget);
    expect(find.text('Closes 8:00 PM'), findsOneWidget);
    await _chooseCustom(
      tester,
      const Key('guided-duration-dropdown'),
      'Custom duration…',
    );
    await tester.enterText(
      find.byKey(const Key('guided-custom-duration-input')),
      '75',
    );
    await tester.pumpAndSettle();
    await _selectDay(tester, 2);
    await _tapReviewNext(tester);

    final saved = (await VanJobServicesStorage.instance.loadAll()).single;
    expect(saved.effectiveAvailabilityByDay.keys, <int>[1]);
    expect(saved.effectiveAvailabilityByDay[1]!.endMinutes, 17 * 60);
    expect(saved.appointmentDurationMinutes, 75);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy shared hours load in Service Detail without data loss', (
    tester,
  ) async {
    final legacy = _service('legacy-shared').copyWith(
      workingDays: const <int>[1, 3, 5],
      businessStartMinutes: 7 * 60 + 30,
      businessEndMinutes: 19 * 60,
    );
    await _seed(<VanJobService>[legacy]);
    await tester.pumpWidget(
      MaterialApp(home: VanJobServiceDetailPage(serviceId: legacy.id)),
    );
    await tester.pumpAndSettle();
    await _tapTextButton(tester, 'Configure in Service Wizard');
    await _openAvailability(tester);

    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('Opens 7:30 AM'), findsNWidgets(3));
    expect(find.text('Closes 7:00 PM'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'custom values persist per service through next service and back navigation',
    (tester) async {
      await _setPhoneSize(tester, const Size(360, 1000));
      final first = _service('custom-first');
      final second = _service('preset-second').copyWith(
        appointmentDurationMinutes: 45,
        noticeHours: 2,
        maxBookingsPerDay: 4,
      );
      await _seed(<VanJobService>[first, second]);
      await _pumpGuidedReview(tester, <VanJobService>[first, second]);
      await _openAvailability(tester);
      await _selectDay(tester, 1);

      await _chooseCustom(
        tester,
        const Key('guided-duration-dropdown'),
        'Custom duration…',
      );
      final durationField = find.byKey(
        const Key('guided-custom-duration-input'),
      );
      expect(
        tester.widget<TextField>(durationField).focusNode?.hasFocus,
        isTrue,
      );
      await tester.enterText(durationField, '75');
      await tester.pumpAndSettle();

      await _chooseCustom(
        tester,
        const Key('guided-notice-dropdown'),
        'Custom notice…',
      );
      await _chooseDropdownValue(
        tester,
        const Key('guided-custom-notice-unit'),
        'Minutes',
      );
      await tester.enterText(
        find.byKey(const Key('guided-custom-notice-input')),
        '30',
      );
      await tester.pumpAndSettle();

      await _chooseCustom(
        tester,
        const Key('guided-booking-limit-dropdown'),
        'Custom booking limit…',
      );
      await tester.enterText(
        find.byKey(const Key('guided-custom-booking-limit-input')),
        '14',
      );
      await tester.pumpAndSettle();

      await _tapReviewNext(tester);
      expect(find.text('Service 2 of 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Service 1 of 2'), findsOneWidget);
      expect(find.text('75 minutes'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('14 bookings'), findsOneWidget);

      await _tapReviewNext(tester);
      expect(find.text('Service 2 of 2'), findsOneWidget);
      await _openAvailability(tester);
      expect(find.text('45 minutes'), findsOneWidget);
      expect(find.text('2 hours'), findsOneWidget);
      expect(find.text('4 bookings'), findsOneWidget);
      await _selectDay(tester, 2);
      await _tapReviewNext(tester);

      final saved = await VanJobServicesStorage.instance.loadAll();
      final savedFirst = saved.singleWhere((item) => item.id == first.id);
      final savedSecond = saved.singleWhere((item) => item.id == second.id);
      expect(savedFirst.appointmentDurationMinutes, 75);
      expect(savedFirst.noticeHours, .5);
      expect(savedFirst.maxBookingsPerDay, 14);
      expect(savedSecond.appointmentDurationMinutes, 45);
      expect(savedSecond.noticeHours, 2);
      expect(savedSecond.maxBookingsPerDay, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid custom value blocks continue and preset can replace it',
    (tester) async {
      final service = _service('custom-validation');
      await _seed(<VanJobService>[service]);
      await _pumpGuidedReview(tester, <VanJobService>[service]);
      await _openAvailability(tester);
      await _selectDay(tester, 1);
      await _chooseCustom(
        tester,
        const Key('guided-duration-dropdown'),
        'Custom duration…',
      );
      await tester.enterText(
        find.byKey(const Key('guided-custom-duration-input')),
        '',
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter a duration.'), findsOneWidget);
      await _tapReviewNext(tester);
      expect(find.text('Fix the custom availability values.'), findsOneWidget);
      expect(find.byKey(const Key('service_review_next')), findsOneWidget);

      await _chooseDropdownValue(
        tester,
        const Key('guided-duration-dropdown'),
        '60 minutes',
      );
      expect(
        find.byKey(const Key('guided-custom-duration-input')),
        findsNothing,
      );
      await _tapReviewNext(tester);
      final saved = (await VanJobServicesStorage.instance.loadAll()).single;
      expect(saved.appointmentDurationMinutes, 60);
    },
  );

  testWidgets('Use Defaults restores all values for only the active service', (
    tester,
  ) async {
    final first = _service('defaults-first');
    final second = _service('defaults-second').copyWith(
      appointmentDurationMinutes: 45,
      noticeHours: 2,
      maxBookingsPerDay: 4,
    );
    await _seed(<VanJobService>[first, second]);
    await _pumpGuidedReview(tester, <VanJobService>[first, second]);
    await _openAvailability(tester);
    await _chooseCustom(
      tester,
      const Key('guided-duration-dropdown'),
      'Custom duration…',
    );
    await tester.enterText(
      find.byKey(const Key('guided-custom-duration-input')),
      '75',
    );
    await tester.pumpAndSettle();
    await _selectDay(tester, 1);
    await _tapTextButton(tester, 'Use Defaults & Continue');

    await _openAvailability(tester);
    expect(find.text('45 minutes'), findsOneWidget);
    expect(find.text('2 hours'), findsOneWidget);
    expect(find.text('4 bookings'), findsOneWidget);
    await _selectDay(tester, 2);
    await _tapReviewNext(tester);

    final saved = await VanJobServicesStorage.instance.loadAll();
    final savedFirst = saved.singleWhere((item) => item.id == first.id);
    final savedSecond = saved.singleWhere((item) => item.id == second.id);
    expect(savedFirst.appointmentDurationMinutes, 60);
    expect(savedFirst.noticeHours, 24);
    expect(savedFirst.maxBookingsPerDay, 8);
    expect(savedSecond.appointmentDurationMinutes, 45);
    expect(savedSecond.noticeHours, 2);
    expect(savedSecond.maxBookingsPerDay, 4);
  });

  testWidgets('cancelling existing-service custom edits persists nothing', (
    tester,
  ) async {
    final service = _service('cancel-custom');
    await _seed(<VanJobService>[service]);
    await tester.pumpWidget(
      MaterialApp(home: VanJobServiceDetailPage(serviceId: service.id)),
    );
    await tester.pumpAndSettle();
    await _tapTextButton(tester, 'Configure in Service Wizard');
    await _openAvailability(tester);
    await _chooseCustom(
      tester,
      const Key('guided-duration-dropdown'),
      'Custom duration…',
    );
    await tester.enterText(
      find.byKey(const Key('guided-custom-duration-input')),
      '75',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final saved = (await VanJobServicesStorage.instance.loadAll()).single;
    expect(saved.appointmentDurationMinutes, 60);
    expect(saved.noticeHours, 24);
    expect(saved.maxBookingsPerDay, 8);
  });
}

Map<int, VanServiceDaySchedule> _weekdaySchedules() =>
    const <int, VanServiceDaySchedule>{
      1: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
      2: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
      3: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
      4: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
      5: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
    };

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _seed(List<VanJobService> services) =>
    VanJobServicesStorage.instance.saveAll(services, syncCloud: false);

Future<void> _pumpGuidedReview(
  WidgetTester tester,
  List<VanJobService> services,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VanJobServiceDetailPage(
        serviceId: services.first.id,
        reviewServiceIds: services.map((service) => service.id).toList(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAvailability(WidgetTester tester) async {
  if (find.text('4 of 4 · Availability').evaluate().isNotEmpty) return;
  for (var index = 0; index < 3; index++) {
    await _tapReviewNext(tester);
  }
  expect(find.text('4 of 4 · Availability'), findsOneWidget);
}

Future<void> _tapReviewNext(WidgetTester tester) async {
  final button = find.byKey(const Key('service_review_next'));
  await tester.scrollUntilVisible(
    button,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _selectDay(WidgetTester tester, int day) async {
  final chip = find.byKey(ValueKey<String>('guided-availability-day-$day'));
  final scrollable = find.byType(Scrollable).first;
  await tester.drag(scrollable, const Offset(0, 1200));
  await tester.pumpAndSettle();
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _applyDayTo(
  WidgetTester tester,
  int sourceDay,
  List<int> targetDays,
) async {
  final action = find.byKey(
    ValueKey<String>('guided-availability-apply-$sourceDay'),
  );
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
  for (final day in targetDays) {
    await tester.tap(
      find.byKey(ValueKey<String>('apply-availability-day-$day')),
    );
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('apply_availability_days')));
  await tester.pumpAndSettle();
}

Future<void> _setClosingHour(WidgetTester tester, int day, String hour) async {
  final action = find.byKey(
    ValueKey<String>('guided-availability-closes-$day'),
  );
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Switch to text input mode'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, hour);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _tapTextButton(WidgetTester tester, String label) async {
  final button = find.text(label);
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(button, 350, scrollable: scrollable);
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final rect = tester.getRect(button);
  if (rect.bottom > viewportHeight - 16) {
    await tester.drag(
      scrollable,
      Offset(0, -(rect.bottom - viewportHeight + 32)),
    );
    await tester.pumpAndSettle();
  } else if (rect.top < 16) {
    await tester.drag(scrollable, Offset(0, 32 - rect.top));
    await tester.pumpAndSettle();
  }
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _chooseCustom(
  WidgetTester tester,
  Key dropdownKey,
  String option,
) async {
  await _chooseDropdownValue(tester, dropdownKey, option);
}

Future<void> _chooseDropdownValue(
  WidgetTester tester,
  Key dropdownKey,
  String option,
) async {
  final dropdown = find.byKey(dropdownKey);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  expect(find.text(option), findsWidgets);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

int _selectedDayCount(WidgetTester tester) {
  var count = 0;
  for (var day = 1; day <= 7; day++) {
    final chip = tester.widget<FilterChip>(
      find.byKey(ValueKey<String>('guided-availability-day-$day')),
    );
    if (chip.selected) count++;
  }
  return count;
}

VanJobService _service(
  String id, {
  Map<int, VanServiceDaySchedule>? availabilityByDay,
}) {
  final now = DateTime.utc(2026, 7, 21, 10);
  return VanJobService(
    id: id,
    name: 'Scheduled Delivery',
    description: 'Delivery service.',
    isActive: true,
    requestPhotos: false,
    requireAddress: true,
    requestExactPinAfterQuoteAccepted: false,
    linkedQuestionIds: const <String>[],
    quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
    createdAt: now,
    updatedAt: now,
    category: 'Transport & Delivery',
    workingDays: availabilityByDay?.keys.toList() ?? const <int>[1, 2, 3, 4, 5],
    businessStartMinutes: 9 * 60,
    businessEndMinutes: 17 * 60,
    availabilityByDay: availabilityByDay,
    noticeHours: 24,
    maxBookingsPerDay: 8,
    appointmentDurationMinutes: 60,
    creationSource: 'capabilityBuilder',
    starterPackId: 'courier_business',
    starterTemplateId: 'scheduled_delivery',
    capabilitySchemaVersion: 1,
  );
}
