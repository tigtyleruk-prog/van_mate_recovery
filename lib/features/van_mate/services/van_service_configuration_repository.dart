import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_service_configuration_draft.dart';
import 'van_business_profile_scope_storage.dart';
import 'van_custom_job_questions_storage.dart';
import 'van_job_services_storage.dart';

class VanServiceConfigurationConflict implements Exception {
  const VanServiceConfigurationConflict(this.message);

  final String message;

  @override
  String toString() => message;
}

class VanServiceConfigurationRepository {
  VanServiceConfigurationRepository({
    VanJobServicesStorage? services,
    VanCustomJobQuestionsStorage? questions,
    VanBusinessProfileScopeStorage? businessScope,
  }) : _services = services ?? VanJobServicesStorage.instance,
       _questions = questions ?? VanCustomJobQuestionsStorage.instance,
       _businessScope =
           businessScope ?? VanBusinessProfileScopeStorage.instance;

  final VanJobServicesStorage _services;
  final VanCustomJobQuestionsStorage _questions;
  final VanBusinessProfileScopeStorage _businessScope;

  Future<VanServiceConfigurationDraft> loadExisting(String serviceId) async {
    final businessProfileId = await _businessScope.activeBusinessId();
    final services = await _services.loadAll();
    final service = services.where((item) => item.id == serviceId).firstOrNull;
    if (service == null) {
      throw StateError('Service could not be found.');
    }
    final allQuestions = await _questions.loadAll();
    final linkedIds = service.linkedQuestionIds.toSet();
    final linkedQuestions = <String, VanCustomJobQuestion>{
      for (final question in allQuestions)
        if (linkedIds.contains(question.id)) question.id: question,
    };
    return VanServiceConfigurationDraft.existing(
      businessProfileId: businessProfileId,
      service: service,
      questions: linkedQuestions,
    );
  }

  Future<void> commit(VanServiceConfigurationDraft draft) async {
    final activeBusinessId = await _businessScope.activeBusinessId();
    if (activeBusinessId != draft.businessProfileId) {
      throw const VanServiceConfigurationConflict(
        'The active business changed while this service was being edited.',
      );
    }

    final allServices = await _services.loadAll();
    final original = draft.originalService;
    if (original != null) {
      final current = allServices
          .where((service) => service.id == original.id)
          .firstOrNull;
      if (current == null) {
        throw const VanServiceConfigurationConflict(
          'This service was deleted while it was being edited.',
        );
      }
      if (current.updatedAt != original.updatedAt) {
        throw const VanServiceConfigurationConflict(
          'This service changed elsewhere. Reload it before saving.',
        );
      }
    }

    final allQuestions = await _questions.loadAll();
    final mergedQuestions = <String, VanCustomJobQuestion>{
      for (final question in allQuestions) question.id: question,
      ...draft.questions,
    };
    await _questions.saveAll(mergedQuestions.values.toList());

    final savedService = draft.service.copyWith(
      isDraft: false,
      updatedAt: DateTime.now(),
    );
    await _services.upsert(savedService);

    final oldIds = draft.originalQuestions.keys.toSet();
    final removedIds = oldIds.difference(
      savedService.linkedQuestionIds.toSet(),
    );
    if (removedIds.isEmpty) return;

    final savedServices = await _services.loadAll();
    final stillLinkedIds = <String>{
      for (final service in savedServices) ...service.linkedQuestionIds,
    };
    mergedQuestions.removeWhere(
      (id, _) => removedIds.contains(id) && !stillLinkedIds.contains(id),
    );
    await _questions.saveAll(mergedQuestions.values.toList());
  }

  Future<void> commitNewSession({
    required String businessProfileId,
    required List<VanJobService> services,
    required Map<String, VanCustomJobQuestion> questions,
  }) async {
    if (services.isEmpty) return;
    final activeBusinessId = await _businessScope.activeBusinessId();
    if (activeBusinessId != businessProfileId) {
      throw const VanServiceConfigurationConflict(
        'The active business changed while these services were being configured.',
      );
    }

    final existingServices = await _services.loadAll();
    final existingIds = existingServices.map((service) => service.id).toSet();
    if (services.any((service) => existingIds.contains(service.id))) {
      throw const VanServiceConfigurationConflict(
        'One of these services was created elsewhere. Reload before saving.',
      );
    }

    final existingQuestions = await _questions.loadAll();
    final mergedQuestions = <String, VanCustomJobQuestion>{
      for (final question in existingQuestions) question.id: question,
      ...questions,
    };
    await _questions.saveAll(mergedQuestions.values.toList());

    final now = DateTime.now();
    final completedServices = <VanJobService>[
      for (final service in services)
        service.copyWith(isDraft: false, isActive: true, updatedAt: now),
    ];
    await _services.saveAll(<VanJobService>[
      ...completedServices,
      ...existingServices,
    ]);
  }
}
