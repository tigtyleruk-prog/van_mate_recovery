import 'package:flutter/material.dart';

import '../models/van_custom_job_question.dart';
import '../widgets/van_form_field_styles.dart';

Future<VanCustomJobQuestion?> editVanServiceQuestion(
  BuildContext context, {
  required String serviceId,
  VanCustomJobQuestion? question,
}) {
  return Navigator.of(context).push<VanCustomJobQuestion>(
    MaterialPageRoute<VanCustomJobQuestion>(
      builder: (_) => _VanServiceQuestionEditorPage(
        serviceId: serviceId,
        question: question,
      ),
    ),
  );
}

class _VanServiceQuestionEditorPage extends StatefulWidget {
  const _VanServiceQuestionEditorPage({required this.serviceId, this.question});

  final String serviceId;
  final VanCustomJobQuestion? question;

  @override
  State<_VanServiceQuestionEditorPage> createState() =>
      _VanServiceQuestionEditorPageState();
}

class _VanServiceQuestionEditorPageState
    extends State<_VanServiceQuestionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _helperController;
  late final TextEditingController _choicesController;
  late VanCustomQuestionAnswerType _answerType;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(
      text: widget.question?.questionText ?? '',
    );
    _helperController = TextEditingController(
      text: widget.question?.helperText ?? '',
    );
    _choicesController = TextEditingController(
      text: widget.question?.choiceOptions.join('\n') ?? '',
    );
    _answerType =
        widget.question?.answerType ?? VanCustomQuestionAnswerType.shortText;
    _active = widget.question?.isActive ?? true;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _helperController.dispose();
    _choicesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final questionText = _questionController.text.trim();
    final helperText = _helperController.text.trim();
    final now = DateTime.now();
    final existing = widget.question;
    final choiceOptions =
        _answerType == VanCustomQuestionAnswerType.multipleChoice
        ? _choicesController.text
              .split(RegExp(r'[\r\n,]+'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : const <String>[];
    if (_answerType == VanCustomQuestionAnswerType.multipleChoice &&
        choiceOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least two answer options.')),
      );
      return;
    }
    final normalizedServiceId = widget.serviceId.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '_',
    );
    Navigator.of(context).pop(
      VanCustomJobQuestion(
        id:
            existing?.id ??
            'service_question_${normalizedServiceId}_${now.microsecondsSinceEpoch}',
        questionText: questionText,
        helperText: helperText,
        answerType: _answerType,
        category: existing?.category,
        choiceOptions: choiceOptions,
        isActive: _active,
        isArchived: false,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.question == null ? 'New Question' : 'Edit Question'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('service_question_text'),
              controller: _questionController,
              decoration: vanMateFieldDecoration(label: 'Question'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a question.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('service_question_helper'),
              controller: _helperController,
              decoration: vanMateFieldDecoration(
                label: 'Helper text',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<VanCustomQuestionAnswerType>(
              key: const Key('service_question_answer_type'),
              initialValue: _answerType,
              isExpanded: true,
              decoration: vanMateFieldDecoration(label: 'Answer type'),
              items: [
                for (final type in VanCustomQuestionAnswerType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _answerType = value);
                }
              },
            ),
            if (_answerType == VanCustomQuestionAnswerType.multipleChoice) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _choicesController,
                minLines: 3,
                maxLines: 6,
                decoration: vanMateFieldDecoration(
                  label: 'Answer options',
                  hintText: 'Enter one option per line',
                ),
              ),
            ],
            SwitchListTile.adaptive(
              key: const Key('service_question_enabled'),
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: const Text('Enabled'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('save_service_question'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save question'),
            ),
          ],
        ),
      ),
    );
  }
}
