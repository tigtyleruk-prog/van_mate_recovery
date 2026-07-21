import '../models/van_custom_job_question.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_job_request_record.dart';
import '../models/van_job_service.dart';
import 'van_text_formatters.dart';

const String kVanManualQuestionIdPrefix = 'new_job_manual_';

class VanQuestionSelectionResolution {
  const VanQuestionSelectionResolution({
    required this.selectedQuestionIds,
    required this.manualQuestions,
  });

  final List<String> selectedQuestionIds;
  final List<String> manualQuestions;
}

String _normalizeVanQuestionText(String value) {
  return sanitizeVanText(
    value,
  ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

Map<String, VanCustomJobQuestion> buildVanCustomerRequestQuestionLookup(
  List<VanCustomJobQuestion> customQuestions,
) {
  return <String, VanCustomJobQuestion>{
    for (final question in customQuestions) question.id: question,
  };
}

List<String> buildVanServiceDefaultQuestionIds(
  VanJobService? service,
  Map<String, VanCustomJobQuestion> questionLookup,
) {
  if (service == null) {
    return const <String>[];
  }

  final selected = <String>[];
  final disabledIds = service.disabledLinkedQuestionIds.toSet();
  for (final rawId in service.linkedQuestionIds) {
    final id = rawId.trim();
    if (id.isEmpty ||
        !questionLookup.containsKey(id) ||
        disabledIds.contains(id)) {
      continue;
    }
    final question = questionLookup[id]!;
    if (!question.isActive || question.isArchived) {
      continue;
    }
    if (!selected.contains(id)) {
      selected.add(id);
    }
  }
  return List<String>.unmodifiable(selected);
}

String vanBookingPhotoHelperText(VanCustomerRequestType requestType) {
  return 'Add photos if they help explain the item, pet, access, parking, condition, or anything the business should know.';
}

VanQuestionSelectionResolution resolveVanQuestionTextsForSelection(
  Iterable<String> questionTexts,
  Map<String, VanCustomJobQuestion> questionLookup,
) {
  final idsByText = <String, String>{};
  for (final question in questionLookup.values) {
    final normalizedText = _normalizeVanQuestionText(question.questionText);
    if (normalizedText.isNotEmpty) {
      idsByText.putIfAbsent(normalizedText, () => question.id);
    }
  }

  final selectedQuestionIds = <String>[];
  final manualQuestions = <String>[];
  final usedIds = <String>{};
  final usedManualTexts = <String>{};

  for (final rawText in questionTexts) {
    final cleanedText = sanitizeVanText(
      rawText,
    ).trim().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedText = _normalizeVanQuestionText(cleanedText);
    if (normalizedText.isEmpty) {
      continue;
    }

    final matchedId = idsByText[normalizedText];
    if (matchedId != null) {
      if (usedIds.add(matchedId)) {
        selectedQuestionIds.add(matchedId);
      }
      continue;
    }

    if (usedManualTexts.add(normalizedText)) {
      manualQuestions.add(cleanedText);
    }
  }

  return VanQuestionSelectionResolution(
    selectedQuestionIds: List<String>.unmodifiable(selectedQuestionIds),
    manualQuestions: List<String>.unmodifiable(manualQuestions),
  );
}

String buildVanManualQuestionId(String questionText) {
  final normalized = questionText
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (normalized.isEmpty) {
    return '${kVanManualQuestionIdPrefix}question';
  }
  return '$kVanManualQuestionIdPrefix$normalized';
}

List<VanJobRequestAnswer> buildVanRequestAnswersFromSelection({
  required List<String> selectedQuestionIds,
  required List<String> manualQuestions,
  required Map<String, VanCustomJobQuestion> questionLookup,
}) {
  final answers = <VanJobRequestAnswer>[];
  final usedIds = <String>{};

  for (final rawId in selectedQuestionIds) {
    final id = rawId.trim();
    if (id.isEmpty || usedIds.contains(id)) {
      continue;
    }
    final question = questionLookup[id];
    if (question == null || !question.isActive || question.isArchived) {
      continue;
    }
    usedIds.add(id);
    answers.add(
      VanJobRequestAnswer(
        questionId: question.id,
        questionText: question.questionText.trim(),
        answerType: question.answerType.storageKey,
        category: question.category?.storageKey ?? '',
        answerValue: '',
        order: answers.length,
      ),
    );
  }

  for (final rawQuestion in manualQuestions) {
    final questionText = rawQuestion.trim();
    if (questionText.isEmpty) {
      continue;
    }
    final manualId = buildVanManualQuestionId(questionText);
    if (usedIds.contains(manualId)) {
      continue;
    }
    usedIds.add(manualId);
    answers.add(
      VanJobRequestAnswer(
        questionId: manualId,
        questionText: questionText,
        answerType: VanCustomQuestionAnswerType.shortText.storageKey,
        category: VanCustomQuestionCategory.other.storageKey,
        answerValue: '',
        order: answers.length,
      ),
    );
  }

  return List<VanJobRequestAnswer>.unmodifiable(answers);
}

List<String> buildVanLegacyChecklistItemsFromAnswers(
  List<VanJobRequestAnswer> answers,
) {
  return List<String>.unmodifiable(
    answers
        .where(
          (answer) =>
              answer.answerType == VanCustomQuestionAnswerType.yesNo.storageKey,
        )
        .map((answer) => answer.questionText.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false),
  );
}

List<String> buildVanLegacyCustomQuestionsFromAnswers(
  List<VanJobRequestAnswer> answers,
) {
  return List<String>.unmodifiable(
    answers
        .where(
          (answer) =>
              answer.answerType != VanCustomQuestionAnswerType.yesNo.storageKey,
        )
        .map((answer) => answer.questionText.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false),
  );
}
