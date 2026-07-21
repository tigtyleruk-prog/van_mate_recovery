import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_capability.dart';
import 'package:van_mate_app/features/van_mate/models/van_starter_capability_pack.dart';

void main() {
  test('Bakery selections create independent journey recommendations', () {
    final bakery = findVanStarterCapabilityPackById('bakery_business')!;
    final setups = bakery.recommendationsFor(<String>[
      'walk_in',
      'click_collect',
      'local_delivery',
      'celebration_cakes',
    ]);

    expect(setups, hasLength(4));
    expect(
      setups.firstWhere((item) => item.serviceKey == 'walk_in').journeyType,
      VanCustomerJourneyType.order,
    );
    expect(
      setups
          .firstWhere((item) => item.serviceKey == 'click_collect')
          .capabilityIds,
      contains(VanServiceCapabilityIds.customerCollects),
    );
    expect(
      setups
          .firstWhere((item) => item.serviceKey == 'local_delivery')
          .capabilityIds,
      contains(VanServiceCapabilityIds.localDelivery),
    );
    final cakes = setups.firstWhere(
      (item) => item.serviceKey == 'celebration_cakes',
    );
    expect(cakes.journeyType, VanCustomerJourneyType.quote);
    expect(cakes.suggestedReminderMinutes, containsAll(<int>[10080, 1440]));
    expect(cakes.suggestedStatusNames['ready'], 'Ready for collection');
    expect(
      cakes.quoteExtraDefaults().orderedExtras.map(
        (extra) => extra.resolvedLabel,
      ),
      containsAll(<String>[
        'Deposit',
        'Design consultation',
        'Extra tiers',
        'Fondant finish',
        'Sugar flowers',
        'Delivery',
        'Cake stand hire',
      ]),
    );
    expect(
      cakes.questions.map((question) => question.text),
      containsAll(<String>[
        'Occasion',
        'Number of servings',
        'Theme / Colours',
        'Inspiration photos',
        'Collection or delivery',
        'Additional notes',
      ]),
    );
    expect(
      cakes.questions
          .firstWhere((question) => question.text == 'Collection or delivery')
          .choiceOptions,
      <String>['Collection', 'Delivery'],
    );
  });

  test('Dog Groomer recommends services with universal capabilities', () {
    final grooming = findVanStarterCapabilityPackById('dog_groomer_business')!;
    expect(
      grooming.serviceRecommendations.map((item) => item.name),
      containsAll(<String>[
        'Full Groom',
        'Bath and Brush',
        'Nail Clipping',
        'Puppy Groom',
        'De-shedding Treatment',
        'Customer Drop-off and Collection',
        'Collection and Return Service',
      ]),
    );
    final setup = grooming.recommendationsFor(<String>['full_groom']).single;

    expect(setup.journeyType, VanCustomerJourneyType.booking);
    expect(
      setup.capabilityIds,
      containsAll(<String>[
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
      ]),
    );
    expect(setup.allowCustomerDropOff, isTrue);
    expect(setup.allowCustomerCollection, isTrue);
    expect(
      setup.questions.map((question) => question.text),
      containsAll(<String>[
        'Pet Name',
        'Breed',
        'Weight',
        'Temperament',
        'Health conditions or allergies',
      ]),
    );
    expect(
      setup.quoteExtraDefaults().enabledExtras.map(
        (extra) => extra.resolvedLabel,
      ),
      containsAll(<String>['Nail trim', 'Teeth clean', 'Flea treatment']),
    );
  });

  test('Photography and Garage expose composable service capabilities', () {
    final photography = findVanStarterCapabilityPackById(
      'photography_business',
    )!;
    final garage = findVanStarterCapabilityPackById('garage_business')!;

    expect(
      photography.serviceRecommendations.map((item) => item.name),
      containsAll(<String>[
        'Portrait Session',
        'Family Photoshoot',
        'Wedding Photography',
        'Event Photography',
        'Product Photography',
        'Business Headshots',
        'Photo Editing',
        'Photo Prints',
        'Photo Restoration',
      ]),
    );
    expect(
      garage.serviceRecommendations.map((item) => item.name),
      containsAll(<String>[
        'MOT',
        'Vehicle Repairs',
        'Interim Service',
        'Full Service',
        'Diagnostics',
        'Tyres',
        'Brakes',
        'Vehicle Collection and Return',
      ]),
    );
    final wedding = photography.recommendationsFor(<String>[
      'wedding_photography',
    ]).single;
    expect(
      wedding.questions.map((question) => question.text),
      containsAll(<String>[
        'Wedding date',
        'Venue',
        'Number of guests',
        'Photography style',
        'Additional requests',
      ]),
    );
  });

  test('existing templates expand into useful service menus', () {
    final gardening = findVanStarterCapabilityPackById('gardening_business')!;

    expect(gardening.name, 'Gardening');
    expect(gardening.serviceRecommendations, hasLength(8));
    expect(
      gardening.serviceRecommendations.map((service) => service.name),
      containsAll(<String>[
        'Lawn Mowing',
        'Hedge Trimming',
        'Garden Tidy-up',
        'Regular Garden Maintenance',
      ]),
    );
    expect(
      gardening.recommendationsFor(<String>['lawn_mowing']).single.questions,
      isNotEmpty,
    );
  });

  test('every business type offers a complete selectable service menu', () {
    expect(kVanStarterCapabilityPacks, hasLength(39));
    expect(
      kVanStarterCapabilityPacks.fold<int>(
        0,
        (total, pack) => total + pack.serviceRecommendations.length,
      ),
      greaterThan(250),
    );
    for (final pack in kVanStarterCapabilityPacks) {
      final recommendations = pack.serviceRecommendations;
      expect(
        recommendations.length,
        greaterThanOrEqualTo(5),
        reason: '${pack.name} should offer at least five service choices',
      );
      expect(
        recommendations.map((service) => service.id).toSet(),
        hasLength(recommendations.length),
        reason: '${pack.name} service ids should be unique',
      );
      expect(
        recommendations.any(
          (service) => service.name == 'Standard ${pack.name}',
        ),
        isFalse,
        reason: '${pack.name} should use an audited service catalogue',
      );
      for (final recommendation in recommendations) {
        expect(recommendation.name.trim(), isNotEmpty);
        expect(recommendation.description.trim(), isNotEmpty);
        final setup = pack.recommendationsFor(<String>[
          recommendation.id,
        ]).single;
        expect(
          setup.capabilityIds,
          isNotEmpty,
          reason: '${pack.name} / ${recommendation.name} needs capabilities',
        );
        expect(
          setup.questions,
          isNotEmpty,
          reason: '${pack.name} / ${recommendation.name} needs questions',
        );
        expect(setup.suggestedDurationMinutes, greaterThan(0));
        expect(setup.suggestedStatusNames, isNotEmpty);
      }
    }
  });

  test('every service can use the same universal capability library', () {
    expect(
      kVanServiceCapabilities.map((item) => item.id),
      containsAll(<String>[
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.placeOrder,
        VanServiceCapabilityIds.requestQuote,
        VanServiceCapabilityIds.localDelivery,
        VanServiceCapabilityIds.digitalDelivery,
        VanServiceCapabilityIds.depositRequired,
        VanServiceCapabilityIds.leadTime,
      ]),
    );

    final resolved = resolveVanServiceCapabilities(<String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.appointmentRequired,
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.localDelivery,
      VanServiceCapabilityIds.depositRequired,
    });
    expect(resolved.journeyType, VanCustomerJourneyType.quote);
    expect(resolved.requireAddress, isTrue);
    expect(resolved.builtInQuestionKeys, contains('preferred_date'));
    expect(
      resolved.extras.map((item) => item.label),
      containsAll(<String>['Local delivery', 'Deposit']),
    );
  });

  test('business recommendations can be replaced by any capability mix', () {
    final bakery = findVanStarterCapabilityPackById('bakery_business')!;
    final setup = bakery
        .recommendationsFor(
          <String>['walk_in'],
          capabilityIdsByService: <String, Set<String>>{
            'walk_in': <String>{
              VanServiceCapabilityIds.booking,
              VanServiceCapabilityIds.bookAppointment,
              VanServiceCapabilityIds.appointmentRequired,
              VanServiceCapabilityIds.recurring,
              VanServiceCapabilityIds.businessVisitsCustomer,
              VanServiceCapabilityIds.digitalDelivery,
              VanServiceCapabilityIds.fromPrice,
            },
          },
        )
        .single;

    expect(setup.journeyType, VanCustomerJourneyType.booking);
    expect(setup.requireAddress, isTrue);
    expect(setup.pricingMode, VanServiceCapabilityIds.fromPrice);
    expect(
      setup.questions.map((item) => item.text),
      containsAll(<String>[
        'Preferred file format',
        'How often do you need this service?',
      ]),
    );
    expect(
      setup.quoteExtraDefaults().enabledExtras.map(
        (item) => item.resolvedLabel,
      ),
      contains('Mileage'),
    );
  });

  test('exclusive capability groups keep one journey and pricing mode', () {
    var selected = toggleVanServiceCapability(
      const <String>{VanServiceCapabilityIds.requestQuote},
      VanServiceCapabilityIds.placeOrder,
      true,
    );
    expect(selected, contains(VanServiceCapabilityIds.placeOrder));
    expect(selected, isNot(contains(VanServiceCapabilityIds.requestQuote)));

    selected = toggleVanServiceCapability(
      <String>{...selected, VanServiceCapabilityIds.fixedPrice},
      VanServiceCapabilityIds.customQuote,
      true,
    );
    expect(selected, contains(VanServiceCapabilityIds.customQuote));
    expect(selected, isNot(contains(VanServiceCapabilityIds.fixedPrice)));
  });

  test('capability generation de-duplicates overlapping recommendations', () {
    final resolved = resolveVanServiceCapabilities(<String>{
      VanServiceCapabilityIds.localDelivery,
      VanServiceCapabilityIds.nationwideDelivery,
      VanServiceCapabilityIds.businessVisitsCustomer,
    });

    expect(
      resolved.builtInQuestionKeys.where((item) => item == 'address'),
      hasLength(1),
    );
    expect(
      resolved.questions.where((item) => item.text == 'Delivery instructions'),
      hasLength(1),
    );
  });

  test('courier offers distinct services with complete generated defaults', () {
    final courier = findVanStarterCapabilityPackById('courier_business')!;
    expect(
      courier.serviceRecommendations.map((service) => service.name),
      orderedEquals(<String>[
        'Same-day Delivery',
        'Scheduled Delivery',
        'Multi-drop Delivery',
        'Parcel Collection and Delivery',
        'Legal Document Delivery',
        'Medical or Pharmacy Delivery',
      ]),
    );
    final setup = courier.recommendationsFor(<String>[
      'same_day_delivery',
    ]).single;

    expect(setup.questions, isNotEmpty);
    expect(
      setup.capabilityIds,
      containsAll(<String>[
        VanServiceCapabilityIds.sameDay,
        VanServiceCapabilityIds.businessCollects,
        VanServiceCapabilityIds.businessReturns,
      ]),
    );
    expect(setup.suggestedStatusNames, isNotEmpty);
    expect(setup.suggestedReminderMinutes, isNotEmpty);
    expect(
      setup.quoteExtraDefaults().enabledExtras.map(
        (extra) => extra.resolvedLabel,
      ),
      containsAll(<String>[
        'Urgent collection',
        'Waiting time',
        'Additional stop',
        'Mileage outside included area',
      ]),
    );
  });

  test('transport packs expose only the requested business types', () {
    expect(
      kVanStarterCapabilityPacks
          .where((pack) => pack.category == 'Transport & Delivery')
          .map((pack) => pack.name),
      containsAll(<String>['Courier', 'Man & Van', 'Removals']),
    );
    expect(
      kVanStarterCapabilityPacks.map((pack) => pack.name),
      isNot(
        contains(
          anyOf(<String>[
            'Same-day Delivery',
            'Multi-drop Delivery',
            'Store Collections',
            'Furniture Delivery',
          ]),
        ),
      ),
    );
  });

  test('Man & Van and Removals expose their audited service catalogues', () {
    final manVan = findVanStarterCapabilityPackById('man_van_business')!;
    final removals = findVanStarterCapabilityPackById('removals_business')!;

    expect(
      manVan.serviceRecommendations.map((service) => service.name),
      orderedEquals(<String>[
        'Single Item Delivery',
        'Furniture Collection and Delivery',
        'Store Collection',
        'Marketplace Collection',
        'Small House Move',
        'Student Move',
        'Office Items Move',
        'Appliance Collection and Delivery',
      ]),
    );
    expect(
      removals.serviceRecommendations.map((service) => service.name),
      orderedEquals(<String>[
        'House Move',
        'Flat or Apartment Move',
        'Office Move',
        'Packing Service',
        'Packing and Removal',
        'Storage Collection',
        'Storage Delivery',
        'Internal Property Move',
      ]),
    );
  });

  test('transport questions are useful, reusable and service-specific', () {
    final packs = <VanStarterCapabilityPack>[
      findVanStarterCapabilityPackById('courier_business')!,
      findVanStarterCapabilityPackById('man_van_business')!,
      findVanStarterCapabilityPackById('removals_business')!,
    ];
    const forbidden = <String>{
      'what service do you need?',
      'preferred contact method',
      'customer name',
      'phone number',
      'email address',
      'preferred date',
      'preferred time',
      'address',
    };
    for (final pack in packs) {
      for (final recommendation in pack.serviceRecommendations) {
        final setup = pack.recommendationsFor(<String>[
          recommendation.id,
        ]).single;
        expect(
          setup.questions.any(
            (question) => question.text.startsWith('Tell us what you need'),
          ),
          isFalse,
        );
        expect(
          setup.questions.map((question) => question.text.toLowerCase()),
          isNot(contains(anyOf(forbidden))),
        );
        expect(
          setup.builtInQuestionKeys,
          anyOf(
            contains('address'),
            containsAll(<String>['collection_address', 'delivery_address']),
          ),
        );
        expect(
          setup.questions.where((question) => question.libraryId.isEmpty),
          isEmpty,
        );
      }
    }

    final courier = packs.first;
    final sharedIds = courier.serviceRecommendations
        .map(
          (service) => service.questions
              .firstWhere(
                (question) =>
                    question.text.startsWith('What are we collecting'),
              )
              .libraryId,
        )
        .toSet();
    expect(sharedIds, <String>{'transport.items.what'});

    final legal = courier.serviceRecommendations.firstWhere(
      (service) => service.id == 'legal_document_delivery',
    );
    final parcel = courier.serviceRecommendations.firstWhere(
      (service) => service.id == 'parcel_collection_delivery',
    );
    expect(
      legal.questions.map((question) => question.libraryId),
      contains('legal.proof_required'),
    );
    expect(
      parcel.questions.map((question) => question.libraryId),
      isNot(contains('legal.proof_required')),
    );
  });

  test('transport extras retain charging methods and optional deposits', () {
    final courier = findVanStarterCapabilityPackById('courier_business')!;
    final manVan = findVanStarterCapabilityPackById('man_van_business')!;
    final removals = findVanStarterCapabilityPackById('removals_business')!;

    final courierExtras = <String, dynamic>{
      for (final extra in courier.serviceRecommendations.first.extras)
        extra.label: extra,
    };
    expect(courierExtras['Waiting time'].defaultChargeUnit, '30 Minutes');
    expect(courierExtras['Additional stop'].defaultChargeUnit, 'Stop');
    expect(
      courierExtras['Mileage outside included area'].defaultChargeUnit,
      'Mile',
    );

    final manVanDeposit = manVan.serviceRecommendations.first.extras.firstWhere(
      (extra) => extra.label == 'Deposit',
    );
    expect(manVanDeposit.enabledByDefault, isFalse);
    final removalDeposit = removals.serviceRecommendations.first.extras
        .firstWhere((extra) => extra.label == 'Deposit');
    expect(removalDeposit.enabledByDefault, isTrue);
    expect(
      removals
          .recommendationsFor(<String>[
            removals.serviceRecommendations.first.id,
          ])
          .single
          .quoteExtraDefaults()
          .enabledExtras
          .map((extra) => extra.resolvedLabel),
      contains('Deposit'),
    );
    expect(
      removals.serviceRecommendations.first.extras
          .firstWhere((extra) => extra.label == 'Additional vehicle')
          .defaultChargeUnit,
      'Day',
    );
  });

  test(
    'individual onboarding review preserves every audited transport default',
    () {
      final packs = <VanStarterCapabilityPack>[
        findVanStarterCapabilityPackById('courier_business')!,
        findVanStarterCapabilityPackById('man_van_business')!,
        findVanStarterCapabilityPackById('removals_business')!,
      ];

      for (final pack in packs) {
        final recommendations = pack.serviceRecommendations;
        final setups = pack.recommendationsFor(
          recommendations.map((service) => service.id),
        );
        expect(setups, hasLength(recommendations.length));

        for (final recommendation in recommendations) {
          final setup = setups.singleWhere(
            (candidate) => candidate.serviceKey == recommendation.id,
          );
          expect(setup.name, recommendation.name);
          expect(setup.description, recommendation.description);
          expect(
            setup.capabilityIds,
            containsAll(recommendation.recommendedCapabilityIds),
          );
          for (final question in recommendation.questions) {
            final generated = setup.questions.singleWhere(
              (candidate) => candidate.libraryId == question.libraryId,
            );
            expect(generated.text, question.text);
            expect(generated.answerType, question.answerType);
            expect(generated.category, question.category);
            expect(generated.choiceOptions, question.choiceOptions);
            expect(generated.tags, question.tags);
          }
          for (final extra in recommendation.extras) {
            final generated = setup.extras.singleWhere(
              (candidate) => candidate.key == extra.key,
            );
            expect(generated.label, extra.label);
            expect(generated.defaultPrice, extra.defaultPrice);
            expect(generated.defaultChargeUnit, extra.defaultChargeUnit);
            expect(generated.enabledByDefault, extra.enabledByDefault);
            expect(generated.tags, extra.tags);
          }
          expect(setup.suggestedDurationMinutes, isNotNull);
          expect(setup.suggestedNoticeHours, greaterThanOrEqualTo(0));
          expect(setup.suggestedStatusNames, isNotEmpty);
        }
      }
    },
  );

  test('business search ranks exact, related and aliased plumber matches', () {
    final results = searchVanStarterCapabilityPacks('plumber');

    expect(results.first.label, 'Plumber');
    expect(
      results.map((item) => item.label),
      containsAll(<String>[
        'Emergency Plumber',
        'Heating Engineer',
        'Bathroom Installer',
      ]),
    );
    expect(results.every((item) => item.pack.id == 'plumber_business'), isTrue);
  });

  test('business search uses visible aliases and hidden keywords', () {
    final cakeResults = searchVanStarterCapabilityPacks('cake');
    final cakeLabels = cakeResults.map((item) => item.label);

    expect(
      cakeLabels,
      containsAll(<String>[
        'Cake Orders',
        'Bakery',
        'Wedding Cakes',
        'Cupcakes',
        'Catering',
      ]),
    );
    expect(searchVanStarterCapabilityPacks('bread').first.pack.name, 'Bakery');
    expect(
      searchVanStarterCapabilityPacks('grass').first.pack.name,
      'Gardening',
    );
    expect(
      searchVanStarterCapabilityPacks('glass').first.pack.name,
      'Window Cleaning',
    );
    expect(
      searchVanStarterCapabilityPacks('pet').map((item) => item.pack.name),
      contains('Dog Groomer'),
    );
  });

  test('business search accepts partial and plural terms', () {
    expect(
      searchVanStarterCapabilityPacks('gard').first.pack.name,
      'Gardening',
    );
    expect(
      searchVanStarterCapabilityPacks('windows').map((item) => item.pack.name),
      contains('Window Cleaning'),
    );
    expect(searchVanStarterCapabilityPacks('dogs'), isNotEmpty);
    expect(searchVanStarterCapabilityPacks('no-match-here'), isEmpty);
  });
}
