import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/controllers/van_service_configuration_controller.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_configuration_draft.dart';
import 'package:van_mate_app/features/van_mate/services/van_custom_job_questions_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_service_configuration_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('controller keeps one draft per service and advances four stages', () {
    final first = _draft(_service('first'));
    final second = _draft(_service('second'));
    final controller = VanServiceConfigurationController(
      drafts: <VanServiceConfigurationDraft>[first, second],
    );

    controller.replaceService(first.service.copyWith(noticeHours: 12));
    expect(controller.activeDraft.service.noticeHours, 12);
    expect(controller.drafts[1].service.noticeHours, 24);

    expect(controller.stage, VanServiceConfigurationStage.features);
    expect(controller.moveNext(), isTrue);
    expect(controller.stage, VanServiceConfigurationStage.questions);
    expect(controller.moveNext(), isTrue);
    expect(controller.stage, VanServiceConfigurationStage.extras);
    expect(controller.moveNext(), isTrue);
    expect(controller.stage, VanServiceConfigurationStage.availability);
    expect(controller.moveNext(), isTrue);
    expect(controller.serviceIndex, 1);
    expect(controller.stage, VanServiceConfigurationStage.features);
  });

  test('repository loads the complete service and linked questions', () async {
    final service = _service('loaded').copyWith(
      description: 'Saved description',
      workingDays: const <int>[2, 4],
      availabilityByDay: const <int, VanServiceDaySchedule>{
        2: VanServiceDaySchedule(startMinutes: 600, endMinutes: 1200),
        4: VanServiceDaySchedule(startMinutes: 540, endMinutes: 1020),
      },
    );
    final question = _question('loaded-question');
    await VanCustomJobQuestionsStorage.instance.saveAll(<VanCustomJobQuestion>[
      question,
    ], syncCloud: false);
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      service,
    ], syncCloud: false);

    final draft = await VanServiceConfigurationRepository().loadExisting(
      service.id,
    );

    expect(draft.service.toJson(), service.toJson());
    expect(draft.questions[question.id]?.toJson(), question.toJson());
    expect(draft.isDirty, isFalse);
  });

  test('repository save changes only the selected service', () async {
    final selected = _service('selected');
    final other = _service('other');
    final otherBefore = other.toJson();
    final question = _question('selected-question');
    await VanCustomJobQuestionsStorage.instance.saveAll(<VanCustomJobQuestion>[
      question,
    ], syncCloud: false);
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      selected,
      other,
    ], syncCloud: false);
    final repository = VanServiceConfigurationRepository();
    final draft = await repository.loadExisting(selected.id);

    await repository.commit(
      draft.copyWith(service: draft.service.copyWith(noticeHours: 48)),
    );

    final stored = await VanJobServicesStorage.instance.loadAll();
    expect(
      stored.singleWhere((item) => item.id == selected.id).noticeHours,
      48,
    );
    expect(
      stored.singleWhere((item) => item.id == other.id).toJson(),
      otherBefore,
    );
  });

  test('new session commits all drafts together after configuration', () async {
    final existing = _service('existing');
    final first = _service('new-first').copyWith(isActive: false);
    final second = _service('new-second').copyWith(isActive: false);
    final question = _question('new-first-question');
    await VanJobServicesStorage.instance.saveAll(<VanJobService>[
      existing,
    ], syncCloud: false);

    await VanServiceConfigurationRepository().commitNewSession(
      businessProfileId: 'default_business',
      services: <VanJobService>[first, second],
      questions: <String, VanCustomJobQuestion>{question.id: question},
    );

    final stored = await VanJobServicesStorage.instance.loadAll();
    expect(
      stored.map((service) => service.id),
      containsAll(<String>[existing.id, first.id, second.id]),
    );
    expect(
      stored.where((service) => service.id != existing.id),
      everyElement(predicate<VanJobService>((service) => service.isActive)),
    );
    expect(
      (await VanCustomJobQuestionsStorage.instance.loadAll()).map(
        (item) => item.id,
      ),
      contains(question.id),
    );
  });
}

VanServiceConfigurationDraft _draft(VanJobService service) {
  final question = _question('${service.id}-question');
  return VanServiceConfigurationDraft.existing(
    businessProfileId: 'default_business',
    service: service,
    questions: <String, VanCustomJobQuestion>{question.id: question},
  );
}

VanJobService _service(String id) {
  final now = DateTime.utc(2026, 7, 21);
  return VanJobService(
    id: id,
    name: 'Service $id',
    description: 'Saved service',
    isActive: true,
    requestPhotos: true,
    requireAddress: true,
    requestExactPinAfterQuoteAccepted: false,
    linkedQuestionIds: <String>['$id-question'],
    quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
    createdAt: now,
    updatedAt: now,
  );
}

VanCustomJobQuestion _question(String id) {
  final now = DateTime.utc(2026, 7, 21);
  return VanCustomJobQuestion(
    id: id,
    questionText: 'Saved question $id',
    helperText: 'Saved helper',
    answerType: VanCustomQuestionAnswerType.longText,
    isActive: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}
