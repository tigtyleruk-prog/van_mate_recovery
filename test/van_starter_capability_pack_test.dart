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
  test('Courier and Removals remain installed beside the Cleaning, Gardening, Pet Services, Handyman, Window Cleaning, Photography and Bakery packs', () {
    expect(kVanBusinessTemplateLibrary, hasLength(9));
    expect(kVanStarterCapabilityPacks, hasLength(9));
    expect(kVanServiceTemplateCategories, isEmpty);
    expect(findVanStarterCapabilityPackById('courier'), isNotNull);
    expect(
      findVanStarterCapabilityPackById('removals_man_with_van'),
      isNotNull,
    );
    expect(findVanStarterCapabilityPackById('cleaning'), isNotNull);
    expect(findVanStarterCapabilityPackById('gardening'), isNotNull);
    expect(findVanStarterCapabilityPackById('pet_services'), isNotNull);
    expect(findVanStarterCapabilityPackById('handyman'), isNotNull);
    expect(findVanStarterCapabilityPackById('window_cleaning'), isNotNull);
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

  test('Window Cleaning pack has stable identity, aliases and four services', () {
    final definition = kVanBusinessTemplateLibrary.singleWhere(
      (item) => item.businessTypeId == 'window_cleaning',
    );

    expect(definition.categoryId, 'window_cleaning');
    expect(definition.categoryName, 'Window Cleaning');
    expect(definition.businessTypeName, 'Window Cleaning');
    expect(definition.iconKey, 'home');
    expect(definition.colorValue, 0xFF29B6F4);
    expect(definition.featured, isTrue);
    expect(
      definition.searchAliases.map((alias) => alias.label),
      containsAll(<String>[
        'Window cleaner',
        'Domestic window cleaner',
        'Shopfront cleaner',
        'Commercial window cleaner',
        'Conservatory cleaning',
        'One-off window cleaning',
      ]),
    );
    expect(definition.services.map((service) => service.serviceId), <String>[
      'window_cleaning_domestic',
      'window_cleaning_commercial',
      'window_cleaning_conservatory',
      'window_cleaning_one_off',
    ]);
  });

  test('All Window Cleaning services use one-address standard quote journeys', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere(
          (definition) => definition.businessTypeId == 'window_cleaning',
        )
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

  test('Window Cleaning questions and extras are explicit, unique and safe', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere(
          (definition) => definition.businessTypeId == 'window_cleaning',
        )
        .services;
    final questions = services
        .expand((service) => service.questions)
        .toList(growable: false);
    final extras = services
        .expand((service) => service.extras)
        .toList(growable: false);

    expect(questions.map((question) => question.libraryId).toSet(), hasLength(38));
    expect(questions, hasLength(38));
    expect(
      questions.every(
        (question) =>
            VanCustomQuestionAnswerType.values.contains(question.answerType),
      ),
      isTrue,
    );
    expect(extras.map((extra) => extra.key).toSet(), hasLength(20));
    expect(extras.every((extra) => extra.defaultPrice == 0), isTrue);
    expect(extras.every((extra) => extra.defaultChargeUnit == 'Fixed'), isTrue);
    expect(
      extras.every(
        (extra) =>
            !RegExp(r'\bfree\b', caseSensitive: false).hasMatch(extra.label),
      ),
      isTrue,
    );

    final domestic = services.singleWhere(
      (service) => service.serviceId == 'window_cleaning_domestic',
    );
    final commercial = services.singleWhere(
      (service) => service.serviceId == 'window_cleaning_commercial',
    );
    final conservatory = services.singleWhere(
      (service) => service.serviceId == 'window_cleaning_conservatory',
    );
    final oneOff = services.singleWhere(
      (service) => service.serviceId == 'window_cleaning_one_off',
    );

    expect(domestic.questions, hasLength(9));
    expect(commercial.questions, hasLength(10));
    expect(conservatory.questions, hasLength(9));
    expect(oneOff.questions, hasLength(10));
    expect(domestic.extras, hasLength(5));
    expect(commercial.extras, hasLength(5));
    expect(conservatory.extras, hasLength(5));
    expect(oneOff.extras, hasLength(5));

    expect(
      domestic.questions
          .singleWhere(
            (question) =>
                question.libraryId == 'window_cleaning_domestic_condition',
          )
          .helperText,
      contains('may not be removable'),
    );
    expect(
      commercial.questions
          .singleWhere(
            (question) =>
                question.libraryId == 'window_cleaning_commercial_condition',
          )
          .helperText,
      contains('not guaranteed'),
    );
    expect(
      commercial.questions
          .singleWhere(
            (question) =>
                question.libraryId == 'window_cleaning_commercial_height',
          )
          .helperText,
      contains('suitable equipment and safe access'),
    );
    expect(
      domestic.featureIds.contains(VanServiceCapabilityIds.recurring),
      isFalse,
    );
    expect(
      commercial.featureIds.contains(VanServiceCapabilityIds.recurring),
      isFalse,
    );
    expect(
      conservatory.featureIds.contains(VanServiceCapabilityIds.recurring),
      isFalse,
    );
    expect(
      oneOff.featureIds.contains(VanServiceCapabilityIds.recurring),
      isFalse,
    );
    expect(
      domestic.questions
          .singleWhere(
            (question) =>
                question.libraryId == 'window_cleaning_domestic_frequency',
          )
          .helperText,
      contains('does not automatically create recurring bookings'),
    );
    expect(
      commercial.questions
          .singleWhere(
            (question) =>
                question.libraryId == 'window_cleaning_commercial_frequency',
          )
          .helperText,
      contains('does not automatically create recurring bookings'),
    );
    expect(
      conservatory.questions
          .singleWhere(
            (question) =>
                question.libraryId == 'window_cleaning_conservatory_frequency',
          )
          .helperText,
      contains('does not automatically create recurring bookings'),
    );
    expect(
      oneOff.questions
          .any((question) => question.libraryId == 'window_cleaning_one_off_frequency'),
      isFalse,
    );
  });

  test('Window Cleaning defaults preserve duration, notice, limits and schedule', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'window_cleaning')
        .services;
    final expected = <String, (int, int, int, List<int>)>{
      'window_cleaning_domestic': (90, 24, 6, <int>[1, 2, 3, 4, 5, 6]),
      'window_cleaning_commercial': (180, 24, 3, <int>[1, 2, 3, 4, 5, 6]),
      'window_cleaning_conservatory': (180, 48, 2, <int>[1, 2, 3, 4, 5, 6]),
      'window_cleaning_one_off': (90, 24, 6, <int>[1, 2, 3, 4, 5, 6]),
    };

    for (final service in services) {
      final defaults = expected[service.serviceId]!;
      expect(service.suggestedDurationMinutes, defaults.$1);
      expect(service.suggestedNoticeHours, defaults.$2);
      expect(service.maximumBookingsPerDay, defaults.$3);
      expect(service.availability.map((day) => day.day), defaults.$4);
      if (service.serviceId == 'window_cleaning_commercial') {
        expect(
          service.availability.every(
            (day) => day.startMinutes == 420 && day.endMinutes == 1140,
          ),
          isTrue,
        );
      } else {
        expect(
          service.availability.every(
            (day) => day.startMinutes == 480 && day.endMinutes == 1080,
          ),
          isTrue,
        );
      }
    }
  });

  test('Dog Day Care has stable identity, 10 questions and 5 extras', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');
    final dayCare = definition.services.singleWhere(
      (service) => service.serviceId == 'pet_services_dog_day_care',
    );

    expect(dayCare.serviceId, 'pet_services_dog_day_care');
    expect(dayCare.name, 'Dog Day Care');
    expect(dayCare.customerJourney, VanCustomerJourneyType.quote);
    expect(dayCare.requestType, VanCustomerRequestType.dropOffPickupRequest);
    expect(dayCare.startHandover, VanStartHandover.customerDropsOff);
    expect(dayCare.endHandover, VanEndHandover.customerCollects);
    expect(dayCare.questions, hasLength(10));
    expect(dayCare.extras, hasLength(5));
    expect(dayCare.suggestedDurationMinutes, 480);
    expect(dayCare.suggestedNoticeHours, 48);
    expect(dayCare.maximumBookingsPerDay, 4);
    expect(dayCare.requestPhotos, isTrue);
    expect(dayCare.requireAddress, isFalse);
    expect(dayCare.requestFlowOptions.showNotes, isFalse);
    expect(
      dayCare.availability.map((day) => day.day),
      <int>[1, 2, 3, 4, 5],
    );
    expect(
      dayCare.availability.every(
        (day) => day.startMinutes == 420 && day.endMinutes == 1080,
      ),
      isTrue,
    );
  });

  test('Dog Day Care question and extra IDs are unique', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');
    final dayCare = definition.services.singleWhere(
      (service) => service.serviceId == 'pet_services_dog_day_care',
    );

    expect(
      dayCare.questions.map((q) => q.libraryId).toSet(),
      hasLength(10),
    );
    expect(
      dayCare.questions.map((q) => q.libraryId).toSet(),
      containsAll(<String>[
        'pet_services_dog_day_care_dog_details',
        'pet_services_dog_day_care_previous_attendance',
        'pet_services_dog_day_care_vaccination_records',
        'pet_services_dog_day_care_social_behaviour',
        'pet_services_dog_day_care_behaviour_concerns',
        'pet_services_dog_day_care_feeding',
        'pet_services_dog_day_care_health',
        'pet_services_dog_day_care_health_details',
        'pet_services_dog_day_care_rest_routine',
        'pet_services_dog_day_care_items',
      ]),
    );
    expect(
      dayCare.extras.map((e) => e.key).toSet(),
      hasLength(5),
    );
    expect(
      dayCare.extras.map((e) => e.key).toSet(),
      containsAll(<String>[
        'custom_extra_pet_services_dog_day_care_additional_dog',
        'custom_extra_pet_services_dog_day_care_extended_care_hour',
        'custom_extra_pet_services_dog_day_care_meal_preparation',
        'custom_extra_pet_services_dog_day_care_medication_support',
        'custom_extra_pet_services_dog_day_care_weekend_holiday',
      ]),
    );
  });

  test('Dog Day Care uses customer drop-off and collection', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');
    final dayCare = definition.services.singleWhere(
      (service) => service.serviceId == 'pet_services_dog_day_care',
    );

    expect(dayCare.startHandover, VanStartHandover.customerDropsOff);
    expect(dayCare.endHandover, VanEndHandover.customerCollects);
    expect(dayCare.requestFlowOptions.showDropOffDate, isTrue);
    expect(dayCare.requestFlowOptions.showDropOffTime, isTrue);
    expect(dayCare.requestFlowOptions.showPickUpDate, isTrue);
    expect(dayCare.requestFlowOptions.showPickUpTime, isTrue);
    expect(dayCare.requestFlowOptions.askPreferredDate, isFalse);
    expect(dayCare.requestFlowOptions.askPreferredTime, isFalse);
    expect(dayCare.requestFlowOptions.showNotes, isFalse);
  });

  test('Dog Boarding has stable identity, 14 questions and 5 extras', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');
    final boarding = definition.services.singleWhere(
      (service) => service.serviceId == 'pet_services_dog_boarding',
    );

    expect(boarding.serviceId, 'pet_services_dog_boarding');
    expect(boarding.name, 'Dog Boarding');
    expect(boarding.customerJourney, VanCustomerJourneyType.quote);
    expect(boarding.requestType, VanCustomerRequestType.dropOffPickupRequest);
    expect(boarding.startHandover, VanStartHandover.customerDropsOff);
    expect(boarding.endHandover, VanEndHandover.customerCollects);
    expect(boarding.questions, hasLength(14));
    expect(boarding.extras, hasLength(5));
    expect(boarding.suggestedNoticeHours, 72);
    expect(boarding.maximumBookingsPerDay, 3);
    expect(boarding.requestPhotos, isTrue);
    expect(boarding.requireAddress, isFalse);
    expect(boarding.requestFlowOptions.showNotes, isFalse);
    expect(
      boarding.availability.map((day) => day.day),
      <int>[1, 2, 3, 4, 5, 6, 7],
    );
    expect(
      boarding.availability.every(
        (day) => day.startMinutes == 480 && day.endMinutes == 1080,
      ),
      isTrue,
    );
  });

  test('Dog Boarding question and extra IDs are unique', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');
    final boarding = definition.services.singleWhere(
      (service) => service.serviceId == 'pet_services_dog_boarding',
    );

    expect(
      boarding.questions.map((q) => q.libraryId).toSet(),
      hasLength(14),
    );
    expect(
      boarding.questions.map((q) => q.libraryId).toSet(),
      containsAll(<String>[
        'pet_services_dog_boarding_dog_count',
        'pet_services_dog_boarding_dog_details',
        'pet_services_dog_boarding_previous_stay',
        'pet_services_dog_boarding_vaccination_records',
        'pet_services_dog_boarding_social_behaviour',
        'pet_services_dog_boarding_feeding_routine',
        'pet_services_dog_boarding_sleeping_routine',
        'pet_services_dog_boarding_exercise_toilet',
        'pet_services_dog_boarding_behaviour_concerns',
        'pet_services_dog_boarding_health',
        'pet_services_dog_boarding_health_details',
        'pet_services_dog_boarding_items',
        'pet_services_dog_boarding_emergency_contact',
        'pet_services_dog_boarding_safe_care_info',
      ]),
    );
    expect(
      boarding.extras.map((e) => e.key).toSet(),
      hasLength(5),
    );
    expect(
      boarding.extras.map((e) => e.key).toSet(),
      containsAll(<String>[
        'custom_extra_pet_services_dog_boarding_additional_dog',
        'custom_extra_pet_services_dog_boarding_additional_night',
        'custom_extra_pet_services_dog_boarding_special_feeding',
        'custom_extra_pet_services_dog_boarding_medication_support',
        'custom_extra_pet_services_dog_boarding_weekend_holiday',
      ]),
    );
  });

  test('Boarding supports separate arrival and collection dates', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');
    final boarding = definition.services.singleWhere(
      (service) => service.serviceId == 'pet_services_dog_boarding',
    );

    expect(boarding.startHandover, VanStartHandover.customerDropsOff);
    expect(boarding.endHandover, VanEndHandover.customerCollects);
    expect(boarding.requestFlowOptions.showDropOffDate, isTrue);
    expect(boarding.requestFlowOptions.showDropOffTime, isTrue);
    expect(boarding.requestFlowOptions.showPickUpDate, isTrue);
    expect(boarding.requestFlowOptions.showPickUpTime, isTrue);
    expect(boarding.requestFlowOptions.showNotes, isFalse);
  });

  test('Dog Day Care and Boarding do not create recurring jobs', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');

    for (final service in definition.services) {
      expect(
        service.featureIds.contains(VanServiceCapabilityIds.recurring),
        isFalse,
      );
    }
  });

  test('All pet services photos are optional and notes are disabled', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');

    for (final service in definition.services) {
      expect(service.requestPhotos, isTrue);
      expect(service.requestFlowOptions.showNotes, isFalse);
      expect(
        service.builtInQuestionSettings['photos']?['required'],
        isFalse,
      );
      expect(service.extras.map((e) => e.label), isNot(contains('Free')));
      expect(
        service.extras.every((e) => e.defaultPrice == 0),
        isTrue,
      );
      expect(
        service.extras.every((e) => e.defaultChargeUnit == 'Fixed'),
        isTrue,
      );
    }
  });

  test('All Pet Services extra keys are globally unique', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'pet_services');
    final allExtras = definition.services
        .expand((service) => service.extras)
        .toList(growable: false);
