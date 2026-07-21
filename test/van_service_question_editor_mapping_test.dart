import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/pages/van_service_question_editor_page.dart';

void main() {
  testWidgets('empty question with helper text cannot save', (tester) async {
    VanCustomJobQuestion? saved;
    await tester.pumpWidget(
      _QuestionEditorHarness(onSaved: (value) => saved = value),
    );

    await _openEditor(tester);
    await tester.enterText(
      find.byKey(const Key('service_question_helper')),
      'cup of tea',
    );
    await tester.tap(find.byKey(const Key('save_service_question')));
    await tester.pump();

    expect(find.text('New Question'), findsOneWidget);
    expect(find.text('Enter a question.'), findsOneWidget);
    expect(saved, isNull);
    expect(
      _controllerText(tester, const Key('service_question_text')),
      isEmpty,
    );
    expect(
      _controllerText(tester, const Key('service_question_helper')),
      'cup of tea',
    );
  });

  testWidgets(
    'valid question and helper save to separate trimmed model fields',
    (tester) async {
      VanCustomJobQuestion? saved;
      await tester.pumpWidget(
        _QuestionEditorHarness(onSaved: (value) => saved = value),
      );

      await _openEditor(tester);
      await tester.enterText(
        find.byKey(const Key('service_question_text')),
        '  What would you like to drink?  ',
      );
      await tester.enterText(
        find.byKey(const Key('service_question_helper')),
        '  For example, tea or coffee.  ',
      );
      await tester.tap(find.byKey(const Key('service_question_answer_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long text').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service_question_enabled')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save_service_question')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.questionText, 'What would you like to drink?');
      expect(saved!.helperText, 'For example, tea or coffee.');
      expect(saved!.questionText, isNot(saved!.helperText));
      expect(saved!.answerType, VanCustomQuestionAnswerType.longText);
      expect(saved!.isActive, isFalse);
    },
  );

  testWidgets('editing preserves correct field mapping and question settings', (
    tester,
  ) async {
    final createdAt = DateTime.utc(2026, 7, 21, 10);
    final existing = VanCustomJobQuestion(
      id: 'existing-question',
      questionText: 'Original question?',
      helperText: 'Original helper.',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.timing,
      isActive: false,
      isArchived: false,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    VanCustomJobQuestion? saved;
    await tester.pumpWidget(
      _QuestionEditorHarness(
        question: existing,
        onSaved: (value) => saved = value,
      ),
    );

    await _openEditor(tester);
    expect(find.text('Edit Question'), findsOneWidget);
    expect(
      _controllerText(tester, const Key('service_question_text')),
      existing.questionText,
    );
    expect(
      _controllerText(tester, const Key('service_question_helper')),
      existing.helperText,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<VanCustomQuestionAnswerType>>(
            find.byKey(const Key('service_question_answer_type')),
          )
          .initialValue,
      existing.answerType,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('service_question_enabled')),
          )
          .value,
      isFalse,
    );

    await tester.enterText(
      find.byKey(const Key('service_question_text')),
      '  Updated question?  ',
    );
    await tester.enterText(
      find.byKey(const Key('service_question_helper')),
      '  Updated helper.  ',
    );
    await tester.tap(find.byKey(const Key('save_service_question')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.id, existing.id);
    expect(saved!.questionText, 'Updated question?');
    expect(saved!.helperText, 'Updated helper.');
    expect(saved!.answerType, existing.answerType);
    expect(saved!.isActive, existing.isActive);
    expect(saved!.category, existing.category);
    expect(saved!.createdAt, existing.createdAt);
  });
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Open question editor'));
  await tester.pumpAndSettle();
}

String _controllerText(WidgetTester tester, Key key) =>
    tester.widget<TextFormField>(find.byKey(key)).controller!.text;

class _QuestionEditorHarness extends StatelessWidget {
  const _QuestionEditorHarness({required this.onSaved, this.question});

  final ValueChanged<VanCustomJobQuestion> onSaved;
  final VanCustomJobQuestion? question;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () async {
              final result = await editVanServiceQuestion(
                context,
                serviceId: 'test-service',
                question: question,
              );
              if (result != null) onSaved(result);
            },
            child: const Text('Open question editor'),
          ),
        ),
      ),
    ),
  );
}
