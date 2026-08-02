import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_business_profile.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_starter_capability_pack.dart';
import 'package:van_mate_app/features/van_mate/pages/van_booking_link_page.dart';

void main() {
  testWidgets(
    'required Cleaning timing blocks submission without a preferred date',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 7, 25);
      final service = VanJobService(
        id: 'cleaning-service',
        name: 'Domestic Cleaning',
        description: '',
        isActive: true,
        requestPhotos: false,
        requireAddress: true,
        requestExactPinAfterQuoteAccepted: false,
        requestFlowOptions: const VanCustomerRequestFlowOptions(
          showFulfilmentChoice: false,
          askPreferredDate: true,
          askPreferredTime: true,
          showPickupAddress: false,
          showDeliveryAddress: false,
          showDropOffDate: false,
          showDropOffTime: false,
          showPickUpDate: false,
          showPickUpTime: false,
          showNotes: false,
        ),
        linkedQuestionIds: const <String>[],
        quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
        createdAt: now,
        updatedAt: now,
        starterTemplateId: 'cleaning_regular_domestic',
        selectedBuiltInQuestionKeys: const <String>[
          'address',
          'phone',
          'preferred_date',
          'preferred_time',
        ],
        builtInQuestionSettings: const <String, Map<String, dynamic>>{
          'address': <String, dynamic>{'required': true},
          'phone': <String, dynamic>{'required': true},
          'preferred_date': <String, dynamic>{'required': true},
          'preferred_time': <String, dynamic>{'required': true},
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VanBookingLinkCustomerFormPage(
            profile: VanBusinessProfile.defaults(),
            activeServices: <VanJobService>[service],
            questionLookup: const <String, VanCustomJobQuestion>{},
            bookingLinkActive: true,
            bookingLinkUrl: '',
            bookingLinkTitle: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );

      expect(find.text('Preferred date and time'), findsOneWidget);
      expect(find.text('Preferred date and time (optional)'), findsNothing);
      expect(find.text('Anytime / Flexible'), findsOneWidget);

      await tester.enterText(field('Full name'), 'Test Customer');
      await tester.enterText(field('Phone number'), '07123456789');
      await tester.enterText(field('Address'), '1 Test Street');
      final submit = find.text('Request quote');
      await tester.scrollUntilVisible(
        submit,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();

      expect(find.text('Please choose a preferred date.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public booking form renders a manually configured service', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 7, 21);
    final question = VanCustomJobQuestion(
      id: 'manual-question',
      questionText: 'What should we know?',
      helperText: 'Optional supporting detail.',
      answerType: VanCustomQuestionAnswerType.longText,
      isActive: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    final service = VanJobService(
      id: 'manual-service',
      name: 'Manual Booking Service',
      description: 'Configured without a template.',
      isActive: true,
      requestPhotos: false,
      requireAddress: false,
      requestExactPinAfterQuoteAccepted: false,
      linkedQuestionIds: <String>[question.id],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
      creationSource: 'blank',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VanBookingLinkCustomerFormPage(
          profile: const VanBusinessProfile.defaults().copyWith(
            businessName: 'Manual Test Business',
          ),
          activeServices: <VanJobService>[service],
          questionLookup: <String, VanCustomJobQuestion>{question.id: question},
          bookingLinkActive: true,
          bookingLinkUrl: '',
          bookingLinkTitle: 'Manual Test Business',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manual Booking Service'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text(question.questionText),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(question.questionText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile Food Van booking only shows configured collection time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final setup = findVanStarterCapabilityPackById(
      'mobile_food_van',
    )!.recommendationsFor(const <String>['mobile_food_van_burger_van']).single;
    final now = DateTime(2026, 7, 21);
    final service = VanJobService(
      id: setup.serviceKey,
      name: setup.name,
      description: setup.description,
      isActive: true,
      requestPhotos: setup.requestPhotos,
      requireAddress: setup.requireAddress,
      requestExactPinAfterQuoteAccepted: false,
      requestType: VanCustomerRequestType.orderRequest,
      customerJourneyType: VanCustomerJourneyType.order,
      requestFlowOptions: setup.requestFlowOptions,
      linkedQuestionIds: const <String>[],
      quoteExtraDefaults: setup.quoteExtraDefaults(),
      createdAt: now,
      updatedAt: now,
      selectedBuiltInQuestionKeys: setup.builtInQuestionKeys.toList(
        growable: false,
      ),
      builtInQuestionSettings: setup.builtInQuestionSettings,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VanBookingLinkCustomerFormPage(
          profile: VanBusinessProfile.defaults(),
          activeServices: <VanJobService>[service],
          questionLookup: const <String, VanCustomJobQuestion>{},
          bookingLinkActive: true,
          bookingLinkUrl: '',
          bookingLinkTitle: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collection Time'), findsWidgets);
    expect(find.text('Preferred date'), findsNothing);
    expect(find.text('Timing is flexible'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