expect(allExtras.map((e) => e.key).toSet(), hasLength(allExtras.length));
   });

   test('Handyman pack has stable identity, aliases and four services', () {
     final definition = kVanBusinessTemplateLibrary.singleWhere(
       (item) => item.businessTypeId == 'handyman',
     );

     expect(definition.categoryId, 'handyman');
     expect(definition.categoryName, 'Handyman & General Services');
     expect(definition.businessTypeName, 'Handyman & General Services');
     expect(definition.iconKey, 'home');
     expect(definition.colorValue, 0xFFFFC107);
     expect(definition.featured, isTrue);
     expect(
       definition.searchKeywords,
       containsAll(<String>[
         'handyman',
         'general handyman',
         'odd jobs',
         'household jobs',
         'small repairs',
         'furniture assembly',
         'flat-pack assembly',
         'wall mounting',
         'shelf fitting',
       ]),
     );
     expect(
       definition.searchAliases.map((alias) => alias.label),
       containsAll(<String>[
         'Handyman',
         'General Handyman',
         'Odd Jobs',
         'Small Repairs',
         'Household Fixes',
         'Flat-Pack Assembly',
       ]),
     );
     expect(definition.services.map((service) => service.serviceId), <String>[
       'handyman_general_visit',
       'handyman_flat_pack_assembly',
       'handyman_wall_mounting',
       'handyman_minor_home_repairs',
     ]);
   });

   test('All Handyman services use one-address standard quote journeys', () {
     final services = kVanBusinessTemplateLibrary
         .singleWhere(
           (definition) => definition.businessTypeId == 'handyman',
         )
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

   test('Handyman questions and extras are explicit, unique and safe', () {
     final services = kVanBusinessTemplateLibrary
         .singleWhere(
           (definition) => definition.businessTypeId == 'handyman',
         )
         .services;
     final questions = services
         .expand((service) => service.questions)
         .toList(growable: false);
     final extras = services
         .expand((service) => service.extras)
         .toList(growable: false);

     expect(questions.map((question) => question.libraryId).toSet(), hasLength(40));
     expect(questions, hasLength(40));
     expect(
       questions.every(
         (question) =>
             VanCustomQuestionAnswerType.values.contains(question.answerType),
       ),
       isTrue,
     );
     expect(extras.map((extra) => extra.key).toSet(), hasLength(20));
     expect(extras, hasLength(20));
     expect(extras.every((extra) => extra.defaultPrice == 0), isTrue);
     expect(extras.every((extra) => extra.defaultChargeUnit == 'Fixed'), isTrue);
     expect(
       extras.every(
         (extra) =>
             !RegExp(r'\bfree\b', caseSensitive: false).hasMatch(extra.label),
       ),
       isTrue,
     );

     final generalVisit = services.singleWhere(
       (service) => service.serviceId == 'handyman_general_visit',
     );
     final flatPack = services.singleWhere(
       (service) => service.serviceId == 'handyman_flat_pack_assembly',
     );
     final wallMounting = services.singleWhere(
       (service) => service.serviceId == 'handyman_wall_mounting',
     );
     final minorRepairs = services.singleWhere(
       (service) => service.serviceId == 'handyman_minor_home_repairs',
     );

     expect(generalVisit.questions, hasLength(10));
     expect(flatPack.questions, hasLength(10));
     expect(wallMounting.questions, hasLength(10));
     expect(minorRepairs.questions, hasLength(10));
     expect(generalVisit.extras, hasLength(5));
     expect(flatPack.extras, hasLength(5));
     expect(wallMounting.extras, hasLength(5));
     expect(minorRepairs.extras, hasLength(5));
   });

   test('Handyman defaults preserve duration, notice, limits and schedule', () {
     final services = kVanBusinessTemplateLibrary
         .singleWhere((definition) => definition.businessTypeId == 'handyman')
         .services;
     final expected = <String, (int, int, int, List<int>)>{
       'handyman_general_visit': (120, 24, 4, <int>[1, 2, 3, 4, 5, 6]),
       'handyman_flat_pack_assembly': (90, 24, 4, <int>[1, 2, 3, 4, 5, 6]),
       'handyman_wall_mounting': (90, 24, 4, <int>[1, 2, 3, 4, 5, 6]),
       'handyman_minor_home_repairs': (60, 24, 6, <int>[1, 2, 3, 4, 5, 6]),
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
   });

   test('General Handyman Visit warns all tasks may not be completed in one visit', () {
     final definition = kVanBusinessTemplateLibrary
         .singleWhere((item) => item.businessTypeId == 'handyman');
     final service = definition.services.singleWhere(
       (service) => service.serviceId == 'handyman_general_visit',
     );

     final prioritiesQuestion = service.questions.singleWhere(
       (question) =>
           question.libraryId == 'handyman_general_visit_priorities',
     );
     expect(
       prioritiesQuestion.helperText,
       contains('may not be able to complete every requested job in one visit'),
     );

     final taskListQuestion = service.questions.singleWhere(
       (question) =>
           question.libraryId == 'handyman_general_visit_task_list',
     );
     expect(
       taskListQuestion.helperText,
       contains('not included'),
     );
   });

   test('Flat-Pack wall fixing is subject to safe assessment', () {
     final definition = kVanBusinessTemplateLibrary
         .singleWhere((item) => item.businessTypeId == 'handyman');
     final service = definition.services.singleWhere(
       (service) => service.serviceId == 'handyman_flat_pack_assembly',
     );

     final wallFixingQuestion = service.questions.singleWhere(
       (question) =>
           question.libraryId == 'handyman_flat_pack_wall_fixing',
     );
     expect(
       wallFixingQuestion.helperText,
       contains('subject to the business confirming'),
     );
     expect(
       wallFixingQuestion.helperText,
       contains('safe drilling location'),
     );
   });

    test('No Handyman question implies regulated work is accepted', () {
      final definition = kVanBusinessTemplateLibrary
          .singleWhere((item) => item.businessTypeId == 'handyman');

      for (final service in definition.services) {
        for (final question in service.questions) {
          if (service.serviceId == 'handyman_minor_home_repairs' &&
              question.libraryId == 'handyman_minor_repairs_specialist_risk') {
            continue;
          }
          expect(
            question.text.toLowerCase(),
            isNot(contains('electrical installation')),
          );
          expect(
            question.text.toLowerCase(),
            isNot(contains('gas work')),
          );
          expect(
            question.text.toLowerCase(),
            isNot(contains('boiler')),
          );
          expect(
            question.text.toLowerCase(),
            isNot(contains('structural alterations')),
          );
          expect(
            question.text.toLowerCase(),
            isNot(contains('roofing')),
          );
          expect(
            question.text.toLowerCase(),
            isNot(contains('major plumbing')),
          );
        }
      }
    });

    test('Existing eight curated categories remain unchanged', () {
      expect(kVanBusinessTemplateLibrary, hasLength(9));
      expect(findVanStarterCapabilityPackById('courier'), isNotNull);
      expect(
        findVanStarterCapabilityPackById('removals_man_with_van'),
        isNotNull,
      );
      expect(findVanStarterCapabilityPackById('cleaning'), isNotNull);
      expect(findVanStarterCapabilityPackById('gardening'), isNotNull);
      expect(findVanStarterCapabilityPackById('pet_services'), isNotNull);
      expect(findVanStarterCapabilityPackById('handyman'), isNotNull);
      expect(findVanStarterCapabilityPackById('window_cleaning'), isNotNull);
      expect(findVanStarterCapabilityPackById('photography'), isNotNull);
    });

    test('Wall Mounting safe drilling and wall condition disclaimers', () {
      final definition = kVanBusinessTemplateLibrary
          .singleWhere((item) => item.businessTypeId == 'handyman');
      final service = definition.services.singleWhere(
        (service) => service.serviceId == 'handyman_wall_mounting',
      );

      final wallTypeQuestion = service.questions.singleWhere(
        (question) =>
            question.libraryId == 'handyman_wall_mounting_wall_type',
      );
      expect(
        wallTypeQuestion.helperText,
        contains('confirm the wall condition'),
      );
      expect(
        wallTypeQuestion.helperText,
        contains('suitable fixing method before drilling'),
      );

      final hiddenServicesQuestion = service.questions.singleWhere(
        (question) =>
            question.libraryId == 'handyman_wall_mounting_hidden_services',
      );
      expect(
        hiddenServicesQuestion.helperText,
        contains('Work may not proceed'),
      );
      expect(
        hiddenServicesQuestion.helperText,
        contains('safe drilling location cannot be confirmed'),
      );

      final fixingsExtra = service.extras.singleWhere(
        (extra) => extra.key == 'custom_extra_handyman_wall_mounting_fixings',
      );
      expect(
        fixingsExtra.label,
        contains('subject to assessment'),
      );

      final heavyExtra = service.extras.singleWhere(
        (extra) => extra.key == 'custom_extra_handyman_wall_mounting_heavy_item',
      );
      expect(
        heavyExtra.label,
        contains('subject to assessment'),
      );
    });

    test('Minor Home Repairs excludes regulated and hazardous work', () {
      final definition = kVanBusinessTemplateLibrary
          .singleWhere((item) => item.businessTypeId == 'handyman');
      final service = definition.services.singleWhere(
        (service) => service.serviceId == 'handyman_minor_home_repairs',
      );

      expect(
        service.description,
        contains('Electrical, gas, structural, roofing and major plumbing work are not included'),
      );

      final specialistQuestion = service.questions.singleWhere(
        (question) =>
            question.libraryId == 'handyman_minor_repairs_specialist_risk',
      );
      expect(
        specialistQuestion.helperText,
        contains('appropriately qualified specialist'),
      );
      expect(
        specialistQuestion.helperText,
        contains('are not included in this service'),
      );

      final damageQuestion = service.questions.singleWhere(
        (question) =>
            question.libraryId == 'handyman_minor_repairs_damage_risk',
      );
      expect(
        damageQuestion.helperText,
        contains('Listing a concern does not mean'),
      );
      expect(
        damageQuestion.helperText,
        contains('hazardous or structural materials'),
      );

      final wasteExtra = service.extras.singleWhere(
        (extra) => extra.key == 'custom_extra_handyman_minor_repairs_small_waste_removal',
      );
      expect(
        wasteExtra.label,
        contains('non-hazardous'),
      );
      expect(
        wasteExtra.label,
        isNot(contains('asbestos')),
      );
      expect(
        wasteExtra.label,
        isNot(contains('licensed')),
      );
    });

  test('Photography pack has stable identity, aliases and two services', () {
    expect(kVanBusinessTemplateLibrary, hasLength(9));
    expect(kVanStarterCapabilityPacks, hasLength(9));
    expect(findVanStarterCapabilityPackById('photography'), isNotNull);

    final definition = kVanBusinessTemplateLibrary.singleWhere(
      (item) => item.businessTypeId == 'photography',
    );

    expect(definition.categoryId, 'photography');
    expect(definition.categoryName, 'Photography');
    expect(definition.businessTypeName, 'Photography');
    expect(definition.iconKey, 'sparkle');
    expect(definition.colorValue, 0xFFFF6E40);
    expect(definition.featured, isTrue);
    expect(
      definition.searchAliases.map((alias) => alias.label),
      containsAll(<String>[
        'Photographer',
        'Portrait Photography',
        'Family Photography',
        'Event Photographer',
        'Property Photographer',
        'Product Photographer',
        'Headshots',
      ]),
    );
    expect(searchVanStarterCapabilityPacks('photographer'), hasLength(1));
    expect(searchVanStarterCapabilityPacks('portrait photography'), hasLength(1));
    expect(definition.services.map((service) => service.serviceId), <String>[
      'photography_family_portrait',
      'photography_event',
      'photography_property',
      'photography_product',
    ]);
    expect(
      definition.services.every((service) => service.questions.isEmpty),
      isFalse,
    );
  });

  test('Photography services use one-address standard quote journeys', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'photography')
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

    final family = services.singleWhere(
      (service) => service.serviceId == 'photography_family_portrait',
    );
    expect(family.suggestedDurationMinutes, 90);
    expect(family.suggestedNoticeHours, 48);
    expect(family.maximumBookingsPerDay, 3);
    expect(family.availability.length, 6);
    expect(family.availability.every((day) => day.day <= 6), isTrue);
    expect(
      family.availability.every(
        (day) => day.startMinutes == 480 && day.endMinutes == 1080,
      ),
      isTrue,
    );

    final event = services.singleWhere(
      (service) => service.serviceId == 'photography_event',
    );
    expect(event.suggestedDurationMinutes, 180);
    expect(event.suggestedNoticeHours, 72);
    expect(event.maximumBookingsPerDay, 2);
    expect(event.availability.length, 7);
    expect(event.availability.every((day) => day.day >= 1 && day.day <= 7), isTrue);
    expect(
      event.availability.every(
        (day) => day.startMinutes == 420 && day.endMinutes == 1200,
      ),
      isTrue,
    );
  });

  test('Photography questions and extras are explicit, unique and safe', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((definition) => definition.businessTypeId == 'photography')
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

    expect(questions.map((question) => question.libraryId).toSet(), hasLength(46));
    expect(
      questions.map((question) => question.text.trim().toLowerCase())
          .toSet()
          .intersection(forbiddenCustomPrompts),
      isEmpty,
    );
    expect(extras.map((extra) => extra.key).toSet(), hasLength(20));
    expect(extras.every((extra) => extra.defaultPrice == 0), isTrue);
    expect(extras.every((extra) => extra.defaultChargeUnit == 'Fixed'), isTrue);
    expect(
      extras.every(
        (extra) =>
            !RegExp(r'\bfree\b', caseSensitive: false).hasMatch(extra.label),
      ),
      isTrue,
    );

    final family = services.singleWhere(
      (service) => service.serviceId == 'photography_family_portrait',
    );
    expect(family.questions, hasLength(11));
    expect(family.extras, hasLength(5));

    final event = services.singleWhere(
      (service) => service.serviceId == 'photography_event',
    );
    expect(event.questions, hasLength(12));
    expect(event.extras, hasLength(5));

    final property = services.singleWhere(
      (service) => service.serviceId == 'photography_property',
    );
    expect(property.questions, hasLength(11));
    expect(property.extras, hasLength(5));

    final product = services.singleWhere(
      (service) => service.serviceId == 'photography_product',
    );
    expect(product.questions, hasLength(12));
    expect(product.extras, hasLength(5));
  });

  test('Family & Portrait Photography content is safe and explicit', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'photography');
    final service = definition.services.singleWhere(
      (service) => service.serviceId == 'photography_family_portrait',
    );

    final childrenQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_family_portrait_children',
    );
    expect(
      childrenQuestion.helperText,
      contains('This does not grant permission for marketing or public use'),
    );

    final imageQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_family_portrait_image_requirements',
    );
    expect(
      imageQuestion.helperText,
      contains('Do not imply copyright transfer'),
    );
  });

  test('Event Photography content is safe and explicit', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'photography');
    final service = definition.services.singleWhere(
      (service) => service.serviceId == 'photography_event',
    );

    final restrictionQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_event_venue_restrictions',
    );
    expect(
      restrictionQuestion.helperText,
      contains('The photographer is not automatically responsible for arranging them'),
    );

    final coverageQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_event_coverage_duration',
    );
    expect(coverageQuestion.helperText, contains('request only'));
    expect(coverageQuestion.helperText, contains('confirm coverage and pricing'));

    final imageUseQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_event_image_use',
    );
    expect(
      imageUseQuestion.helperText,
      contains('This question does not transfer copyright'),
    );

    final allQuestionIds = service.questions.map((q) => q.libraryId).toSet();
    expect(allQuestionIds, isNot(contains('photography_event_drone')));
    expect(allQuestionIds, isNot(contains('drone')));
  });

  test('Photography services have no drone photography', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'photography');

    for (final service in definition.services) {
      expect(
        service.questions.every(
          (question) => !question.libraryId.toLowerCase().contains('drone'),
        ),
        isTrue,
        reason: '${service.serviceId} must not contain drone questions',
      );
      expect(
        service.extras.every(
          (extra) => !extra.key.toLowerCase().contains('drone'),
        ),
        isTrue,
        reason: '${service.serviceId} must not contain drone extras',
      );
      expect(
        service.extras.every(
          (extra) => !extra.label.toLowerCase().contains('drone'),
        ),
        isTrue,
        reason: '${service.serviceId} must not contain drone extra labels',
      );
    }
  });

  test('Property Photography content is safe and explicit', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'photography');
    final service = definition.services.singleWhere(
      (service) => service.serviceId == 'photography_property',
    );

    final readinessQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_property_readiness',
    );
    expect(
      readinessQuestion.helperText,
      contains('The photographer is not automatically responsible for cleaning'),
    );

    final accessQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_property_access_restrictions',
    );
    expect(
      accessQuestion.helperText,
      contains('The photographer may decline areas that cannot be accessed safely'),
    );

    final parkingQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_property_parking_access',
    );
    expect(
      parkingQuestion.helperText,
      contains('Do not provide alarm, door or key-safe codes publicly'),
    );

    final allQuestionIds = service.questions.map((q) => q.libraryId).toSet();
    expect(allQuestionIds, isNot(contains('photography_property_drone')));
    expect(allQuestionIds, isNot(contains('drone')));
    expect(allQuestionIds, isNot(contains('floor plan')));
    expect(allQuestionIds, isNot(contains('virtual tour')));
    expect(allQuestionIds, isNot(contains('valuation')));
    expect(allQuestionIds, isNot(contains('epc')));
  });

  test('Product Photography content is safe and explicit', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'photography');
    final service = definition.services.singleWhere(
      (service) => service.serviceId == 'photography_product',
    );

    final handlingQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_product_fragile_value',
    );
    expect(
      handlingQuestion.helperText,
      contains('Listing an item does not confirm that the photographer can accept'),
    );

    final intendedUseQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_product_intended_use',
    );
    expect(
      intendedUseQuestion.helperText,
      contains('This question does not transfer copyright'),
    );

    final editingQuestion = service.questions.singleWhere(
      (question) =>
          question.libraryId == 'photography_product_editing_requirements',
    );
    expect(
      editingQuestion.helperText,
      contains('Do not guarantee exact colour reproduction'),
    );

    final allQuestionIds = service.questions.map((q) => q.libraryId).toSet();
    expect(allQuestionIds, isNot(contains('photography_product_drone')));
    expect(allQuestionIds, isNot(contains('drone')));
    expect(allQuestionIds, isNot(contains('collection')));
    expect(allQuestionIds, isNot(contains('delivery')));
    expect(allQuestionIds, isNot(contains('storage')));
    expect(allQuestionIds, isNot(contains('insurance')));
  });

  test('Property and Product Photography use standard one-address quote flows', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'photography');

    for (final service in definition.services) {
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

  test('Property and Product Photography extras are pricing modifiers only', () {
    final definition = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'photography');

    for (final service in definition.services) {
      for (final extra in service.extras) {
        expect(extra.defaultPrice, equals(0));
        expect(extra.defaultChargeUnit, equals('Fixed'));
        expect(
          RegExp(r'\bfree\b', caseSensitive: false).hasMatch(extra.label),
          isFalse,
        );
      }
    }

    final property = definition.services.singleWhere(
      (service) => service.serviceId == 'photography_property',
    );
    final propertyExtraKeys = property.extras.map((e) => e.key).toSet();
    expect(
      propertyExtraKeys,
      containsAll(<String>[
        'custom_extra_photography_property_additional_rooms',
        'custom_extra_photography_property_exterior_garden',
        'custom_extra_photography_property_twilight_session',
        'custom_extra_photography_property_additional_property',
        'custom_extra_photography_property_express_editing',
      ]),
    );

    final product = definition.services.singleWhere(
      (service) => service.serviceId == 'photography_product',
    );
    final productExtraKeys = product.extras.map((e) => e.key).toSet();
    expect(
      productExtraKeys,
      containsAll(<String>[
        'custom_extra_photography_product_additional_product',
        'custom_extra_photography_product_additional_image',
        'custom_extra_photography_product_background_removal',
        'custom_extra_photography_product_lifestyle_setup',
        'custom_extra_photography_product_express_editing',
      ]),
    );
  });

  test('Bakery pack has stable identity and four order services', () {
    expect(kVanBusinessTemplateLibrary, hasLength(9));
    expect(kVanStarterCapabilityPacks, hasLength(9));
    expect(findVanStarterCapabilityPackById('bakery'), isNotNull);

    final definition = kVanBusinessTemplateLibrary.singleWhere(
      (item) => item.businessTypeId == 'bakery',
    );

    expect(definition.categoryId, 'bakery');
    expect(definition.categoryName, 'Cake & Bakery Orders');
    expect(definition.businessTypeId, 'bakery');
    expect(definition.businessTypeName, 'Cake & Bakery Orders');
    expect(
      definition.description,
      'Made-to-order cakes, cupcakes, traybakes and event bakes for collection or delivery.',
    );
    expect(definition.iconKey, 'sparkle');
    expect(definition.colorValue, 0xFF9C27B0);
    expect(definition.featured, isTrue);
    expect(
      definition.searchKeywords,
      containsAll(<String>[
        'bakery',
        'cake shop',
        'celebration cake',
        'cupcakes',
        'treat boxes',
        'brownies',
        'traybakes',
        'dessert boxes',
        'custom cakes',
        'event bakes',
      ]),
    );
    expect(
      definition.searchAliases.map((alias) => alias.label),
      containsAll(<String>[
        'Celebration Cakes',
        'Cupcakes',
        'Treat Boxes',
        'Brownies',
        'Dessert Boxes',
        'Corporate Bakes',
      ]),
    );
    expect(definition.services.map((service) => service.serviceId), <String>[
      'bakery_celebration_cakes',
      'bakery_cupcakes_treat_boxes',
      'bakery_brownies_traybakes',
      'bakery_custom_event_business_bakes',
    ]);
  });

  test('Bakery services use the shared Order Request fulfilment flow', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'bakery')
        .services;

    for (final service in services) {
      expect(service.customerJourney, VanCustomerJourneyType.order);
      expect(service.requestType, VanCustomerRequestType.orderRequest);
      expect(service.requestFlowOptions.showFulfilmentChoice, isTrue);
      expect(service.requireAddress, isFalse);
      expect(service.requestFlowOptions.askPreferredDate, isTrue);
      expect(service.requestFlowOptions.askPreferredTime, isTrue);
      expect(service.requestFlowOptions.showNotes, isTrue);
      expect(service.requestPhotos, isTrue);
      expect(service.startHandover, isNull);
      expect(service.endHandover, isNull);
      expect(service.requestFlowOptions.showPickupAddress, isFalse);
      expect(service.requestFlowOptions.showDeliveryAddress, isFalse);
      expect(service.requestFlowOptions.showDropOffDate, isFalse);
      expect(service.requestFlowOptions.showDropOffTime, isFalse);
      expect(service.requestFlowOptions.showPickUpDate, isFalse);
      expect(service.requestFlowOptions.showPickUpTime, isFalse);
      expect(
        service.builtInQuestionKeys,
        containsAll(<String>[
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        ]),
      );
      expect(service.builtInQuestionSettings['phone']?['required'], isTrue);
      expect(service.builtInQuestionSettings['email']?['required'], isFalse);
      expect(
        service.builtInQuestionSettings['preferred_date']?['required'],
        isTrue,
      );
      expect(
        service.builtInQuestionSettings['preferred_time']?['required'],
        isTrue,
      );
      expect(service.builtInQuestionSettings['photos']?['required'], isFalse);
    }
  });

  test('Bakery services have final question and extra counts', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'bakery')
        .services;

    expect(services, hasLength(4));
    expect(
      services.map((service) => service.questions.length),
      everyElement(12),
    );
    expect(services.map((service) => service.extras.length), everyElement(5));
    expect(
      services.expand((service) => service.questions).map((q) => q.libraryId),
      hasLength(48),
    );
    expect(
      services.expand((service) => service.extras).map((extra) => extra.key),
      hasLength(20),
    );

    final questionIds = services
        .expand((service) => service.questions)
        .map((question) => question.libraryId)
        .toSet();
    expect(questionIds, hasLength(48));
    expect(
      questionIds,
      containsAll(<String>[
        'bakery_celebration_cakes_occasion',
        'bakery_celebration_cakes_servings',
        'bakery_celebration_cakes_size_tiers',
        'bakery_celebration_cakes_sponge_flavour',
        'bakery_celebration_cakes_filling',
        'bakery_celebration_cakes_finish',
        'bakery_celebration_cakes_design_brief',
        'bakery_celebration_cakes_message',
        'bakery_celebration_cakes_decorations',
        'bakery_celebration_cakes_setup',
        'bakery_celebration_cakes_allergy_declaration',
        'bakery_celebration_cakes_allergy_details',
        'bakery_cupcakes_treat_boxes_occasion',
        'bakery_cupcakes_treat_boxes_product_type',
        'bakery_cupcakes_treat_boxes_quantity',
        'bakery_cupcakes_treat_boxes_packaging',
        'bakery_cupcakes_treat_boxes_main_flavour',
        'bakery_cupcakes_treat_boxes_flavour_details',
        'bakery_cupcakes_treat_boxes_design_style',
        'bakery_cupcakes_treat_boxes_theme_colours',
        'bakery_cupcakes_treat_boxes_personalisation',
        'bakery_cupcakes_treat_boxes_individual_distribution',
        'bakery_cupcakes_treat_boxes_allergy_declaration',
        'bakery_cupcakes_treat_boxes_allergy_details',
        'bakery_brownies_traybakes_product_type',
        'bakery_brownies_traybakes_occasion',
        'bakery_brownies_traybakes_portion_count',
        'bakery_brownies_traybakes_portion_format',
        'bakery_brownies_traybakes_main_flavour',
        'bakery_brownies_traybakes_flavour_details',
        'bakery_brownies_traybakes_toppings_fillings',
        'bakery_brownies_traybakes_packaging',
        'bakery_brownies_traybakes_personalised_message',
        'bakery_brownies_traybakes_serving_storage',
        'bakery_brownies_traybakes_allergy_declaration',
        'bakery_brownies_traybakes_allergy_details',
        'bakery_custom_event_business_bakes_purpose',
        'bakery_custom_event_business_bakes_product_types',
        'bakery_custom_event_business_bakes_quantity',
        'bakery_custom_event_business_bakes_serving_format',
        'bakery_custom_event_business_bakes_branding',
        'bakery_custom_event_business_bakes_design_brief',
        'bakery_custom_event_business_bakes_individual_wrapping',
        'bakery_custom_event_business_bakes_packaging_display',
        'bakery_custom_event_business_bakes_setup_access',
        'bakery_custom_event_business_bakes_image_use',
        'bakery_custom_event_business_bakes_allergy_declaration',
        'bakery_custom_event_business_bakes_allergy_details',
      ]),
    );

    final extraKeys = services
        .expand((service) => service.extras)
        .map((extra) => extra.key)
        .toSet();
    expect(extraKeys, hasLength(20));
    expect(
      extraKeys,
      containsAll(<String>[
        'custom_extra_bakery_celebration_cakes_additional_servings',
        'custom_extra_bakery_celebration_cakes_additional_tier',
        'custom_extra_bakery_celebration_cakes_handmade_topper',
        'custom_extra_bakery_celebration_cakes_premium_decoration',
        'custom_extra_bakery_celebration_cakes_venue_setup',
        'custom_extra_bakery_cupcakes_treat_boxes_additional_dozen',
        'custom_extra_bakery_cupcakes_treat_boxes_mixed_flavours',
        'custom_extra_bakery_cupcakes_treat_boxes_personalised_toppers',
        'custom_extra_bakery_cupcakes_treat_boxes_individual_wrapping',
        'custom_extra_bakery_cupcakes_treat_boxes_presentation_box',
        'custom_extra_bakery_brownies_traybakes_additional_portions',
        'custom_extra_bakery_brownies_traybakes_mixed_flavours',
        'custom_extra_bakery_brownies_traybakes_premium_toppings',
        'custom_extra_bakery_brownies_traybakes_personalised_message',
        'custom_extra_bakery_brownies_traybakes_gift_packaging',
        'custom_extra_bakery_custom_event_business_bakes_additional_quantity',
        'custom_extra_bakery_custom_event_business_bakes_individual_wrapping',
        'custom_extra_bakery_custom_event_business_bakes_edible_logo',
        'custom_extra_bakery_custom_event_business_bakes_display_packaging',
        'custom_extra_bakery_custom_event_business_bakes_venue_setup',
      ]),
    );
  });

  test('Bakery custom questions do not duplicate built-in fields or fulfilment extras', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'bakery')
        .services;
    final forbiddenQuestionTerms = <String>[
      'collection or delivery',
      'delivery address',
      'preferred date',
      'preferred time',
      'phone',
      'email',
      'order notes',
      'photo upload',
    ];

    for (final service in services) {
      for (final question in service.questions) {
        final text = question.text.toLowerCase();
        for (final term in forbiddenQuestionTerms) {
          expect(text, isNot(contains(term)));
        }
      }
      expect(
        service.extras.map((extra) => extra.label.toLowerCase()),
        isNot(contains('collection')),
      );
      expect(
        service.extras.map((extra) => extra.label.toLowerCase()),
        isNot(contains('delivery')),
      );
    }
  });

  test('Bakery safety helpers keep allergen, copyright and logistics promises bounded', () {
    final services = kVanBusinessTemplateLibrary
        .singleWhere((item) => item.businessTypeId == 'bakery')
        .services;
    const allergenSafeguards = <String>[
      'does not guarantee that the business can accept the order',
      'do not guarantee an allergen-free environment',
      'Cross-contamination risks must be discussed directly',
      'confirm whether it can fulfil the request safely',
    ];

    for (final service in services) {
      final allText = <String>[
        service.description,
        service.suggestedCustomerMessage,
        for (final question in service.questions) question.text,
        for (final question in service.questions) question.helperText,
        for (final extra in service.extras) extra.label,
      ].join(' ');

      final allergyDetails = service.questions.singleWhere(
        (question) => question.libraryId.endsWith('_allergy_details'),
      );
      for (final safeguard in allergenSafeguards) {
        expect(allergyDetails.helperText, contains(safeguard));
      }
      expect(allText, isNot(contains('allergen-free production')));
      expect(allText, isNot(contains('licensed-character permission')));
      expect(allText, isNot(contains('exact colour matching is guaranteed')));
      expect(allText, isNot(contains('refrigerated transport is included')));
      expect(allText, isNot(contains('national shipping is included')));
      expect(allText, isNot(contains('venue setup is included')));
    }
  });
}
