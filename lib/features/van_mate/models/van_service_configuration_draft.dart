import 'van_custom_job_question.dart';
import 'van_job_service.dart';

enum VanServiceConfigurationStage { features, questions, extras, availability }

enum VanServiceConfigurationMode {
  onboarding,
  existing,
  duplicate,
  resumedDraft,
}

class VanServiceConfigurationDraft {
  VanServiceConfigurationDraft({
    required this.businessProfileId,
    required this.mode,
    required this.originalService,
    required this.service,
    required Map<String, VanCustomJobQuestion> originalQuestions,
    required Map<String, VanCustomJobQuestion> questions,
  }) : originalQuestions = Map<String, VanCustomJobQuestion>.unmodifiable(
         originalQuestions,
       ),
       questions = Map<String, VanCustomJobQuestion>.unmodifiable(questions);

  factory VanServiceConfigurationDraft.existing({
    required String businessProfileId,
    required VanJobService service,
    required Map<String, VanCustomJobQuestion> questions,
  }) {
    return VanServiceConfigurationDraft(
      businessProfileId: businessProfileId,
      mode: service.isDraft
          ? VanServiceConfigurationMode.resumedDraft
          : VanServiceConfigurationMode.existing,
      originalService: service,
      service: service,
      originalQuestions: questions,
      questions: questions,
    );
  }

  final String businessProfileId;
  final VanServiceConfigurationMode mode;
  final VanJobService? originalService;
  final VanJobService service;
  final Map<String, VanCustomJobQuestion> originalQuestions;
  final Map<String, VanCustomJobQuestion> questions;

  bool get isExisting => originalService != null;

  bool get isDirty {
    if (originalService?.toJson().toString() != service.toJson().toString()) {
      return true;
    }
    if (originalQuestions.length != questions.length) return true;
    for (final entry in questions.entries) {
      if (originalQuestions[entry.key]?.toJson().toString() !=
          entry.value.toJson().toString()) {
        return true;
      }
    }
    return false;
  }

  VanServiceConfigurationDraft copyWith({
    VanJobService? service,
    Map<String, VanCustomJobQuestion>? questions,
  }) {
    return VanServiceConfigurationDraft(
      businessProfileId: businessProfileId,
      mode: mode,
      originalService: originalService,
      service: service ?? this.service,
      originalQuestions: originalQuestions,
      questions: questions ?? this.questions,
    );
  }
}
