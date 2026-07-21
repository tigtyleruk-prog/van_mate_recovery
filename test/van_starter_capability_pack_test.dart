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
  test('only the first curated Courier pack is installed', () {
    expect(kVanBusinessTemplateLibrary, hasLength(1));
    expect(kVanStarterCapabilityPacks, hasLength(1));
    expect(kVanServiceTemplateCategories, isEmpty);
    expect(findVanStarterCapabilityPackById('courier'), isNotNull);
    expect(findVanStarterCapabilityPackById('courier_business'), isNull);
    expect(findVanServiceTemplateById('courier'), isNull);
    expect(searchVanStarterCapabilityPacks('courier'), hasLength(1));

    final definition = kVanBusinessTemplateLibrary.single;
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

  test('generic capabilities do not reinterpret legacy services as delivery', () {
    final resolved = resolveVanServiceCapabilities(<String>{
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.businessCollects,
      VanServiceCapabilityIds.localDelivery,
    });

    expect(resolved.requestType, VanCustomerRequestType.quoteRequest);
    expect(resolved.allowBusinessDelivery, isFalse);
  });

  test('Courier services keep explicit delivery journeys and curated data', () {
    final services = kVanBusinessTemplateLibrary.single.services;
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
