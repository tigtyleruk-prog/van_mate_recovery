import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_customer_request_questions.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_template.dart';

void main() {
  test('template services ship with their own starter questions', () {
    final bakery = findVanServiceTemplateById('bakery')!;
    final courier = findVanServiceTemplateById('courier')!;

    expect(
      bakery.questions.map((question) => question.text),
      containsAll(<String>[
        'What would you like to order?',
        'Quantity',
        'Allergies or dietary notes?',
        'Anything else about your order?',
      ]),
    );
    expect(
      courier.questions.map((question) => question.text),
      containsAll(<String>[
        'Collection address',
        'Delivery address',
        'Parcel size',
        'Fragile item?',
        'Same-day delivery needed?',
      ]),
    );
  });

  test(
    'pet sitting template keeps care questions without logistics duplicates',
    () {
      final petSitting = findVanServiceTemplateById('pet_sitting')!;
      final texts = petSitting.questions.map((question) => question.text);

      expect(
        texts,
        containsAll(<String>[
          'Pet or dog name',
          'Breed or type',
          'Feeding notes',
          'Medication notes',
          'Emergency contact',
          'Any special requirements?',
        ]),
      );
      expect(texts, isNot(contains('Event date')));
      expect(texts, isNot(contains('Event time')));
      expect(texts, isNot(contains('Location')));
    },
  );

  test('custom service starts with no linked questions', () {
    final service = _service(id: 'custom-service', linkedIds: const <String>[]);
    expect(service.linkedQuestionIds, isEmpty);
  });

  test('service request flow uses template-aware safe defaults', () {
    expect(
      defaultVanCustomerRequestTypeForService(
        serviceId: 'bakery',
        serviceName: 'Bakery',
      ),
      VanCustomerRequestType.orderRequest,
    );
    expect(
      defaultVanCustomerRequestTypeForService(
        serviceId: 'courier',
        serviceName: 'Courier',
      ),
      VanCustomerRequestType.pickupDeliveryRequest,
    );
    expect(
      defaultVanCustomerRequestTypeForService(
        serviceId: 'cleaning',
        serviceName: 'Cleaning',
      ),
      VanCustomerRequestType.bookingRequest,
    );
    expect(
      defaultVanCustomerRequestTypeForService(
        serviceId: 'custom-service',
        serviceName: 'My custom work',
      ),
      VanCustomerRequestType.quoteRequest,
    );
  });

  test('legacy journey request types serialize as standard service flow', () {
    final orderService = _service(
      id: 'bakery',
      linkedIds: const <String>[],
    ).copyWith(requestType: VanCustomerRequestType.orderRequest);
    expect(
      VanJobService.fromJson(orderService.toJson()).requestType,
      VanCustomerRequestType.quoteRequest,
    );

    final legacyJson = orderService.toJson()
      ..remove('requestType')
      ..remove('serviceFlow');
    expect(
      VanJobService.fromJson(legacyJson).requestType,
      VanCustomerRequestType.quoteRequest,
    );
  });

  test(
    'flow options survive serialization and missing options use defaults',
    () {
      final options = VanCustomerRequestFlowOptions.defaultsFor(
        VanCustomerRequestType.orderRequest,
      ).copyWith(askPreferredTime: false);
      final restored = VanJobService.fromJson(
        _service(id: 'bakery', linkedIds: const <String>[])
            .copyWith(
              requestType: VanCustomerRequestType.orderRequest,
              requestFlowOptions: options,
            )
            .toJson(),
      );

      expect(
        restored.effectiveRequestFlowOptions.showFulfilmentChoice,
        isFalse,
      );
      expect(restored.effectiveRequestFlowOptions.askPreferredTime, isFalse);

      final legacyJson = restored.toJson()..remove('requestFlowOptions');
      final legacyRestored = VanJobService.fromJson(legacyJson);
      expect(
        legacyRestored.effectiveRequestFlowOptions.showFulfilmentChoice,
        isFalse,
      );
      expect(
        legacyRestored.effectiveRequestFlowOptions.askPreferredDate,
        isTrue,
      );
    },
  );

  test('new template services skip questions covered by built-in blocks', () {
    expect(
      isVanCustomerRequestBuiltInQuestion(
        VanCustomerRequestType.orderRequest,
        'Collection or delivery?',
      ),
      isFalse,
    );
    expect(
      isVanCustomerRequestBuiltInQuestion(
        VanCustomerRequestType.pickupDeliveryRequest,
        'Delivery address',
      ),
      isTrue,
    );
    expect(
      isVanCustomerRequestBuiltInQuestion(
        VanCustomerRequestType.orderRequest,
        'Allergies or dietary notes?',
      ),
      isFalse,
    );
    expect(
      isVanCustomerRequestBuiltInQuestion(
        VanCustomerRequestType.dropOffPickupRequest,
        'Event date',
      ),
      isTrue,
    );
    expect(
      isVanCustomerRequestBuiltInQuestion(
        VanCustomerRequestType.dropOffPickupRequest,
        'Event time',
      ),
      isTrue,
    );
    expect(
      isVanCustomerRequestBuiltInQuestion(
        VanCustomerRequestType.dropOffPickupRequest,
        'Location',
      ),
      isTrue,
    );
  });

  test('public flow hides only seeded drop-off logistics duplicates', () {
    final service = _service(id: 'pet_sitting', linkedIds: const <String>[])
        .copyWith(
          requestType: VanCustomerRequestType.dropOffPickupRequest,
          requestFlowOptions: VanCustomerRequestFlowOptions.defaultsFor(
            VanCustomerRequestType.dropOffPickupRequest,
          ),
        );
    final seededEventDate = _question(
      'service_template_pet_sitting_1_seed',
      'Event date?',
    );
    final customEventDate = _question('custom-event-date', 'Event date');
    final usefulPetQuestion = _question(
      'service_template_pet_sitting_2_seed',
      'Medication notes',
    );

    expect(
      isVanSeededQuestionCoveredByBuiltInFlow(
        service: service,
        question: seededEventDate,
      ),
      isTrue,
    );
    expect(
      isVanSeededQuestionCoveredByBuiltInFlow(
        service: service,
        question: customEventDate,
      ),
      isFalse,
    );
    expect(
      isVanSeededQuestionCoveredByBuiltInFlow(
        service: service,
        question: usefulPetQuestion,
      ),
      isFalse,
    );
  });

  test('photo helper wording does not infer journey from service flow', () {
    final labels = VanCustomerRequestType.values
        .map(vanBookingPhotoHelperText)
        .toSet();
    expect(labels, hasLength(1));
  });

  test(
    'hosted booking link mirrors seeded filtering and mobile time safety',
    () {
      final source = File('web/booking_link.html').readAsStringSync();
      final functionsSource = File('functions/index.js').readAsStringSync();

      expect(source, contains('text === "event date"'));
      expect(source, contains('text === "event time"'));
      expect(source, contains('text === "location"'));
      expect(source, contains('id.startsWith("service_template_")'));
      expect(source, contains('input[type="time"]'));
      expect(source, contains('min-inline-size: 0'));
      expect(source, contains('bookingPhotoHelperText'));
      expect(functionsSource, contains("text === 'event date'"));
      expect(functionsSource, contains("text === 'event time'"));
      expect(functionsSource, contains("text === 'location'"));
    },
  );

  test('New Job selection uses only ordered enabled service links', () {
    final questions = <VanCustomJobQuestion>[
      _question('reusable-a', 'Reusable A'),
      _question('service-b', 'Service B'),
      _question('service-c', 'Service C'),
      _question('other-service', 'Other service'),
    ];
    final lookup = buildVanCustomerRequestQuestionLookup(questions);
    final selected = _service(
      id: 'bakery',
      linkedIds: const <String>['service-c', 'reusable-a', 'service-b'],
      disabledIds: const <String>['service-b'],
    );

    expect(buildVanServiceDefaultQuestionIds(selected, lookup), <String>[
      'service-c',
      'reusable-a',
    ]);
    expect(
      buildVanServiceDefaultQuestionIds(
        _service(id: 'courier', linkedIds: const <String>['other-service']),
        lookup,
      ),
      <String>['other-service'],
    );
  });

  test('service question order and disabled state survive serialization', () {
    final restored = VanJobService.fromJson(
      _service(
        id: 'bakery',
        linkedIds: const <String>['q3', 'q1', 'q2'],
        disabledIds: const <String>['q1'],
      ).toJson(),
    );

    expect(restored.linkedQuestionIds, <String>['q3', 'q1', 'q2']);
    expect(restored.disabledLinkedQuestionIds, <String>['q1']);
  });

  test('service question remains attached only to its service', () {
    final bakeryQuestion = _question(
      'service_question_bakery_1',
      'Allergies or dietary notes?',
    );
    final bakery = _service(
      id: 'bakery',
      linkedIds: <String>[bakeryQuestion.id],
    );
    final courier = _service(id: 'courier', linkedIds: const <String>[]);

    expect(bakeryQuestion.isActive, isTrue);
    expect(bakery.linkedQuestionIds, contains(bakeryQuestion.id));
    expect(courier.linkedQuestionIds, isNot(contains(bakeryQuestion.id)));
  });

  test('question library metadata is additive and backwards compatible', () {
    final now = DateTime(2026, 7, 21);
    final question = VanCustomJobQuestion(
      id: 'q-access',
      questionText: 'Are there any access restrictions?',
      helperText: '',
      libraryQuestionId: 'transport.access.restrictions',
      tags: const <String>['access', 'transport'],
      answerType: VanCustomQuestionAnswerType.longText,
      category: VanCustomQuestionCategory.access,
      isActive: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    final restored = VanCustomJobQuestion.fromJson(question.toJson());
    expect(restored.libraryQuestionId, 'transport.access.restrictions');
    expect(restored.tags, <String>['access', 'transport']);

    final legacy = VanCustomJobQuestion.fromJson(<String, dynamic>{
      'id': 'legacy-question',
      'questionText': 'Legacy wording',
      'answerType': 'short_text',
      'isActive': true,
      'isArchived': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    expect(legacy.libraryQuestionId, isEmpty);
    expect(legacy.tags, isEmpty);
  });

  test('New Job no longer imports or reads the legacy default pack', () {
    final source = File(
      'lib/features/van_mate/pages/create_job_request_flow.dart',
    ).readAsStringSync();
    final hub = File(
      'lib/features/van_mate/pages/business_hub_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('VanDefaultNewJobQuestionsStorage')));
    expect(source, isNot(contains('openVanCustomJobQuestionsPage')));
    expect(hub, isNot(contains("title: 'Custom Job Questions'")));
  });

  test('service management no longer exposes a shared question picker', () {
    final servicesPage = File(
      'lib/features/van_mate/pages/van_job_types_services_page.dart',
    ).readAsStringSync();
    final requestQuestions = File(
      'lib/features/van_mate/helpers/van_customer_request_questions.dart',
    ).readAsStringSync();
    final bookingLink = File(
      'lib/features/van_mate/pages/van_booking_link_page.dart',
    ).readAsStringSync();

    expect(servicesPage, isNot(contains('pickVanServiceQuestionIds')));
    expect(servicesPage, isNot(contains('VanPrefilledJobQuestions.all')));
    expect(requestQuestions, isNot(contains('VanPrefilledJobQuestions.all')));
    expect(bookingLink, isNot(contains('VanPrefilledJobQuestions.all')));
    expect(
      File(
        'lib/features/van_mate/models/van_prefilled_job_questions.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('service settings expose independent journey and flow selectors', () {
    final source = File(
      'lib/features/van_mate/pages/van_job_types_services_page.dart',
    ).readAsStringSync();

    expect(source, contains("'Customer journey'"));
    expect(source, contains("label: 'Service flow'"));
    expect(
      source,
      contains("'Choose how customers buy or request this service.'"),
    );
    expect(source, contains("'Choose how this service is carried out.'"));
    expect(source, contains("'Booking options'"));
    expect(source, contains('kVanServiceFlows'));
    expect(source, isNot(contains('ReorderableListView<CustomerRequest')));
  });
}

VanJobService _service({
  required String id,
  required List<String> linkedIds,
  List<String> disabledIds = const <String>[],
}) {
  final now = DateTime(2026, 7, 11);
  return VanJobService(
    id: id,
    name: id,
    description: '',
    isActive: true,
    requestPhotos: false,
    requireAddress: true,
    requestExactPinAfterQuoteAccepted: false,
    linkedQuestionIds: linkedIds,
    disabledLinkedQuestionIds: disabledIds,
    quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
    createdAt: now,
    updatedAt: now,
  );
}

VanCustomJobQuestion _question(String id, String text) {
  final now = DateTime(2026, 7, 11);
  return VanCustomJobQuestion(
    id: id,
    questionText: text,
    answerType: VanCustomQuestionAnswerType.shortText,
    isActive: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}
