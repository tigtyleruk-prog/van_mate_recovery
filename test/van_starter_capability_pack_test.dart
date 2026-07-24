import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_capability.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_handover.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_template.dart';
import 'package:van_mate_app/features/van_mate/models/van_starter_capability_pack.dart';

void main() {
  test('Courier remains installed beside the curated Removals pack', () {
    expect(kVanBusinessTemplateLibrary, hasLength(2));
    expect(kVanStarterCapabilityPacks, hasLength(2));
    expect(kVanServiceTemplateCategories, isEmpty);
    expect(findVanStarterCapabilityPackById('courier'), isNotNull);
    expect(
      findVanStarterCapabilityPackById('removals_man_with_van'),
      isNotNull,
    );
    expect(findVanStarterCapabilityPackById('courier_business'), isNull);
    expect(findVanServiceTemplateById('courier'), isNull);
    expect(searchVanStarterCapabilityPacks('courier'), hasLength(1));

    final definition = kVanBusinessTemplateLibrary.singleWhere(
      (item) => item.businessTypeId == 'courier',
    );
    expect(definition.categoryId, 'transport_delivery');
    expect(definition.businessTypeId, 'courier');
    expect(definition.services.map((service) => service.serviceId), <String>[
      'courier_same_day_delivery',
      'courier_scheduled_delivery',
    ]);
  });

  test('central template schema requires explicit service behaviour', () {
    const service = VanBusinessServiceTemplateDefinition(
      serviceId: 'manual_test_service',
      name: 'Manual test service',
      description: 'Only constructed inside this schema test.',
      featureIds: <String>[VanServiceCapabilityIds.photoUpload],
      bookingOptionIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.requestQuote,
      ],
      customerJourney: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      startHandover: VanStartHandover.customerDropsOff,
      endHandover: VanEndHandover.customerCollects,
      requestFlowOptions: VanCustomerRequestFlowOptions(
        showFulfilmentChoice: false,
        askPreferredDate: true,
        askPreferredTime: true,
        showPickupAddress: false,
        showDeliveryAddress: false,
        showDropOffDate: false,
        showDropOffTime: false,
        showPickUpDate: false,
        showPickUpTime: false,
        showNotes: true,
      ),
      builtInQuestionKeys: <String>{'phone'},
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(
          text: 'What should we know?',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(key: 'custom_extra_test', label: 'Test extra'),
      ],
      availability: <VanTemplateDayAvailability>[
        VanTemplateDayAvailability(
          day: 1,
          startMinutes: 9 * 60,
          endMinutes: 17 * 60,
        ),
      ],
    );

    expect(service.serviceId, 'manual_test_service');
    expect(service.customerJourney, VanCustomerJourneyType.quote);
    expect(service.startHandover, VanStartHandover.customerDropsOff);
    expect(service.endHandover, VanEndHandover.customerCollects);
    expect(service.questions.single.text, 'What should we know?');
    expect(service.extras.single.label, 'Test extra');
    expect(service.availability.single.day, 1);
  });

  test('capability resolver no longer generates questions or extras', () {
    final resolved = resolveVanServiceCapabilities(<String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.recurring,
      VanServiceCapabilityIds.localDelivery,
      VanServiceCapabilityIds.sameDay,
      VanServiceCapabilityIds.depositRequired,
    });

    expect(resolved.questions, isEmpty);
    expect(resolved.extras, isEmpty);
    expect(resolved.builtInQuestionKeys, isEmpty);
    expect(resolved.requestType, VanCustomerRequestType.quoteRequest);
    expect(resolved.requireAddress, isTrue);
  });

  test(
    'generic capabilities do not reinterpret legacy services as delivery',
    () {
      final resolved = resolveVanServiceCapabilities(<String>{
        VanServiceCapabilityIds.requestQuote,
        VanServiceCapabilityIds.businessCollects,
        VanServiceCapabilityIds.localDelivery,
      });

      expect(resolved.requestType, VanCustomerRequestType.quoteRequest);
      expect(resolved.allowBusinessDelivery, isFalse);
    },
  );

  test('Courier services keep explicit delivery journeys and curated data', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'courier')
        .services;
    final sameDay = services.first;
    final scheduled = services.last;

    for (final service in services) {
      expect(service.requestType, VanCustomerRequestType.pickupDeliveryRequest);
      expect(service.startHandover, VanStartHandover.businessCollects);
      expect(service.endHandover, VanEndHandover.businessDelivers);
      expect(service.requireAddress, isFalse);
      expect(service.requestFlowOptions.showPickupAddress, isTrue);
      expect(service.requestFlowOptions.showDeliveryAddress, isTrue);
      expect(service.requestFlowOptions.askPreferredDate, isFalse);
      expect(service.requestFlowOptions.askPreferredTime, isFalse);
      expect(
        service.featureIds,
        isNot(contains(VanServiceCapabilityIds.businessReturns)),
      );
      expect(
        service.extras.map((extra) => extra.label),
        isNot(contains('Waiting time')),
      );
      expect(
        service.extras.every((extra) => extra.defaultChargeUnit == 'Fixed'),
        isTrue,
      );
    }

    expect(
      scheduled.featureIds,
      isNot(contains(VanServiceCapabilityIds.appointmentRequired)),
    );
    expect(scheduled.featureIds, contains(VanServiceCapabilityIds.leadTime));
    expect(sameDay.questions, hasLength(5));
    expect(scheduled.questions, hasLength(5));
    expect(
      scheduled.questions
          .singleWhere(
            (question) => question.libraryId == 'courier_scheduled_access',
          )
          .requiredByDefault,
      isFalse,
    );
    expect(
      sameDay.extras
          .map((extra) => extra.key)
          .toSet()
          .intersection(scheduled.extras.map((extra) => extra.key).toSet()),
      isEmpty,
    );
    expect(sameDay.availability.map((day) => day.day), <int>[1, 2, 3, 4, 5, 6]);
    expect(scheduled.availability.map((day) => day.day), <int>[1, 2, 3, 4, 5]);
  });

  test('Removals pack has stable identity, aliases and four services', () {
    final definition = kVanBusinessTemplateLibrary.singleWhere(
      (item) => item.businessTypeId == 'removals_man_with_van',
    );

    expect(definition.businessTypeName, 'Removals / Man with a Van');
    expect(definition.categoryId, 'removals_moving');
    expect(definition.categoryName, 'Removals & Moving');
    expect(definition.searchAliases.map((alias) => alias.label), <String>[
      'Man & Van',
      'Removal service',
      'Moving service',
      'House removals',
    ]);
    expect(searchVanStarterCapabilityPacks('man & van'), hasLength(1));
    expect(searchVanStarterCapabilityPacks('house removals'), hasLength(1));
    expect(definition.services.map((service) => service.serviceId), <String>[
      'removals_man_with_van_general',
      'removals_full_house_move',
      'removals_furniture_single_item',
      'removals_clearance',
    ]);
  });

  test('Removals delivery services use explicit collection and delivery', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere(
          (definition) => definition.businessTypeId == 'removals_man_with_van',
        )
        .services;

    for (final service in services.take(3)) {
      expect(service.customerJourney, VanCustomerJourneyType.quote);
      expect(service.requestType, VanCustomerRequestType.pickupDeliveryRequest);
      expect(service.startHandover, VanStartHandover.businessCollects);
      expect(service.endHandover, VanEndHandover.businessDelivers);
      expect(service.requestFlowOptions.showPickupAddress, isTrue);
      expect(service.requestFlowOptions.showDeliveryAddress, isTrue);
      expect(service.requestFlowOptions.showDropOffDate, isTrue);
      expect(service.requestFlowOptions.showDropOffTime, isTrue);
      expect(service.requestFlowOptions.showPickUpDate, isTrue);
      expect(service.requestFlowOptions.showPickUpTime, isTrue);
      expect(service.requestFlowOptions.askPreferredDate, isFalse);
      expect(service.requestFlowOptions.askPreferredTime, isFalse);
      expect(service.requireAddress, isFalse);
    }
  });

  test('Clearance uses one required address and preferred time window', () {
    final clearance = kVanBusinessTemplateLibrary
        .singleWhere(
          (definition) => definition.businessTypeId == 'removals_man_with_van',
        )
        .services
        .singleWhere((service) => service.serviceId == 'removals_clearance');

    expect(clearance.customerJourney, VanCustomerJourneyType.quote);
    expect(clearance.requestType, VanCustomerRequestType.quoteRequest);
    expect(clearance.startHandover, isNull);
    expect(clearance.endHandover, isNull);
    expect(clearance.requireAddress, isTrue);
    expect(clearance.requestFlowOptions.askPreferredDate, isTrue);
    expect(clearance.requestFlowOptions.askPreferredTime, isTrue);
    expect(clearance.requestFlowOptions.showPickupAddress, isFalse);
    expect(clearance.requestFlowOptions.showDeliveryAddress, isFalse);
    expect(
      clearance.builtInQuestionKeys,
      containsAll(<String>[
        'address',
        'phone',
        'email',
        'preferred_date',
        'preferred_time',
        'photos',
      ]),
    );
    expect(
      clearance.builtInQuestionSettings['preferred_date']?['required'],
      isTrue,
    );
    expect(
      clearance.builtInQuestionSettings['preferred_time']?['required'],
      isTrue,
    );
    expect(
      clearance.questions
          .singleWhere(
            (question) =>
                question.libraryId == 'removals_clearance_restricted_items',
          )
          .helperText,
      contains(
        'Listing an item does not mean the business can accept or remove it.',
      ),
    );
  });

  test('Removals questions and extras are explicit, unique and editable', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere(
          (definition) => definition.businessTypeId == 'removals_man_with_van',
        )
        .services;
    final questions = services
        .expand((service) => service.questions)
        .toList(growable: false);
    final extras = services
        .expand((service) => service.extras)
        .toList(growable: false);
    final forbiddenCustomPrompts = <String>{
      'customer name',
      'phone',
      'phone number',
      'email',
      'collection address',
      'delivery address',
      'job address',
      'booking date',
      'booking time',
      'preferred date',
      'preferred time',
    };

    expect(
      questions.map((question) => question.libraryId).toSet(),
      hasLength(22),
    );
    expect(questions, hasLength(22));
    expect(
      questions
          .map((question) => question.text.trim().toLowerCase())
          .toSet()
          .intersection(forbiddenCustomPrompts),
      isEmpty,
    );
    expect(extras.map((extra) => extra.key).toSet(), hasLength(19));
    expect(extras, hasLength(19));
    expect(extras.every((extra) => extra.defaultPrice == 0), isTrue);
    expect(extras.every((extra) => extra.defaultChargeUnit == 'Fixed'), isTrue);
    expect(extras.map((extra) => extra.label), isNot(contains('Free')));
    expect(
      services.every(
        (service) =>
            service.builtInQuestionSettings['phone']?['required'] == true &&
            service.builtInQuestionSettings['email']?['required'] == false &&
            service.builtInQuestionSettings['photos']?['required'] == false,
      ),
      isTrue,
    );
  });

  test('Removals defaults preserve duration, notice, limits and schedule', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere(
          (definition) => definition.businessTypeId == 'removals_man_with_van',
        )
        .services;
    final expected = <String, (int, int, int)>{
      'removals_man_with_van_general': (120, 24, 4),
      'removals_full_house_move': (480, 72, 1),
      'removals_furniture_single_item': (90, 24, 6),
      'removals_clearance': (180, 48, 3),
    };

    for (final service in services) {
      final defaults = expected[service.serviceId]!;
      expect(service.suggestedDurationMinutes, defaults.$1);
      expect(service.suggestedNoticeHours, defaults.$2);
      expect(service.maximumBookingsPerDay, defaults.$3);
      expect(service.availability.map((day) => day.day), <int>[
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(
        service.availability.every(
          (day) => day.startMinutes == 480 && day.endMinutes == 1080,
        ),
        isTrue,
      );
    }
  });

  test('service names no longer generate journeys or pricing extras', () {
    for (final name in <String>['Courier', 'Man & Van', 'Removals', 'Bakery']) {
      expect(
        defaultVanCustomerRequestTypeForService(
          serviceId: name.toLowerCase().replaceAll(' ', '_'),
          serviceName: name,
        ),
        VanCustomerRequestType.quoteRequest,
      );
      expect(
        VanQuoteExtraDefaults.starterForServiceName(name).orderedExtras,
        isEmpty,
      );
    }
  });
}
