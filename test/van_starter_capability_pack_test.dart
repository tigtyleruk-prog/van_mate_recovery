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
  test('Courier and Removals remain installed beside the Cleaning and Gardening packs', () {
    expect(kVanBusinessTemplateLibrary, hasLength(4));
    expect(kVanStarterCapabilityPacks, hasLength(4));
    expect(kVanServiceTemplateCategories, isEmpty);
    expect(findVanStarterCapabilityPackById('courier'), isNotNull);
    expect(
      findVanStarterCapabilityPackById('removals_man_with_van'),
      isNotNull,
    );
    expect(findVanStarterCapabilityPackById('cleaning'), isNotNull);
    expect(findVanStarterCapabilityPackById('gardening'), isNotNull);
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

  test('Cleaning pack has stable identity, aliases and four services', () {
    final definition = kVanBusinessTemplateLibrary.singleWhere(
      (item) => item.businessTypeId == 'cleaning',
    );

    expect(definition.categoryId, 'cleaning');
    expect(definition.categoryName, 'Cleaning');
    expect(definition.businessTypeName, 'Cleaning');
    expect(definition.iconKey, 'cleaning');
    expect(definition.colorValue, 0xFF2DB7A3);
    expect(definition.featured, isTrue);
    expect(
      definition.searchAliases.map((alias) => alias.label),
      containsAll(<String>[
        'Domestic cleaner',
        'House cleaning',
        'Deep cleaning',
        'End of tenancy cleaner',
        'Office cleaning',
        'Commercial cleaning',
      ]),
    );
    expect(searchVanStarterCapabilityPacks('domestic cleaner'), hasLength(1));
    expect(searchVanStarterCapabilityPacks('office cleaning'), hasLength(1));
    expect(definition.services.map((service) => service.serviceId), <String>[
      'cleaning_regular_domestic',
      'cleaning_one_off_deep',
      'cleaning_end_of_tenancy',
      'cleaning_office_commercial',
    ]);
    expect(definition.services.map((service) => service.name), <String>[
      'Domestic Cleaning',
      'One-off Deep Clean',
      'End of Tenancy Cleaning',
      'Office / Commercial Cleaning',
    ]);
    expect(
      definition.services.where(
        (service) => service.name == 'Regular Domestic Cleaning',
      ),
      isEmpty,
    );
  });

  test('Cleaning services use one-address standard quote journeys', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'cleaning')
        .services;

    for (final service in services) {
      expect(service.customerJourney, VanCustomerJourneyType.quote);
      expect(service.requestType, VanCustomerRequestType.quoteRequest);
      expect(service.startHandover, isNull);
      expect(service.endHandover, isNull);
      expect(service.requireAddress, isTrue);
      expect(service.requestPhotos, isTrue);
      expect(service.requestFlowOptions.askPreferredDate, isTrue);
      expect(service.requestFlowOptions.askPreferredTime, isTrue);
      expect(service.requestFlowOptions.showPickupAddress, isFalse);
      expect(service.requestFlowOptions.showDeliveryAddress, isFalse);
      expect(service.requestFlowOptions.showDropOffDate, isFalse);
      expect(service.requestFlowOptions.showDropOffTime, isFalse);
      expect(service.requestFlowOptions.showPickUpDate, isFalse);
      expect(service.requestFlowOptions.showPickUpTime, isFalse);
      expect(service.requestFlowOptions.showFulfilmentChoice, isFalse);
      expect(service.requestFlowOptions.showNotes, isFalse);
      expect(
        service.builtInQuestionKeys,
        containsAll(<String>[
          'address',
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        ]),
      );
      for (final key in <String>[
        'address',
        'preferred_date',
        'preferred_time',
        'phone',
      ]) {
        expect(
          service.builtInQuestionSettings[key]?['required'],
          isTrue,
          reason: '${service.serviceId} should require $key',
        );
      }
      expect(service.builtInQuestionSettings['email']?['required'], isFalse);
      expect(service.builtInQuestionSettings['photos']?['required'], isFalse);
    }
  });

  test('Cleaning questions and extras are explicit, unique and safe', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'cleaning')
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
      'email address',
      'address',
      'postcode',
      'booking date',
      'booking time',
      'preferred date',
      'preferred time',
    };

    expect(questions, hasLength(29));
    expect(questions.map((question) => question.libraryId), <String>[
      'cleaning_regular_property_type',
      'cleaning_regular_bedrooms_bathrooms',
      'cleaning_regular_rooms_priorities',
      'cleaning_regular_frequency',
      'cleaning_regular_pets',
      'cleaning_regular_supplies',
      'cleaning_regular_access_occupancy',
      'cleaning_deep_property_type',
      'cleaning_deep_bedrooms_bathrooms',
      'cleaning_deep_condition',
      'cleaning_deep_priorities',
      'cleaning_deep_occupancy',
      'cleaning_deep_supplies',
      'cleaning_deep_access_furniture',
      'cleaning_tenancy_property_type',
      'cleaning_tenancy_bedrooms_bathrooms',
      'cleaning_tenancy_furnishing_occupancy',
      'cleaning_tenancy_condition',
      'cleaning_tenancy_handover_deadline',
      'cleaning_tenancy_agent_requirements',
      'cleaning_tenancy_access',
      'cleaning_office_premises_type',
      'cleaning_office_floor_area',
      'cleaning_office_areas_facilities',
      'cleaning_office_frequency',
      'cleaning_office_hours',
      'cleaning_office_access',
      'cleaning_office_supplies',
      'cleaning_office_bins',
    ]);
    expect(
      questions.map((question) => question.libraryId).toSet(),
      hasLength(29),
    );
    expect(
      questions.every(
        (question) =>
            VanCustomQuestionAnswerType.values.contains(question.answerType),
      ),
      isTrue,
    );
    expect(
      questions
          .map((question) => question.text.trim().toLowerCase())
          .toSet()
          .intersection(forbiddenCustomPrompts),
      isEmpty,
    );
    expect(extras, hasLength(19));
    expect(extras.map((extra) => extra.key), <String>[
      'custom_extra_cleaning_regular_additional_bedroom',
      'custom_extra_cleaning_regular_additional_bathroom',
      'custom_extra_cleaning_regular_interior_windows',
      'custom_extra_cleaning_regular_bed_linen_change',
      'custom_extra_cleaning_regular_ironing',
      'custom_extra_cleaning_deep_inside_oven',
      'custom_extra_cleaning_deep_inside_fridge_freezer',
      'custom_extra_cleaning_deep_inside_cupboards',
      'custom_extra_cleaning_deep_interior_windows',
      'custom_extra_cleaning_deep_pet_hair_treatment',
      'custom_extra_cleaning_tenancy_inside_oven',
      'custom_extra_cleaning_tenancy_inside_fridge_freezer',
      'custom_extra_cleaning_tenancy_inside_cupboards',
      'custom_extra_cleaning_tenancy_interior_windows',
      'custom_extra_cleaning_office_additional_washroom',
      'custom_extra_cleaning_office_communal_area_deep_clean',
      'custom_extra_cleaning_office_interior_windows',
      'custom_extra_cleaning_office_products_supplied',
      'custom_extra_cleaning_office_internal_bins',
    ]);
    expect(extras.map((extra) => extra.key).toSet(), hasLength(19));
    expect(extras.every((extra) => extra.defaultPrice == 0), isTrue);
    expect(extras.every((extra) => extra.defaultChargeUnit == 'Fixed'), isTrue);
    expect(
      extras.every(
        (extra) =>
            !RegExp(r'\bfree\b', caseSensitive: false).hasMatch(extra.label),
      ),
      isTrue,
    );
    const forbiddenExtras = <String>{
      'Carpet cleaning',
      'Upholstery cleaning',
      'Hazardous waste',
      'Clinical waste',
      'Biohazard cleaning',
    };
    expect(
      extras.every((extra) => !forbiddenExtras.contains(extra.label)),
      isTrue,
    );

    final regular = services.singleWhere(
      (service) => service.serviceId == 'cleaning_regular_domestic',
    );
    final deep = services.singleWhere(
      (service) => service.serviceId == 'cleaning_one_off_deep',
    );
    final office = services.singleWhere(
      (service) => service.serviceId == 'cleaning_office_commercial',
    );
    final tenancy = services.singleWhere(
      (service) => service.serviceId == 'cleaning_end_of_tenancy',
    );
    expect(
      regular.questions
          .singleWhere(
            (question) => question.libraryId == 'cleaning_regular_frequency',
          )
          .helperText,
      contains('does not automatically create recurring bookings'),
    );
    expect(
      deep.questions
          .singleWhere(
            (question) => question.libraryId == 'cleaning_deep_occupancy',
          )
          .choiceOptions,
      <String>[
        'Someone will be present',
        'Property will be empty and access arranged',
        'Property is vacant',
        'Unsure',
      ],
    );
    expect(
      office.questions
          .singleWhere(
            (question) => question.libraryId == 'cleaning_office_frequency',
          )
          .helperText,
      contains('does not automatically create repeat jobs'),
    );
    expect(
      office.questions
          .singleWhere(
            (question) => question.libraryId == 'cleaning_office_access',
          )
          .helperText,
      contains('Do not include alarm codes'),
    );
    expect(
      office.questions
          .singleWhere(
            (question) => question.libraryId == 'cleaning_office_bins',
          )
          .helperText,
      contains('Hazardous, clinical and licensed waste is not included.'),
    );
    expect(tenancy.suggestedCustomerMessage, contains('does not guarantee'));
    expect(
      tenancy.suggestedCustomerMessage.toLowerCase(),
      isNot(contains('guaranteed deposit')),
    );
  });

  test('Cleaning defaults preserve timing, limits and recurrence metadata', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'cleaning')
        .services;
    final expected = <String, (int, int, int, List<int>)>{
      'cleaning_regular_domestic': (120, 24, 3, <int>[1, 2, 3, 4, 5, 6]),
      'cleaning_one_off_deep': (240, 48, 2, <int>[1, 2, 3, 4, 5, 6]),
      'cleaning_end_of_tenancy': (360, 72, 1, <int>[1, 2, 3, 4, 5, 6]),
      'cleaning_office_commercial': (180, 48, 2, <int>[1, 2, 3, 4, 5]),
    };

    for (final service in services) {
      final defaults = expected[service.serviceId]!;
      expect(service.suggestedDurationMinutes, defaults.$1);
      expect(service.suggestedNoticeHours, defaults.$2);
      expect(service.maximumBookingsPerDay, defaults.$3);
      expect(service.availability.map((day) => day.day), defaults.$4);
      expect(
        service.availability.every(
          (day) => day.startMinutes == 480 && day.endMinutes == 1080,
        ),
        isTrue,
      );
    }

    for (final service in services) {
      final repeats =
          service.serviceId == 'cleaning_regular_domestic' ||
          service.serviceId == 'cleaning_office_commercial';
      expect(
        service.featureIds.contains(VanServiceCapabilityIds.recurring),
        repeats,
      );
      expect(
        service.featureIds.contains(VanServiceCapabilityIds.oneOff),
        !repeats,
      );
    }
  });

  test('service names no longer generate journeys or pricing extras', () {
    for (final name in <String>[
      'Courier',
      'Man & Van',
      'Removals',
      'Cleaning',
      'Bakery',
    ]) {
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

  test('Gardening pack has stable identity, aliases and four services', () {
    final definition = kVanBusinessTemplateLibrary.singleWhere(
      (item) => item.businessTypeId == 'gardening',
    );

    expect(definition.categoryId, 'gardening');
    expect(definition.categoryName, 'Gardening');
    expect(definition.businessTypeName, 'Gardening');
    expect(definition.iconKey, 'local_florist');
    expect(definition.colorValue, 0xFF4CAF50);
    expect(definition.searchAliases.map((alias) => alias.label), <String>[
      'Lawn care',
      'Garden care',
      'Hedge cutting',
      'Garden tidy',
    ]);
    expect(searchVanStarterCapabilityPacks('lawn care'), hasLength(1));
    expect(searchVanStarterCapabilityPacks('hedge cutting'), hasLength(1));
    expect(definition.services.map((service) => service.serviceId), <String>[
      'gardening_lawn_mowing',
      'gardening_maintenance',
      'gardening_hedge_trimming',
      'gardening_clearance',
    ]);
  });

  test('Gardening services use one-address standard quote journeys', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'gardening')
        .services;

    for (final service in services) {
      expect(service.customerJourney, VanCustomerJourneyType.quote);
      expect(service.requestType, VanCustomerRequestType.quoteRequest);
      expect(service.startHandover, isNull);
      expect(service.endHandover, isNull);
      expect(service.requireAddress, isTrue);
      expect(service.requestPhotos, isTrue);
      expect(service.requestFlowOptions.askPreferredDate, isTrue);
      expect(service.requestFlowOptions.askPreferredTime, isTrue);
      expect(service.requestFlowOptions.showPickupAddress, isFalse);
      expect(service.requestFlowOptions.showDeliveryAddress, isFalse);
      expect(service.requestFlowOptions.showDropOffDate, isFalse);
      expect(service.requestFlowOptions.showDropOffTime, isFalse);
      expect(service.requestFlowOptions.showPickUpDate, isFalse);
      expect(service.requestFlowOptions.showPickUpTime, isFalse);
      expect(service.requestFlowOptions.showFulfilmentChoice, isFalse);
      expect(service.requestFlowOptions.showNotes, isFalse);
      expect(
        service.builtInQuestionKeys,
        containsAll(<String>[
          'address',
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        ]),
      );
      for (final key in <String>[
        'address',
        'preferred_date',
        'preferred_time',
        'phone',
      ]) {
        expect(
          service.builtInQuestionSettings[key]?['required'],
          isTrue,
          reason: '${service.serviceId} should require $key',
        );
      }
      expect(service.builtInQuestionSettings['email']?['required'], isFalse);
      expect(service.builtInQuestionSettings['photos']?['required'], isFalse);
    }
  });

  test('Gardening questions and extras are explicit, unique and safe', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'gardening')
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
      'email address',
      'address',
      'postcode',
      'booking date',
      'booking time',
      'preferred date',
      'preferred time',
    };

    expect(questions.map((question) => question.libraryId).toSet(), hasLength(37));
    expect(
      questions.map((question) => question.text.trim().toLowerCase())
          .toSet()
          .intersection(forbiddenCustomPrompts),
      isEmpty,
    );
    expect(extras.map((extra) => extra.key).toSet(), hasLength(21));
    expect(extras.every((extra) => extra.defaultPrice == 0), isTrue);
    expect(extras.every((extra) => extra.defaultChargeUnit == 'Fixed'), isTrue);
    expect(
      extras.every(
        (extra) =>
            !RegExp(r'\bfree\b', caseSensitive: false).hasMatch(extra.label),
      ),
      isTrue,
    );

    final lawn = services.singleWhere(
      (service) => service.serviceId == 'gardening_lawn_mowing',
    );
    final maintenance = services.singleWhere(
      (service) => service.serviceId == 'gardening_maintenance',
    );
    final hedge = services.singleWhere(
      (service) => service.serviceId == 'gardening_hedge_trimming',
    );
    final clearance = services.singleWhere(
      (service) => service.serviceId == 'gardening_clearance',
    );

    expect(
      lawn.questions
          .singleWhere(
            (question) => question.libraryId == 'gardening_lawn_parking_access',
          )
          .helperText,
      contains('Do not provide door, alarm or key-safe codes'),
    );
    expect(
      maintenance.questions
          .singleWhere(
            (question) => question.libraryId == 'gardening_maintenance_frequency',
          )
          .helperText,
      contains('does not automatically create recurring bookings'),
    );
    expect(
      maintenance.questions
          .singleWhere(
            (question) => question.libraryId == 'gardening_maintenance_access_issues',
          )
          .helperText,
      contains('Do not provide door, alarm or key-safe codes'),
    );
    expect(
      hedge.questions
          .singleWhere(
            (question) => question.libraryId == 'gardening_hedge_nesting',
          )
          .helperText,
      contains('may need to be postponed or restricted'),
    );
    expect(
      hedge.questions
          .singleWhere(
            (question) => question.libraryId == 'gardening_hedge_parking_access',
          )
          .helperText,
      contains('Do not provide door, alarm or key-safe codes'),
    );
    expect(
      clearance.questions
          .singleWhere(
            (question) => question.libraryId == 'gardening_clearance_restricted_materials_details',
          )
          .helperText,
      contains('The business must confirm accepted waste'),
    );
    expect(
      clearance.questions
          .singleWhere(
            (question) => question.libraryId == 'gardening_clearance_parking_access',
          )
          .helperText,
      contains('Do not provide door, alarm or key-safe codes'),
    );
  });

  test('Gardening defaults preserve duration, notice, limits and schedule', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'gardening')
        .services;
    final expected = <String, (int, int, int)>{
      'gardening_lawn_mowing': (60, 24, 6),
      'gardening_maintenance': (120, 24, 4),
      'gardening_hedge_trimming': (120, 48, 3),
      'gardening_clearance': (240, 72, 2),
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
}
