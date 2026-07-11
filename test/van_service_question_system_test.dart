import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_customer_request_questions.dart';
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
        'Collection or delivery?',
        'Preferred date',
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

  test('custom service starts with no linked questions', () {
    final service = _service(id: 'custom-service', linkedIds: const <String>[]);
    expect(service.linkedQuestionIds, isEmpty);
  });

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
