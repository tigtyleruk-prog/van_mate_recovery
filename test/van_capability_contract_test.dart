import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_capability.dart';

void main() {
  test(
    'resolves journey, response, presentation and movement choices once',
    () {
      final contract = resolveVanCapabilityContract([
        VanServiceCapabilityIds.preOrder,
        VanServiceCapabilityIds.customerVisitsBusiness,
        VanServiceCapabilityIds.localDelivery,
        VanServiceCapabilityIds.preparationTime,
        VanServiceCapabilityIds.fixedPrice,
      ]);

      expect(contract.journeyType, VanCustomerJourneyType.preOrder);
      expect(contract.requestType, VanCustomerRequestType.orderRequest);
      expect(contract.responseDocumentType, 'orderSummary');
      expect(contract.calendarPresentation, 'compactTimed');
      expect(contract.pricingMode, VanServiceCapabilityIds.fixedPrice);
      expect(contract.exactTimeRequired, isTrue);
      expect(
        contract.recommendedBuiltInQuestionKeys,
        containsAll(<String>[
          'preferred_date',
          'preferred_time',
          'flexible_timing',
        ]),
      );
      expect(contract.movementChoiceGroups, hasLength(1));
      expect(contract.movementChoiceGroups.single.id, 'receive');
      expect(
        contract.movementChoiceGroups.single.options.map(
          (option) => option.value,
        ),
        ['collection', 'localDelivery'],
      );
      expect(contract.requireAddress, isTrue);
      expect(contract.noticeHours, 48);
    },
  );

  test('fixed price resolves as the contract pricing mode', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.placeOrder,
      VanServiceCapabilityIds.fixedPrice,
    ]);

    expect(contract.pricingMode, VanServiceCapabilityIds.fixedPrice);
    expect(
      contract.toJson()['pricingMode'],
      VanServiceCapabilityIds.fixedPrice,
    );
  });

  test('from price resolves as the contract pricing mode', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.fromPrice,
    ]);

    expect(contract.pricingMode, VanServiceCapabilityIds.fromPrice);
    expect(contract.toJson()['pricingMode'], VanServiceCapabilityIds.fromPrice);
  });

  test('appointment timing recommends flexible timing built-in question', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.bookAppointment,
      VanServiceCapabilityIds.appointmentRequired,
    ]);

    expect(contract.appointmentRequired, isTrue);
    expect(contract.exactTimeRequired, isFalse);
    expect(
      contract.recommendedBuiltInQuestionKeys,
      containsAll(<String>[
        'preferred_date',
        'preferred_time',
        'flexible_timing',
      ]),
    );
    expect(
      contract.toJson()['recommendedBuiltInQuestionKeys'],
      contains('flexible_timing'),
    );

    final resolved = resolveVanServiceCapabilities([
      VanServiceCapabilityIds.bookAppointment,
      VanServiceCapabilityIds.appointmentRequired,
    ]);
    expect(resolved.journeyType, VanCustomerJourneyType.booking);
    expect(resolved.requestType, VanCustomerRequestType.bookingRequest);
    expect(
      resolved.builtInQuestionKeys,
      containsAll(<String>['preferred_date', 'preferred_time']),
    );
    expect(resolved.builtInQuestionKeys, isNot(contains('flexible_timing')));
    expect(resolved.suggestedDurationMinutes, 60);
  });

  test('preparation time resolves into booking notice without questions', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.placeOrder,
      VanServiceCapabilityIds.preparationTime,
    ]);

    expect(contract.preparationTime, isTrue);
    expect(contract.leadTime, isFalse);
    expect(contract.noticeHours, 48);
    expect(contract.journeyType, VanCustomerJourneyType.order);
    expect(contract.requestType, VanCustomerRequestType.orderRequest);
    expect(contract.recommendedBuiltInQuestionKeys, isEmpty);
    expect(contract.toJson()['preparationTime'], isTrue);
    expect(contract.toJson()['noticeHours'], 48);

    final resolved = resolveVanServiceCapabilities([
      VanServiceCapabilityIds.placeOrder,
      VanServiceCapabilityIds.preparationTime,
    ]);
    expect(resolved.suggestedNoticeHours, 48);
    expect(resolved.builtInQuestionKeys, isEmpty);
    expect(resolved.questions, isEmpty);
    expect(resolved.extras, isEmpty);
  });

  test('exact pin resolves as a post-acceptance built-in capability', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.businessVisitsCustomer,
      VanServiceCapabilityIds.exactPin,
    ]);

    expect(contract.requiresExactPinAfterAcceptance, isTrue);
    expect(contract.exactPinTiming, 'afterAcceptance');
    expect(contract.recommendedBuiltInQuestionKeys, contains('exact_pin'));
    expect(contract.toJson()['requiresExactPinAfterAcceptance'], isTrue);
    expect(contract.toJson()['exactPinTiming'], 'afterAcceptance');

    final resolved = resolveVanServiceCapabilities([
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.businessVisitsCustomer,
      VanServiceCapabilityIds.exactPin,
    ]);
    expect(resolved.builtInQuestionKeys, contains('exact_pin'));
    expect(resolved.requireAddress, isTrue);
  });

  test('customer visits business resolves as collection without address', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.customerVisitsBusiness,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'receive');
    expect(
      contract.movementChoiceGroups.single.heading,
      'How would you like to receive your order?',
    );
    expect(contract.movementChoiceGroups.single.options, hasLength(1));
    expect(
      contract.movementChoiceGroups.single.options.single.value,
      'collection',
    );
    expect(
      contract.movementChoiceGroups.single.options.single.label,
      'Collect',
    );
    expect(contract.requireAddress, isFalse);
    expect(contract.recommendedBuiltInQuestionKeys, isNot(contains('address')));
  });

  test('business visits customer resolves service address behaviour', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.businessVisitsCustomer,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'receive');
    expect(
      contract.movementChoiceGroups.single.options.single.value,
      'businessVisit',
    );
    expect(
      contract.movementChoiceGroups.single.options.single.label,
      'Business visit',
    );
    expect(contract.requireAddress, isTrue);
    expect(contract.recommendedBuiltInQuestionKeys, contains('address'));
    expect(contract.addressHeading, 'Service address');
    expect(contract.addressFieldLabel, 'Service address');
    expect(contract.addressHint, 'Where will the work take place?');
    expect(contract.addressRequiredMessage, 'Please add the service address.');
    expect(contract.toJson()['addressHeading'], 'Service address');
  });

  test('customer drops off resolves as an implied intake movement', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.customerDropsOff,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'intake');
    expect(
      contract.movementChoiceGroups.single.heading,
      'How would you like to get your item to us?',
    );
    expect(contract.movementChoiceGroups.single.options, hasLength(1));
    expect(
      contract.movementChoiceGroups.single.options.single.value,
      'customerDropsOff',
    );
    expect(
      contract.movementChoiceGroups.single.options.single.label,
      "I'll drop it off",
    );
    expect(contract.requireAddress, isFalse);
    expect(contract.recommendedBuiltInQuestionKeys, isNot(contains('address')));
  });

  test('business collects resolves collection address behaviour', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.businessCollects,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'intake');
    expect(
      contract.movementChoiceGroups.single.options.single.value,
      'businessCollects',
    );
    expect(
      contract.movementChoiceGroups.single.options.single.label,
      'Please collect it',
    );
    expect(contract.requireAddress, isTrue);
    expect(contract.recommendedBuiltInQuestionKeys, contains('address'));
    expect(contract.addressHeading, 'Collection address');
    expect(contract.addressFieldLabel, 'Collection address');
    expect(contract.addressHint, 'Where should the business collect from?');
    expect(
      contract.addressRequiredMessage,
      'Please add the collection address.',
    );
  });

  test('customer collects resolves as an implied completion movement', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.customerCollects,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'completion');
    expect(
      contract.movementChoiceGroups.single.heading,
      'How would you like to receive your completed item?',
    );
    expect(contract.movementChoiceGroups.single.options, hasLength(1));
    expect(
      contract.movementChoiceGroups.single.options.single.value,
      'customerCollects',
    );
    expect(
      contract.movementChoiceGroups.single.options.single.label,
      "I'll collect it",
    );
    expect(contract.requireAddress, isFalse);
    expect(contract.recommendedBuiltInQuestionKeys, isNot(contains('address')));
  });

  test('business returns resolves return address behaviour', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.businessReturns,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'completion');
    expect(
      contract.movementChoiceGroups.single.heading,
      'How would you like to receive your completed item?',
    );
    expect(contract.movementChoiceGroups.single.options, hasLength(1));
    expect(
      contract.movementChoiceGroups.single.options.single.value,
      'businessReturns',
    );
    expect(
      contract.movementChoiceGroups.single.options.single.label,
      'Please return it',
    );
    expect(contract.requireAddress, isTrue);
    expect(contract.recommendedBuiltInQuestionKeys, contains('address'));
    expect(contract.addressHeading, 'Return address');
    expect(contract.addressFieldLabel, 'Return address');
    expect(contract.addressHint, 'Where should the business return it?');
    expect(contract.addressRequiredMessage, 'Please add the return address.');
  });

  test('nationwide delivery resolves delivery address behaviour', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.nationwideDelivery,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'receive');
    expect(
      contract.movementChoiceGroups.single.heading,
      'How would you like to receive your order?',
    );
    expect(contract.movementChoiceGroups.single.options, hasLength(1));
    expect(
      contract.movementChoiceGroups.single.options.single.value,
      'nationwideDelivery',
    );
    expect(
      contract.movementChoiceGroups.single.options.single.label,
      'Nationwide delivery',
    );
    expect(contract.requireAddress, isTrue);
    expect(contract.recommendedBuiltInQuestionKeys, contains('address'));
    expect(contract.addressHeading, 'Nationwide delivery address');
    expect(contract.addressFieldLabel, 'Nationwide delivery address');
    expect(contract.addressHint, 'Where should the order be sent?');
    expect(
      contract.addressRequiredMessage,
      'Please add the nationwide delivery address.',
    );
  });

  test('resolves handover choices without trade-specific behaviour', () {
    final contract = resolveVanCapabilityContract([
      VanServiceCapabilityIds.customerDropsOff,
      VanServiceCapabilityIds.businessCollects,
    ]);

    expect(contract.movementChoiceGroups, hasLength(1));
    expect(contract.movementChoiceGroups.single.id, 'intake');
    expect(
      contract.movementChoiceGroups.single.options.map(
        (option) => option.value,
      ),
      ['customerDropsOff', 'businessCollects'],
    );
  });

  test('serializes the contract for hosted surfaces', () {
    final json = resolveVanCapabilityContract([
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.photoUpload,
      VanServiceCapabilityIds.customQuote,
    ]).toJson();

    expect(json['journeyType'], 'quote');
    expect(json['responseDocumentType'], 'quote');
    expect(json['requestPhotos'], isTrue);
    expect(json['pricingMode'], VanServiceCapabilityIds.customQuote);
  });
}
