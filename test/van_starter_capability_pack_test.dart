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
  test('the seeded business and legacy service libraries are empty', () {
    expect(kVanBusinessTemplateLibrary, isEmpty);
    expect(kVanStarterCapabilityPacks, isEmpty);
    expect(kVanServiceTemplateCategories, isEmpty);
    expect(findVanStarterCapabilityPackById('courier_business'), isNull);
    expect(findVanServiceTemplateById('courier'), isNull);
    expect(searchVanStarterCapabilityPacks('courier'), isEmpty);
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
