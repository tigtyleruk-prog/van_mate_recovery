import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:van_mate_app/features/van_mate/helpers/van_customer_request_questions.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_default_new_job_question_set.dart';
import 'package:van_mate_app/features/van_mate/models/van_prefilled_job_questions.dart';
import 'package:van_mate_app/features/van_mate/services/van_default_new_job_questions_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starter set falls back when nothing is saved', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = VanDefaultNewJobQuestionsStorage.instance;

    final questions = await storage.loadQuestions();

    expect(questions, VanDefaultNewJobQuestionSet.starterQuestions);
  });

  test('saved questions stay empty when no default pack exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = VanDefaultNewJobQuestionsStorage.instance;

    final questions = await storage.loadSavedQuestions();

    expect(questions, isEmpty);
  });

  test('question texts resolve to ids and manual extras', () {
    final lookup = buildVanCustomerRequestQuestionLookup(<VanCustomJobQuestion>[
      ...VanPrefilledJobQuestions.all,
    ]);

    final resolved = resolveVanQuestionTextsForSelection(<String>[
      'Can the van park close to the door?',
      'Custom loading note',
      'What needs collecting or delivering?',
    ], lookup);

    expect(
      resolved.selectedQuestionIds,
      contains('prefill_parking_close_to_door'),
    );
    expect(
      resolved.selectedQuestionIds,
      contains('prefill_job_what_needs_doing'),
    );
    expect(resolved.manualQuestions, <String>['Custom loading note']);
  });
}
