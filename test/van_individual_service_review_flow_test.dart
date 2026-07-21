import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/pages/van_job_types_services_page.dart';
import 'package:van_mate_app/features/van_mate/pages/van_service_wizard_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_custom_job_questions_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'guided review progresses one service and one section at a time',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _service('scheduled', 'Scheduled Delivery');
      final question = _question(
        'scheduled-question',
        'What is being delivered?',
      );
      await VanCustomJobQuestionsStorage.instance.saveAll(
        <VanCustomJobQuestion>[question],
        syncCloud: false,
      );
      await VanJobServicesStorage.instance.saveAll(<VanJobService>[
        service,
      ], syncCloud: false);

      await tester.pumpWidget(
        MaterialApp(
          home: VanJobServiceDetailPage(
            serviceId: service.id,
            reviewServiceIds: <String>[service.id],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service 1 of 1'), findsOneWidget);
      expect(find.text('1 of 4 · Service Features'), findsOneWidget);
      expect(find.text('Request a quote'), findsWidgets);
      expect(find.text('Use Defaults & Finish'), findsOneWidget);

      await _tapReviewNext(tester);
      expect(find.text('2 of 4 · Customer Questions'), findsOneWidget);
      expect(find.text('What is being delivered?'), findsOneWidget);
      expect(find.text('Add custom question'), findsOneWidget);

      await _tapReviewNext(tester);
      expect(find.text('3 of 4 · Pricing Extras'), findsOneWidget);
      expect(find.textContaining('Waiting time'), findsOneWidget);
      expect(find.text('Enable, edit or add extras'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('guided-extra-price-scheduled-waiting_time'),
        ),
        findsOneWidget,
      );

      await _tapReviewNext(tester);
      expect(find.text('4 of 4 · Availability'), findsOneWidget);
      expect(find.text('Working days'), findsOneWidget);
      expect(find.text('Typical duration'), findsOneWidget);
      expect(find.text('Minimum notice'), findsOneWidget);
      expect(find.text('Maximum bookings per day'), findsOneWidget);
    },
  );

  testWidgets('quick defaults never rewrites existing services or questions', (
    tester,
  ) async {
    final first = _service('custom-one', 'My Custom Courier').copyWith(
      description: 'Customer-edited description',
      noticeHours: 72,
      workingDays: const <int>[2, 4, 6],
    );
    final second = _service(
      'custom-two',
      'My Legal Runs',
    ).copyWith(maxBookingsPerDay: 3, businessStartMinutes: 10 * 60);
    final question = _question(
      'custom-one-question',
      'Use my exact custom wording?',
    );
    await VanCustomJobQuestionsStorage.instance.saveAll(<VanCustomJobQuestion>[
      question,
    ], syncCloud: false);
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      first,
      second,
    ], syncCloud: false);
    final beforeServices = <Map<String, dynamic>>[
      first.toJson(),
      second.toJson(),
    ];
    final beforeQuestion = question.toJson();

    await tester.pumpWidget(
      MaterialApp(
        home: VanJobServiceDetailPage(
          serviceId: first.id,
          reviewServiceIds: <String>[first.id, second.id],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Service 1 of 2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Use Defaults & Continue'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Use Defaults & Continue'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Service 2 of 2'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Service 2 of 2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Use Defaults & Finish'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Use Defaults & Finish'));
    await tester.pumpAndSettle();

    final afterServices = await VanJobServicesStorage.instance.loadAll();
    final afterQuestions = await VanCustomJobQuestionsStorage.instance
        .loadAll();
    expect(
      afterServices.map((item) => item.toJson()).toList(growable: false),
      equals(beforeServices),
    );
    expect(afterQuestions.single.toJson(), beforeQuestion);
  });

  testWidgets(
    'feature controls are directly editable for the active reviewed service',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sameDay = _service('same-day', 'Same-day Delivery');
      final scheduled = _service('scheduled', 'Scheduled Delivery');
      await VanJobServicesStorage.instance.saveAll(<VanJobService>[
        sameDay,
        scheduled,
      ], syncCloud: false);

      await tester.pumpWidget(
        MaterialApp(
          home: VanJobServiceDetailPage(
            serviceId: sameDay.id,
            reviewServiceIds: <String>[sameDay.id, scheduled.id],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Service 1 of 2'), findsOneWidget);

      expect(find.text('Service features'), findsOneWidget);
      expect(find.text('Same-day Delivery'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('service_feature_recurring')),
        findsOneWidget,
      );
      expect(find.text('Edit service features'), findsNothing);
      expect(find.text('Basic information'), findsNothing);
      expect(find.text('Step 1 of 8'), findsNothing);

      expect(find.text('Service 1 of 2'), findsOneWidget);
      expect(find.text('Same-day Delivery'), findsOneWidget);
      expect(find.text('1 of 4 · Service Features'), findsOneWidget);
    },
  );

  testWidgets('saving features changes only the currently reviewed service', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sameDay = _service('same-day', 'Same-day Delivery');
    final scheduled = _service('scheduled', 'Scheduled Delivery');
    final scheduledBefore = scheduled.toJson();
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      sameDay,
      scheduled,
    ], syncCloud: false);

    await tester.pumpWidget(
      MaterialApp(
        home: VanJobServiceDetailPage(
          serviceId: sameDay.id,
          reviewServiceIds: <String>[sameDay.id, scheduled.id],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final recurring = find.byKey(
      const ValueKey<String>('service_feature_recurring'),
    );
    await tester.ensureVisible(recurring);
    await tester.tap(recurring);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('service_review_next')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('service_review_next')));
    await tester.pumpAndSettle();

    expect(find.text('Service 1 of 2'), findsOneWidget);
    expect(find.text('2 of 4 · Customer Questions'), findsOneWidget);
    final stored = await VanJobServicesStorage.instance.loadAll();
    final editedSameDay = stored.singleWhere((item) => item.id == sameDay.id);
    final untouchedScheduled = stored.singleWhere(
      (item) => item.id == scheduled.id,
    );
    expect(editedSameDay.serviceCapabilityIds, contains('recurring'));
    expect(untouchedScheduled.toJson(), equals(scheduledBefore));
  });

  testWidgets('transport category dropdown uses one stable unique item', (
    tester,
  ) async {
    final transportService = _service(
      'transport-service',
      'Same-day Delivery',
    ).copyWith(category: 'Transport & Delivery');

    await tester.pumpWidget(
      MaterialApp(home: VanServiceWizardPage(initialService: transportService)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    final items = dropdown.items!;
    expect(dropdown.value, 'transport_delivery');
    expect(items.map((item) => item.value).toSet(), hasLength(items.length));
    expect(
      items.where(
        (item) =>
            item.child is Text &&
            (item.child as Text).data == 'Transport & Delivery',
      ),
      hasLength(1),
    );
  });

  testWidgets(
    'customer question row stays readable and usable at 360 logical pixels',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longText =
          'Are there any collection or delivery time restrictions?';
      final longQuestion = _question(
        'mobile-question',
        longText,
      ).copyWith(category: VanCustomQuestionCategory.collection);
      final secondQuestion = _question(
        'mobile-second-question',
        'Are there any access restrictions?',
      );
      final service = _service('mobile', 'Scheduled Delivery').copyWith(
        linkedQuestionIds: <String>[longQuestion.id, secondQuestion.id],
      );
      await VanCustomJobQuestionsStorage.instance.saveAll(
        <VanCustomJobQuestion>[longQuestion, secondQuestion],
        syncCloud: false,
      );
      await VanJobServicesStorage.instance.saveAll(<VanJobService>[
        service,
      ], syncCloud: false);

      await tester.pumpWidget(
        MaterialApp(
          home: VanJobServiceDetailPage(
            serviceId: service.id,
            reviewServiceIds: <String>[service.id],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('service_review_next')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('service_review_next')));
      await tester.pumpAndSettle();

      final title = find.byKey(
        const ValueKey<String>('question_title_mobile-question'),
      );
      await tester.scrollUntilVisible(
        title,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(longText), findsOneWidget);
      expect(tester.getSize(title).width, greaterThan(170));
      expect(tester.getSize(title).height, inInclusiveRange(25, 60));
      expect(tester.takeException(), isNull, reason: 'question stage');

      final visibility = find.byKey(
        const ValueKey<String>('question_visibility_mobile-question'),
      );
      final edit = find.byKey(
        const ValueKey<String>('question_edit_mobile-question'),
      );
      final remove = find.byKey(
        const ValueKey<String>('question_remove_mobile-question'),
      );
      final reorder = find.byKey(
        const ValueKey<String>('question_reorder_mobile-question'),
      );
      for (final control in <Finder>[visibility, edit, remove, reorder]) {
        expect(control, findsOneWidget);
        expect(control.hitTestable(), findsOneWidget);
        expect(tester.getSize(control), const Size(40, 40));
      }

      await tester.longPress(reorder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'reorder handle');
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'visibility action');
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'question editor');
      expect(find.text('Edit Question'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'return from editor');
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'remove dialog');
      expect(find.text('Delete question?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'return from dialog');

      await tester.scrollUntilVisible(
        find.text('Add custom question'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Add custom question').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('service_review_next')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('service_review_next')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tapReviewNext(WidgetTester tester) async {
  final next = find.byKey(const Key('service_review_next'));
  await tester.ensureVisible(next);
  await tester.pumpAndSettle();
  await tester.tap(next);
  await tester.pumpAndSettle();
}

VanJobService _service(String id, String name) {
  final now = DateTime.utc(2026, 7, 21, 10);
  return VanJobService(
    id: id,
    name: name,
    description: 'A preserved service description.',
    isActive: true,
    requestPhotos: true,
    requireAddress: true,
    requestExactPinAfterQuoteAccepted: false,
    linkedQuestionIds: <String>['$id-question'],
    quoteExtraDefaults: VanQuoteExtraDefaults.empty().copyWithExtra(
      VanQuoteExtraDefault.fallback(
        kVanQuoteExtraWaitingTimeKey,
      ).copyWith(enabled: true, label: 'Waiting time', defaultPrice: 15),
    ),
    createdAt: now,
    updatedAt: now,
    selectedBuiltInQuestionKeys: const <String>['phone', 'email'],
    serviceCapabilityIds: const <String>[
      'booking',
      'request_quote',
      'business_collects',
      'business_returns',
    ],
    capabilitySchemaVersion: 1,
    creationSource: 'capabilityBuilder',
  );
}

VanCustomJobQuestion _question(String id, String text) {
  final now = DateTime.utc(2026, 7, 21, 10);
  return VanCustomJobQuestion(
    id: id,
    questionText: text,
    libraryQuestionId: 'transport.items.what',
    tags: const <String>['transport', 'items'],
    answerType: VanCustomQuestionAnswerType.longText,
    isActive: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}
